import 'package:ai_assistant/ai_assistant.dart';

import '../planning/deterministic_planner.dart';
import 'egyptian_nlu_analyzer.dart';
import 'user_energy_preferences.dart';

enum PlanningPhase {
  none,
  awaitingConstraints,
  awaitingConfirmation,
  verifyingBeforeApply,
}

class PlanningSessionState {
  PlanningSessionState({
    required this.conversationId,
    required this.now,
    this.phase = PlanningPhase.none,
    this.rawTasks = const [],
    this.availableWindows = const [],
    this.fixedCommitments = const [],
    this.preferredPeriod,
    this.breakMinutes = 0,
    this.proposal,
    this.planVersion = 0,
  });

  final String conversationId;
  DateTime now;
  PlanningPhase phase;
  List<Map<String, dynamic>> rawTasks;
  List<TimeWindow> availableWindows;
  List<TimeWindow> fixedCommitments;
  String? preferredPeriod;
  int breakMinutes;
  ScheduleProposal? proposal;
  int planVersion;

  bool get isActive => phase != PlanningPhase.none;
}

class PlanningTurnDecision {
  const PlanningTurnDecision({
    this.reply,
    this.updateCalls = const [],
  });

  final LlmReply? reply;
  final List<ToolCall> updateCalls;
}

/// Manages multi-turn interactive planning Q&A, draft generation, user revision,
/// diffing, `inputHash` invalidation on task drift, and explicit confirmation.
class PlanningCoordinator {
  PlanningCoordinator({
    DeterministicSchedulePlanner? planner,
    required this.nlu,
    this.languageCodeProvider,
  }) : _planner = planner ?? const DeterministicSchedulePlanner();

  final DeterministicSchedulePlanner _planner;
  final EgyptianNluAnalyzer nlu;
  final String Function()? languageCodeProvider;
  final Map<String, PlanningSessionState> _sessions = {};

  bool get _isEnglish =>
      (languageCodeProvider?.call() ?? 'ar').toLowerCase().startsWith('en');

  String get _langCode => _isEnglish ? 'en' : 'ar';

  PlanningSessionState? sessionFor(String conversationId) =>
      _sessions[conversationId];

  void clearSession(String conversationId) {
    _sessions.remove(conversationId);
  }

  /// Starts planning after initial `get_tasks` / `get_schedule` tool results return.
  String handleFetchedTasks({
    required String conversationId,
    required List<Map<String, dynamic>> openTasks,
    required String userPromptRaw,
    required DateTime now,
  }) {
    if (openTasks.isEmpty) {
      _sessions.remove(conversationId);
      return _isEnglish
          ? 'You have no open tasks right now. Tell me what you need to get done — e.g. "I have a Math exam tomorrow and English the day after" — and we will organize them together.'
          : 'مفيش مهام مفتوحة متسجلة دلوقتي! '
              'قولّي إيه اللي وراك — مثلًا «عندي امتحان بكره عربي و بعده انجليزي» — وأنا أسجّلهم ونرتّبهم سوا.';
    }

    final norm = nlu.normalize(userPromptRaw);
    final session = _sessions[conversationId] ??
        PlanningSessionState(conversationId: conversationId, now: now);
    session.now = now;
    session.rawTasks = openTasks;
    _ingestConstraintsFromText(userPromptRaw, norm, session, now);

    // Ask 1 focused question when user explicitly asks for full schedule planning
    // and we have multiple tasks with zero supplied window/time preferences.
    final explicitFullPlanRequest = nlu.containsAny(norm, [
          'نظملي جدول',
          'انظم جدول',
          'خطط معايا',
          'خططلي',
          'اعمل لي خطه',
          'اقترحلي جدول',
          'جدوللي',
          'plan my day',
          'build a schedule',
          'study schedule',
          'organize my schedule',
        ]) &&
        !nlu.containsAny(norm, ['ابدأ بايه', 'ابدا بايه', 'اولويات', 'مزنوق', 'prioritize', 'start first']);

    final allMissingTimes = openTasks.every(
      (t) => (t['time'] == null || t['time'].toString().isEmpty),
    );
    if (explicitFullPlanRequest &&
        openTasks.length >= 2 &&
        allMissingTimes &&
        session.availableWindows.isEmpty &&
        session.preferredPeriod == null &&
        session.fixedCommitments.isEmpty) {
      session.phase = PlanningPhase.awaitingConstraints;
      _sessions[conversationId] = session;
      return _isEnglish
          ? 'You have ${openTasks.length} open tasks. To build a realistic schedule without guessing your time:\n'
              'What hours are you free today or tomorrow (e.g. "from 6 to 9 pm"), and do you have any fixed commitments?'
          : 'عندك ${openTasks.length} مهام مفتوحة. عشان أعملك جدول واقعي من غير ما أخمن أوقاتك:\n'
              'إيه الساعات الفاضية عندك النهارده أو بكرة (مثلًا: من ٦ لـ ٩ بليل)، وهل في ميعاد ثابت ما ينفعش يتحرك؟';
    }

    // Data sufficient (or user asked for priority order right now) -> build Draft v1.
    return _generateDraftReply(session, isRevision: false);
  }

  /// Handles user replies during an active planning Q&A or draft confirmation.
  /// Returns null only if the utterance clearly jumps to an unrelated command.
  LlmReply? handleActivePlanningTurn({
    required String conversationId,
    required String rawInput,
    required DateTime now,
    required ToolCall Function(String name, Map<String, dynamic> args) callBuilder,
  }) {
    final session = _sessions[conversationId];
    if (session == null || !session.isActive) return null;

    final corrected = ArabicText.resolveSelfCorrection(rawInput).resolved;
    final norm = nlu.normalize(corrected);

    // Explicit cancel / exit planning mode.
    if (nlu.containsAny(norm, [
      'لا خلاص',
      'الغي التخطيط',
      'مش عايز خطه',
      'سيبك من الجدول',
      'cancel plan',
      'cancel schedule',
      'nevermind',
      'discard draft',
    ])) {
      clearSession(conversationId);
      return LlmReply(
        text: _isEnglish
            ? 'Okay, I cancelled the planning draft without changing any of your tasks.'
            : 'تمام، لغيت مسودة التخطيط من غير أي تعديل على مهامك.',
      );
    }

    // If user is awaiting constraints -> absorb answer & generate Draft v1.
    if (session.phase == PlanningPhase.awaitingConstraints) {
      if (_clearlyUnrelatedCommand(norm) || _isNewTaskCreationTurn(corrected, norm, now)) {
        clearSession(conversationId);
        return null;
      }
      session.now = now;
      _ingestConstraintsFromText(corrected, norm, session, now);
      return LlmReply(text: _generateDraftReply(session, isRevision: false));
    }

    // Phase: awaitingConfirmation
    if (session.phase == PlanningPhase.awaitingConfirmation) {
      if (_isApprovalPhrase(norm) && !_isRejectionOrCounter(norm)) {
        // Must verify live DB hash before executing any update_task write!
        session.phase = PlanningPhase.verifyingBeforeApply;
        return LlmReply(
          toolCalls: [
            callBuilder('get_tasks', {'status': 'pending', 'limit': 30}),
          ],
        );
      }

      if (_clearlyUnrelatedCommand(norm) || _isNewTaskCreationTurn(corrected, norm, now)) {
        clearSession(conversationId);
        return null;
      }

      if (_isRejectionOrCounter(norm) || _containsConstraintChange(norm)) {
        session.now = now;
        _ingestConstraintsFromText(corrected, norm, session, now);
        return LlmReply(text: _generateDraftReply(session, isRevision: true));
      }

      // Gentle clarification inside draft review.
      return LlmReply(
        text: _isEnglish
            ? 'Say "confirm schedule" if you want me to apply this draft, or tell me what to adjust (e.g. "from 7 to 10 pm").'
            : 'قولّي لو تحب أعتمد المسودة الحالية بـ «اعتمد الخطة»، أو اكتب التعديل اللي تحبه (مثلًا: خليه من ٧ لـ ١٠ بليل).',
      );
    }

    return null;
  }

  /// Called when Round 2 receives fresh `get_tasks` during confirmation verification.
  PlanningTurnDecision verifyHashAndPrepareApply({
    required String conversationId,
    required List<Map<String, dynamic>> liveOpenTasks,
    required DateTime now,
    required ToolCall Function(String name, Map<String, dynamic> args) callBuilder,
  }) {
    final session = _sessions[conversationId];
    if (session == null || session.proposal == null) {
      clearSession(conversationId);
      return PlanningTurnDecision(
        reply: LlmReply(
          text: _isEnglish
              ? 'There is no active draft to confirm right now. Want me to build a fresh plan?'
              : 'مفيش مسودة نشطة حاليًا للاعتماد. تحب نرتّب مهامك من جديد؟',
        ),
      );
    }

    final liveProblem = _buildProblem(session, liveOpenTasks, now);
    final liveHash = _planner.computeInputHash(liveProblem);
    final oldHash = session.proposal!.inputHash;

    // Input drift detection: invalidate stale approval automatically!
    if (liveHash != oldHash) {
      session.rawTasks = liveOpenTasks;
      session.now = now;
      session.phase = PlanningPhase.awaitingConfirmation;
      final refreshed = _generateDraftReply(session, isRevision: true);
      return PlanningTurnDecision(
        reply: LlmReply(
          text: _isEnglish
              ? 'Your tasks changed after the previous draft, so the earlier approval was invalidated automatically to avoid conflicts.\n\n$refreshed'
              : 'مهامك اتعدلت بعد آخر مسودة، فالموافقة القديمة اتلغت تلقائيًا عشان ما يتسجلش تعارض.\n\n$refreshed',
        ),
      );
    }

    final validItems = session.proposal!.items
        .where((it) => it.taskId.isNotEmpty)
        .toList();
    if (validItems.isEmpty) {
      clearSession(conversationId);
      return PlanningTurnDecision(
        reply: LlmReply(
          text: _isEnglish
              ? 'The current draft has no schedulable items right now. Adjust your windows and we will recalculate.'
              : 'المسودة مفيهاش عناصر قابلة للتحديث حاليًا. ممكن تعدّل الشروط ونحسبها تاني.',
        ),
      );
    }

    // Clear active phase before executing validated writes; tool round synthesizes truth.
    final calls = [
      for (final item in validItems)
        callBuilder('update_task', {
          'task_id': item.taskId,
          'date': item.suggestedYmd,
          'time': item.suggestedHm,
        }),
    ];
    clearSession(conversationId);
    return PlanningTurnDecision(updateCalls: calls);
  }

  String _generateDraftReply(
    PlanningSessionState session, {
    required bool isRevision,
  }) {
    final prev = session.proposal;
    session.planVersion = session.planVersion + 1;
    final problem = _buildProblem(session, session.rawTasks, session.now);
    final proposal = _planner.plan(
      problem,
      planVersion: session.planVersion,
      previousProposal: prev,
      languageCode: _langCode,
    );
    session.proposal = proposal;
    session.phase = PlanningPhase.awaitingConfirmation;
    _sessions[session.conversationId] = session;

    final header = _isEnglish
        ? (isRevision
            ? 'Updated draft (v${proposal.planVersion} • #${proposal.inputHash.substring(0, 6)}):'
            : 'Prepared your schedule draft (v${proposal.planVersion} • #${proposal.inputHash.substring(0, 6)}):')
        : (isRevision
            ? 'حدّثت المسودة (نسخة ${proposal.planVersion} • #${proposal.inputHash.substring(0, 6)}):'
            : 'جهّزتلك مسودة الخطة (نسخة ${proposal.planVersion} • #${proposal.inputHash.substring(0, 6)}):');
    final footer = _isEnglish
        ? 'This is a draft only — nothing was saved yet. Say "confirm schedule" to apply it, or tell me what times to change.'
        : 'دي مسودة فقط ولسه ما اتعدّلتش في جدولك — قولّي «اعتمد الخطة» عشان أثبّتها، أو عدّل الوقت اللي تحبه.';
    final userPrefs = UserEnergyPreferencesStore.current;
    final energyNote = userPrefs.completedWizard
        ? (_isEnglish
            ? '\n• Energy Profile: Tailored to your peak energy (${userPrefs.peakLabelEn}) • ${userPrefs.preferredSessionMinutes}-min blocks • ${userPrefs.strategyLabelEn}.'
            : '\n• بصمة طاقتك: تم ضبط الجدول على ذروة نشاطك (${userPrefs.peakLabelAr}) • جلسات (${userPrefs.preferredSessionMinutes} د) • ${userPrefs.strategyLabelAr}.')
        : '';
    return '$header\n${proposal.explanationFor(_langCode)}$energyNote\n\n$footer';
  }

  PlanningProblem _buildProblem(
    PlanningSessionState session,
    List<Map<String, dynamic>> rawTasks,
    DateTime now,
  ) {
    final inputs = <PlanningTaskInput>[];
    for (final raw in rawTasks) {
      final id = (raw['task_id'] ?? raw['id'] ?? '').toString();
      final title = (raw['title'] ?? '').toString();
      if (id.isEmpty || title.isEmpty) continue;
      final status = (raw['status'] ?? 'pending').toString();
      final dateStr = raw['date']?.toString();
      final timeStr = raw['time']?.toString();
      final dueDate =
          dateStr != null && dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;
      DateTime? scheduled;
      if (dueDate != null && timeStr != null && timeStr.contains(':')) {
        final parts = timeStr.split(':');
        final h = int.tryParse(parts[0]) ?? 9;
        final m = int.tryParse(parts[1]) ?? 0;
        scheduled = DateTime(dueDate.year, dueDate.month, dueDate.day, h, m);
      }
      final estMin = raw['estimated_minutes'] is int
          ? raw['estimated_minutes'] as int
          : null;
      final deps = (raw['depends_on_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];

      inputs.add(
        PlanningTaskInput(
          id: id,
          title: title,
          dueDate: dueDate,
          scheduledTime: scheduled,
          estimatedMinutes: estMin,
          priority: (raw['priority'] ?? 'medium').toString().toLowerCase(),
          isCompleted: status == 'completed',
          dependsOnIds: deps,
        ),
      );
    }

    final userPrefs = UserEnergyPreferencesStore.current;
    final effectivePeriod = session.preferredPeriod ??
        (userPrefs.completedWizard ? userPrefs.peakEnergyPeriod : null);

    return PlanningProblem(
      now: now,
      tasks: inputs,
      availableWindows: session.availableWindows,
      fixedCommitments: session.fixedCommitments,
      breakMinutes: session.breakMinutes,
      preferredPeriod: effectivePeriod,
      defaultAssumedDurationMinutes:
          userPrefs.completedWizard ? userPrefs.preferredSessionMinutes : 45,
    );
  }

  void _ingestConstraintsFromText(
    String raw,
    String norm,
    PlanningSessionState session,
    DateTime now,
  ) {
    final baseDate = nlu.parseDate(norm, now) ??
        DateTime(now.year, now.month, now.day);

    // Match explicit window range: Arabic "من 6 ل 9 بليل" or English "from 9 am to 5 pm" / "6 to 9 pm".
    final rangeRe = RegExp(
      r'(?:من\s+|from\s+)?(\d{1,2})(?::(\d{2}))?\s*(الصبح|صباحا|الضهر|الظهر|العصر|المغرب|بليل|بالليل|مساء|am|pm)?\s*(?:لـ|ل|الى|حتى|to|until|-)\s*(\d{1,2})(?::(\d{2}))?\s*(الصبح|صباحا|الضهر|الظهر|العصر|المغرب|بليل|بالليل|مساء|am|pm)?',
      caseSensitive: false,
    );
    final match = rangeRe.firstMatch(norm);
    if (match != null) {
      var sh = int.parse(match.group(1)!);
      final sm = int.tryParse(match.group(2) ?? '0') ?? 0;
      final sp = match.group(3);
      var eh = int.parse(match.group(4)!);
      final em = int.tryParse(match.group(5) ?? '0') ?? 0;
      final ep = match.group(6) ?? sp;

      sh = _resolveHourPeriod(sh, sp ?? ep, norm);
      eh = _resolveHourPeriod(eh, ep ?? sp, norm);
      if (eh <= sh && eh + 12 <= 23) eh += 12;

      var start = DateTime(baseDate.year, baseDate.month, baseDate.day, sh, sm);
      final end = DateTime(baseDate.year, baseDate.month, baseDate.day, eh, em);
      if (start.isBefore(now) &&
          baseDate.year == now.year &&
          baseDate.month == now.month &&
          baseDate.day == now.day &&
          end.isAfter(now)) {
        start = now;
      }
      if (end.isAfter(start)) {
        final isFixed = nlu.containsAny(norm, [
          'ثابت', 'عندي دكتور', 'محاضره', 'اجتماع', 'مشغول',
          'fixed', 'appointment', 'meeting', 'busy', 'class',
        ]);
        final win = TimeWindow(
          start: start,
          end: end,
          label: isFixed
              ? (_isEnglish ? 'Fixed commitment' : 'التزام ثابت')
              : (_isEnglish ? 'Available window' : 'وقت متاح'),
        );
        if (isFixed) {
          session.fixedCommitments = [...session.fixedCommitments, win];
        } else {
          // Replace draft availability windows when user gives a new preferred slot.
          session.availableWindows = [win];
        }
      }
    } else {
      // Single counter hour like "خليه 8 بليل" or "make it 8 pm"
      final singleTime = nlu.parseTime(norm);
      if (singleTime != null) {
        final parts = singleTime.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final start = DateTime(baseDate.year, baseDate.month, baseDate.day, h, m);
        final end = start.add(const Duration(hours: 3));
        session.availableWindows = [
          TimeWindow(
            start: start,
            end: end,
            label: _isEnglish ? 'Adjusted slot' : 'وقت معدّل',
          ),
        ];
      }
    }

    if (nlu.containsAny(norm, ['الصبح', 'بدري', 'morning', 'early'])) {
      session.preferredPeriod = 'morning';
    } else if (nlu.containsAny(norm, ['الضهر', 'الظهر', 'العصر', 'afternoon'])) {
      session.preferredPeriod = 'afternoon';
    } else if (nlu.containsAny(norm, ['بليل', 'بالليل', 'مساء', 'evening', 'tonight', 'night'])) {
      session.preferredPeriod = 'evening';
    }

    final brk = RegExp(r'(?:راح[هة]\s*(\d{1,2})\s*د|(\d{1,2})\s*min\s*break|break\s*(\d{1,2})\s*min)')
        .firstMatch(norm);
    if (brk != null) {
      session.breakMinutes =
          int.tryParse(brk.group(1) ?? brk.group(2) ?? brk.group(3) ?? '0') ?? 0;
    }
  }

  int _resolveHourPeriod(int h, String? suffix, String norm) {
    final s = (suffix ?? '').toLowerCase();
    final eve = s == 'بليل' ||
        s == 'بالليل' ||
        s == 'مساء' ||
        s == 'العصر' ||
        s == 'المغرب' ||
        s == 'pm' ||
        (s.isEmpty &&
            (norm.contains('بليل') ||
                norm.contains('بالليل') ||
                norm.contains('مساء') ||
                norm.contains('pm') ||
                norm.contains('evening') ||
                norm.contains('tonight')));
    final morn = s == 'الصبح' || s == 'صباحا' || s == 'am';
    if (eve && h >= 1 && h <= 11) return h + 12;
    if (morn && h == 12) return 0;
    if (!morn && !eve && h >= 1 && h <= 6) return h + 12;
    return h;
  }

  bool _isApprovalPhrase(String norm) => nlu.containsAny(norm, [
        'اعتمد',
        'اعتمدها',
        'موافق',
        'تمام نفذ',
        'ايوه اعتمد',
        'اه اعتمد',
        'ماشي اعتمد',
        'ثبت الجدول',
        'نفذ الخطة',
        'نفذ الخطه',
        'confirm schedule',
        'confirm plan',
        'apply schedule',
        'apply plan',
        'approve',
        'confirm',
        'looks good',
      ]);

  bool _isRejectionOrCounter(String norm) => nlu.containsAny(norm, [
        'مش موافق',
        'لا قصدي',
        'لا خليها',
        'عدل',
        'غير',
        'بدل',
        'بلاش الساعة',
        'خليه ',
        'change',
        'adjust',
        'make it',
        'instead',
      ]);

  bool _containsConstraintChange(String norm) =>
      RegExp(r'من\s+\d|الساعه\s+\d|from\s+\d|\b\d+\s*(?:am|pm)\b|الصبح|بليل|بالليل|ثابت|مشغول|راحه\s*\d|break\s*\d|morning|evening|tomorrow|fixed')
          .hasMatch(norm);

  bool _isNewTaskCreationTurn(String raw, String norm, DateTime now) {
    if (_isRejectionOrCounter(norm)) return false;
    final hasRange = RegExp(
      r'(?:من\s+|from\s+)?\d{1,2}(?::\d{2})?\s*(?:الصبح|صباحا|الضهر|الظهر|العصر|المغرب|بليل|بالليل|مساء|am|pm)?\s*(?:لـ|ل|الى|حتى|to|until|-)\s*\d{1,2}',
      caseSensitive: false,
    ).hasMatch(norm);
    if (hasRange && nlu.containsAny(norm, ['ثابت', 'مشغول', 'فاضي', 'متاح', 'fixed', 'busy', 'free', 'available'])) {
      return false;
    }
    if (RegExp(r'^(?:ضيف|ضيفلي|سجل|سجلي|حط|حطلي|اكتب|اكتبلي|فكرني|ذكرني|add\s+|create\s+|remind\s+me)').hasMatch(norm)) {
      return true;
    }
    if (RegExp(r'(?:^|\s)(?:عندي|ورايا|لازم|محتاج|عاوز|عايز)(?=\s|$)').hasMatch(norm) &&
        !nlu.containsAny(norm, ['ثابت', 'مشغول', 'fixed', 'busy'])) {
      final specs = nlu.extractTaskSpecs(raw, now);
      if (specs.isNotEmpty) return true;
    }
    return false;
  }

  bool _clearlyUnrelatedCommand(String norm) => RegExp(
        r'^(?:امسح|احذف|شيل|الغي\s+مهم|خلصت|وريني|ايه\s+اللي\s+ورايا|احكيلي|قسم|قسّم|فصص|فصل|جزأ|افصل|ازيك|اهلا|مرحبا|صباح\s+الخير|مساء\s+الخير|رتب|اختار|لخص|ملخص|ده\s+امتحان|دول\s+حاجتين|دول\s+مهمتين|delete|remove|cancel\s+task|finished|show\s+me|what\s+tasks|break\s+down|split|decompose|hello|hi\b|plan\s+my|pick\s+)',
        caseSensitive: false,
      ).hasMatch(norm);
}

import 'dart:convert';

import 'package:ai_assistant/ai_assistant.dart';

import '../../../app/mode/student_mode_controller.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../projects/data/exam_grades_store.dart';
import '../planning/deterministic_planner.dart';
import 'egyptian_nlu_analyzer.dart';
import 'planning_coordinator.dart';
import 'user_energy_preferences.dart';

class _PendingClarification {
  const _PendingClarification({
    required this.action,
    required this.knownFields,
    this.candidates = const [],
  });

  final String action;
  final Map<String, dynamic> knownFields;
  final List<Map<String, dynamic>> candidates;
}

class _PendingMutationDraft {
  const _PendingMutationDraft({
    required this.actionKind,
    required this.toolCalls,
    required this.originalPrompt,
    this.alertMode,
    this.revision = 1,
  });

  final String actionKind;
  final List<ToolCall> toolCalls;
  final String originalPrompt;
  final String? alertMode;
  final int revision;

  bool get isDestructive =>
      actionKind == 'delete_task' || actionKind == 'delete_reminder';
}

class _TaskRef {
  const _TaskRef({
    required this.id,
    required this.title,
    this.date,
    this.time,
  });

  final String id;
  final String title;
  final String? date;
  final String? time;
}

/// On-device Egyptian productivity assistant brain (zero external APIs).
///
/// Architecture:
/// 1) Normalized NLU + from-scratch trained softmax intent classifier + hard
///    safety gates ([EgyptianNluAnalyzer]).
/// 2) Conversational state & single-question clarifications (`PendingAction`
///    and per-conversation task reference stack; never cross-session guessing).
/// 3) Deterministic, explainable scheduler ([PlanningCoordinator] +
///    [DeterministicSchedulePlanner]) with draft versioning, `inputHash` drift
///    invalidation, and strict confirmation before DB writes.
class LocalEgyptianLlmService implements LLMService {
  LocalEgyptianLlmService({
    EgyptianIntentModel? intentModel,
    DeterministicSchedulePlanner? planner,
    this.languageCodeProvider,
    this.onAlertModeSelected,
    this.onTelemetryEvent,
    this.onDraftConfirmLatency,
    this.requireMutationConfirmation = true,
  })  : _nlu = EgyptianNluAnalyzer(intentModel: intentModel),
        _planner = planner ?? const DeterministicSchedulePlanner() {
    _planning = PlanningCoordinator(
      planner: _planner,
      nlu: _nlu,
      languageCodeProvider: languageCodeProvider,
    );
  }

  static const Set<String> _writeToolNames = {
    'create_task',
    'update_task',
    'delete_task',
    'complete_task',
    'create_reminder',
    'update_reminder',
    'delete_reminder',
  };

  final EgyptianNluAnalyzer _nlu;
  final DeterministicSchedulePlanner _planner;
  final String Function()? languageCodeProvider;
  final void Function(String alertMode)? onAlertModeSelected;
  final void Function(String eventName)? onTelemetryEvent;
  final void Function(int latencyMs)? onDraftConfirmLatency;

  /// Enforces explicit user preview & confirmation before ANY write/destructive
  /// tool execution (`create_task`, `update_task`, `delete_task`, `complete_task`,
  /// `create_reminder`, `update_reminder`, `delete_reminder`). Enabled by default.
  final bool requireMutationConfirmation;
  late final PlanningCoordinator _planning;

  final Map<String, _PendingClarification> _pendingByCid = {};
  final Map<String, _PendingMutationDraft> _pendingDraftByCid = {};
  final Map<String, DateTime> _draftStagedAtByCid = {};
  final Map<String, List<_TaskRef>> _recentRefsByCid = {};
  int _callSeq = 0;

  bool hasPendingMutationDraft(String conversationId) =>
      _pendingDraftByCid.containsKey(conversationId);

  bool get _isEnglish =>
      (languageCodeProvider?.call() ?? 'ar').toLowerCase().startsWith('en');

  String get _langCode => _isEnglish ? 'en' : 'ar';

  String _tr(String ar, String en) => _isEnglish ? en : ar;

  /// Exposes structured pre-tool understanding (schema v1.0) for tests/telemetry.
  AssistantUnderstandingResult analyzeUtterance(
    String text, {
    DateTime? now,
    String conversationId = 'default',
  }) {
    final activeDraft = _planning.sessionFor(conversationId)?.isActive ?? false;
    final hasPend = _pendingByCid.containsKey(conversationId);
    return _nlu
        .analyze(
          text,
          now: now ?? DateTime.now(),
          hasPendingClarification: hasPend,
          hasActiveDraft: activeDraft,
          languageCode: _langCode,
        )
        .understanding;
  }

  PlanningSessionState? planningSessionFor(String conversationId) =>
      _planning.sessionFor(conversationId);

  @override
  Future<LlmReply> complete(LlmRequest request) async {
    final cid = request.conversationId;
    final now = WallClock.tryParse(_extractCurrentIso(request.systemPrompt))?.wall ??
        DateTime.now();

    if (request.messages.isNotEmpty &&
        request.messages.last.role == MessageRole.tool) {
      return _replyFromTools(cid, request, now);
    }

    final lastUser = request.messages.lastWhere(
      (m) => m.role == MessageRole.user,
      orElse: () => ConversationMessage.user(''),
    );
    final raw = lastUser.content.trim();
    if (raw.isEmpty) {
      return LlmReply(
        text: _tr(
          'قولّي حابب ترتّب إيه النهارده وأنا أساعدك خطوة بخطوة.',
          'Tell me what you want to organize today and I will help step by step.',
        ),
      );
    }

    if (cid == 'project-plan') {
      return LlmReply(text: _buildStructuredProjectPlanJson(raw, now));
    }
    if (cid == 'task-extraction') {
      return LlmReply(text: _buildStructuredTaskExtractionJson(raw, now));
    }

    final norm = _nlu.normalize(raw);

    // 1. Gratitude & capability discovery (never writes)
    if (_isThanks(norm)) {
      return LlmReply(
        text: _tr(
          'تحت أمرك في أي وقت! لو جدّ جديد أو حبيت نبدأ جلسة تركيز قولّي فورًا.',
          'Anytime! Let me know whenever something new comes up or if you want to start a focus session.',
        ),
      );
    }
    if (_isCapabilitiesQuery(norm)) {
      return LlmReply(
        text: _tr(
          'أنا مساعد هندلها المتخصص في المهام والتخطيط محليًا:\n'
          '• تضيف مهمة أو أكتر في جملة، زي: «عندي امتحان بكره عربي و بعده انجليزي».\n'
          '• نرتّب جدولك بمسودة وأسباب واضحة ونعتمدها بعد موافقتك.\n'
          '• تعدّل ميعاد، تعلّم مهمة خلصت، أو تقسّم هدف كبير لـ ٣ خطوات.',
          'I am your local Handelha tasks & planning assistant:\n'
          '• Add one or multiple tasks in natural speech or text.\n'
          '• Build an explainable schedule draft and apply it only after your confirmation.\n'
          '• Reschedule tasks, mark them complete, or break a big goal into 3 steps.',
        ),
      );
    }

    // 2. Active interactive planning session (Q&A -> Draft -> Revision / Approval)
    final planningReply = _planning.handleActivePlanningTurn(
      conversationId: cid,
      rawInput: raw,
      now: now,
      callBuilder: _call,
    );
    if (planningReply != null) {
      return planningReply;
    }

    // 2b. Active mutation preview draft (Confirm / Edit / Cancel before ANY write)
    final pendingDraft = _pendingDraftByCid[cid];
    if (pendingDraft != null) {
      final draftReply = _handlePendingMutationDraft(
        cid: cid,
        draft: pendingDraft,
        raw: raw,
        norm: norm,
        now: now,
      );
      if (draftReply != null) {
        return draftReply;
      }
    }

    // 3. Pending breakdown confirmation follow-up ("تمام ضيفهم") — already previewed!
    final confirmBreakdown = _maybeConfirmBreakdownFollowUp(norm, request.messages, now);
    if (confirmBreakdown != null && confirmBreakdown.isNotEmpty) {
      return LlmReply(toolCalls: confirmBreakdown);
    }

    // Route normal turn and guard every write/destructive tool behind preview confirmation.
    final reply = await _routeTurn(
      cid: cid,
      raw: raw,
      norm: norm,
      now: now,
      request: request,
    );
    return _stageWriteCallsIfNeeded(
      cid: cid,
      reply: reply,
      now: now,
      rawPrompt: raw,
    );
  }

  Future<LlmReply> _routeTurn({
    required String cid,
    required String raw,
    required String norm,
    required DateTime now,
    required LlmRequest request,
  }) async {

    // 4. Pending clarification merge from previous turn (e.g. "ضيف العربي" -> "مذاكرة عربي بكرة")
    final pending = _pendingByCid[cid];
    if (pending != null) {
      final merged = _resolvePendingClarification(cid, pending, raw, norm, now, request);
      if (merged != null) return merged;
    }

    // 5. Run specialized NLU + safety gates + slot extraction
    final analysis = _nlu.analyze(
      raw,
      now: now,
      hasPendingClarification: false,
      hasActiveDraft: false,
      languageCode: _langCode,
    );
    final u = analysis.understanding;

    // Strict write-safety gate (negations, hypotheticals, quotes, future statements)
    if (u.safetyFlags.blocksWrite && !_nlu.isConversationalCoachingQuery(norm)) {
      return _clarificationReply(
        cid: cid,
        request: request,
        question: u.clarificationQuestion ??
            _tr(
              'مش متأكد عايز أنفّذ تغيير ولا ده مجرد سؤال؟ وضّحلي تحب أعمل إيه بالضبط.',
              'Not sure whether to modify anything or if that was just a question — tell me what you would like me to do.',
            ),
        pendingAction: u.pendingAction ?? 'other',
        knownFields: u.slots,
      );
    }

    // Conversational study/focus/procrastination coaching (never blindly turned into a task)
    if (_nlu.isConversationalCoachingQuery(norm)) {
      if (_isOverwhelmOrCoaching(norm)) {
        return LlmReply(
          toolCalls: [_call('get_tasks', {'status': 'pending', 'limit': 15})],
        );
      }
      return LlmReply(text: _buildSmartCoachingAdviceReply(norm));
    }

    // Greeting
    if (u.intent == EgyptianIntent.greeting) {
      return LlmReply(
        text: _tr(
          'أهلًا بيك! يومك ماشي إزاي؟ قولّي اللي وراك أو ابعت «رتبلي يومي» ونظبّط جدولك سوا.',
          'Welcome! How is your day going? Tell me what tasks are on your plate or say "plan my day" to organize them.',
        ),
      );
    }

    // Exam grade / score celebration ("جبت امتياز في امتحان العربي", "قفلت الامتحان", "جبت جيد جدا")
    if (_isExamGradeReport(norm)) {
      return LlmReply(text: _buildExamGradeReply(raw, norm, cid, request.messages));
    }

    // Energy & productivity preference update in chat ("انا بحب اشتغل بليل", "طاقتي الصبح")
    if (_isEnergyPreferenceUpdate(norm)) {
      return LlmReply(text: _handleEnergyPreferenceUpdate(norm));
    }

    // Out of scope (honest domain boundary)
    if (u.intent == EgyptianIntent.outOfScope) {
      return LlmReply(
        text: _tr(
          'أنا مساعد متخصص في المهام والتخطيط داخل هندلها بس، مش مودل دردشة عام. لو عندك مهام أو مواعيد تحب نرتّبها قولّي وأنا معاك.',
          'I am a specialized task and planning assistant inside Handelha, not a general-purpose chat model. Tell me any tasks or deadlines and I can organize them with you.',
        ),
      );
    }

    // Explicit breakdown or task-separation correction ("قسملي مذاكرة ...", "قسمها لخطوات ده امتحان وده حاجة تانيه", "افصلهم")
    if (_isSeparateTasksCorrection(norm)) {
      final splitCalls = _buildSplitMergedTaskCalls(cid, request.messages, now);
      if (splitCalls != null && splitCalls.isNotEmpty) {
        return LlmReply(toolCalls: splitCalls);
      }
    }
    if (_isBreakdownRequest(norm)) {
      return LlmReply(text: _buildBreakdownReply(raw, cid, request.messages, now));
    }

    // Overwhelm coaching grounded in actual tasks
    if (_isOverwhelmOrCoaching(norm)) {
      return LlmReply(
        toolCalls: [_call('get_tasks', {'status': 'pending', 'limit': 15})],
      );
    }

    // Interactive planning / scheduling ("رتب معايا اولوياتي", "خطط معايا اليوم")
    if (u.intent == EgyptianIntent.schedule) {
      final targetDate = analysis.requestedDate ?? now;
      return LlmReply(
        toolCalls: [
          _call('get_schedule', {'date': _ymd(targetDate)}),
          _call('get_tasks', {'status': 'pending', 'limit': 25}),
        ],
      );
    }

    // Complete task ("خلصت ...", "علمها خلصت")
    if (u.intent == EgyptianIntent.completeTask) {
      return _handleTargetedMutation(
        cid: cid,
        toolName: 'complete_task',
        query: analysis.targetQuery,
        raw: raw,
        norm: norm,
        extraArgs: const {},
        request: request,
      );
    }

    // Delete task ("امسح ...", "شيلها")
    if (u.intent == EgyptianIntent.deleteTask) {
      return _handleTargetedMutation(
        cid: cid,
        toolName: 'delete_task',
        query: analysis.targetQuery,
        raw: raw,
        norm: norm,
        extraArgs: const {},
        request: request,
      );
    }

    // Update / postpone task ("أجلها لبكرة", "خلي المذاكرة الخميس", "قبلها بنص ساعة")
    if (u.intent == EgyptianIntent.updateTask) {
      final relUpdate = _resolveRelativeUpdate(cid, analysis, norm, now, request);
      if (relUpdate != null) return relUpdate;
    }

    // Reminder intent — strictly honest against actual tools in `request.tools`
    if (u.intent == EgyptianIntent.reminder) {
      return _handleReminderIntent(cid, analysis, request, now);
    }

    // Task creation / multi-clause Egyptian commitment
    if (u.intent == EgyptianIntent.createTask) {
      if (u.needsClarification) {
        final spec = analysis.taskSpecs.isNotEmpty ? analysis.taskSpecs.first : null;
        final isMissingTitle = spec?.isMissingTitle == true;
        final explicitAlarm = _nlu.containsAny(norm, ['منبه', 'منبهه', 'يرن', 'alarm']);
        final explicitNotif = _nlu.containsAny(norm, ['رساله', 'اشعار', 'نوتفيكيشن', 'notification']);
        if (explicitAlarm || explicitNotif) {
          onAlertModeSelected?.call(
            explicitNotif && !explicitAlarm ? 'notification' : 'alarm',
          );
        }
        return _clarificationReply(
          cid: cid,
          request: request,
          question: u.clarificationQuestion!,
          pendingAction: 'create_task',
          knownFields: {
            if (spec != null && spec.title.isNotEmpty) 'title': spec.title,
            if (spec?.date != null) 'date': _ymd(spec!.date!),
            if (spec?.time != null) 'time': spec!.time,
            if (spec?.inMinutes != null) 'in_minutes': spec!.inMinutes,
            if (spec?.category != null) 'category': spec!.category,
            if (spec != null) 'priority': spec.priority,
            if (isMissingTitle) 'missing_slot': 'title',
            if (spec?.inMinutes != null || explicitAlarm) 'prefer_reminder': true,
          },
        );
      }
      if (analysis.taskSpecs.isNotEmpty) {
        return LlmReply(toolCalls: _buildCreateCalls(analysis.taskSpecs));
      }
    }

    // Summary / list / search
    if (u.intent == EgyptianIntent.summary) {
      final targetDate = analysis.requestedDate ?? now;
      return LlmReply(
        toolCalls: [
          _call('get_daily_summary', {'date': _ymd(targetDate)}),
          _call('get_tasks', {'status': 'pending', 'limit': 15}),
        ],
      );
    }

    if (u.intent == EgyptianIntent.listTasks) {
      if (norm.contains('الجايه') ||
          norm.contains('الاسبوع') ||
          norm.contains('upcoming') ||
          norm.contains('week')) {
        return LlmReply(
          toolCalls: [_call('get_upcoming_tasks', {'days_ahead': 7, 'limit': 15})],
        );
      }
      return LlmReply(
        toolCalls: [
          _call('get_tasks', {
            'status': (norm.contains('خلصت') ||
                    norm.contains('المكتمله') ||
                    norm.contains('completed') ||
                    norm.contains('done'))
                ? 'completed'
                : 'pending',
            if (analysis.requestedDate != null) 'date': _ymd(analysis.requestedDate!),
            'limit': 20,
          }),
        ],
      );
    }

    if (analysis.targetQuery.isNotEmpty &&
        RegExp(r'^(?:دور\s+علي|ابحث\s+عن|فين|find|search\s+for)(?=\s|$)', caseSensitive: false)
            .hasMatch(norm)) {
      return LlmReply(toolCalls: [_call('search_tasks', {'query': analysis.targetQuery})]);
    }

    // Fallback clarification without fabricating actions
    return _clarificationReply(
      cid: cid,
      request: request,
      question: _tr(
        'مش متأكد تقصد إيه بالضبط: تحب أسجّل مهمة جديدة، أعدّل ميعاد، ولا نرتّب جدولك؟',
        'I am not sure what you want me to do: should I add a task, update a deadline, or plan your schedule?',
      ),
      pendingAction: 'other',
      knownFields: {'raw': raw},
    );
  }

  // ---------------------------------------------------------------------------
  // Clarification, pronoun & reminder handlers
  // ---------------------------------------------------------------------------

  LlmReply? _resolvePendingClarification(
    String cid,
    _PendingClarification pending,
    String raw,
    String norm,
    DateTime now,
    LlmRequest request,
  ) {
    // Allow user to cancel cleanly.
    if (_nlu.containsAny(norm, [
      'لا خلاص',
      'الغي',
      'سيبك',
      'مش عايز',
      'nevermind',
      'cancel',
      'never mind',
      'forget it',
    ])) {
      _pendingByCid.remove(cid);
      return LlmReply(
        text: _tr(
          'تمام، لغيت العملية من غير أي تعديل.',
          'Okay, I cancelled that action without changing any tasks.',
        ),
      );
    }

    // If the user switches abruptly to an explicit other verb command or starts
    // a brand-new task/reminder utterance, discard stale clarification cleanly.
    if (RegExp(
      r'^(?:وريني|ايه\s+اللي\s+ورايا|رتبلي|لخص|امسح\s+\S+\s+\S+|احكيلي|عندي\s+|ورايا\s+|فكرني\s+|ذكرني\s+|نبهني\s+|اضبط\s+|show\s+me|what\s+tasks|plan\s+my\s+day|delete\s+\S+|remind\s+me|add\s+a?\s*task)',
      caseSensitive: false,
    ).hasMatch(norm)) {
      _pendingByCid.remove(cid);
      return null;
    }

    // Candidate disambiguation ("الأولى", "التانية", "second", or partial name match).
    if (pending.candidates.isNotEmpty) {
      final picked = _pickCandidate(norm, pending.candidates);
      if (picked != null) {
        _pendingByCid.remove(cid);
        final id = (picked['task_id'] ?? picked['id'] ?? '').toString();
        final title = (picked['title'] ?? '').toString();
        final args = Map<String, dynamic>.from(pending.knownFields)
          ..remove('candidates')
          ..remove('query')
          ..remove('title');
        if (id.isNotEmpty) {
          args['task_id'] = id;
        } else {
          args['query'] = title;
        }
        return LlmReply(toolCalls: [_call(pending.action, args)]);
      }
      return LlmReply(
        text: _tr(
          'لسه مش متأكد تقصد أنهي رقم أو اسم في الاختيارات، ممكن تكتب الاسم أو الرقم (الأولى/التانية)؟',
          'Still not sure which option you mean — please reply with the name or number (e.g. first / second).',
        ),
      );
    }

    // Completing `create_task` clarification (missing time OR missing title).
    if (pending.action == 'create_task') {
      final date = _nlu.parseDate(norm, now);
      final time = _nlu.parseTime(norm);
      final replyInMinutes = _nlu.parseInMinutes(norm);
      final explicitNoDate = RegExp(
        r'(?:من\s+غير\s+ميعاد|بدون\s+ميعاد|مفتوح[هة]?|اي\s+وقت|no\s+(?:specific\s+)?date|any\s*time|undated)',
        caseSensitive: false,
      ).hasMatch(norm);

      final missingSlot = pending.knownFields['missing_slot']?.toString();
      final prevTitle = (pending.knownFields['title'] ?? '').toString();
      final rawWithoutNoDate = explicitNoDate
          ? raw
              .replaceAll(
                RegExp(
                  r'(?:من\s+غير\s+ميعاد(?:\s+محدد)?|بدون\s+ميعاد(?:\s+محدد)?|مفتوح[هة]?|أ?ي\s+وقت|no\s+(?:specific\s+)?date|any\s*time|undated)',
                  caseSensitive: false,
                ),
                ' ',
              )
              .trim()
          : raw;
      var resolvedTitle = rawWithoutNoDate.isEmpty
          ? ''
          : _nlu.extractCleanClauseTitle(rawWithoutNoDate);

      final wantsNotif = _nlu.containsAny(norm, [
        'رساله', 'اشعار', 'نوتفيكيشن', 'notification',
      ]);
      final wantsAlarm = _nlu.containsAny(norm, [
        'منبه', 'منبهه', 'يرن', 'alarm',
      ]);
      final isAlarmOrNotifChoice = wantsNotif || wantsAlarm;
      if (isAlarmOrNotifChoice) {
        onAlertModeSelected?.call(
          wantsNotif && !wantsAlarm ? 'notification' : 'alarm',
        );
      }
      // Strip pure alert-mode words from resolvedTitle when user writes e.g. "مراجعة الكيمياء منبه".
      final cleanedOfMode = resolvedTitle
          .replaceAll(
            RegExp(
              r'(?:^|\s)(?:سميها|سمّيها|اسمها|خليها|خلّيها|ب?منبه(?:\s+يرن)?|ب?رسالة\s+إشعار|ب?اشعار|ب?إشعار|هادي[هة]?|alarm|notification)(?=\s|$)',
              caseSensitive: false,
            ),
            ' ',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleanedOfMode.isNotEmpty) {
        resolvedTitle = cleanedOfMode;
      }

      if (resolvedTitle.isEmpty ||
          (isAlarmOrNotifChoice && cleanedOfMode.isEmpty) ||
          RegExp(
            r'^(?:بكره|بكرة|النهارده|اليوم|الخميس|الجمعه|محدد|ميعاد|معاد|من\s+غير|بدون|تمام|ايوه|اه|ok|yes|yeah|sure|tomorrow|today)$',
            caseSensitive: false,
          ).hasMatch(_nlu.normalize(resolvedTitle))) {
        resolvedTitle = prevTitle;
      } else if (prevTitle.isNotEmpty &&
          _nlu.normalize(resolvedTitle) != _nlu.normalize(prevTitle)) {
        // Combine activity verb like "مذاكرة" + "العربي" if omitted subject.
        if (RegExp(r'^(?:مذاكر[هة]|مراجع[هة]|واجب|امتحان)$')
            .hasMatch(_nlu.normalize(resolvedTitle))) {
          resolvedTitle = '$resolvedTitle $prevTitle';
        }
      }

      if (resolvedTitle.isEmpty) resolvedTitle = prevTitle;

      // If we are still waiting for the title and user only picked alarm/notif mode -> ask for title once.
      if (missingSlot == 'title' && resolvedTitle.isEmpty) {
        _pendingByCid[cid] = _PendingClarification(
          action: 'create_task',
          knownFields: {
            ...pending.knownFields,
            if (isAlarmOrNotifChoice) 'prefer_reminder': true,
          },
        );
        return _clarificationReply(
          cid: cid,
          request: request,
          question: _tr(
            'تمام، ظبّطت نوع التنبيه! اكتبلي بس اسم المهمة اللي تحب نضيفها في الميعاد ده.',
            'Got the alert style set! Just tell me what you want to name this task.',
          ),
          pendingAction: 'create_task',
          knownFields: {
            ...pending.knownFields,
            if (isAlarmOrNotifChoice) 'prefer_reminder': true,
          },
        );
      }

      // Absorb explicit or relative date/time from reply or pending state.
      final pendingInMinutes =
          replyInMinutes ?? (pending.knownFields['in_minutes'] as int?);
      var finalDate = date ??
          (pending.knownFields['date'] != null
              ? DateTime.tryParse(pending.knownFields['date'].toString())
              : null);
      var finalTime = time ?? pending.knownFields['time']?.toString();
      if (replyInMinutes != null && date == null && time == null) {
        final shifted = now.add(Duration(minutes: replyInMinutes));
        finalDate = DateTime(shifted.year, shifted.month, shifted.day);
        finalTime =
            '${shifted.hour.toString().padLeft(2, '0')}:${shifted.minute.toString().padLeft(2, '0')}';
      } else if (finalTime != null && finalDate == null) {
        finalDate = DateTime(now.year, now.month, now.day);
      }

      final preferReminder =
          pending.knownFields['prefer_reminder'] == true || isAlarmOrNotifChoice;
      if (preferReminder &&
          _hasTool(request, 'create_reminder') &&
          date == null &&
          time == null &&
          pendingInMinutes != null) {
        _pendingByCid.remove(cid);
        return LlmReply(
          toolCalls: [
            _call('create_reminder', {
              'title': resolvedTitle,
              'in_minutes': pendingInMinutes,
            }),
          ],
        );
      }

      // If still NO date AND NO explicitNoDate -> ask once for timing.
      if (finalDate == null &&
          finalTime == null &&
          pendingInMinutes == null &&
          !explicitNoDate &&
          resolvedTitle.isNotEmpty) {
        _pendingByCid[cid] = _PendingClarification(
          action: 'create_task',
          knownFields: {
            ...pending.knownFields,
            'title': resolvedTitle,
          },
        );
        return _clarificationReply(
          cid: cid,
          request: request,
          question: _tr(
            'تمام! تحب أسجّل «$resolvedTitle» بميعاد إمتى (زي النهارده أو بكرة الساعة كام)، ولا من غير ميعاد محدد؟',
            'Got it! When should I schedule "$resolvedTitle" (e.g. today or tomorrow and at what time), or leave it with no specific date?',
          ),
          pendingAction: 'create_task',
          knownFields: {
            ...pending.knownFields,
            'title': resolvedTitle,
          },
        );
      }

      _pendingByCid.remove(cid);
      if (preferReminder &&
          _hasTool(request, 'create_reminder') &&
          (finalDate != null || finalTime != null)) {
        return LlmReply(
          toolCalls: [
            _call('create_reminder', {
              'title': resolvedTitle,
              'date': _ymd(finalDate ?? now),
              'time': finalTime ?? '09:00',
            }),
          ],
        );
      }
      return LlmReply(
        toolCalls: [
          _call('create_task', {
            'title': resolvedTitle,
            if (finalDate != null) 'date': _ymd(finalDate),
            if (finalDate != null && finalTime != null) 'time': finalTime,
            'priority': (pending.knownFields['priority'] ??
                    _nlu.parsePriority(norm))
                .toString(),
            if (pending.knownFields['category'] != null)
              'category': pending.knownFields['category'],
          }),
        ],
      );
    }

    _pendingByCid.remove(cid);
    return null;
  }

  LlmReply _handleTargetedMutation({
    required String cid,
    required String toolName,
    required String query,
    required String raw,
    required String norm,
    required Map<String, dynamic> extraArgs,
    required LlmRequest request,
  }) {
    if (query.isNotEmpty) {
      return LlmReply(
        toolCalls: [
          _call(toolName, {'query': query, ...extraArgs}),
        ],
      );
    }

    // Pronoun reference ("علمها خلصت", "امسحها") -> ONLY resolve if exactly 1 unambiguous ref in current conversation!
    final refs = _recentRefsByCid[cid] ?? const <_TaskRef>[];
    if (refs.length == 1) {
      return LlmReply(
        toolCalls: [
          _call(toolName, {'task_id': refs.first.id, ...extraArgs}),
        ],
      );
    }
    if (refs.length > 1) {
      final candidates = [
        for (final r in refs) {'task_id': r.id, 'title': r.title},
      ];
      _pendingByCid[cid] = _PendingClarification(
        action: toolName,
        knownFields: extraArgs,
        candidates: candidates,
      );
      final q = _isEnglish
          ? 'Which task did you mean: ${refs.take(3).map((r) => '"${r.title}"').join(' or ')}?'
          : 'تقصد أنهي مهمة فيهم: ${refs.take(3).map((r) => '«${r.title}»').join(' ولا ')}؟';
      return _clarificationReply(
        cid: cid,
        request: request,
        question: q,
        pendingAction: toolName,
        knownFields: {'candidates': [for (final r in refs) r.title]},
        keepLocalPending: false,
      );
    }

    // Fresh/empty reference stack: fetch pending list instead of guessing.
    _pendingByCid[cid] = _PendingClarification(
      action: toolName,
      knownFields: extraArgs,
    );
    return LlmReply(toolCalls: [_call('get_tasks', {'status': 'pending', 'limit': 8})]);
  }

  LlmReply? _resolveRelativeUpdate(
    String cid,
    NluAnalysisOutcome analysis,
    String norm,
    DateTime now,
    LlmRequest request,
  ) {
    var targetDate = analysis.requestedDate;
    var targetTime = analysis.requestedTime;
    final targetPriority = analysis.requestedPriority;

    // Support "قبلها بنص ساعة" / "بعدها بساعة" / "30 minutes earlier" relative to last referenced task.
    final refs = _recentRefsByCid[cid] ?? const <_TaskRef>[];
    final shiftEarlier30 = norm.contains('قبلها بنص') || norm.contains('30 min earlier') || norm.contains('half hour earlier');
    final shiftEarlier60 = norm.contains('قبلها بساع') || norm.contains('hour earlier');
    final shiftLater60 = norm.contains('بعدها بساع') || norm.contains('hour later');
    if ((shiftEarlier30 || shiftEarlier60 || shiftLater60) &&
        refs.length == 1 &&
        refs.first.time != null) {
      final parts = refs.first.time!.split(':');
      final baseDate = DateTime.tryParse(refs.first.date ?? '') ?? now;
      final baseDt = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      final offset = shiftEarlier30
          ? const Duration(minutes: -30)
          : (shiftEarlier60
              ? const Duration(hours: -1)
              : const Duration(hours: 1));
      final shifted = baseDt.add(offset);
      targetDate = DateTime(shifted.year, shifted.month, shifted.day);
      targetTime =
          '${shifted.hour.toString().padLeft(2, '0')}:${shifted.minute.toString().padLeft(2, '0')}';
    }

    final updates = <String, dynamic>{
      if (targetDate != null) 'date': _ymd(targetDate),
      'time': ?targetTime,
      'priority': ?targetPriority,
    };

    if (updates.isEmpty) {
      return _clarificationReply(
        cid: cid,
        request: request,
        question: _tr(
          'عايز تعدّل الميعاد لإمتى بالضبط (التاريخ أو الساعة) أو الأولوية؟',
          'What new date, time, or priority would you like to set?',
        ),
        pendingAction: 'update_task',
        knownFields: {if (analysis.targetQuery.isNotEmpty) 'query': analysis.targetQuery},
      );
    }

    // ToolValidator requires `date` if `time` is set when we know task's current date.
    if (updates.containsKey('time') &&
        !updates.containsKey('date') &&
        refs.length == 1 &&
        refs.first.date != null) {
      updates['date'] = refs.first.date;
    }

    return _handleTargetedMutation(
      cid: cid,
      toolName: 'update_task',
      query: analysis.targetQuery,
      raw: analysis.understanding.originalText,
      norm: norm,
      extraArgs: updates,
      request: request,
    );
  }

  LlmReply _handleReminderIntent(
    String cid,
    NluAnalysisOutcome analysis,
    LlmRequest request,
    DateTime now,
  ) {
    final spec = analysis.taskSpecs.isNotEmpty ? analysis.taskSpecs.first : null;
    final hasMissingTitle = spec == null || spec.isMissingTitle || spec.title.trim().isEmpty;
    final cleanTitle = hasMissingTitle ? '' : spec.title;
    final hasReminderTool = _hasTool(request, 'create_reminder');
    final norm = analysis.understanding.normalizedText;
    final explicitAlarm = _nlu.containsAny(norm, [
      'منبه', 'منبهه', 'يرن', 'صحيني', 'alarm',
    ]);
    final explicitNotif = _nlu.containsAny(norm, [
      'رساله', 'اشعار', 'نوتفيكيشن', 'notification',
    ]);

    DateTime? targetDate = spec?.date;
    String? targetTime = spec?.time;
    final relMinutes = analysis.inMinutes ?? spec?.inMinutes;
    if (relMinutes != null && targetDate == null && targetTime == null) {
      final shifted = now.add(Duration(minutes: relMinutes));
      targetDate = DateTime(shifted.year, shifted.month, shifted.day);
      targetTime =
          '${shifted.hour.toString().padLeft(2, '0')}:${shifted.minute.toString().padLeft(2, '0')}';
    }

    if (hasMissingTitle) {
      if (explicitAlarm || explicitNotif) {
        onAlertModeSelected?.call(
          explicitNotif && !explicitAlarm ? 'notification' : 'alarm',
        );
      }
      final whenPreview = targetDate != null
          ? _formatWhen(_ymd(targetDate), targetTime, now)
          : '';
      final whenClause = whenPreview.isEmpty
          ? ''
          : _tr(' ($whenPreview)', ' ($whenPreview)');
      return _clarificationReply(
        cid: cid,
        request: request,
        question: _tr(
          'تمام، جاهز أظبّطلك ${explicitAlarm ? 'المنبه' : 'التذكير'}$whenClause — تحب أفكّرك بإيه بالظبط؟',
          'Got it — I am ready to set your ${explicitAlarm ? 'alarm' : 'reminder'}$whenClause. What should I remind you about?',
        ),
        pendingAction: 'create_task',
        knownFields: {
          if (targetDate != null) 'date': _ymd(targetDate),
          'time': ?targetTime,
          'in_minutes': ?relMinutes,
          'priority': spec?.priority ?? 'high',
          'prefer_reminder': true,
          'missing_slot': 'title',
        },
      );
    }

    if (explicitAlarm || explicitNotif) {
      final mode = explicitNotif && !explicitAlarm ? 'notification' : 'alarm';
      onAlertModeSelected?.call(mode);
      if (hasReminderTool) {
        if (relMinutes != null) {
          return LlmReply(
            toolCalls: [
              _call('create_reminder', {
                'title': cleanTitle,
                'in_minutes': relMinutes,
              }),
            ],
          );
        }
        if (targetDate != null || targetTime != null) {
          return LlmReply(
            toolCalls: [
              _call('create_reminder', {
                'title': cleanTitle,
                'date': _ymd(targetDate ?? now),
                'time': targetTime ?? '09:00',
              }),
            ],
          );
        }
      }
    }

    final known = <String, dynamic>{
      'title': cleanTitle,
      if (targetDate != null) 'date': _ymd(targetDate),
      'time': ?targetTime,
      'in_minutes': ?relMinutes,
      'priority': spec.priority,
      if (spec.category != null) 'category': spec.category,
      'prefer_reminder': true,
    };
    final whenPreview = targetDate != null
        ? _formatWhen(_ymd(targetDate), targetTime, now)
        : '';
    final whenClause = whenPreview.isEmpty
        ? ''
        : _tr(' (الميعاد: $whenPreview)', ' ($whenPreview)');
    return _clarificationReply(
      cid: cid,
      request: request,
      question: _tr(
        'إعداد المنبه والتذكير لـ «$cleanTitle»$whenClause:\n'
        'تأكد من تفعيل إذن الإشعارات، واختار هل تحب أفكرك بـ «منبه يرن بصوت كامل» ولا «رسالة إشعار هادئة»؟',
        'Alarm & Reminder Setup for "$cleanTitle"$whenClause:\n'
        'Make sure notifications are allowed, then pick whether you want a "Ringing Alarm" or a "Quiet Notification".',
      ),
      pendingAction: 'create_task',
      knownFields: known,
    );
  }

  // ---------------------------------------------------------------------------
  // Tool synthesis (strict honesty: never claim success before checking ToolResult)
  // ---------------------------------------------------------------------------

  Future<LlmReply> _replyFromTools(
    String cid,
    LlmRequest request,
    DateTime now,
  ) async {
    final messages = request.messages;
    final trailingTools = <ConversationMessage>[];
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == MessageRole.tool) {
        trailingTools.insert(0, messages[i]);
      } else {
        break;
      }
    }
    if (trailingTools.isEmpty) {
      return LlmReply(
        text: _tr(
          'محتاج معلومات أوضح قبل التنفيذ.',
          'I need clearer details before making changes.',
        ),
      );
    }

    final lastUserRaw = messages.lastWhere(
      (m) => m.role == MessageRole.user,
      orElse: () => ConversationMessage.user(''),
    ).content;
    final lastUserNorm = _nlu.normalize(lastUserRaw);

    final parsed = <({String name, ToolResult result})>[];
    for (final msg in trailingTools) {
      final decoded = jsonDecode(msg.content) as Map<String, dynamic>;
      parsed.add((
        name: msg.toolName ?? '',
        result: ToolResult.fromJson(decoded),
      ));
    }

    // 1. Handle Plan Confirmation Live Verification (`verifyingBeforeApply`)
    final planSession = _planning.sessionFor(cid);
    if (planSession != null && planSession.phase == PlanningPhase.verifyingBeforeApply) {
      final openTasks = _mergeTaskLists(parsed);
      final decision = _planning.verifyHashAndPrepareApply(
        conversationId: cid,
        liveOpenTasks: openTasks,
        now: now,
        callBuilder: _call,
      );
      if (decision.updateCalls.isNotEmpty) {
        return LlmReply(toolCalls: decision.updateCalls);
      }
      return decision.reply!;
    }

    // 2. Batch or single `create_task` / `create_reminder` confirmation (including split-repair when paired with delete_task)
    final createCalls = parsed
        .where((e) => e.name == 'create_task' || e.name == 'create_reminder')
        .toList();
    if (createCalls.isNotEmpty) {
      _recordCreatedRefs(cid, createCalls);
      final baseReply = _formatCreatedReply(createCalls, now);
      if (_isBreakdownRequest(lastUserNorm)) {
        final breakdownText = _buildBreakdownReply(lastUserRaw, cid, messages, now);
        return LlmReply(text: '$baseReply\n\n$breakdownText');
      }
      return LlmReply(text: baseReply);
    }

    // 3. Batch `update_task` results (e.g., confirmed schedule draft!)
    final updateCalls = parsed.where((e) => e.name == 'update_task').toList();
    if (updateCalls.length > 1) {
      final ok = updateCalls.where((c) => c.result.isSuccess).toList();
      final failed = updateCalls.where((c) => !c.result.isSuccess).toList();
      if (ok.isEmpty) {
        return LlmReply(
          text: _tr(
            'ما قدرتش أحفظ التعديلات في قاعدة البيانات (${failed.first.result.message ?? 'خطأ تحقق'}). جدولك فضل زي ما هو.',
            'Could not save the schedule updates (${failed.first.result.message ?? 'validation error'}). Your tasks remain unchanged.',
          ),
        );
      }
      if (failed.isEmpty) {
        return LlmReply(
          text: _tr(
            'تمام! اعتمدت وحفظتلك مواعيد ${ok.length} مهام في جدولك بنجاح.',
            'Done! Applied and saved updated times for ${ok.length} tasks to your schedule.',
          ),
        );
      }
      return LlmReply(
        text: _tr(
          'حفظت مواعيد ${ok.length} مهام بس، وفشلت ${failed.length} في التحديث، فتأكد من جدولك قبل الاعتماد.',
          'Saved updates for ${ok.length} task(s), while ${failed.length} failed; please review your schedule.',
        ),
      );
    }

    // 4. Single mutation (`complete_task`, `delete_task`, `update_task`)
    if (parsed.length == 1 &&
        (parsed.first.name == 'complete_task' ||
            parsed.first.name == 'delete_task' ||
            parsed.first.name == 'update_task')) {
      final first = parsed.first;
      final res = first.result;
      if (res.status == ToolStatus.ambiguous) {
        final rawCandidates = (res.data['candidates'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _pendingByCid[cid] = _PendingClarification(
          action: first.name,
          knownFields: const {},
          candidates: rawCandidates,
        );
        final lines = [
          for (var i = 0; i < rawCandidates.length; i++)
            '${_indexLabel(i + 1)} ${_quote(rawCandidates[i]['title']?.toString() ?? '')}',
        ].join('\n');
        return LlmReply(
          text: _tr(
            'لقيت أكتر من مهمة بالاسم ده:\n$lines\nقولّي تقصد أنهي رقم أو اسم بالضبط؟',
            'I found multiple matching tasks:\n$lines\nWhich number or title did you mean?',
          ),
        );
      }
      if (res.status == ToolStatus.notFound) {
        return LlmReply(
          text: _tr(
            'ملقتش مهمة بالاسم ده في جدولك. تحب أعرضلك مهامك المفتوحة أو تضيفها كمهمة جديدة؟',
            'I could not find a task matching that name. Would you like me to list your open tasks or create it as a new one?',
          ),
        );
      }
      if (!res.isSuccess) {
        return LlmReply(
          text: res.message ??
              _tr(
                'محصلش تعديل لأن في معلومة ناقصة.',
                'No changes were made because a required field is missing.',
              ),
        );
      }
      final title = (res.data['title'] ?? _tr('المهمة', 'the task')).toString();
      if (first.name == 'complete_task') {
        _recentRefsByCid.remove(cid);
        final isExam = StudentModeStore.isActive &&
            _nlu.containsAny(
              _nlu.normalize(title),
              ['امتحان', 'اختبار', 'كويز', 'ميدتيرم', 'فاينل', 'exam', 'quiz', 'midterm'],
            );
        if (isExam) {
          return LlmReply(
            text: _tr(
              'عاش بجد! علّمت على «$title» إنها خلصت.\n'
              'طمّني عملت إيه أو جبت تقدير كام عشان نسجّل نتيجتك في وضع الطالب؟',
              'Nice work! Marked "$title" as completed.\n'
              'Tell me how it went or what grade you got so we can save your result in Student Mode.',
            ),
          );
        }
        return LlmReply(
          text: _tr(
            'عاش عليك! علّمت على «$title» إنها خلصت. خطوة كويسة النهارده، تحب نكمل باللي بعدها؟',
            'Well done! Marked "$title" as completed. Want to pick what to tackle next?',
          ),
        );
      }
      if (first.name == 'delete_task') {
        _recentRefsByCid.remove(cid);
        return LlmReply(
          text: _tr(
            'تمام، مسحت «$title» من جدولك.',
            'Done — removed "$title" from your tasks.',
          ),
        );
      }
      final id = (res.data['task_id'] ?? res.data['id'] ?? '').toString();
      final date = res.data['date'] as String?;
      final time = res.data['time'] as String?;
      if (id.isNotEmpty) {
        _recentRefsByCid[cid] = [_TaskRef(id: id, title: title, date: date, time: time)];
      }
      final when = _formatWhen(date, time, now);
      return LlmReply(
        text: when.isEmpty
            ? _tr('تمام، حدّثتلك بيانات «$title».', 'Updated "$title".')
            : _tr(
                'تمام، نقلتلك ميعاد «$title» لـ $when.',
                'Rescheduled "$title" to $when.',
              ),
      );
    }

    // 5. Read results (`get_tasks` / `get_schedule` / `get_daily_summary` / `search_tasks`)
    final allTasks = _mergeTaskLists(parsed);
    Map<String, dynamic>? summaryData;
    for (final entry in parsed) {
      if (entry.name == 'get_daily_summary') summaryData = entry.result.data;
    }

    // If pending disambiguation was waiting on pending task list:
    final pending = _pendingByCid[cid];
    if (pending != null &&
        parsed.length == 1 &&
        parsed.first.name == 'get_tasks' &&
        (pending.action == 'complete_task' ||
            pending.action == 'delete_task' ||
            pending.action == 'update_task')) {
      if (allTasks.isEmpty) {
        _pendingByCid.remove(cid);
        return LlmReply(
          text: _tr(
            'مفيش مهام مفتوحة دلوقتي عشان أعدّل عليها.',
            'There are no open tasks right now to modify.',
          ),
        );
      }
      if (allTasks.length == 1) {
        _pendingByCid.remove(cid);
        final one = allTasks.first;
        final call = _call(pending.action, {
          'task_id': one['task_id'] ?? one['id'],
          if (one['title'] != null) '_preview_title': one['title'],
          ...pending.knownFields,
        });
        return _stageWriteCallsIfNeeded(
          cid: cid,
          reply: LlmReply(toolCalls: [call]),
          now: now,
          rawPrompt: lastUserRaw,
        );
      }
      _pendingByCid[cid] = _PendingClarification(
        action: pending.action,
        knownFields: pending.knownFields,
        candidates: allTasks.take(5).toList(),
      );
      final lines = [
        for (var i = 0; i < allTasks.length && i < 5; i++)
          '${_indexLabel(i + 1)} ${_quote('${allTasks[i]['title'] ?? ''}')}',
      ].join('\n');
      return LlmReply(
        text: _tr(
          'عندك أكتر من مهمة مفتوحة، تقصد أنهي واحدة فيهم؟\n$lines',
          'You have multiple open tasks — which one did you mean?\n$lines',
        ),
      );
    }

    if (_isOverwhelmOrCoaching(lastUserNorm)) {
      return LlmReply(text: _buildOverwhelmCoachingReply(allTasks, now));
    }

    // Planning request -> feed live tasks into deterministic PlanningCoordinator!
    final analysis = _nlu.analyze(lastUserRaw, now: now, languageCode: _langCode);
    if (analysis.understanding.intent == EgyptianIntent.schedule) {
      return LlmReply(
        text: _planning.handleFetchedTasks(
          conversationId: cid,
          openTasks: allTasks,
          userPromptRaw: lastUserRaw,
          now: now,
        ),
      );
    }

    if (summaryData != null) {
      final done = summaryData['completed_count'] ?? summaryData['completed'] ?? 0;
      final pendingCount =
          summaryData['pending_count'] ?? summaryData['pending'] ?? allTasks.length;
      final overdue = summaryData['overdue_count'] ?? summaryData['overdue'] ?? 0;
      final buf = StringBuffer(
        _isEnglish
            ? 'Your summary: $done completed, $pendingCount open task(s)'
                '${(overdue is num && overdue > 0) ? ' ($overdue overdue)' : ''}.'
            : 'ملخصك الحالي: خلّصت $done مهام، ولسه قدامك $pendingCount مهام مفتوحة'
                '${(overdue is num && overdue > 0) ? ' (منهم $overdue متأخرين)' : ''}.',
      );
      if (allTasks.isNotEmpty) {
        buf.write(
          _isEnglish
              ? '\nBest next step to start with: "${allTasks.first['title']}".'
              : '\nأقرب خطوة تبدأ بيها دلوقتي: «${allTasks.first['title']}».',
        );
      }
      return LlmReply(text: buf.toString());
    }

    if (allTasks.isEmpty) {
      return LlmReply(
        text: _tr(
          'مفيش مهام مطابقة حاليًا. قولّي لو تحب نضيف مهمة جديدة أو نخطّط يومك.',
          'No matching tasks found right now. Tell me if you want to add a task or plan your day.',
        ),
      );
    }

    _recentRefsByCid[cid] = [
      for (final t in allTasks.take(5))
        if ((t['task_id'] ?? t['id']) != null)
          _TaskRef(
            id: (t['task_id'] ?? t['id']).toString(),
            title: (t['title'] ?? '').toString(),
            date: t['date']?.toString(),
            time: t['time']?.toString(),
          ),
    ];

    final lines = [
      for (var i = 0; i < allTasks.length && i < 6; i++)
        '${_indexLabel(i + 1)} ${_formatTaskLine(allTasks[i], now)}',
    ].join('\n');
    return LlmReply(
      text: _tr(
        'دي المهام اللي لقيتها عندك:\n$lines\nقولّي لو حابب نرتّبهم أو نشتغل على واحدة منهم.',
        'Here are the tasks I found:\n$lines\nTell me if you want to schedule them or work on one first.',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Formatting & small helpers
  // ---------------------------------------------------------------------------

  LlmReply _clarificationReply({
    required String cid,
    required LlmRequest request,
    required String question,
    required String pendingAction,
    required Map<String, dynamic> knownFields,
    bool keepLocalPending = true,
  }) {
    if (keepLocalPending) {
      _pendingByCid[cid] = _PendingClarification(
        action: pendingAction,
        knownFields: knownFields,
      );
    }
    final shortQ = question.length > 290 ? question.substring(0, 290) : question;
    if (_hasTool(request, AssistantTools.clarificationName)) {
      const allowed = {
        'create_task', 'update_task', 'delete_task', 'complete_task',
        'create_reminder', 'update_reminder', 'delete_reminder', 'other',
      };
      return LlmReply(
        toolCalls: [
          _call(AssistantTools.clarificationName, {
            'question': shortQ,
            'pending_action': allowed.contains(pendingAction) ? pendingAction : 'other',
            'known_fields': knownFields,
          }),
        ],
      );
    }
    return LlmReply(text: shortQ);
  }

  List<ToolCall> _buildCreateCalls(List<ExtractedTaskSpec> specs) {
    return [
      for (final spec in specs)
        _call('create_task', {
          'title': spec.title,
          if (spec.date != null) 'date': _ymd(spec.date!),
          if (spec.date != null && spec.time != null) 'time': spec.time!,
          'priority': spec.priority,
          if (spec.recurrence != 'none') 'recurrence': spec.recurrence,
          if (spec.category != null) 'category': spec.category!,
        }),
    ];
  }

  // ---------------------------------------------------------------------------
  // Confirm-Before-Write Preview Gate (Preview -> Edit -> Confirm -> Execute)
  // ---------------------------------------------------------------------------

  LlmReply _stageWriteCallsIfNeeded({
    required String cid,
    required LlmReply reply,
    required DateTime now,
    required String rawPrompt,
  }) {
    if (!requireMutationConfirmation || reply.toolCalls.isEmpty) {
      return reply;
    }
    final hasWrite = reply.toolCalls.any(
      (c) => _writeToolNames.contains(c.name),
    );
    if (!hasWrite) return reply;

    final cleanedCalls = [
      for (final call in reply.toolCalls)
        ToolCall(
          id: call.id,
          name: call.name,
          arguments: Map<String, dynamic>.from(call.arguments)
            ..remove('_preview_title'),
        ),
    ];
    final previewTitles = <String, String>{
      for (final call in reply.toolCalls)
        if (call.arguments['_preview_title'] != null)
          call.id: call.arguments['_preview_title'].toString(),
    };

    final draft = _PendingMutationDraft(
      actionKind: cleanedCalls.first.name,
      toolCalls: cleanedCalls,
      originalPrompt: rawPrompt,
    );
    _pendingDraftByCid[cid] = draft;
    _draftStagedAtByCid[cid] = DateTime.now();
    onTelemetryEvent?.call('preview_shown');
    return LlmReply(
      text: _formatMutationPreview(
        draft,
        now,
        previewTitles: previewTitles,
        cid: cid,
      ),
    );
  }

  LlmReply? _handlePendingMutationDraft({
    required String cid,
    required _PendingMutationDraft draft,
    required String raw,
    required String norm,
    required DateTime now,
  }) {
    // 1. Explicit cancellation -> ZERO DB writes.
    if (_isDraftCancel(norm)) {
      _pendingDraftByCid.remove(cid);
      _draftStagedAtByCid.remove(cid);
      onTelemetryEvent?.call('draft_cancelled');
      return LlmReply(
        text: _tr(
          'تمام، لغيت المسودة من غير أي تغيير في جدولك.',
          'Cancelled — left your tasks completely unchanged.',
        ),
      );
    }

    // 2. Explicit confirmation -> execute exact staged tool calls once.
    if (_isDraftConfirm(norm)) {
      _pendingDraftByCid.remove(cid);
      final stagedAt = _draftStagedAtByCid.remove(cid);
      if (stagedAt != null) {
        final ms = DateTime.now().difference(stagedAt).inMilliseconds;
        if (ms >= 0) onDraftConfirmLatency?.call(ms);
      }
      onTelemetryEvent?.call('draft_confirmed');
      return LlmReply(toolCalls: draft.toolCalls);
    }

    // 3. Structured quick-edit command emitted by the UI Quick-Edit Sheet.
    if (raw.startsWith('تعديل المسودة |') || raw.startsWith('EDIT_DRAFT |')) {
      final updated = _applyStructuredQuickEdit(draft, raw, now);
      onTelemetryEvent?.call('draft_edited');
      if (updated.applyImmediately) {
        _pendingDraftByCid.remove(cid);
        final stagedAt = _draftStagedAtByCid.remove(cid);
        if (stagedAt != null) {
          final ms = DateTime.now().difference(stagedAt).inMilliseconds;
          if (ms >= 0) onDraftConfirmLatency?.call(ms);
        }
        onTelemetryEvent?.call('draft_confirmed');
        return LlmReply(toolCalls: updated.draft.toolCalls);
      }
      _pendingDraftByCid[cid] = updated.draft;
      return LlmReply(
        text: _formatMutationPreview(updated.draft, now, cid: cid),
      );
    }

    // 4. Conversational in-place edit ("خليها الساعة 9", "خليها الخميس", "غيّر العنوان لـ ...", "خليها شهريًا").
    final edited = _tryApplyConversationalDraftEdit(draft, raw, norm, now);
    if (edited != null) {
      _pendingDraftByCid[cid] = edited;
      onTelemetryEvent?.call('draft_edited');
      return LlmReply(
        text: _formatMutationPreview(edited, now, cid: cid),
      );
    }

    // 5. Unrelated new command/query -> discard stale draft and process normally.
    _pendingDraftByCid.remove(cid);
    return null;
  }

  bool _isDraftConfirm(String norm) {
    final cleaned = norm.trim();
    if (cleaned.isEmpty) return false;
    return RegExp(
      r'^(?:تمام|ايوه|أيوة|اه|آه|موافق|اعتمد|اعتمدها|اعتمدهم|احفظ|احفظها|احفظهم|سجل|سجلها|ضيفها|ضيفهم|نفذ|نفذها|تاكيد|تأكيد|تأكيد\s+الحذف|تاكيد\s+الحذف|امسح\s+فعلا|yes|yeah|yep|ok|okay|sure|confirm|approve|save|apply|confirm\s+delete)(?:\s+(?:احفظ|اعتمد|ضيفها|ضيفهم|يا\s+سيدي|لو\s+سمحت|please))?$',
      caseSensitive: false,
    ).hasMatch(cleaned);
  }

  bool _isDraftCancel(String norm) {
    final cleaned = norm.trim();
    if (cleaned.isEmpty) return false;
    return RegExp(
      r'^(?:لا|لأ|لا\s+خلاص|الغي|إلغاء|الغاء|الغيها|الغيه|خلاص|سيبك|مش\s+عايز|بلاش|تراجع|no|nope|cancel|discard|abort|nevermind|never\s+mind|forget\s+it)$',
      caseSensitive: false,
    ).hasMatch(cleaned);
  }

  ({
    _PendingMutationDraft draft,
    bool applyImmediately,
  }) _applyStructuredQuickEdit(
    _PendingMutationDraft draft,
    String raw,
    DateTime now,
  ) {
    final parts = raw.split('|').skip(1);
    String? newTitle;
    String? newDate;
    String? newTime;
    String? newRecurrence;
    String? newAlertMode;
    var applyNow = false;

    for (final part in parts) {
      final idx = part.indexOf(':');
      if (idx <= 0) continue;
      final key = part.substring(0, idx).trim().toLowerCase();
      final val = part.substring(idx + 1).trim();
      if (val.isEmpty) continue;
      switch (key) {
        case 'title' || 'العنوان':
          newTitle = val;
        case 'date' || 'التاريخ':
          if (val == 'none' || val == 'بدون') {
            newDate = '';
          } else {
            newDate = val;
          }
        case 'time' || 'الوقت':
          if (val == 'none' || val == 'بدون') {
            newTime = '';
          } else {
            newTime = val;
          }
        case 'recurrence' || 'التكرار':
          newRecurrence = val;
        case 'alert' || 'التنبيه':
          newAlertMode = val;
          onAlertModeSelected?.call(val == 'notification' ? 'notification' : 'alarm');
        case 'apply':
          applyNow = val == 'true';
      }
    }

    final updatedCalls = <ToolCall>[];
    for (var i = 0; i < draft.toolCalls.length; i++) {
      final c = draft.toolCalls[i];
      if (i > 0) {
        updatedCalls.add(c);
        continue;
      }
      final args = Map<String, dynamic>.from(c.arguments);
      if (newTitle != null && newTitle.isNotEmpty) {
        args['title'] = newTitle;
      }
      if (newDate != null) {
        if (newDate.isEmpty) {
          args.remove('date');
          args.remove('time');
        } else {
          args['date'] = newDate;
        }
      }
      if (newTime != null) {
        if (newTime.isEmpty) {
          args.remove('time');
        } else {
          args['time'] = newTime;
          args.putIfAbsent('date', () => _ymd(now));
        }
      }
      if (newRecurrence != null &&
          const {'none', 'daily', 'weekdays', 'weekly', 'monthly'}
              .contains(newRecurrence)) {
        args['recurrence'] = newRecurrence;
      }
      updatedCalls.add(ToolCall(id: c.id, name: c.name, arguments: args));
    }

    return (
      draft: _PendingMutationDraft(
        actionKind: draft.actionKind,
        toolCalls: updatedCalls,
        originalPrompt: draft.originalPrompt,
        alertMode: newAlertMode ?? draft.alertMode,
        revision: draft.revision + 1,
      ),
      applyImmediately: applyNow,
    );
  }

  _PendingMutationDraft? _tryApplyConversationalDraftEdit(
    _PendingMutationDraft draft,
    String raw,
    String norm,
    DateTime now,
  ) {
    if (draft.isDestructive) return null;

    final editDate = _nlu.parseDate(norm, now);
    final editTime = _nlu.parseTime(norm);
    final editRecurrence = _nlu.parseRecurrence(norm);
    final editPrio = _nlu.parseExplicitPriority(norm);
    final wantsAlarm = _nlu.containsAny(norm, ['منبه', 'يرن', 'alarm']);
    final wantsNotif =
        _nlu.containsAny(norm, ['رساله', 'اشعار', 'نوتفيكيشن', 'notification']);
    final titleMatch = RegExp(
      r'(?:غير|غيّر|عدل|عدّل|سميها|سمّيها|خلي\s+العنوان|خلي\s+الاسم|rename\s+to|change\s+title\s+to)\s*(?:العنوان|الاسم)?\s*(?:لـ|ل|إلى|الى|to)?\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    final newTitle = titleMatch?.group(1)?.trim();

    final isEditLike = editDate != null ||
        editTime != null ||
        editRecurrence != 'none' ||
        editPrio != null ||
        wantsAlarm ||
        wantsNotif ||
        (newTitle != null && newTitle.isNotEmpty);
    if (!isEditLike) return null;

    // Avoid hijacking a brand-new full command ("ضيفلي...", "وريني...", "امسح...").
    if (RegExp(
      r'^(?:ضيف|سجل|حط|وريني|ايه\s+اللي|امسح|احذف|شيل|رتبلي|لخص|اهلا|add\s+|create\s+|delete\s+|show\s+)',
      caseSensitive: false,
    ).hasMatch(norm)) {
      return null;
    }

    String? nextAlert = draft.alertMode;
    if (wantsNotif && !wantsAlarm) {
      nextAlert = 'notification';
      onAlertModeSelected?.call('notification');
    } else if (wantsAlarm) {
      nextAlert = 'alarm';
      onAlertModeSelected?.call('alarm');
    }

    final updatedCalls = <ToolCall>[];
    for (var i = 0; i < draft.toolCalls.length; i++) {
      final c = draft.toolCalls[i];
      if (i > 0) {
        updatedCalls.add(c);
        continue;
      }
      final args = Map<String, dynamic>.from(c.arguments);
      if (newTitle != null && newTitle.isNotEmpty) {
        args['title'] = newTitle;
      }
      if (editDate != null) {
        args['date'] = _ymd(editDate);
        args.remove('in_minutes');
      }
      if (editTime != null) {
        args['time'] = editTime;
        args.putIfAbsent('date', () => _ymd(now));
        args.remove('in_minutes');
      }
      if (editRecurrence != 'none') {
        args['recurrence'] = editRecurrence;
      }
      if (editPrio != null) {
        args['priority'] = editPrio;
      }
      updatedCalls.add(ToolCall(id: c.id, name: c.name, arguments: args));
    }

    return _PendingMutationDraft(
      actionKind: draft.actionKind,
      toolCalls: updatedCalls,
      originalPrompt: draft.originalPrompt,
      alertMode: nextAlert,
      revision: draft.revision + 1,
    );
  }

  String _formatMutationPreview(
    _PendingMutationDraft draft,
    DateTime now, {
    Map<String, String> previewTitles = const {},
    String cid = 'default',
  }) {
    final revSuffix = draft.revision > 1
        ? _tr(' • تعديل ${draft.revision}', ' • rev ${draft.revision}')
        : '';

    String resolveTargetLabel(ToolCall call) {
      final a = call.arguments;
      final direct = (previewTitles[call.id] ?? a['title'] ?? a['query'] ?? '')
          .toString()
          .trim();
      if (direct.isNotEmpty) return direct;
      final taskId = a['task_id']?.toString();
      if (taskId != null && taskId.isNotEmpty) {
        final match = (_recentRefsByCid[cid] ?? const <_TaskRef>[])
            .where((r) => r.id == taskId)
            .firstOrNull;
        if (match != null) return match.title;
      }
      return _tr('المهمة المحددة', 'selected task');
    }

    String recurrenceLabel(String? r) => switch (r) {
          'daily' => _tr('يوميًا', 'Daily'),
          'weekdays' => _tr('أيام العمل', 'Weekdays'),
          'weekly' => _tr('أسبوعيًا', 'Weekly'),
          'monthly' => _tr('شهريًا', 'Monthly'),
          _ => '',
        };

    if (draft.isDestructive) {
      final lines = [
        for (final call in draft.toolCalls)
          '• ${_quote(resolveTargetLabel(call))}',
      ].join('\n');
      return _tr(
        '⚠️ تأكيد قبل الحذف (لم يتم الحذف بعد$revSuffix):\n'
        '$lines\n'
        'اضغط «تأكيد الحذف» للمتابعة أو «إلغاء» للتراجع.',
        '⚠️ Confirm before deleting (not deleted yet$revSuffix):\n'
        '$lines\n'
        'Tap "Confirm Delete" to proceed or "Cancel" to keep your tasks.',
      );
    }

    if (draft.actionKind == 'update_task' ||
        draft.actionKind == 'update_reminder') {
      final call = draft.toolCalls.first;
      final a = call.arguments;
      final label = resolveTargetLabel(call);
      final when = _formatWhen(a['date']?.toString(), a['time']?.toString(), now);
      final rec = recurrenceLabel(a['recurrence']?.toString());
      final details = [
        if (when.isNotEmpty) _tr('الميعاد الجديد: $when', 'New time: $when'),
        if (a['priority'] != null)
          _tr('الأولوية: ${a['priority']}', 'Priority: ${a['priority']}'),
        if (rec.isNotEmpty) _tr('التكرار: $rec', 'Repeats: $rec'),
      ].join(' • ');
      return _tr(
        '🔍 مراجعة قبل التعديل (مسودة — لم يتم التعديل بعد$revSuffix):\n'
        '• ${_quote(label)}${details.isEmpty ? '' : ' — $details'}\n'
        'اضغط «اعتماد وحفظ» للتنفيذ، أو عدّل أي تفصيلة، أو «إلغاء».',
        '🔍 Review before updating (draft — not applied yet$revSuffix):\n'
        '• ${_quote(label)}${details.isEmpty ? '' : ' — $details'}\n'
        'Tap "Confirm & Save", edit any detail, or "Cancel".',
      );
    }

    if (draft.actionKind == 'complete_task') {
      final label = resolveTargetLabel(draft.toolCalls.first);
      return _tr(
        '🔍 مراجعة قبل التعليم كمكتملة (لم يتم التعديل بعد$revSuffix):\n'
        '• ${_quote(label)}\n'
        'اضغط «اعتماد وحفظ» للتأكيد أو «إلغاء».',
        '🔍 Review before completing (not changed yet$revSuffix):\n'
        '• ${_quote(label)}\n'
        'Tap "Confirm & Save" or "Cancel".',
      );
    }

    // create_task / create_reminder (single or multi-clause)
    final lines = <String>[];
    for (var i = 0; i < draft.toolCalls.length; i++) {
      final call = draft.toolCalls[i];
      final a = call.arguments;
      final title = resolveTargetLabel(call);
      String when = _formatWhen(a['date']?.toString(), a['time']?.toString(), now);
      if (when.isEmpty && a['in_minutes'] != null) {
        final mins = (a['in_minutes'] as num).toInt();
        when = _tr('بعد $mins دقيقة', 'in $mins min');
      }
      final rec = recurrenceLabel(a['recurrence']?.toString());
      final parts = <String>[
        when.isEmpty
            ? _tr('بدون ميعاد محدد', 'No specific date')
            : _tr('الميعاد: $when', 'When: $when'),
        if (rec.isNotEmpty) _tr('التكرار: $rec', 'Repeats: $rec'),
        if (call.name == 'create_reminder' || draft.alertMode != null)
          (draft.alertMode == 'notification'
              ? _tr('تنبيه: إشعار هادئ', 'Alert: Quiet notification')
              : _tr('تنبيه: منبه يرن', 'Alert: Ringing alarm')),
      ];
      final prefix = draft.toolCalls.length > 1 ? '${_indexLabel(i + 1)} ' : '• ';
      lines.add('$prefix${_quote(title)} — ${parts.join(' • ')}');
    }

    return _tr(
      '🔍 مراجعة قبل الحفظ (مسودة — لم يتم الحفظ بعد$revSuffix):\n'
      '${lines.join('\n')}\n'
      'راجع العنوان والميعاد: اضغط «اعتماد وحفظ»، أو «تعديل»، أو «إلغاء».',
      '🔍 Review before saving (draft — not saved yet$revSuffix):\n'
      '${lines.join('\n')}\n'
      'Check title & timing: tap "Confirm & Save", "Edit", or "Cancel".',
    );
  }

  List<Map<String, dynamic>> _mergeTaskLists(
    List<({String name, ToolResult result})> parsed,
  ) {
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final entry in parsed) {
      final d = entry.result.data;
      final list = (d['tasks'] as List?) ?? (d['items'] as List?) ?? const [];
      for (final item in list) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final key = (m['task_id'] ?? m['id'] ?? m['title'] ?? '').toString();
        if (key.isEmpty || seen.add(key)) out.add(m);
      }
    }
    return out;
  }

  void _recordCreatedRefs(
    String cid,
    List<({String name, ToolResult result})> calls,
  ) {
    final refs = <_TaskRef>[];
    for (final c in calls) {
      if (!c.result.isSuccess) continue;
      final d = c.result.data;
      final id = (d['task_id'] ?? d['id'] ?? '').toString();
      final title = (d['title'] ?? '').toString();
      if (id.isNotEmpty && title.isNotEmpty) {
        refs.add(_TaskRef(
          id: id,
          title: title,
          date: d['date']?.toString(),
          time: d['time']?.toString(),
        ));
      }
    }
    if (refs.isNotEmpty) _recentRefsByCid[cid] = refs;
  }

  Map<String, dynamic>? _pickCandidate(
    String norm,
    List<Map<String, dynamic>> candidates,
  ) {
    if (candidates.isEmpty) return null;
    if (RegExp(r'(?:^|\s)(?:الاول|الأول|الاولي|الأولى|1|١|واحد|first|1st)(?=\s|$)', caseSensitive: false)
        .hasMatch(norm)) {
      return candidates[0];
    }
    if (candidates.length >= 2 &&
        RegExp(r'(?:^|\s)(?:التاني|التانيه|الثاني|الثانية|2|٢|اتنين|second|2nd)(?=\s|$)', caseSensitive: false)
            .hasMatch(norm)) {
      return candidates[1];
    }
    if (candidates.length >= 3 &&
        RegExp(r'(?:^|\s)(?:التالت|التالته|الثالث|3|٣|third|3rd)(?=\s|$)', caseSensitive: false)
            .hasMatch(norm)) {
      return candidates[2];
    }
    final cleanQuery = _nlu.extractCleanClauseTitle(norm);
    if (cleanQuery.isNotEmpty) {
      final matches = candidates.where(
        (c) => _nlu.normalize((c['title'] ?? '').toString()).contains(_nlu.normalize(cleanQuery)),
      ).toList();
      if (matches.length == 1) return matches.first;
    }
    return null;
  }

  String _formatCreatedReply(
    List<({String name, ToolResult result})> calls,
    DateTime now,
  ) {
    final succeeded = calls.where((c) => c.result.isSuccess).toList();
    final failedCount = calls.length - succeeded.length;
    if (succeeded.isEmpty) {
      return calls.first.result.message ??
          _tr(
            'ما قدرتش أسجّل المهمة، ممكن توضّحلي الاسم والميعاد؟',
            'Could not save the task — please clarify the title and date.',
          );
    }
    if (succeeded.length == 1 && failedCount == 0) {
      final entry = succeeded.first;
      final d = entry.result.data;
      final title = (d['title'] ?? _tr('المهمة', 'the task')).toString();
      final when = _formatWhen(d['date'] as String?, d['time'] as String?, now);
      final scheduleNote = _scheduleStatusNote(d['schedule_status']?.toString());
      if (entry.name == 'create_reminder') {
        final isAlarm = (d['alert_mode'] ?? 'alarm').toString() == 'alarm';
        final whenText = when.isEmpty ? '' : _tr(' في ميعاد $when', ' for $when');
        return _tr(
          isAlarm
              ? 'تمام، ظبطتلك «$title»$whenText كمنبه وضفته في جدولك.$scheduleNote'
              : 'تمام، ظبطتلك «$title»$whenText كرسالة إشعار وضفتها في جدولك.$scheduleNote',
          isAlarm
              ? 'All set — saved "$title"$whenText as an alarm in your schedule.$scheduleNote'
              : 'All set — saved "$title"$whenText as a quiet notification in your schedule.$scheduleNote',
        );
      }
      if (_isEnglish) {
        final whenText = when.isEmpty ? '' : ' ($when)';
        return 'Added "$title"$whenText to your tasks.$scheduleNote Want to start a focus step or plan your day?';
      }
      final whenText = when.isEmpty ? '' : ' في ميعاد $when';
      return 'تمام، ضفتلك «$title»$whenText.$scheduleNote تحب نبدأ خطوة تركيز دلوقتي أو نقسّمها لخطوات؟';
    }
    final lines = <String>[];
    String? degradedStatus;
    for (var i = 0; i < succeeded.length; i++) {
      final d = succeeded[i].result.data;
      final title = (d['title'] ?? _tr('مهمة', 'Task')).toString();
      final when = _formatWhen(d['date'] as String?, d['time'] as String?, now);
      final st = d['schedule_status']?.toString();
      if (st == 'permissionDenied' || st == 'inexactFallback') {
        degradedStatus ??= st;
      }
      lines.add('${_indexLabel(i + 1)} ${_quote(title)}${when.isEmpty ? '' : ' — $when'}');
    }
    final scheduleNote = _scheduleStatusNote(degradedStatus);
    final failNote = failedCount > 0
        ? _tr(
            '\n(ملحوظة: $failedCount عنصر متسجلش لعدم اكتمال بياناته.)',
            '\n(Note: $failedCount item(s) were not saved due to incomplete fields.)',
          )
        : '';
    return _tr(
      'تمام! ضفتلك ${succeeded.length} مهام في جدولك:\n${lines.join('\n')}$scheduleNote$failNote',
      'Added ${succeeded.length} tasks to your schedule:\n${lines.join('\n')}$scheduleNote$failNote',
    );
  }

  String _scheduleStatusNote(String? status) {
    if (status == 'permissionDenied') {
      return _tr(
        '\n⚠️ تنبيه: لم تتم جدولة المنبه لأن إذن الإشعارات مرفوض على النظام — فعّله من الإشعارات.',
        '\n⚠️ Warning: Reminder was NOT scheduled because notification permission is denied on this device.',
      );
    }
    if (status == 'inexactFallback') {
      return _tr(
        '\nℹ️ ملحوظة: التذكير مجدول بتوقيت تقريبي لأن إذن المنبه الدقيق غير مفعّل.',
        '\nℹ️ Note: Scheduled as an approximate reminder because exact alarm permission is not enabled.',
      );
    }
    return '';
  }

  String _buildBreakdownReply(
    String raw, [
    String cid = 'default',
    List<ConversationMessage> messages = const [],
    DateTime? now,
  ]) {
    final effectiveNow = now ?? DateTime.now();
    final stripped = raw
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .replaceFirst(
          RegExp(
            r'^(?:لو\s+سمحت\s+|ممكن\s+|يا\s+ريت\s+|طيب\s+|طب\s+)?'
            r'(?:قسملي|قسمها|قسمهم|قسمهولي|قسمهالي|قسمه|قسم|'
            r'فصصلي|فصصها|فصصهم|فصص|فصلها|فصلهم|فصل|'
            r'جزأها|جزأهم|جزأ|رتبها|رتبهم|ازاي\s+اذاكر|اذاكر\s+ازاي|'
            r'break\s+(?:it|them)\s+down|break\s+down|split\s+(?:it|them)(?:\s+into\s+steps)?|decompose)\s*'
            r'(?:لي\s+|لنا\s+)?'
            r'(?:لـ?\s*خطوات(?:\s+عمليه|\s+عملية|\s+صغيره|\s+صغيرة)?|خطوات|into\s+steps|to\s+steps)?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:لـ?\s*خطوات(?:\s+عمليه|\s+عملية)?|ده\s+امتحان\s+وده\s+حاج[هة]\s+تاني[هة]|دول\s+حاجتين|دول\s+مهمتين|دول\s+اتنين|كل\s+واحد[هة]?\s+لوحد[هة]?|عن\s+بعض)(?=\s|$)',
            caseSensitive: false,
          ),
          ' ',
        )
        .trim();

    final extractedTopic = _nlu.extractCleanClauseTitle(stripped);
    final isPronounOrEmpty = extractedTopic.isEmpty ||
        RegExp(
          r'^(?:ها|هم|ده|دي|دول|الهدف|الهدف\s+ده|المهمه|المهمة|التاسك|الخطوات|خطوات|ها\s+لخطوات.*|it|them|this|that)$',
          caseSensitive: false,
        ).hasMatch(_nlu.normalize(extractedTopic));

    var topics = <String>[];
    if (!isPronounOrEmpty) {
      final specs = _nlu.extractTaskSpecs(extractedTopic, effectiveNow);
      if (specs.length > 1) {
        topics = [for (final s in specs) s.title];
      } else {
        topics = [extractedTopic];
      }
    } else {
      topics = _resolveContextTopics(cid, messages, effectiveNow);
    }

    if (topics.isEmpty) {
      topics = [_tr('الهدف ده', 'this goal')];
    }

    if (topics.length > 1) {
      final sections = <String>[];
      for (var tIdx = 0; tIdx < topics.length; tIdx++) {
        final tTitle = topics[tIdx];
        final bd = _planner.decomposeGoal(tTitle, languageCode: _langCode);
        final steps = bd.stepsFor(_langCode);
        final stepLines = [
          for (var i = 0; i < steps.length; i++)
            '${_indexLabel(i + 1).replaceFirst('.', ')')} ${steps[i]}',
        ].join('\n');
        final badge = _isEnglish
            ? '📌 Part ${tIdx + 1}: "${bd.goalTitle}"'
            : '📌 ${_ordinalHeadingAr(tIdx + 1)}: «${bd.goalTitle}»';
        sections.add('$badge\n$stepLines');
      }
      final userPrefs = UserEnergyPreferencesStore.current;
      final energyTipAr =
          '💡 حسب بصمة طاقتك (${userPrefs.peakLabelAr}): ابدأ بالخطوة الأساسية في وقت ذروة نشاطك بنظام جلسات (${ArabicFormatters.toArabicDigits(userPrefs.preferredSessionMinutes)} دقيقة).';
      final energyTipEn =
          '💡 Based on your energy profile (${userPrefs.peakLabelEn}): tackle the core step during your peak hours using ${userPrefs.preferredSessionMinutes}-min blocks.';
      if (_isEnglish) {
        return 'Sure! I separated each item and broke it down into actionable steps:\n\n'
            '${sections.join('\n\n')}\n\n'
            '$energyTipEn\n'
            'Want me to add these steps as today’s tasks? Reply: "yes add them"';
      }
      return 'أكيد! فصّلتلك كل مهمة على حدة إلى خطوات عملية واضحة:\n\n'
          '${sections.join('\n\n')}\n\n'
          '$energyTipAr\n'
          'تحب أضيف الخطوات دي كمهام في جدولك النهارده؟ اكتبلي: تمام ضيفهم';
    }

    final label = topics.first;
    final breakdown = _planner.decomposeGoal(label, languageCode: _langCode);
    final steps = breakdown.stepsFor(_langCode);
    final rationale = breakdown.rationaleFor(_langCode);
    final userPrefs = UserEnergyPreferencesStore.current;
    final lines = [
      for (var i = 0; i < steps.length; i++)
        '${_indexLabel(i + 1).replaceFirst('.', ')')} ${steps[i]}',
    ].join('\n');
    if (_isEnglish) {
      return 'Sure! Here are ${steps.length} actionable steps for "${breakdown.goalTitle}":\n'
          '$lines\n($rationale • Peak Energy: ${userPrefs.peakShortEn})\n\nWant me to add these steps as today’s tasks? Reply: "yes add them"';
    }
    return 'أكيد! نقسّم «${breakdown.goalTitle}» لـ ${steps.length} خطوات عملية:\n'
        '$lines\n'
        '($rationale • ذروة طاقتك: ${userPrefs.peakShortAr})\n\n'
        'تحب أضيف الخطوات دي كمهام في جدولك النهارده؟ اكتبلي: تمام ضيفهم';
  }

  String _ordinalHeadingAr(int index) => switch (index) {
        1 => 'أولًا',
        2 => 'ثانيًا',
        3 => 'ثالثًا',
        _ => 'البند $index',
      };

  List<String> _resolveContextTopics(
    String cid,
    List<ConversationMessage> messages,
    DateTime now,
  ) {
    final out = <String>[];
    final refs = _recentRefsByCid[cid] ?? const <_TaskRef>[];
    for (final r in refs) {
      final split = _nlu.extractTaskSpecs(r.title, now);
      if (split.length > 1) {
        for (final s in split) {
          if (s.title.isNotEmpty && !out.contains(s.title)) out.add(s.title);
        }
      } else if (r.title.isNotEmpty && !out.contains(r.title)) {
        out.add(r.title);
      }
    }
    if (out.isNotEmpty) return out;

    // Fallback: inspect conversation history for previous user task specs or assistant quotes.
    for (final msg in messages.reversed) {
      if (msg.role == MessageRole.user) {
        final norm = _nlu.normalize(msg.content);
        if (_isBreakdownRequest(norm) || _isSeparateTasksCorrection(norm)) continue;
        final specs = _nlu.extractTaskSpecs(msg.content, now);
        if (specs.isNotEmpty) {
          return [for (final s in specs) s.title];
        }
      }
      if (msg.role == MessageRole.assistant) {
        final matches = RegExp(r'«([^»]+)»|"([^"]+)"').allMatches(msg.content);
        for (final m in matches) {
          final candidate = (m.group(1) ?? m.group(2) ?? '').trim();
          if (candidate.isEmpty ||
              candidate.contains('رتبلي') ||
              candidate.contains('اعتمد')) {
            continue;
          }
          final split = _nlu.extractTaskSpecs(candidate, now);
          if (split.length > 1) {
            for (final s in split) {
              if (!out.contains(s.title)) out.add(s.title);
            }
          } else if (!out.contains(candidate)) {
            out.add(candidate);
          }
        }
        if (out.isNotEmpty) return out;
      }
    }
    return out;
  }

  List<ToolCall>? _buildSplitMergedTaskCalls(
    String cid,
    List<ConversationMessage> messages,
    DateTime now,
  ) {
    final refs = _recentRefsByCid[cid] ?? const <_TaskRef>[];
    String? mergedId;
    String? mergedTitle;
    DateTime? baseDate;

    for (final r in refs) {
      if (r.title.contains(' و') || r.title.contains(' and ')) {
        mergedId = r.id;
        mergedTitle = r.title;
        if (r.date != null) baseDate = DateTime.tryParse(r.date!);
        break;
      }
    }

    // Also search conversation history for the original multi-clause user message.
    List<ExtractedTaskSpec> specs = const [];
    for (final msg in messages.reversed) {
      if (msg.role == MessageRole.user) {
        final norm = _nlu.normalize(msg.content);
        if (_isSeparateTasksCorrection(norm) || _isBreakdownRequest(norm)) continue;
        final extracted = _nlu.extractTaskSpecs(msg.content, now);
        if (extracted.length > 1) {
          specs = extracted;
          break;
        }
      } else if (msg.role == MessageRole.assistant && mergedTitle == null) {
        final m = RegExp(r'«([^»]+(?:\s+و\S+)+)»').firstMatch(msg.content);
        if (m != null) {
          mergedTitle = m.group(1)?.trim();
        }
      }
    }

    if (specs.length <= 1 && mergedTitle != null) {
      final fallbackSpecs = _nlu.extractTaskSpecs('عندي $mergedTitle', baseDate ?? now);
      if (fallbackSpecs.length > 1) {
        specs = [
          for (var i = 0; i < fallbackSpecs.length; i++)
            ExtractedTaskSpec(
              title: fallbackSpecs[i].title,
              date: fallbackSpecs[i].date ?? baseDate ?? now.add(const Duration(days: 1)),
              time: fallbackSpecs[i].time ?? (i == 0 ? '08:00' : '20:00'),
              priority: fallbackSpecs[i].priority,
              category: fallbackSpecs[i].category,
              isReminder: false,
              explicitNoDate: false,
              isVagueTitle: false,
            ),
        ];
      }
    }

    if (specs.length <= 1) return null;

    final calls = <ToolCall>[];
    if (mergedId != null && mergedId.isNotEmpty) {
      calls.add(_call('delete_task', {'task_id': mergedId}));
    } else if (mergedTitle != null && mergedTitle.isNotEmpty) {
      calls.add(_call('delete_task', {'query': mergedTitle}));
    }
    calls.addAll(_buildCreateCalls(specs));
    return calls;
  }

  List<ToolCall>? _maybeConfirmBreakdownFollowUp(
    String norm,
    List<ConversationMessage> messages,
    DateTime now,
  ) {
    if (!_nlu.containsAny(norm, [
      'تمام ضيفهم', 'ضيفهم', 'سجلهم', 'ايوه ضيفهم', 'اه ضيفهم',
      'yes add them', 'add them', 'add those', 'save them',
    ])) {
      return null;
    }
    final prevAssistant =
        messages.reversed.where((m) => m.role == MessageRole.assistant).firstOrNull;
    if (prevAssistant == null ||
        (!prevAssistant.content.contains('١)') && !prevAssistant.content.contains('1)'))) {
      return null;
    }

    final stepLines = prevAssistant.content
        .split('\n')
        .where((l) => RegExp(r'^[١٢٣123]\)').hasMatch(l.trim()))
        .toList();
    if (stepLines.isEmpty) return null;

    final today = _ymd(now);
    return [
      for (final line in stepLines)
        _call('create_task', {
          'title': line.replaceFirst(RegExp(r'^[١٢٣123]\)\s*'), '').split('(').first.trim(),
          'description': line.trim(),
          'date': today,
          'priority': 'medium',
        }),
    ];
  }

  String _buildOverwhelmCoachingReply(List<Map<String, dynamic>> rawTasks, DateTime now) {
    final open =
        rawTasks.where((t) => (t['status'] ?? 'pending').toString() != 'completed').toList();
    if (open.isEmpty) {
      return _tr(
        'خُد نفس هادي.. اكتبلي مهمة واحدة شاغلة بالك دلوقتي وأنا أرتّبهالك خطوة بخطوة.',
        'Take a slow breath — tell me one task on your mind right now and we will tackle it step by step.',
      );
    }
    return _tr(
      'فاهم إحساس الضغط ده تمامًا، ومش مطلوب تخلص كله في لحظة.\n'
      'أوضح خطوة تبدأ بيها دلوقتي هي: «${open.first['title']}».\n'
      'اضبط ٢٥ دقيقة تركيز عليها بس، ولما تخلص هنشوف اللي بعدها سوا.',
      'I understand feeling overwhelmed — you do not have to finish everything at once.\n'
      'The clearest first step right now is: "${open.first['title']}".\n'
      'Set a 25-minute focus timer on just that, and we will pick the next one afterward.',
    );
  }

  String _formatTaskLine(Map<String, dynamic> task, DateTime now) {
    final when = _formatWhen(task['date']?.toString(), task['time']?.toString(), now);
    final prioKey = (task['priority'] ?? 'medium').toString().toLowerCase();
    final pLabel = _isEnglish
        ? switch (prioKey) {
            'urgent' => 'Urgent',
            'high' => 'High',
            'medium' => 'Medium',
            _ => 'Low',
          }
        : switch (prioKey) {
            'urgent' => 'عاجلة',
            'high' => 'عالية',
            'medium' => 'متوسطة',
            _ => 'هادية',
          };
    final tag = when.isEmpty ? pLabel : '$pLabel • $when';
    return '• ${_quote('${task['title'] ?? ''}')} ($tag)';
  }

  String _formatWhen(String? date, String? time, DateTime now) {
    if (_isEnglish) return _formatWhenEnglish(date, time, now);
    return _formatWhenArabic(date, time, now);
  }

  String _formatWhenEnglish(String? date, String? time, DateTime now) {
    final parts = <String>[];
    if (date != null && date.isNotEmpty) {
      final parsed = DateTime.tryParse(date);
      if (parsed != null) {
        final today = DateTime(now.year, now.month, now.day);
        final diff = DateTime(parsed.year, parsed.month, parsed.day).difference(today).inDays;
        if (diff == 0) {
          parts.add('Today');
        } else if (diff == 1) {
          parts.add('Tomorrow');
        } else if (diff == 2) {
          parts.add('Day after tomorrow');
        } else {
          parts.add(WallClock.ymd(parsed));
        }
      }
    }
    if (time != null && time.isNotEmpty) {
      final segs = time.split(':');
      if (segs.length >= 2) {
        final h = int.tryParse(segs[0]) ?? 0;
        final m = int.tryParse(segs[1]) ?? 0;
        final isPm = h >= 12;
        final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
        final mPart = m == 0 ? '' : ':${m.toString().padLeft(2, '0')}';
        parts.add('$h12$mPart ${isPm ? 'PM' : 'AM'}');
      }
    }
    return parts.join(', ');
  }

  String _formatWhenArabic(String? date, String? time, DateTime now) {
    final parts = <String>[];
    if (date != null && date.isNotEmpty) {
      final parsed = DateTime.tryParse(date);
      if (parsed != null) {
        final today = DateTime(now.year, now.month, now.day);
        final diff = DateTime(parsed.year, parsed.month, parsed.day).difference(today).inDays;
        if (diff == 0) {
          parts.add('النهارده');
        } else if (diff == 1) {
          parts.add('بكرة');
        } else if (diff == 2) {
          parts.add('بعد بكرة');
        } else {
          parts.add(ArabicFormatters.dateShort(parsed));
        }
      }
    }
    if (time != null && time.isNotEmpty) {
      final segs = time.split(':');
      if (segs.length >= 2) {
        final h = int.tryParse(segs[0]) ?? 0;
        final m = int.tryParse(segs[1]) ?? 0;
        final isPm = h >= 12;
        final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
        final mPart = m == 0 ? '' : ':${m.toString().padLeft(2, '0')}';
        parts.add('الساعة ${ArabicFormatters.toArabicDigits('$h12$mPart')} ${isPm ? 'مساءً' : 'صباحًا'}');
      }
    }
    return parts.join(' ');
  }

  bool _isThanks(String norm) =>
      _nlu.containsAny(norm, ['شكرا', 'تسلم', 'متشكر', 'يعطيك العافيه', 'thank you', 'thanks', 'thx']) &&
      norm.split(' ').length <= 5;

  bool _isCapabilitiesQuery(String norm) => _nlu.containsAny(norm, [
        'بتعمل ايه', 'تساعدني ازاي', 'ايه امكانياتك', 'انت مين', 'بتقدر تعمل ايه',
        'what can you do', 'who are you', 'capabilities',
      ]);

  bool _isBreakdownRequest(String norm) => _nlu.containsAny(norm, [
        'قسملي', 'قسمها', 'قسمهم', 'قسم', 'جزأ', 'فصص', 'فصلها', 'فصلهم',
        'خطه مذاكر', 'اذاكر ازاي', 'ازاي اذاكر', 'خطه سريعه',
        'break down', 'break it down', 'break them down', 'decompose', 'split into steps',
      ]);

  bool _isSeparateTasksCorrection(String norm) => _nlu.containsAny(norm, [
        'ده امتحان وده', 'دي حاجه ودي حاجه', 'دول حاجتين', 'دول مهمتين',
        'دول اتنين', 'دول امتحانين', 'افصلهم', 'فصلهم عن بعض',
        'كل واحد لوحده', 'كل امتحان لوحده', 'حاطط حاجتين', 'جمعتهم ليه',
        'separate them', 'two separate tasks', 'two different exams',
      ]);

  bool _isOverwhelmOrCoaching(String norm) => _nlu.containsAny(norm, [
        'مضغوط', 'متلخبط', 'زهقت', 'زهقان', 'مكسل', 'مش قادر اركز', 'تعبان', 'تايه',
        'مشتت', 'overwhelmed', 'stressed', 'procrastinating', "can't focus", 'stuck',
      ]);

  String _buildSmartCoachingAdviceReply(String norm) {
    final energy = UserEnergyPreferencesStore.current;
    final mins = energy.preferredSessionMinutes;
    final isStudent = StudentModeStore.isActive;

    if (_nlu.containsAny(norm, ['بومودورو', 'جلسه تركيز', 'جلسة تركيز', 'ابدا تركيز', 'pomodoro'])) {
      return _tr(
        'ممتاز! جلسة تركيز قصيرة لمدة ${ArabicFormatters.toArabicDigits(mins)} دقيقة وبعدها استراحة ٥ دقايق هي أسرع طريقة تدخل بيها في المود.\n'
        '• اختار مهمة واحدة بس (أصغر خطوة فيها).\n'
        '• حط الموبايل على الصامت وشغّل صوت المطر أو الضوضاء الدافئة من شاشة التركيز.\n'
        'تحب أختارلك أنسب أول خطوة من مهامك تبدأ بيها دلوقتي؟',
        'Awesome! A focused $mins-minute sprint followed by a 5-minute break is the fastest way into flow.\n'
        '• Pick just ONE concrete micro-step.\n'
        '• Mute distractions and turn on Gentle Rain or Warm Focus noise.\n'
        'Want me to pick the best first task from your list right now?',
      );
    }

    if (_nlu.containsAny(norm, ['تسويف', 'بسوف', 'مكسل', 'ماليش نفس', 'شجعني', 'procrastinat', 'motivation'])) {
      return _tr(
        'التسويف مش كسل — غالبًا المهمة شكلها كبير فالمخ بيهرب منها. جرب قاعدة الـ ٥ دقايق معايا دلوقتي:\n'
        '١) افتح أصغر جزء في المهمة لمدة ٥ دقايق بس من غير ضغط تكمّل.\n'
        '٢) لو كملت بعدها، ندخل في جلسة ${ArabicFormatters.toArabicDigits(mins)} دقيقة في وقت ذروة طاقتك (${energy.peakShortAr}).\n'
        'قولّي إيه الحاجة اللي بتأجّلها وهقسّمهالك لـ ٣ خطوات سهلة جدًا.',
        'Procrastination usually means a task feels too big, not laziness. Try the 5-minute rule:\n'
        '1) Spend just 5 low-pressure minutes opening the smallest piece.\n'
        '2) Once momentum kicks in, switch into a $mins-minute block during your peak (${energy.peakShortEn}).\n'
        'Tell me what you have been putting off and I will break it into 3 easy steps.',
      );
    }

    if (isStudent || _nlu.containsAny(norm, ['اذاكر', 'مذاكر', 'امتحان', 'study', 'exam'])) {
      return _tr(
        'أقوى طريقة تذاكر بيها بتركيز من غير ما تزهق:\n'
        '١) الاسترجاع النشط (Active Recall): بعد كل ٢٠ دقيقة اقفل الكتاب واكتب أهم ٣ أفكار بإيدك.\n'
        '٢) جلسات ${ArabicFormatters.toArabicDigits(mins)} دقيقة مركّزة + ٥ دقايق راحة بعيد عن الموبايل.\n'
        '٣) ابدأ بالمادة الأهم في وقت ذروتك (${energy.peakShortAr}).\n'
        'لو قولتلي اسم المادة اللي هتذاكرها، أقدر أقسّمهالك لخطة خطوة بخطوة دلوقتي!',
        'The strongest way to study deeply without burning out:\n'
        '1) Active Recall: every 20 minutes, close your notes and summarize 3 key takeaways from memory.\n'
        '2) Run $mins-minute focus blocks + 5-minute screen-free breaks.\n'
        '3) Tackle the hardest subject during your peak (${energy.peakShortEn}).\n'
        'Tell me which subject you are studying and I can break it down into steps right now!',
      );
    }

    return _tr(
      'فاهمك تمامًا — تشتت التركيز بيحصل لما يكون في كذا حاجة مفتوحة في دماغك مرة واحدة.\n'
      '• فرّغ اللي في بالك هنا في جملة واحدة وهرتّبهولك.\n'
      '• نختار مهمة واحدة بس لمدة ${ArabicFormatters.toArabicDigits(mins)} دقيقة في وقت نشاطك (${energy.peakShortAr}).\n'
      'تحب أرتّبلك مهام النهارده ونختار أسهل أول خطوة سوا؟',
      'Totally get it — losing focus usually happens when too many open loops compete in your head.\n'
      '• Brain-dump what is on your mind here and I will organize it.\n'
      '• Pick ONE task for a $mins-minute sprint during your peak (${energy.peakShortEn}).\n'
      'Want me to sort today’s tasks and pick the easiest first step?',
    );
  }

  bool _isExamGradeReport(String norm) => _nlu.containsAny(norm, [
        'جبت امتياز', 'جبت جيد جدا', 'جبت جيد', 'جبت مقبول', 'تقديري',
        'قفلت الامتحان', 'قفلت الماده', 'جبت درجه', 'جبت 9', 'جبت 8', 'جبت 100',
        'حليت حلو في الامتحان', 'عديت الامتحان', 'نجحت في الامتحان',
        'got an a', 'got a+', 'got a b', 'passed the exam', 'aced the exam',
      ]);

  bool _isEnergyPreferenceUpdate(String norm) => _nlu.containsAny(norm, [
        'طاقتي الصبح', 'طاقتي بتكون الصبح', 'طاقتي بليل', 'طاقتي بتكون بليل',
        'انا كائن ليلي', 'انا كائن صباحي', 'بحب انجز الصبح', 'بحب انجز بليل',
        'بحب اذاكر الصبح', 'بحب اذاكر بليل', 'خلي تفضيلاتي',
        'night owl', 'morning person', 'peak energy is', 'work best at night',
        'work best in the morning',
      ]);

  String _handleEnergyPreferenceUpdate(String norm) {
    final current = UserEnergyPreferencesStore.current;
    String period = current.peakEnergyPeriod;
    if (_nlu.containsAny(norm, ['بليل', 'بالليل', 'ليلي', 'مسائي', 'night', 'evening'])) {
      period = 'evening';
    } else if (_nlu.containsAny(norm, ['الظهر', 'الضهر', 'العصر', 'afternoon'])) {
      period = 'afternoon';
    } else if (_nlu.containsAny(norm, ['الصبح', 'صباحي', 'بدري', 'morning'])) {
      period = 'morning';
    }
    final next = current.copyWith(
      peakEnergyPeriod: period,
      completedWizard: true,
    );
    UserEnergyPreferencesStore.setCurrent(next);
    return _tr(
      '⚡ تمام جدًا! سجّلت في بصمة طاقتك إن ذروة نشاطك «${next.peakLabelAr}».\n'
      'من دلوقتي هرتّبلك أهم التاسكات والمشاريع والامتحانات في الوقت ده، وهقسّمها لجلسات من ${ArabicFormatters.toArabicDigits(next.preferredSessionMinutes)} دقيقة!',
      '⚡ Got it! Updated your energy profile to "${next.peakLabelEn}".\n'
      'From now on, I will schedule your hardest tasks, exams, and projects during your peak hours in ${next.preferredSessionMinutes}-minute blocks!',
    );
  }

  String _buildExamGradeReply(
    String raw,
    String norm,
    String cid,
    List<ConversationMessage> messages,
  ) {
    String gradeTier = 'excellent';
    String scoreLabel = _isEnglish ? 'Excellent (A+)' : 'امتياز';
    if (_nlu.containsAny(norm, ['جيد جدا', 'very good', 'b+'])) {
      gradeTier = 'very_good';
      scoreLabel = _isEnglish ? 'Very Good (B+)' : 'جيد جدًا';
    } else if (_nlu.containsAny(norm, ['مقبول', 'pass', 'c'])) {
      gradeTier = 'pass';
      scoreLabel = _isEnglish ? 'Pass' : 'مقبول';
    } else if (_nlu.containsAny(norm, ['جيد', 'good', 'b']) &&
        !_nlu.containsAny(norm, ['جيد جدا'])) {
      gradeTier = 'good';
      scoreLabel = _isEnglish ? 'Good (B)' : 'جيد';
    }

    String subject = _isEnglish ? 'your exam' : 'الامتحان';
    final recent = _recentRefsByCid[cid];
    if (recent != null && recent.isNotEmpty) {
      subject = recent.first.title;
    } else {
      for (final s in [
        'عربي', 'انجليزي', 'فيزياء', 'كيمياء', 'احياء', 'رياضيات', 'تاريخ', 'برمجه',
        'arabic', 'english', 'physics', 'math',
      ]) {
        if (norm.contains(s)) {
          subject = _isEnglish ? '$s exam' : 'امتحان $s';
          break;
        }
      }
    }

    final enc = ExamGradesStore.buildEncouragement(
      examTitle: subject,
      gradeTier: gradeTier,
      scoreLabel: scoreLabel,
    );
    return _isEnglish
        ? '${enc.badgeEn}\n${enc.en}'
        : '${enc.badgeAr}\n${enc.ar}';
  }

  bool _hasTool(LlmRequest req, String name) =>
      req.tools.any((t) => t['name'] == name);

  String _quote(String s) => _isEnglish ? '"$s"' : '«$s»';

  String _indexLabel(int i) => _isEnglish ? '$i.' : _arabicIndex(i);

  String _arabicIndex(int i) => switch (i) {
        1 => '١.',
        2 => '٢.',
        3 => '٣.',
        4 => '٤.',
        5 => '٥.',
        6 => '٦.',
        _ => '$i.',
      };

  ToolCall _call(String name, Map<String, dynamic> args) =>
      ToolCall(id: 'local_${++_callSeq}', name: name, arguments: args);

  String _ymd(DateTime dt) => WallClock.ymd(dt);

  String _buildStructuredProjectPlanJson(String rawJson, DateTime now) {
    Map<String, dynamic> input = const {};
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) input = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    final title = (input['title']?.toString().trim().isNotEmpty == true)
        ? input['title'].toString().trim()
        : _tr('مشروع جديد', 'New Project');
    final goal = (input['goal']?.toString().trim().isNotEmpty == true)
        ? input['goal'].toString().trim()
        : title;
    final refinement = input['refinement']?.toString().trim() ?? '';
    final existingTasks = (input['existing_tasks'] is List)
        ? (input['existing_tasks'] as List).whereType<Map>().toList()
        : const <Map>[];
    final existingIds = existingTasks
        .map((t) => t['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final seq = ++_callSeq;
    String freshId(String suffix) {
      var candidate = 'plan_${seq}_$suffix';
      var i = 1;
      while (existingIds.contains(candidate)) {
        candidate = 'plan_${seq}_${suffix}_${++i}';
      }
      return candidate;
    }

    final t1 = freshId('t1');
    final t2 = freshId('t2');
    final t3 = freshId('t3');
    final d1 = _ymd(now.add(const Duration(days: 1)));
    final d2 = _ymd(now.add(const Duration(days: 2)));
    final d3 = _ymd(now.add(const Duration(days: 3)));
    final prevDep = existingIds.isNotEmpty ? [existingIds.first] : <String>[];

    final plan = {
      'title': title,
      'goal': goal,
      'clarification_question': refinement.isEmpty
          ? _tr(
              'هل تحب نركّز على خطوات سريعة في الأول ولا نقسّمها على أيام أكتر؟',
              'Would you like to focus on quick wins first or spread the steps across more days?',
            )
          : null,
      'phases': [
        {
          'id': 'phase_${seq}_1',
          'title': _tr('١. التحضير وتحديد الأولويات', '1. Preparation & Scope'),
          'description': _tr('تجهيز الأساسيات اللازمة لـ $title', 'Setting up the foundation for $title'),
          'estimated_duration_minutes': 45,
          'suggested_deadline': d1,
          'tasks': [
            {
              'id': t1,
              'title': _tr('تحديد المتطلبات الأساسية لـ $title', 'Define core requirements for $title'),
              'description': goal,
              'estimated_duration_minutes': 45,
              'duration_uncertainty': _tr('تقدير مبدئي قابل للتعديل', 'Initial estimate'),
              'priority': 'high',
              'suggested_deadline': d1,
              'depends_on': prevDep,
            },
          ],
        },
        {
          'id': 'phase_${seq}_2',
          'title': _tr('٢. التنفيذ الأساسي', '2. Core Execution'),
          'description': refinement.isNotEmpty
              ? refinement
              : _tr('إنجاز الجزء الأكبر من الهدف خطوة بخطوة', 'Completing the primary deliverables step by step'),
          'estimated_duration_minutes': 90,
          'suggested_deadline': d2,
          'tasks': [
            {
              'id': t2,
              'title': _tr('تنفيذ الخطوة الرئيسية في $title', 'Execute core milestone for $title'),
              'description': refinement.isNotEmpty ? refinement : goal,
              'estimated_duration_minutes': 90,
              'duration_uncertainty': _tr('يعتمد على تفاصيل التنفيذ', 'Depends on implementation scope'),
              'priority': 'high',
              'suggested_deadline': d2,
              'depends_on': [t1],
            },
          ],
        },
        {
          'id': 'phase_${seq}_3',
          'title': _tr('٣. المراجعة والإنهاء', '3. Review & Finalization'),
          'description': _tr('مراجعة المخرجات والتأكد من اكتمال الهدف', 'Review deliverables and finalize'),
          'estimated_duration_minutes': 45,
          'suggested_deadline': d3,
          'tasks': [
            {
              'id': t3,
              'title': _tr('مراجعة وتسليم $title', 'Review and finalize $title'),
              'description': null,
              'estimated_duration_minutes': 45,
              'duration_uncertainty': _tr('تقدير مبدئي', 'Initial estimate'),
              'priority': 'medium',
              'suggested_deadline': d3,
              'depends_on': [t2],
            },
          ],
        },
      ],
    };
    return jsonEncode(plan);
  }

  String _buildStructuredTaskExtractionJson(String rawJson, DateTime now) {
    Map<String, dynamic> input = const {};
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) input = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    final text = input['text']?.toString().trim() ?? rawJson.trim();
    final analysis = _nlu.analyze(
      text,
      now: now,
      hasPendingClarification: false,
      hasActiveDraft: false,
      languageCode: _langCode,
    );
    final spec = analysis.taskSpecs.isNotEmpty ? analysis.taskSpecs.first : null;
    final cleanTitle = (spec != null && spec.title.trim().isNotEmpty)
        ? spec.title.trim()
        : _nlu.extractCleanClauseTitle(text);
    String? dueAtIso;
    if (spec?.date != null) {
      final d = spec!.date!;
      if (spec.time != null && spec.time!.contains(':')) {
        final parts = spec.time!.split(':');
        final h = int.tryParse(parts[0]) ?? 9;
        final m = int.tryParse(parts[1]) ?? 0;
        dueAtIso = DateTime(d.year, d.month, d.day, h, m).toIso8601String();
      } else {
        dueAtIso = DateTime(d.year, d.month, d.day).toIso8601String();
      }
    }
    return jsonEncode({
      'title': cleanTitle.isEmpty ? text : cleanTitle,
      'description': null,
      'estimated_duration_minutes': analysis.inMinutes,
      'due_at': dueAtIso,
      'priority': spec?.priority,
      'depends_on': const <String>[],
      'clarification_question': analysis.understanding.clarificationQuestion,
    });
  }

  String? _extractCurrentIso(String systemPrompt) {
    final nowMatch = RegExp(
      r'Now:\s*(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}(?::\d{2})?)',
    ).firstMatch(systemPrompt);
    if (nowMatch != null) {
      return '${nowMatch.group(1)}T${nowMatch.group(2)}';
    }
    return RegExp(
      r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:\d{2})?',
    ).firstMatch(systemPrompt)?.group(0);
  }
}

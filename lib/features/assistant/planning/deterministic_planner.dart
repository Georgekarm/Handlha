import 'dart:math' as math;

/// Standardized grounded reason codes emitted by [DeterministicSchedulePlanner].
enum PlanReasonCode {
  deadlineSoon,
  overduePriority,
  dependencyReady,
  userPriority,
  availableWindow,
  preferredFocusTime,
  fixedCommitment,
  criticalPath,
  rollingPreserved,
  insufficientData,
}

class PlanReason {
  const PlanReason({
    required this.code,
    required this.factRef,
    required this.textAr,
    this.textEn = '',
  });

  final PlanReasonCode code;
  final String factRef;
  final String textAr;
  final String textEn;

  String localized(bool isEnglish) =>
      isEnglish && textEn.isNotEmpty ? textEn : textAr;
}

class TimeWindow {
  const TimeWindow({
    required this.start,
    required this.end,
    this.label,
    this.isPreferredFocus = false,
  });

  final DateTime start;
  final DateTime end;
  final String? label;
  final bool isPreferredFocus;

  int get durationMinutes => math.max(0, end.difference(start).inMinutes);

  bool overlaps(DateTime otherStart, DateTime otherEnd) =>
      start.isBefore(otherEnd) && otherStart.isBefore(end);
}

class PlanningWeights {
  const PlanningWeights({
    this.deadlineUrgency = 0.40,
    this.userPriority = 0.30,
    this.dependencyImpact = 0.18,
    this.focusWindowMatch = 0.12,
  });

  final double deadlineUrgency;
  final double userPriority;
  final double dependencyImpact;
  final double focusWindowMatch;
}

class PlanningTaskInput {
  const PlanningTaskInput({
    required this.id,
    required this.title,
    this.dueDate,
    this.scheduledTime,
    this.estimatedMinutes,
    this.priority = 'medium',
    this.isCompleted = false,
    this.locked = false,
    this.dependsOnIds = const [],
    this.category,
  });

  final String id;
  final String title;
  final DateTime? dueDate;
  final DateTime? scheduledTime;
  final int? estimatedMinutes;
  final String priority; // 'high' | 'medium' | 'low'
  final bool isCompleted;
  final bool locked;
  final List<String> dependsOnIds;
  final String? category;

  bool get hasExplicitDuration =>
      estimatedMinutes != null && estimatedMinutes! > 0;
}

class PlanningProblem {
  const PlanningProblem({
    required this.now,
    required this.tasks,
    this.availableWindows = const [],
    this.fixedCommitments = const [],
    this.weights = const PlanningWeights(),
    this.breakMinutes = 0,
    this.defaultAssumedDurationMinutes = 45,
    this.horizonDays = 3,
    this.preferredPeriod, // 'morning' | 'afternoon' | 'evening' | null
  });

  final DateTime now;
  final List<PlanningTaskInput> tasks;
  final List<TimeWindow> availableWindows;
  final List<TimeWindow> fixedCommitments;
  final PlanningWeights weights;
  final int breakMinutes;
  final int defaultAssumedDurationMinutes;
  final int horizonDays;
  final String? preferredPeriod;
}

class ProposedScheduleItem {
  const ProposedScheduleItem({
    required this.taskId,
    required this.title,
    required this.suggestedStart,
    required this.suggestedEnd,
    required this.durationMinutes,
    required this.isDurationAssumed,
    required this.priority,
    required this.softScore,
    required this.dependsOnIds,
    required this.locked,
    required this.reasons,
    this.cpmSlackMinutes,
  });

  final String taskId;
  final String title;
  final DateTime suggestedStart;
  final DateTime suggestedEnd;
  final int durationMinutes;
  final bool isDurationAssumed;
  final String priority;
  final double softScore;
  final List<String> dependsOnIds;
  final bool locked;
  final List<PlanReason> reasons;
  final int? cpmSlackMinutes;

  String get suggestedYmd => _fmtYmd(suggestedStart);
  String get suggestedHm => _fmtHm(suggestedStart);
  String get suggestedEndHm => _fmtHm(suggestedEnd);
}

enum ScheduleConflictType {
  dependencyCycle,
  missingDependency,
  noAvailableSlot,
  deadlineMissed,
  fixedOverlap,
}

class ScheduleConflict {
  const ScheduleConflict({
    required this.type,
    required this.taskIds,
    required this.messageAr,
    this.messageEn = '',
  });

  final ScheduleConflictType type;
  final List<String> taskIds;
  final String messageAr;
  final String messageEn;

  String localized(bool isEnglish) =>
      isEnglish && messageEn.isNotEmpty ? messageEn : messageAr;
}

enum PlanDiffKind { preserved, moved, added, removed }

class PlanDiffItem {
  const PlanDiffItem({
    required this.kind,
    required this.taskId,
    required this.title,
    this.previousStart,
    this.newStart,
  });

  final PlanDiffKind kind;
  final String taskId;
  final String title;
  final DateTime? previousStart;
  final DateTime? newStart;
}

class CpmNodeMetrics {
  const CpmNodeMetrics({
    required this.taskId,
    required this.earliestStartMinutes,
    required this.earliestFinishMinutes,
    required this.latestStartMinutes,
    required this.latestFinishMinutes,
    required this.slackMinutes,
  });

  final String taskId;
  final int earliestStartMinutes;
  final int earliestFinishMinutes;
  final int latestStartMinutes;
  final int latestFinishMinutes;
  final int slackMinutes;

  bool get isCritical => slackMinutes <= 0;
}

class ScheduleProposal {
  const ScheduleProposal({
    required this.proposalId,
    required this.planVersion,
    required this.algorithmVersion,
    required this.inputHash,
    required this.createdAt,
    required this.items,
    required this.unresolvedConflicts,
    required this.assumptions,
    required this.criticalPathIds,
    required this.cpmMetrics,
    required this.diffFromPrevious,
    required this.explainAr,
    this.explainEn = '',
    this.unscheduledTaskIds = const [],
  });

  final String proposalId;
  final int planVersion;
  final String algorithmVersion;
  final String inputHash;
  final DateTime createdAt;
  final List<ProposedScheduleItem> items;
  final List<ScheduleConflict> unresolvedConflicts;
  final List<String> assumptions;
  final List<String> criticalPathIds;
  final Map<String, CpmNodeMetrics> cpmMetrics;
  final List<PlanDiffItem> diffFromPrevious;
  final String explainAr;
  final String explainEn;
  final List<String> unscheduledTaskIds;

  bool get hasConflicts => unresolvedConflicts.isNotEmpty;

  String explanationFor(String languageCode) =>
      languageCode.toLowerCase().startsWith('en') && explainEn.isNotEmpty
          ? explainEn
          : explainAr;
}

class GoalBreakdown {
  const GoalBreakdown({
    required this.goalTitle,
    required this.steps,
    required this.rationaleAr,
    this.stepsEn = const [],
    this.rationaleEn = '',
  });

  final String goalTitle;
  final List<String> steps;
  final String rationaleAr;
  final List<String> stepsEn;
  final String rationaleEn;

  List<String> stepsFor(String languageCode) =>
      languageCode.toLowerCase().startsWith('en') && stepsEn.isNotEmpty
          ? stepsEn
          : steps;

  String rationaleFor(String languageCode) =>
      languageCode.toLowerCase().startsWith('en') && rationaleEn.isNotEmpty
          ? rationaleEn
          : rationaleAr;
}

/// Deterministic, explainable, completely offline planning engine.
///
/// Separated cleanly from NLP: operates exclusively on typed tasks, windows,
/// commitments, weights, and dependencies. Never hallucinates tasks or reasons.
class DeterministicSchedulePlanner {
  const DeterministicSchedulePlanner();

  static const String currentAlgorithmVersion = 'planner-v1.0';

  /// Computes a canonical fingerprint across all inputs so edits/completions
  /// automatically invalidate stale plan approvals.
  String computeInputHash(PlanningProblem problem) {
    final sortedTasks = [...problem.tasks]
      ..sort((a, b) => a.id.compareTo(b.id));
    final sortedWindows = [...problem.availableWindows]
      ..sort((a, b) => a.start.compareTo(b.start));
    final sortedFixed = [...problem.fixedCommitments]
      ..sort((a, b) => a.start.compareTo(b.start));

    final buf = StringBuffer()
      ..write('alg=$currentAlgorithmVersion;')
      ..write('brk=${problem.breakMinutes};')
      ..write('defDur=${problem.defaultAssumedDurationMinutes};')
      ..write('pref=${problem.preferredPeriod ?? ''};')
      ..write('w=${problem.weights.deadlineUrgency},${problem.weights.userPriority},${problem.weights.dependencyImpact},${problem.weights.focusWindowMatch};');

    for (final t in sortedTasks) {
      final deps = [...t.dependsOnIds]..sort();
      buf
        ..write('T[${t.id}|${t.title}|')
        ..write('${t.dueDate?.toIso8601String() ?? ''}|')
        ..write('${t.scheduledTime?.toIso8601String() ?? ''}|')
        ..write('${t.estimatedMinutes ?? ''}|')
        ..write('${t.priority}|${t.isCompleted}|${t.locked}|${deps.join(',')}]');
    }
    for (final w in sortedWindows) {
      buf.write('W[${w.start.toIso8601String()}..${w.end.toIso8601String()}]');
    }
    for (final f in sortedFixed) {
      buf.write('F[${f.start.toIso8601String()}..${f.end.toIso8601String()}]');
    }

    return _fnv128Hex(buf.toString());
  }

  /// Generates a deterministic [ScheduleProposal] with DAG validation, optional
  /// CPM (when explicit durations + deps + deadline exist), hard constraints,
  /// soft scoring, and grounded Arabic/English explanations.
  ScheduleProposal plan(
    PlanningProblem problem, {
    int planVersion = 1,
    ScheduleProposal? previousProposal,
    String languageCode = 'ar',
  }) {
    final isEn = languageCode.toLowerCase().startsWith('en');
    final hash = computeInputHash(problem);
    final activeTasks = problem.tasks.where((t) => !t.isCompleted).toList();
    if (activeTasks.isEmpty) {
      return ScheduleProposal(
        proposalId: 'prop-${hash.substring(0, 8)}-v$planVersion',
        planVersion: planVersion,
        algorithmVersion: currentAlgorithmVersion,
        inputHash: hash,
        createdAt: problem.now,
        items: const [],
        unresolvedConflicts: const [],
        assumptions: const [],
        criticalPathIds: const [],
        cpmMetrics: const {},
        diffFromPrevious: const [],
        explainAr: 'مفيش مهام مفتوحة دلوقتي محتاجة ترتيب.',
        explainEn: 'There are no open tasks that need scheduling right now.',
      );
    }

    final byId = {for (final t in activeTasks) t.id: t};
    final conflicts = <ScheduleConflict>[];
    final assumptions = <String>[];
    final assumptionsEn = <String>[];

    // 1. Validate explicit dependencies and compute topological order via Kahn.
    final dag = _topologicalSort(activeTasks, byId);
    conflicts.addAll(dag.conflicts);

    if (dag.hasCycle) {
      return ScheduleProposal(
        proposalId: 'prop-${hash.substring(0, 8)}-v$planVersion',
        planVersion: planVersion,
        algorithmVersion: currentAlgorithmVersion,
        inputHash: hash,
        createdAt: problem.now,
        items: const [],
        unresolvedConflicts: conflicts,
        assumptions: isEn ? assumptionsEn : assumptions,
        criticalPathIds: const [],
        cpmMetrics: const {},
        diffFromPrevious: const [],
        unscheduledTaskIds: [for (final t in activeTasks) t.id],
        explainAr: conflicts.first.messageAr,
        explainEn: conflicts.first.localized(true),
      );
    }

    // 2. Run CPM ONLY when explicit durations, explicit dependency edges, and
    // an explicit deadline exist on the chain (strict zero-hallucination rule).
    final cpm = _computeCpmIfEligible(
      orderedTasks: dag.ordered,
      byId: byId,
      now: problem.now,
    );
    final criticalIds = [
      for (final entry in cpm.entries)
        if (entry.value.isCritical) entry.key,
    ];

    // 3. Build explicit scheduling horizon windows (never overwrite fixed blocks).
    final windows = problem.availableWindows.isNotEmpty
        ? [...problem.availableWindows]
        : _defaultHorizonWindows(
            problem.now,
            problem.horizonDays,
            assumptions,
            assumptionsEn: assumptionsEn,
          );

    final busyIntervals = <TimeWindow>[...problem.fixedCommitments];

    // Track assumptions when tasks omit durations.
    final missingDurationTitles = <String>[];
    for (final t in activeTasks) {
      if (!t.hasExplicitDuration) {
        missingDurationTitles.add(t.title);
      }
    }
    if (missingDurationTitles.isNotEmpty) {
      assumptions.add(
        'المدة مش محددة في ${missingDurationTitles.length} '
        'مهمة فافترضت ${problem.defaultAssumedDurationMinutes} دقيقة لكل واحدة لحد ما تعدلها.',
      );
      assumptionsEn.add(
        'Duration was omitted for ${missingDurationTitles.length} '
        'task(s), so I assumed ${problem.defaultAssumedDurationMinutes} min each until you adjust it.',
      );
    }

    // Downstream dependency count to reward unblocking critical tasks.
    final downstreamCount = _countDownstreamDependents(activeTasks, byId);

    // 4. Deterministic soft score + topological level tie-breaker.
    final scores = <String, double>{};
    for (final t in activeTasks) {
      scores[t.id] = _scoreTask(
        t,
        problem: problem,
        downstream: downstreamCount[t.id] ?? 0,
        cpm: cpm[t.id],
      );
    }

    // Reserve locked/fixed tasks first (hard constraint).
    final scheduledEndById = <String, DateTime>{};
    final items = <ProposedScheduleItem>[];
    final unscheduled = <String>[];

    final prevById = {
      if (previousProposal != null)
        for (final p in previousProposal.items) p.taskId: p,
    };

    // Ready-queue topological scheduler ordered dynamically by softScore DESC.
    final remaining = [...dag.ordered];
    final placedIds = <String>{};

    // First pass: anchor locked tasks that already have a valid scheduledTime.
    for (final t in remaining.where((t) => t.locked && t.scheduledTime != null)) {
      final start = t.scheduledTime!;
      final dur = t.hasExplicitDuration
          ? t.estimatedMinutes!
          : problem.defaultAssumedDurationMinutes;
      final end = start.add(Duration(minutes: dur));
      final overlapsFixed = problem.fixedCommitments.any((f) => f.overlaps(start, end));
      if (overlapsFixed) {
        conflicts.add(
          ScheduleConflict(
            type: ScheduleConflictType.fixedOverlap,
            taskIds: [t.id],
            messageAr: 'ميعاد «${t.title}» متعارض مع التزام ثابت تاني.',
            messageEn: 'Time for "${t.title}" overlaps another fixed commitment.',
          ),
        );
      }
      busyIntervals.add(TimeWindow(start: start, end: end, label: t.title));
      scheduledEndById[t.id] = end;
      placedIds.add(t.id);
      items.add(
        ProposedScheduleItem(
          taskId: t.id,
          title: t.title,
          suggestedStart: start,
          suggestedEnd: end,
          durationMinutes: dur,
          isDurationAssumed: !t.hasExplicitDuration,
          priority: t.priority,
          softScore: scores[t.id]!,
          dependsOnIds: t.dependsOnIds,
          locked: true,
          cpmSlackMinutes: cpm[t.id]?.slackMinutes,
          reasons: [
            PlanReason(
              code: previousProposal != null
                  ? PlanReasonCode.rollingPreserved
                  : PlanReasonCode.fixedCommitment,
              factRef: t.id,
              textAr: previousProposal != null
                  ? 'حافظنا على ميعادها المتثبّت من قبل كده'
                  : 'ميعادها ثابت ومحفوظ زي ما هو',
              textEn: previousProposal != null
                  ? 'preserved previous locked slot'
                  : 'fixed locked commitment',
            ),
          ],
        ),
      );
    }

    // Place all remaining tasks respecting dependencies + hard windows + soft score.
    while (placedIds.length + unscheduled.length < activeTasks.length) {
      final ready = remaining.where((t) {
        if (placedIds.contains(t.id) || unscheduled.contains(t.id)) return false;
        return t.dependsOnIds.every(
          (depId) => !byId.containsKey(depId) || placedIds.contains(depId),
        );
      }).toList();

      if (ready.isEmpty) {
        // Remaining tasks wait on an unscheduled dependency.
        for (final t in remaining) {
          if (!placedIds.contains(t.id) && !unscheduled.contains(t.id)) {
            unscheduled.add(t.id);
          }
        }
        break;
      }

      ready.sort((a, b) {
        final cmp = scores[b.id]!.compareTo(scores[a.id]!);
        if (cmp != 0) return cmp;
        final da = a.dueDate;
        final db = b.dueDate;
        if (da != null && db != null) {
          final dc = da.compareTo(db);
          if (dc != 0) return dc;
        } else if (da != null) {
          return -1;
        } else if (db != null) {
          return 1;
        }
        return a.id.compareTo(b.id);
      });

      final current = ready.first;
      final dur = current.hasExplicitDuration
          ? current.estimatedMinutes!
          : problem.defaultAssumedDurationMinutes;

      DateTime earliest = problem.now;
      for (final depId in current.dependsOnIds) {
        final depEnd = scheduledEndById[depId];
        if (depEnd != null) {
          final candidate = depEnd.add(Duration(minutes: problem.breakMinutes));
          if (candidate.isAfter(earliest)) earliest = candidate;
        }
      }

      // Rolling stability: if previous proposal slot is still conflict-free & valid, prefer it.
      TimeWindow? chosenSlot;
      var preservedRolling = false;
      final prev = prevById[current.id];
      if (prev != null && !prev.suggestedStart.isBefore(earliest)) {
        final prevEnd = prev.suggestedStart.add(Duration(minutes: dur));
        if (_fitsWindows(prev.suggestedStart, prevEnd, windows) &&
            !_overlapsAny(prev.suggestedStart, prevEnd, busyIntervals) &&
            (current.dueDate == null ||
                !prev.suggestedStart.isAfter(_endOfDueDay(current.dueDate!)))) {
          chosenSlot = TimeWindow(start: prev.suggestedStart, end: prevEnd);
          preservedRolling = true;
        }
      }

      chosenSlot ??= _findEarliestValidSlot(
        windows: windows,
        busy: busyIntervals,
        earliestStart: earliest,
        durationMinutes: dur,
        breakMinutes: problem.breakMinutes,
        preferredPeriod: problem.preferredPeriod,
      );

      if (chosenSlot == null) {
        unscheduled.add(current.id);
        conflicts.add(
          ScheduleConflict(
            type: ScheduleConflictType.noAvailableSlot,
            taskIds: [current.id],
            messageAr:
                'مفيش وقت فاضي يكفّي «${current.title}» ($dur د) جوه الفترة المتاحة.',
            messageEn:
                'No free slot large enough for "${current.title}" ($dur min) inside the available window.',
          ),
        );
        continue;
      }

      if (current.dueDate != null &&
          chosenSlot.start.isAfter(_endOfDueDay(current.dueDate!))) {
        conflicts.add(
          ScheduleConflict(
            type: ScheduleConflictType.deadlineMissed,
            taskIds: [current.id],
            messageAr:
                'أقرب وقت فاضي لـ «${current.title}» بعد الموعد النهائي بتاعها (${_fmtYmd(current.dueDate!)}).',
            messageEn:
                'Earliest open slot for "${current.title}" falls past its deadline (${_fmtYmd(current.dueDate!)}).',
          ),
        );
      }

      busyIntervals.add(
        TimeWindow(
          start: chosenSlot.start,
          end: chosenSlot.end,
          label: current.title,
        ),
      );
      scheduledEndById[current.id] = chosenSlot.end;
      placedIds.add(current.id);

      final reasons = _buildReasons(
        current,
        slot: chosenSlot,
        now: problem.now,
        byId: byId,
        cpmMetric: cpm[current.id],
        preservedRolling: preservedRolling,
        preferredPeriod: problem.preferredPeriod,
      );

      items.add(
        ProposedScheduleItem(
          taskId: current.id,
          title: current.title,
          suggestedStart: chosenSlot.start,
          suggestedEnd: chosenSlot.end,
          durationMinutes: dur,
          isDurationAssumed: !current.hasExplicitDuration,
          priority: current.priority,
          softScore: scores[current.id]!,
          dependsOnIds: current.dependsOnIds,
          locked: current.locked,
          reasons: reasons,
          cpmSlackMinutes: cpm[current.id]?.slackMinutes,
        ),
      );
    }

    items.sort((a, b) => a.suggestedStart.compareTo(b.suggestedStart));

    final diff = previousProposal == null
        ? const <PlanDiffItem>[]
        : _computeDiff(previousProposal.items, items);

    final explainAr = renderArabicExplanation(
      items: items,
      conflicts: conflicts,
      assumptions: assumptions,
      diff: diff,
      criticalPathIds: criticalIds,
    );
    final explainEn = renderEnglishExplanation(
      items: items,
      conflicts: conflicts,
      assumptions: assumptionsEn,
      diff: diff,
      criticalPathIds: criticalIds,
    );

    return ScheduleProposal(
      proposalId: 'prop-${hash.substring(0, 8)}-v$planVersion',
      planVersion: planVersion,
      algorithmVersion: currentAlgorithmVersion,
      inputHash: hash,
      createdAt: problem.now,
      items: items,
      unresolvedConflicts: conflicts,
      assumptions: isEn ? assumptionsEn : assumptions,
      criticalPathIds: criticalIds,
      cpmMetrics: cpm,
      diffFromPrevious: diff,
      unscheduledTaskIds: unscheduled,
      explainAr: explainAr,
      explainEn: explainEn,
    );
  }

  /// Decomposes a goal or broad task into 1–3 concrete, actionable next steps.
  GoalBreakdown decomposeGoal(String goalTitle, {String languageCode = 'ar'}) {
    final trimmed = goalTitle.trim();
    final lower = trimmed.toLowerCase();

    if (RegExp(r'(امتحان|اختبار|مذاكر|مراجع|كورس|فرنساوي|انجليزي|عربي|فيزيا|كيميا|رياض|برمج|ml|flutter|exam|study|review|course|quiz)')
        .hasMatch(lower)) {
      return GoalBreakdown(
        goalTitle: trimmed,
        steps: [
          'حصر أهم الأجزاء أو الدروس الأساسية في «$trimmed» (١٥ دقيقة)',
          'مذاكرة وفهم الجزء الأهم أولًا بتركيز (٣٠ دقيقة)',
          'حل تمارين سريعة وتلخيص النقط الصعبة (١٥ دقيقة)',
        ],
        rationaleAr: 'تقسيم خطي للمذاكرة من الحصر للفهم ثم التطبيق العملي.',
        stepsEn: [
          'List the core chapters or topics for "$trimmed" (15 min)',
          'Focus on understanding the highest-weight concepts first (30 min)',
          'Solve practice problems and summarize tricky points (15 min)',
        ],
        rationaleEn: 'Structured study progression from scoping to core comprehension and practice.',
      );
    }
    if (RegExp(r'(مشروع|تطبيق|تقرير|بحث|برزنتيشن|presentation|report|project|slides|app)')
        .hasMatch(lower)) {
      return GoalBreakdown(
        goalTitle: trimmed,
        steps: [
          'تحديد المطلوب النهائي وتجهيز الهيكل الرئيسي لـ «$trimmed» (٢٠ دقيقة)',
          'تنفيذ الجزء الأساسي الأول بدون تشتيت (٤٠ دقيقة)',
          'مراجعة سريعة وتجهيز التسليم النهائي (١٥ دقيقة)',
        ],
        rationaleAr: 'تقسيم تنفيذي من التخطيط السريع للجزء الأساسي ثم المراجعة.',
        stepsEn: [
          'Define the deliverables and outline structure for "$trimmed" (20 min)',
          'Execute the primary core section with deep focus (40 min)',
          'Do a quick review and package the final delivery (15 min)',
        ],
        rationaleEn: 'Action-focused split from scoping to deep execution and final review.',
      );
    }
    return GoalBreakdown(
      goalTitle: trimmed,
      steps: [
        'تجهيز الخطوة الأولى المطلوبة لـ «$trimmed» (١٥ دقيقة)',
        'تنفيذ الجزء الرئيسي من «$trimmed» (٣٠ دقيقة)',
      ],
      rationaleAr: 'خطوتان واضحتان للبدء بدون تشتيت.',
      stepsEn: [
        'Prepare the concrete first step for "$trimmed" (15 min)',
        'Complete the main block of "$trimmed" (30 min)',
      ],
      rationaleEn: 'Two clear starting steps to eliminate friction.',
    );
  }

  /// Strict grounded renderer: every clause is built ONLY from actual item
  /// dates, times, priorities, dependency IDs, conflicts, and assumptions.
  String renderArabicExplanation({
    required List<ProposedScheduleItem> items,
    required List<ScheduleConflict> conflicts,
    required List<String> assumptions,
    required List<PlanDiffItem> diff,
    required List<String> criticalPathIds,
  }) {
    final buf = StringBuffer();
    if (items.isEmpty) {
      buf.writeln('ما قدرتش أطلع جدول صالح بسبب التعارضات الحالية:');
    } else {
      buf.writeln('دي مسودة ترتيب المهام المقترحة (${items.length}):');
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final durTag = item.isDurationAssumed
            ? '~${item.durationMinutes} د (تقديري)'
            : '${item.durationMinutes} د';
        final reasonText = item.reasons.isEmpty
            ? 'متاحة للتنفيذ'
            : item.reasons.map((r) => r.textAr).join('، ');
        buf.writeln(
          '${i + 1}. «${item.title}» — ${item.suggestedYmd} الساعة ${item.suggestedHm}..${item.suggestedEndHm} ($durTag)\n'
          '   السبب: $reasonText.',
        );
      }
    }

    if (criticalPathIds.isNotEmpty) {
      buf.writeln('• المسار الحرج يضم ${criticalPathIds.length} مهام مترابطة ما ينفعش تتأخر.');
    }
    if (diff.any((d) => d.kind != PlanDiffKind.preserved)) {
      final changed = diff.where((d) => d.kind != PlanDiffKind.preserved).length;
      buf.writeln('• اتعدّل $changed عنصر مقارنة بالمسودة اللي فاتت.');
    }
    if (assumptions.isNotEmpty) {
      for (final a in assumptions) {
        buf.writeln('• افتراض: $a');
      }
    }
    if (conflicts.isNotEmpty) {
      for (final c in conflicts) {
        buf.writeln('• تنبيه تعارض: ${c.messageAr}');
      }
    }
    return buf.toString().trim();
  }

  /// Strict grounded English renderer matching [renderArabicExplanation].
  String renderEnglishExplanation({
    required List<ProposedScheduleItem> items,
    required List<ScheduleConflict> conflicts,
    required List<String> assumptions,
    required List<PlanDiffItem> diff,
    required List<String> criticalPathIds,
  }) {
    final buf = StringBuffer();
    if (items.isEmpty) {
      buf.writeln('Could not generate a valid schedule due to current conflicts:');
    } else {
      buf.writeln('Proposed schedule draft (${items.length} task${items.length == 1 ? '' : 's'}):');
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final durTag = item.isDurationAssumed
            ? '~${item.durationMinutes} min (assumed)'
            : '${item.durationMinutes} min';
        final reasonText = item.reasons.isEmpty
            ? 'available for execution'
            : item.reasons.map((r) => r.localized(true)).join(', ');
        buf.writeln(
          '${i + 1}. "${item.title}" — ${item.suggestedYmd} ${item.suggestedHm}..${item.suggestedEndHm} ($durTag)\n'
          '   Why: $reasonText.',
        );
      }
    }

    if (criticalPathIds.isNotEmpty) {
      buf.writeln('• Critical path includes ${criticalPathIds.length} linked tasks with zero slack.');
    }
    if (diff.any((d) => d.kind != PlanDiffKind.preserved)) {
      final changed = diff.where((d) => d.kind != PlanDiffKind.preserved).length;
      buf.writeln('• $changed item(s) updated compared to the previous draft.');
    }
    if (assumptions.isNotEmpty) {
      for (final a in assumptions) {
        buf.writeln('• Assumption: $a');
      }
    }
    if (conflicts.isNotEmpty) {
      for (final c in conflicts) {
        buf.writeln('• Conflict: ${c.localized(true)}');
      }
    }
    return buf.toString().trim();
  }

  _DagResult _topologicalSort(
    List<PlanningTaskInput> tasks,
    Map<String, PlanningTaskInput> byId,
  ) {
    final inDegree = {for (final t in tasks) t.id: 0};
    final dependents = <String, List<String>>{for (final t in tasks) t.id: []};
    final conflicts = <ScheduleConflict>[];

    for (final t in tasks) {
      for (final dep in t.dependsOnIds) {
        if (!byId.containsKey(dep)) {
          conflicts.add(
            ScheduleConflict(
              type: ScheduleConflictType.missingDependency,
              taskIds: [t.id],
              messageAr: '«${t.title}» بتعتمد على مهمة رقمها مش موجود ($dep).',
              messageEn: '"${t.title}" depends on a missing task ID ($dep).',
            ),
          );
          continue;
        }
        inDegree[t.id] = inDegree[t.id]! + 1;
        dependents[dep]!.add(t.id);
      }
    }

    final queue = [
      for (final t in tasks)
        if (inDegree[t.id] == 0) t,
    ]..sort((a, b) => a.id.compareTo(b.id));

    final ordered = <PlanningTaskInput>[];
    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      ordered.add(curr);
      for (final nextId in dependents[curr.id]!) {
        inDegree[nextId] = inDegree[nextId]! - 1;
        if (inDegree[nextId] == 0) {
          queue.add(byId[nextId]!);
        }
      }
      queue.sort((a, b) => a.id.compareTo(b.id));
    }

    if (ordered.length < tasks.length) {
      final stuck = [
        for (final t in tasks)
          if (!ordered.any((o) => o.id == t.id)) t.id,
      ];
      conflicts.add(
        ScheduleConflict(
          type: ScheduleConflictType.dependencyCycle,
          taskIds: stuck,
          messageAr:
              'فيه اعتمادية دائرية بين المهام (${stuck.join(' ↔ ')})، لازم نفكّها الأول قبل الجدولة.',
          messageEn:
              'Circular dependency detected among tasks (${stuck.join(' ↔ ')}); break the cycle before scheduling.',
        ),
      );
      return _DagResult(ordered: ordered, conflicts: conflicts, hasCycle: true);
    }

    return _DagResult(ordered: ordered, conflicts: conflicts, hasCycle: false);
  }

  Map<String, CpmNodeMetrics> _computeCpmIfEligible({
    required List<PlanningTaskInput> orderedTasks,
    required Map<String, PlanningTaskInput> byId,
    required DateTime now,
  }) {
    final hasAnyDeps = orderedTasks.any((t) => t.dependsOnIds.isNotEmpty);
    if (!hasAnyDeps) return const {};

    // Identify tasks connected via dependency edges that have explicit durations & a project deadline.
    final linked = orderedTasks.where((t) {
      final isParent = orderedTasks.any((o) => o.dependsOnIds.contains(t.id));
      return t.dependsOnIds.isNotEmpty || isParent;
    }).toList();

    if (linked.isEmpty || !linked.every((t) => t.hasExplicitDuration)) {
      return const {};
    }

    final latestDue = linked
        .where((t) => t.dueDate != null)
        .map((t) => _endOfDueDay(t.dueDate!))
        .fold<DateTime?>(
          null,
          (maxDt, dt) => maxDt == null || dt.isAfter(maxDt) ? dt : maxDt,
        );
    if (latestDue == null) return const {};

    final horizonMinutes = math.max(1, latestDue.difference(now).inMinutes);
    final es = <String, int>{};
    final ef = <String, int>{};
    final succs = <String, List<String>>{for (final t in linked) t.id: []};
    final linkedIds = {for (final t in linked) t.id};

    for (final t in orderedTasks) {
      if (!linkedIds.contains(t.id)) continue;
      var start = 0;
      for (final dep in t.dependsOnIds) {
        if (!linkedIds.contains(dep)) continue;
        succs[dep]!.add(t.id);
        start = math.max(start, ef[dep] ?? 0);
      }
      es[t.id] = start;
      ef[t.id] = start + t.estimatedMinutes!;
    }

    final ls = <String, int>{};
    final lf = <String, int>{};
    for (final t in orderedTasks.reversed) {
      if (!linkedIds.contains(t.id)) continue;
      final taskDueMin = t.dueDate == null
          ? horizonMinutes
          : math.max(1, _endOfDueDay(t.dueDate!).difference(now).inMinutes);
      var finish = taskDueMin;
      for (final s in succs[t.id]!) {
        finish = math.min(finish, ls[s] ?? taskDueMin);
      }
      lf[t.id] = finish;
      ls[t.id] = finish - t.estimatedMinutes!;
    }

    return {
      for (final t in linked)
        t.id: CpmNodeMetrics(
          taskId: t.id,
          earliestStartMinutes: es[t.id]!,
          earliestFinishMinutes: ef[t.id]!,
          latestStartMinutes: ls[t.id]!,
          latestFinishMinutes: lf[t.id]!,
          slackMinutes: ls[t.id]! - es[t.id]!,
        ),
    };
  }

  List<TimeWindow> _defaultHorizonWindows(
    DateTime now,
    int horizonDays,
    List<String> assumptions, {
    List<String>? assumptionsEn,
  }) {
    assumptions.add(
      'ما تحددتش ساعات تفرغ فافترضت نوافذ شغل من 09:00 لـ 21:00 على مدار $horizonDays أيام.',
    );
    assumptionsEn?.add(
      'No free window specified, so I assumed 09:00–21:00 work windows over $horizonDays days.',
    );
    final list = <TimeWindow>[];
    for (var d = 0; d < horizonDays; d++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: d));
      final winStart = DateTime(day.year, day.month, day.day, 9, 0);
      final winEnd = DateTime(day.year, day.month, day.day, 21, 0);
      final effectiveStart = d == 0 && now.isAfter(winStart) ? _ceil15(now) : winStart;
      if (effectiveStart.isBefore(winEnd)) {
        list.add(TimeWindow(start: effectiveStart, end: winEnd));
      }
    }
    return list;
  }

  Map<String, int> _countDownstreamDependents(
    List<PlanningTaskInput> tasks,
    Map<String, PlanningTaskInput> byId,
  ) {
    final counts = {for (final t in tasks) t.id: 0};
    for (final t in tasks) {
      for (final dep in t.dependsOnIds) {
        if (counts.containsKey(dep)) {
          counts[dep] = counts[dep]! + 1;
        }
      }
    }
    return counts;
  }

  double _scoreTask(
    PlanningTaskInput task, {
    required PlanningProblem problem,
    required int downstream,
    CpmNodeMetrics? cpm,
  }) {
    final w = problem.weights;

    double deadlineScore = 0.2;
    if (task.dueDate != null) {
      final hoursLeft = _endOfDueDay(task.dueDate!).difference(problem.now).inHours;
      if (hoursLeft <= 0) {
        deadlineScore = 1.25;
      } else if (hoursLeft <= 24) {
        deadlineScore = 1.0;
      } else if (hoursLeft <= 72) {
        deadlineScore = 0.72;
      } else {
        deadlineScore = 0.4;
      }
    }

    final priorityScore = switch (task.priority) {
      'high' => 1.0,
      'medium' => 0.55,
      _ => 0.2,
    };

    var depScore = math.min(1.0, downstream * 0.45);
    if (cpm != null && cpm.isCritical) {
      depScore = math.max(depScore, 1.0);
    }

    final focusScore = problem.preferredPeriod != null ? 0.6 : 0.0;

    return deadlineScore * w.deadlineUrgency +
        priorityScore * w.userPriority +
        depScore * w.dependencyImpact +
        focusScore * w.focusWindowMatch;
  }

  TimeWindow? _findEarliestValidSlot({
    required List<TimeWindow> windows,
    required List<TimeWindow> busy,
    required DateTime earliestStart,
    required int durationMinutes,
    required int breakMinutes,
    String? preferredPeriod,
  }) {
    final orderedWindows = [...windows];
    if (preferredPeriod != null) {
      orderedWindows.sort((a, b) {
        final am = _matchesPeriod(a.start.hour, preferredPeriod) ? 0 : 1;
        final bm = _matchesPeriod(b.start.hour, preferredPeriod) ? 0 : 1;
        if (am != bm) return am.compareTo(bm);
        return a.start.compareTo(b.start);
      });
    } else {
      orderedWindows.sort((a, b) => a.start.compareTo(b.start));
    }

    final sortedBusy = [...busy]..sort((a, b) => a.start.compareTo(b.start));

    for (final win in orderedWindows) {
      var cursor = earliestStart.isAfter(win.start) ? earliestStart : win.start;
      while (!cursor.add(Duration(minutes: durationMinutes)).isAfter(win.end)) {
        final candidateEnd = cursor.add(Duration(minutes: durationMinutes));
        TimeWindow? blocker;
        for (final b in sortedBusy) {
          if (b.overlaps(cursor, candidateEnd)) {
            blocker = b;
            break;
          }
        }
        if (blocker == null) {
          return TimeWindow(start: cursor, end: candidateEnd);
        }
        final next = blocker.end.add(Duration(minutes: breakMinutes));
        cursor = next.isAfter(cursor) ? next : cursor.add(const Duration(minutes: 5));
      }
    }
    return null;
  }

  bool _fitsWindows(DateTime start, DateTime end, List<TimeWindow> windows) {
    return windows.any((w) => !start.isBefore(w.start) && !end.isAfter(w.end));
  }

  bool _overlapsAny(DateTime start, DateTime end, List<TimeWindow> busy) {
    return busy.any((b) => b.overlaps(start, end));
  }

  bool _matchesPeriod(int hour, String period) => switch (period) {
        'morning' => hour >= 6 && hour < 12,
        'afternoon' => hour >= 12 && hour < 17,
        'evening' => hour >= 17 && hour <= 23,
        _ => true,
      };

  List<PlanReason> _buildReasons(
    PlanningTaskInput task, {
    required TimeWindow slot,
    required DateTime now,
    required Map<String, PlanningTaskInput> byId,
    CpmNodeMetrics? cpmMetric,
    required bool preservedRolling,
    String? preferredPeriod,
  }) {
    final reasons = <PlanReason>[];
    if (task.dueDate != null) {
      final dueEnd = _endOfDueDay(task.dueDate!);
      if (dueEnd.isBefore(now)) {
        reasons.add(
          PlanReason(
            code: PlanReasonCode.overduePriority,
            factRef: _fmtYmd(task.dueDate!),
            textAr: 'متأخرة عن ميعادها (${_fmtYmd(task.dueDate!)})',
            textEn: 'overdue (${_fmtYmd(task.dueDate!)})',
          ),
        );
      } else {
        reasons.add(
          PlanReason(
            code: PlanReasonCode.deadlineSoon,
            factRef: _fmtYmd(task.dueDate!),
            textAr: 'موعدها النهائي ${_fmtYmd(task.dueDate!)}',
            textEn: 'due by ${_fmtYmd(task.dueDate!)}',
          ),
        );
      }
    }
    if (task.priority == 'high') {
      reasons.add(
        const PlanReason(
          code: PlanReasonCode.userPriority,
          factRef: 'high',
          textAr: 'أولوية عالية',
          textEn: 'high priority',
        ),
      );
    }
    if (cpmMetric != null && cpmMetric.isCritical) {
      reasons.add(
        const PlanReason(
          code: PlanReasonCode.criticalPath,
          factRef: 'slack=0',
          textAr: 'على المسار الحرج (من غير هامش تأخير)',
          textEn: 'on critical path (zero slack)',
        ),
      );
    }
    if (task.dependsOnIds.isNotEmpty) {
      final depTitles = [
        for (final id in task.dependsOnIds) byId[id]?.title ?? id,
      ];
      reasons.add(
        PlanReason(
          code: PlanReasonCode.dependencyReady,
          factRef: task.dependsOnIds.join(','),
          textAr: 'بتبدأ بعد انتهاء: ${depTitles.join('، ')}',
          textEn: 'starts after: ${depTitles.join(', ')}',
        ),
      );
    }
    if (preservedRolling) {
      reasons.add(
        const PlanReason(
          code: PlanReasonCode.rollingPreserved,
          factRef: 'rolling',
          textAr: 'ثبتت في ميعادها السابق للاستقرار',
          textEn: 'kept at previous slot for stability',
        ),
      );
    }
    if (preferredPeriod != null && _matchesPeriod(slot.start.hour, preferredPeriod)) {
      final label = switch (preferredPeriod) {
        'morning' => 'فترة الصبح المفضلة',
        'afternoon' => 'فترة الظهر المفضلة',
        _ => 'فترة بالليل المفضلة',
      };
      final labelEn = switch (preferredPeriod) {
        'morning' => 'preferred morning focus window',
        'afternoon' => 'preferred afternoon focus window',
        _ => 'preferred evening focus window',
      };
      reasons.add(
        PlanReason(
          code: PlanReasonCode.preferredFocusTime,
          factRef: preferredPeriod,
          textAr: 'موافقة لـ $label',
          textEn: 'matches $labelEn',
        ),
      );
    }
    if (reasons.isEmpty) {
      reasons.add(
        PlanReason(
          code: PlanReasonCode.availableWindow,
          factRef: '${_fmtYmd(slot.start)}_${_fmtHm(slot.start)}',
          textAr: 'أقرب وقت متاح في جدولك (${_fmtHm(slot.start)})',
          textEn: 'earliest open slot in your window (${_fmtHm(slot.start)})',
        ),
      );
    }
    return reasons;
  }

  List<PlanDiffItem> _computeDiff(
    List<ProposedScheduleItem> prev,
    List<ProposedScheduleItem> next,
  ) {
    final prevMap = {for (final p in prev) p.taskId: p};
    final nextMap = {for (final n in next) n.taskId: n};
    final diff = <PlanDiffItem>[];

    for (final n in next) {
      final p = prevMap[n.taskId];
      if (p == null) {
        diff.add(
          PlanDiffItem(
            kind: PlanDiffKind.added,
            taskId: n.taskId,
            title: n.title,
            newStart: n.suggestedStart,
          ),
        );
      } else if (p.suggestedStart != n.suggestedStart) {
        diff.add(
          PlanDiffItem(
            kind: PlanDiffKind.moved,
            taskId: n.taskId,
            title: n.title,
            previousStart: p.suggestedStart,
            newStart: n.suggestedStart,
          ),
        );
      } else {
        diff.add(
          PlanDiffItem(
            kind: PlanDiffKind.preserved,
            taskId: n.taskId,
            title: n.title,
            previousStart: p.suggestedStart,
            newStart: n.suggestedStart,
          ),
        );
      }
    }
    for (final p in prev) {
      if (!nextMap.containsKey(p.taskId)) {
        diff.add(
          PlanDiffItem(
            kind: PlanDiffKind.removed,
            taskId: p.taskId,
            title: p.title,
            previousStart: p.suggestedStart,
          ),
        );
      }
    }
    return diff;
  }

  static DateTime _endOfDueDay(DateTime due) =>
      DateTime(due.year, due.month, due.day, 23, 59);

  static DateTime _ceil15(DateTime dt) {
    final rem = dt.minute % 15;
    final clean = DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
    return rem == 0 ? clean : clean.add(Duration(minutes: 15 - rem));
  }

  static String _fnv128Hex(String input) {
    var h1 = 0x811c9dc5;
    var h2 = 0x9e3779b9;
    var h3 = 0x85ebca6b;
    var h4 = 0xc2b2ae35;
    const p1 = 0x01000193;
    const p2 = 0x01000195;
    for (final unit in input.codeUnits) {
      h1 = ((h1 ^ unit) * p1) & 0xffffffff;
      h2 = ((h2 ^ (unit + 31)) * p2) & 0xffffffff;
      h3 = ((h3 ^ (unit + 67)) * p1) & 0xffffffff;
      h4 = ((h4 ^ (unit + 131)) * p2) & 0xffffffff;
    }
    return '${h1.toRadixString(16).padLeft(8, '0')}'
        '${h2.toRadixString(16).padLeft(8, '0')}'
        '${h3.toRadixString(16).padLeft(8, '0')}'
        '${h4.toRadixString(16).padLeft(8, '0')}';
  }
}

class _DagResult {
  _DagResult({
    required this.ordered,
    required this.conflicts,
    required this.hasCycle,
  });

  final List<PlanningTaskInput> ordered;
  final List<ScheduleConflict> conflicts;
  final bool hasCycle;
}

String _fmtYmd(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-'
    '${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')}';

String _fmtHm(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';


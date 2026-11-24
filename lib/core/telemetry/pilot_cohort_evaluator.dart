/// Pure-Dart Phase 4a & 4b Pilot Cohort & Go/Stop Gate Evaluator.
///
/// Zero Flutter dependencies so the exact same evaluation logic runs both inside
/// automated Flutter tests and from the CLI (`dart run tool/evaluate_pilot_cohorts.dart`).
///
/// Strictly enforces Review Board rules:
/// - Rejects any export containing forbidden PII/content fields or lacking consent.
/// - Computes right-censored D1 / D7 / D28 retention from `firstActivatedAt` vs `asOf`.
/// - Computes Commitment Completion Rate & relative lift vs self-reported baseline.
/// - Produces an explicit, auditable `Go` / `CautionIterate` / `StopOrPivot` / `InsufficientData` verdict.
enum PilotGateDecision {
  go,
  cautionIterate,
  stopOrPivot,
  insufficientData,
}

class PilotSegmentBreakdown {
  const PilotSegmentBreakdown({
    required this.segment,
    required this.participants,
    required this.activated,
    required this.d7Eligible,
    required this.d7Retained,
    required this.d28Eligible,
    required this.d28Retained,
    required this.tasksCreated,
    required this.tasksCompleted,
    required this.previewsShown,
    required this.draftsConfirmed,
    required this.draftsEdited,
  });

  final String segment;
  final int participants;
  final int activated;
  final int d7Eligible;
  final int d7Retained;
  final int d28Eligible;
  final int d28Retained;
  final int tasksCreated;
  final int tasksCompleted;
  final int previewsShown;
  final int draftsConfirmed;
  final int draftsEdited;

  double get d7RetentionRate =>
      d7Eligible == 0 ? 0.0 : d7Retained / d7Eligible;
  double get d28RetentionRate =>
      d28Eligible == 0 ? 0.0 : d28Retained / d28Eligible;
  double get completionRate =>
      tasksCreated == 0 ? 0.0 : (tasksCompleted / tasksCreated).clamp(0.0, 1.0);
  double get confirmationRate =>
      previewsShown == 0 ? 0.0 : draftsConfirmed / previewsShown;
  double get editRate => previewsShown == 0 ? 0.0 : draftsEdited / previewsShown;
}

class PilotCohortReport {
  const PilotCohortReport({
    required this.asOfDate,
    required this.totalInputs,
    required this.validSnapshots,
    required this.rejectedSnapshots,
    required this.rejectionReasons,
    required this.activatedUsers,
    required this.totalPreviews,
    required this.totalEdited,
    required this.totalConfirmed,
    required this.totalCancelled,
    required this.avgConfirmLatencyMs,
    required this.voiceInputs,
    required this.textInputs,
    required this.totalTasksCreated,
    required this.totalTasksCompleted,
    required this.baselineParticipants,
    required this.avgBaselineCompletionRate,
    required this.d1Eligible,
    required this.d1Retained,
    required this.d7Eligible,
    required this.d7Retained,
    required this.d28Eligible,
    required this.d28Retained,
    required this.weeklyReturningUsers,
    required this.alarmOutcomes,
    required this.bySegment,
    required this.decision,
    required this.decisionReasons,
  });

  final String asOfDate;
  final int totalInputs;
  final int validSnapshots;
  final int rejectedSnapshots;
  final List<String> rejectionReasons;

  final int activatedUsers;
  final int totalPreviews;
  final int totalEdited;
  final int totalConfirmed;
  final int totalCancelled;
  final int avgConfirmLatencyMs;
  final int voiceInputs;
  final int textInputs;
  final int totalTasksCreated;
  final int totalTasksCompleted;

  final int baselineParticipants;
  final double? avgBaselineCompletionRate;

  final int d1Eligible;
  final int d1Retained;
  final int d7Eligible;
  final int d7Retained;
  final int d28Eligible;
  final int d28Retained;
  final int weeklyReturningUsers;

  final Map<String, int> alarmOutcomes;
  final Map<String, PilotSegmentBreakdown> bySegment;

  final PilotGateDecision decision;
  final List<String> decisionReasons;

  double get activationRate =>
      validSnapshots == 0 ? 0.0 : activatedUsers / validSnapshots;
  double get confirmationRate =>
      totalPreviews == 0 ? 0.0 : totalConfirmed / totalPreviews;
  double get editRate => totalPreviews == 0 ? 0.0 : totalEdited / totalPreviews;
  double get cancelRate =>
      totalPreviews == 0 ? 0.0 : totalCancelled / totalPreviews;
  double get voiceShare {
    final total = voiceInputs + textInputs;
    return total == 0 ? 0.0 : voiceInputs / total;
  }

  double get actualCompletionRate => totalTasksCreated == 0
      ? 0.0
      : (totalTasksCompleted / totalTasksCreated).clamp(0.0, 1.0);

  double? get relativeCompletionLift {
    final base = avgBaselineCompletionRate;
    if (base == null || base <= 0) return null;
    return (actualCompletionRate - base) / base;
  }

  double get d1RetentionRate =>
      d1Eligible == 0 ? 0.0 : d1Retained / d1Eligible;
  double get d7RetentionRate =>
      d7Eligible == 0 ? 0.0 : d7Retained / d7Eligible;
  double get d28RetentionRate =>
      d28Eligible == 0 ? 0.0 : d28Retained / d28Eligible;
  double get weeklyReturnRate =>
      activatedUsers == 0 ? 0.0 : weeklyReturningUsers / activatedUsers;

  int get totalAlarmAttempts =>
      alarmOutcomes.values.fold<int>(0, (sum, v) => sum + v);

  double get alarmDegradedOrFailedRate {
    final total = totalAlarmAttempts;
    if (total == 0) return 0.0;
    final problem = (alarmOutcomes['permissionDenied'] ?? 0) +
        (alarmOutcomes['failed'] ?? 0);
    return problem / total;
  }

  String toMarkdownReport() {
    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
    final b = StringBuffer()
      ..writeln('# Handelha Phase 4 Pilot Cohort Evaluation Report')
      ..writeln('- **As-Of Date:** $asOfDate')
      ..writeln(
        '- **Snapshots:** $validSnapshots valid / $totalInputs total ($rejectedSnapshots rejected)',
      )
      ..writeln('- **Automated Gate Decision:** `${decision.name}`')
      ..writeln()
      ..writeln('## Gate Rationale');
    for (final r in decisionReasons) {
      b.writeln('- $r');
    }
    b
      ..writeln()
      ..writeln('## Phase 4a — Core-Loop Quality')
      ..writeln(
        '- **Activation Rate:** ${pct(activationRate)} ($activatedUsers/$validSnapshots)',
      )
      ..writeln(
        '- **Preview Confirmation Rate:** ${pct(confirmationRate)} ($totalConfirmed/$totalPreviews)',
      )
      ..writeln(
        '- **Draft Edit Rate:** ${pct(editRate)} ($totalEdited/$totalPreviews)',
      )
      ..writeln(
        '- **Draft Cancel Rate:** ${pct(cancelRate)} ($totalCancelled/$totalPreviews)',
      )
      ..writeln('- **Average Confirm Latency:** ${avgConfirmLatencyMs}ms')
      ..writeln(
        '- **Voice vs Text Share:** ${pct(voiceShare)} voice ($voiceInputs voice / $textInputs text)',
      )
      ..writeln(
        '- **Alarm Problem Rate (`permissionDenied` + `failed`):** ${pct(alarmDegradedOrFailedRate)} ($alarmOutcomes)',
      )
      ..writeln()
      ..writeln('## Phase 4b — Right-Censored Retention & Outcome')
      ..writeln(
        '- **D1 Retention:** ${d1Eligible == 0 ? 'N/A' : '${pct(d1RetentionRate)} ($d1Retained/$d1Eligible eligible)'}',
      )
      ..writeln(
        '- **D7 Retention:** ${d7Eligible == 0 ? 'N/A' : '${pct(d7RetentionRate)} ($d7Retained/$d7Eligible eligible)'}',
      )
      ..writeln(
        '- **D28 Retention:** ${d28Eligible == 0 ? 'N/A' : '${pct(d28RetentionRate)} ($d28Retained/$d28Eligible eligible)'}',
      )
      ..writeln(
        '- **Multi-Week Active Return:** ${pct(weeklyReturnRate)} ($weeklyReturningUsers/$activatedUsers)',
      )
      ..writeln(
        '- **Commitment Completion Rate:** ${pct(actualCompletionRate)} ($totalTasksCompleted/$totalTasksCreated)',
      )
      ..writeln(
        '- **Relative Lift vs Baseline:** ${relativeCompletionLift == null ? 'N/A (no baseline)' : '${(relativeCompletionLift! * 100).toStringAsFixed(1)}% (baseline ${pct(avgBaselineCompletionRate!)} across $baselineParticipants users)'}',
      );

    if (bySegment.isNotEmpty) {
      b
        ..writeln()
        ..writeln('## Breakdown by ICP Segment')
        ..writeln(
          '| Segment | Users | Activated | Confirm | Edit | Completion | D7 | D28 |',
        )
        ..writeln('|---|---:|---:|---:|---:|---:|---:|---:|');
      for (final s in bySegment.values) {
        b.writeln(
          '| ${s.segment} | ${s.participants} | ${s.activated} | ${pct(s.confirmationRate)} | ${pct(s.editRate)} | ${pct(s.completionRate)} | ${s.d7Eligible == 0 ? 'N/A' : pct(s.d7RetentionRate)} | ${s.d28Eligible == 0 ? 'N/A' : pct(s.d28RetentionRate)} |',
        );
      }
    }
    if (rejectionReasons.isNotEmpty) {
      b
        ..writeln()
        ..writeln('## Rejected Snapshots (Privacy / Consent Guard)');
      for (final r in rejectionReasons) {
        b.writeln('- $r');
      }
    }
    return b.toString();
  }
}

class PilotCohortEvaluator {
  const PilotCohortEvaluator._();

  static const Set<String> _forbiddenPiiKeys = {
    'email',
    'userid',
    'user_id',
    'phone',
    'phonenumber',
    'displayname',
    'name',
    'title',
    'content',
    'messages',
    'tasks',
    'transcript',
    'utterance',
  };

  /// Validates that an exported snapshot has explicit consent and ZERO PII keys.
  /// Returns `null` if valid, or an error description if rejected.
  static String? validateAnonymousPayload(Map<String, dynamic> payload) {
    if (payload['consentGranted'] != true) {
      return 'Snapshot lacks explicit opt-in consent (`consentGranted != true`).';
    }
    final leaked = _findForbiddenKey(payload);
    if (leaked != null) {
      return 'Snapshot rejected for privacy safety: forbidden PII/content key `$leaked`.';
    }
    return null;
  }

  static String? _findForbiddenKey(Object? node) {
    if (node is Map) {
      for (final entry in node.entries) {
        final k = entry.key.toString().trim().toLowerCase();
        if (_forbiddenPiiKeys.contains(k)) return entry.key.toString();
        final nested = _findForbiddenKey(entry.value);
        if (nested != null) return nested;
      }
    } else if (node is List) {
      for (final item in node) {
        final nested = _findForbiddenKey(item);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  /// Evaluates a cohort of exported anonymous JSON telemetry maps against
  /// the Review Board's Phase 4a & Phase 4b Go/Stop criteria.
  static PilotCohortReport evaluate(
    List<Map<String, dynamic>> rawSnapshots, {
    required DateTime asOf,
    int minActivatedForDecision = 10,
    int minD28EligibleForDecision = 10,
  }) {
    final refDate = DateTime(asOf.year, asOf.month, asOf.day);
    final asOfStr =
        '${refDate.year.toString().padLeft(4, '0')}-${refDate.month.toString().padLeft(2, '0')}-${refDate.day.toString().padLeft(2, '0')}';

    var valid = 0;
    var rejected = 0;
    final rejectionReasons = <String>[];

    var activatedUsers = 0;
    var totalPreviews = 0;
    var totalEdited = 0;
    var totalConfirmed = 0;
    var totalCancelled = 0;
    var latencyTotal = 0;
    var latencySamples = 0;
    var voiceInputs = 0;
    var textInputs = 0;
    var totalTasksCreated = 0;
    var totalTasksCompleted = 0;

    var baselineCount = 0;
    var baselineSum = 0.0;

    var d1Eligible = 0;
    var d1Retained = 0;
    var d7Eligible = 0;
    var d7Retained = 0;
    var d28Eligible = 0;
    var d28Retained = 0;
    var weeklyReturning = 0;

    final alarmOutcomes = <String, int>{};
    final segAccum = <String, _SegAcc>{};

    for (var i = 0; i < rawSnapshots.length; i++) {
      final raw = rawSnapshots[i];
      final err = validateAnonymousPayload(raw);
      if (err != null) {
        rejected++;
        rejectionReasons.add('Snapshot #$i: $err');
        continue;
      }
      valid++;

      final segName = (raw['segment']?.toString().trim().isNotEmpty ?? false)
          ? raw['segment'].toString().trim().toLowerCase()
          : 'unspecified';
      final seg = segAccum.putIfAbsent(segName, () => _SegAcc(segName));
      seg.participants++;

      final previews = _int(raw['previewsShown']);
      final edited = _int(raw['draftsEdited']);
      final confirmed = _int(raw['draftsConfirmed']);
      final cancelled = _int(raw['draftsCancelled']);
      final created = _int(raw['tasksCreated']);
      final completed = _int(raw['tasksCompleted']);
      final latTotal = _int(raw['confirmLatencyTotalMs']);
      final latSamples = _int(raw['confirmLatencySamples']);
      final voice = _int(raw['voiceInputsUsed']);
      final text = _int(raw['textInputsUsed']);

      totalPreviews += previews;
      totalEdited += edited;
      totalConfirmed += confirmed;
      totalCancelled += cancelled;
      latencyTotal += latTotal;
      latencySamples += latSamples;
      voiceInputs += voice;
      textInputs += text;
      totalTasksCreated += created;
      totalTasksCompleted += completed;

      seg.previewsShown += previews;
      seg.draftsConfirmed += confirmed;
      seg.draftsEdited += edited;
      seg.tasksCreated += created;
      seg.tasksCompleted += completed;

      final rawBaseline = (raw['baselineCompletionRate'] as num?)?.toDouble();
      if (rawBaseline != null && rawBaseline >= 0 && rawBaseline <= 1) {
        baselineCount++;
        baselineSum += rawBaseline;
      }

      final rawAlarms = raw['alarmOutcomes'];
      if (rawAlarms is Map) {
        for (final entry in rawAlarms.entries) {
          final k = entry.key.toString();
          final v = _int(entry.value);
          alarmOutcomes[k] = (alarmOutcomes[k] ?? 0) + v;
        }
      }

      final days = (raw['activeDays'] as List<dynamic>? ?? const [])
          .map((e) => _parseDay(e.toString()))
          .whereType<DateTime>()
          .toList()
        ..sort();

      final firstActivated = _parseDay(raw['firstActivatedAt']?.toString()) ??
          ((created > 0 || confirmed > 0) && days.isNotEmpty
              ? days.first
              : null);

      final isActivated =
          firstActivated != null || created > 0 || confirmed > 0;
      if (isActivated) {
        activatedUsers++;
        seg.activated++;

        final distinctWeeks = <String>{
          for (final d in days)
            '${d.year}-W${((d.difference(DateTime(d.year, 1, 1)).inDays ~/ 7) + 1).toString().padLeft(2, '0')}',
        };
        if (distinctWeeks.length >= 2) {
          weeklyReturning++;
        }

        if (firstActivated != null) {
          final ageDays = refDate.difference(firstActivated).inDays;
          final maxOffset = days.isEmpty
              ? 0
              : days
                  .map((d) => d.difference(firstActivated).inDays)
                  .reduce((a, b) => a > b ? a : b);

          if (ageDays >= 1) {
            d1Eligible++;
            if (maxOffset >= 1) d1Retained++;
          }
          if (ageDays >= 7) {
            d7Eligible++;
            seg.d7Eligible++;
            if (maxOffset >= 7) {
              d7Retained++;
              seg.d7Retained++;
            }
          }
          if (ageDays >= 28) {
            d28Eligible++;
            seg.d28Eligible++;
            if (maxOffset >= 28) {
              d28Retained++;
              seg.d28Retained++;
            }
          }
        }
      }
    }

    final avgLatency =
        latencySamples == 0 ? 0 : (latencyTotal / latencySamples).round();
    final avgBaseline = baselineCount == 0 ? null : baselineSum / baselineCount;
    final actualComp = totalTasksCreated == 0
        ? 0.0
        : (totalTasksCompleted / totalTasksCreated).clamp(0.0, 1.0);
    final relLift = (avgBaseline != null && avgBaseline > 0)
        ? (actualComp - avgBaseline) / avgBaseline
        : null;
    final d28Rate = d28Eligible == 0 ? 0.0 : d28Retained / d28Eligible;
    final totalAlarms =
        alarmOutcomes.values.fold<int>(0, (sum, v) => sum + v);
    final alarmProblemRate = totalAlarms == 0
        ? 0.0
        : ((alarmOutcomes['permissionDenied'] ?? 0) +
                (alarmOutcomes['failed'] ?? 0)) /
            totalAlarms;
    final editRate = totalPreviews == 0 ? 0.0 : totalEdited / totalPreviews;

    final reasons = <String>[];
    PilotGateDecision decision;

    if (activatedUsers < minActivatedForDecision ||
        d28Eligible < minD28EligibleForDecision) {
      decision = PilotGateDecision.insufficientData;
      reasons.add(
        'Insufficient cohort maturity: activated=$activatedUsers (min $minActivatedForDecision), D28-eligible=$d28Eligible (min $minD28EligibleForDecision). Do NOT declare PMF or start paid scaling yet.',
      );
      if (alarmProblemRate > 0.10) {
        reasons.add(
          'Early warning: alarm problem rate is ${(alarmProblemRate * 100).toStringAsFixed(1)}% (> 10%). Investigate permissions/OEM scheduling.',
        );
      }
    } else if (d28Rate < 0.10) {
      decision = PilotGateDecision.stopOrPivot;
      reasons.add(
        'STOP/PIVOT: D28 retention is ${(d28Rate * 100).toStringAsFixed(1)}% (< 10% Board stop floor). Halt expansion and re-examine ICP/core loop.',
      );
    } else if (alarmProblemRate > 0.10) {
      decision = PilotGateDecision.stopOrPivot;
      reasons.add(
        'STOP/FIX: Alarm failure/denied rate is ${(alarmProblemRate * 100).toStringAsFixed(1)}% (> 10%). Fix reliability before scaling.',
      );
    } else if (d28Rate >= 0.25 &&
        (relLift == null || relLift >= 0.20) &&
        editRate <= 0.35) {
      decision = PilotGateDecision.go;
      reasons.add(
        'GO: D28 retention ${(d28Rate * 100).toStringAsFixed(1)}% >= 25% target across $d28Eligible eligible activated users.',
      );
      if (relLift != null) {
        reasons.add(
          'GO: Commitment completion relative lift ${(relLift * 100).toStringAsFixed(1)}% >= +20% target vs baseline.',
        );
      }
      reasons.add(
        'Safe to unlock Phase 5 monetization & single-channel acquisition tests.',
      );
    } else {
      decision = PilotGateDecision.cautionIterate;
      if (d28Rate < 0.25) {
        reasons.add(
          'ITERATE: D28 retention ${(d28Rate * 100).toStringAsFixed(1)}% is between 10% and 25% — improve core loop before Phase 5.',
        );
      }
      if (relLift != null && relLift < 0.20) {
        reasons.add(
          'ITERATE: Commitment completion lift ${(relLift * 100).toStringAsFixed(1)}% is below +20% target vs baseline.',
        );
      }
      if (editRate > 0.35) {
        reasons.add(
          'ITERATE: Draft edit rate ${(editRate * 100).toStringAsFixed(1)}% (> 35%) signals Egyptian NLU slot extraction friction — inspect field utterances.',
        );
      }
    }

    return PilotCohortReport(
      asOfDate: asOfStr,
      totalInputs: rawSnapshots.length,
      validSnapshots: valid,
      rejectedSnapshots: rejected,
      rejectionReasons: rejectionReasons,
      activatedUsers: activatedUsers,
      totalPreviews: totalPreviews,
      totalEdited: totalEdited,
      totalConfirmed: totalConfirmed,
      totalCancelled: totalCancelled,
      avgConfirmLatencyMs: avgLatency,
      voiceInputs: voiceInputs,
      textInputs: textInputs,
      totalTasksCreated: totalTasksCreated,
      totalTasksCompleted: totalTasksCompleted,
      baselineParticipants: baselineCount,
      avgBaselineCompletionRate: avgBaseline,
      d1Eligible: d1Eligible,
      d1Retained: d1Retained,
      d7Eligible: d7Eligible,
      d7Retained: d7Retained,
      d28Eligible: d28Eligible,
      d28Retained: d28Retained,
      weeklyReturningUsers: weeklyReturning,
      alarmOutcomes: alarmOutcomes,
      bySegment: {
        for (final e in segAccum.entries) e.key: e.value.build(),
      },
      decision: decision,
      decisionReasons: reasons,
    );
  }

  static int _int(Object? v) => (v as num?)?.toInt() ?? 0;

  static DateTime? _parseDay(String? ymd) {
    if (ymd == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(ymd.trim());
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }
}

class _SegAcc {
  _SegAcc(this.segment);
  final String segment;
  int participants = 0;
  int activated = 0;
  int d7Eligible = 0;
  int d7Retained = 0;
  int d28Eligible = 0;
  int d28Retained = 0;
  int tasksCreated = 0;
  int tasksCompleted = 0;
  int previewsShown = 0;
  int draftsConfirmed = 0;
  int draftsEdited = 0;

  PilotSegmentBreakdown build() => PilotSegmentBreakdown(
        segment: segment,
        participants: participants,
        activated: activated,
        d7Eligible: d7Eligible,
        d7Retained: d7Retained,
        d28Eligible: d28Eligible,
        d28Retained: d28Retained,
        tasksCreated: tasksCreated,
        tasksCompleted: tasksCompleted,
        previewsShown: previewsShown,
        draftsConfirmed: draftsConfirmed,
        draftsEdited: draftsEdited,
      );
}

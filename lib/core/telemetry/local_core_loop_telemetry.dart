import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/authentication/data/student_preview_seeder.dart';

/// Allowed anonymous participant segments for Phase 3/4 pilot cohorts.
enum PilotSegment {
  student,
  freelancer,
  employee,
  other;

  static PilotSegment? tryParse(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    for (final s in values) {
      if (s.name == v) return s;
    }
    return null;
  }
}

/// Privacy-safe, opt-in local core-loop & cohort telemetry (schema v2).
///
/// Strict guarantees:
/// - **Disabled by default** (`consentGranted == false`). Zero events are stored
///   unless the user explicitly opts in via Settings -> Privacy.
/// - **Zero PII & zero content:** never stores task titles, descriptions, chat
///   utterances, emails, user IDs, or device identifiers.
/// - **Excludes QA preview accounts** (`StudentPreviewAccount.userId`) so QA
///   sessions never pollute validation cohort metrics.
@immutable
class CoreLoopTelemetrySnapshot {
  const CoreLoopTelemetrySnapshot({
    required this.consentGranted,
    this.cohortTag,
    this.segment,
    this.baselineCompletionRate,
    this.firstActivatedAt,
    this.previewsShown = 0,
    this.draftsEdited = 0,
    this.draftsConfirmed = 0,
    this.draftsCancelled = 0,
    this.confirmLatencyTotalMs = 0,
    this.confirmLatencySamples = 0,
    this.voiceInputsUsed = 0,
    this.textInputsUsed = 0,
    this.tasksCreated = 0,
    this.tasksCompleted = 0,
    this.focusSessionsStarted = 0,
    this.focusSessionsCompleted = 0,
    this.alarmOutcomes = const {},
    this.activeDays = const [],
  });

  static const int currentSchemaVersion = 2;

  final bool consentGranted;
  final String? cohortTag;
  final PilotSegment? segment;

  /// Optional self-reported pre-Handelha completion ratio (0.0 .. 1.0) used
  /// in Phase 4b to compare actual commitment completion lift against baseline.
  final double? baselineCompletionRate;

  /// `YYYY-MM-DD` date of the first confirmed commitment (Day 0 for D1/D7/D28).
  final String? firstActivatedAt;

  final int previewsShown;
  final int draftsEdited;
  final int draftsConfirmed;
  final int draftsCancelled;
  final int confirmLatencyTotalMs;
  final int confirmLatencySamples;
  final int voiceInputsUsed;
  final int textInputsUsed;
  final int tasksCreated;
  final int tasksCompleted;
  final int focusSessionsStarted;
  final int focusSessionsCompleted;
  final Map<String, int> alarmOutcomes;
  final List<String> activeDays; // YYYY-MM-DD only

  bool get isActivated =>
      firstActivatedAt != null || tasksCreated > 0 || draftsConfirmed > 0;

  double get confirmationRate =>
      previewsShown == 0 ? 0.0 : draftsConfirmed / previewsShown;

  double get editRate =>
      previewsShown == 0 ? 0.0 : draftsEdited / previewsShown;

  double get cancelRate =>
      previewsShown == 0 ? 0.0 : draftsCancelled / previewsShown;

  double get commitmentCompletionRate => tasksCreated == 0
      ? 0.0
      : (tasksCompleted / tasksCreated).clamp(0.0, 1.0);

  int get avgConfirmLatencyMs => confirmLatencySamples == 0
      ? 0
      : (confirmLatencyTotalMs / confirmLatencySamples).round();

  DateTime? get firstActivatedDate =>
      firstActivatedAt == null ? null : _parseDay(firstActivatedAt!);

  /// True when the cohort age has reached [targetDay] relative to [asOf],
  /// ensuring right-censored retention calculations do not penalize new users.
  bool isCohortEligibleForDay(int targetDay, DateTime asOf) {
    final day0 = firstActivatedDate;
    if (day0 == null) return false;
    final ref = DateTime(asOf.year, asOf.month, asOf.day);
    return ref.difference(day0).inDays >= targetDay;
  }

  /// True when the user returned on or after [targetDay] days from Day 0.
  bool retainedOnOrAfterDay(int targetDay) {
    final day0 = firstActivatedDate;
    if (day0 == null) return false;
    for (final raw in activeDays) {
      final d = _parseDay(raw);
      if (d != null && d.difference(day0).inDays >= targetDay) {
        return true;
      }
    }
    return false;
  }

  /// Distinct ISO-like week keys (`YYYY-Www`) active in [activeDays].
  int get distinctActiveWeeks {
    final weeks = <String>{};
    for (final raw in activeDays) {
      final d = _parseDay(raw);
      if (d == null) continue;
      final startOfYear = DateTime(d.year, 1, 1);
      final dayOfYear = d.difference(startOfYear).inDays;
      final weekNum = (dayOfYear ~/ 7) + 1;
      weeks.add('${d.year}-W${weekNum.toString().padLeft(2, '0')}');
    }
    return weeks.length;
  }

  static DateTime? _parseDay(String ymd) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(ymd.trim());
    if (m == null) return null;
    final y = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final da = int.tryParse(m.group(3)!);
    if (y == null || mo == null || da == null) return null;
    return DateTime(y, mo, da);
  }

  Map<String, dynamic> toAnonymousJson() => {
        'schema': currentSchemaVersion,
        'privacy': 'anonymous-counts-only-no-pii',
        'consentGranted': consentGranted,
        if (cohortTag != null && cohortTag!.isNotEmpty) 'cohortTag': cohortTag,
        if (segment != null) 'segment': segment!.name,
        if (baselineCompletionRate != null)
          'baselineCompletionRate': double.parse(
            baselineCompletionRate!.clamp(0.0, 1.0).toStringAsFixed(3),
          ),
        if (firstActivatedAt != null) 'firstActivatedAt': firstActivatedAt,
        'previewsShown': previewsShown,
        'draftsEdited': draftsEdited,
        'draftsConfirmed': draftsConfirmed,
        'draftsCancelled': draftsCancelled,
        'confirmLatencyTotalMs': confirmLatencyTotalMs,
        'confirmLatencySamples': confirmLatencySamples,
        'avgConfirmLatencyMs': avgConfirmLatencyMs,
        'confirmationRate': double.parse(confirmationRate.toStringAsFixed(3)),
        'editRate': double.parse(editRate.toStringAsFixed(3)),
        'cancelRate': double.parse(cancelRate.toStringAsFixed(3)),
        'voiceInputsUsed': voiceInputsUsed,
        'textInputsUsed': textInputsUsed,
        'tasksCreated': tasksCreated,
        'tasksCompleted': tasksCompleted,
        'commitmentCompletionRate':
            double.parse(commitmentCompletionRate.toStringAsFixed(3)),
        'focusSessionsStarted': focusSessionsStarted,
        'focusSessionsCompleted': focusSessionsCompleted,
        'alarmOutcomes': alarmOutcomes,
        'activeDaysCount': activeDays.length,
        'distinctActiveWeeks': distinctActiveWeeks,
        'activeDays': activeDays,
      };

  factory CoreLoopTelemetrySnapshot.fromJson(
    Map<String, dynamic> json, {
    required bool consentGranted,
  }) {
    final rawAlarms = json['alarmOutcomes'];
    final alarmMap = <String, int>{};
    if (rawAlarms is Map) {
      for (final e in rawAlarms.entries) {
        alarmMap[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    final days = (json['activeDays'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((s) => _parseDay(s) != null)
        .toList();
    final rawBaseline = (json['baselineCompletionRate'] as num?)?.toDouble();
    final rawFirst = json['firstActivatedAt']?.toString();
    return CoreLoopTelemetrySnapshot(
      consentGranted: consentGranted,
      cohortTag: _sanitizeTag(json['cohortTag']?.toString()),
      segment: PilotSegment.tryParse(json['segment']?.toString()),
      baselineCompletionRate: rawBaseline?.clamp(0.0, 1.0),
      firstActivatedAt:
          (rawFirst != null && _parseDay(rawFirst) != null) ? rawFirst : null,
      previewsShown: (json['previewsShown'] as num?)?.toInt() ?? 0,
      draftsEdited: (json['draftsEdited'] as num?)?.toInt() ?? 0,
      draftsConfirmed: (json['draftsConfirmed'] as num?)?.toInt() ?? 0,
      draftsCancelled: (json['draftsCancelled'] as num?)?.toInt() ?? 0,
      confirmLatencyTotalMs:
          (json['confirmLatencyTotalMs'] as num?)?.toInt() ?? 0,
      confirmLatencySamples:
          (json['confirmLatencySamples'] as num?)?.toInt() ?? 0,
      voiceInputsUsed: (json['voiceInputsUsed'] as num?)?.toInt() ?? 0,
      textInputsUsed: (json['textInputsUsed'] as num?)?.toInt() ?? 0,
      tasksCreated: (json['tasksCreated'] as num?)?.toInt() ?? 0,
      tasksCompleted: (json['tasksCompleted'] as num?)?.toInt() ?? 0,
      focusSessionsStarted:
          (json['focusSessionsStarted'] as num?)?.toInt() ?? 0,
      focusSessionsCompleted:
          (json['focusSessionsCompleted'] as num?)?.toInt() ?? 0,
      alarmOutcomes: alarmMap,
      activeDays: days,
    );
  }

  static String? _sanitizeTag(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    if (cleaned.isEmpty) return null;
    return cleaned.length > 32 ? cleaned.substring(0, 32) : cleaned;
  }
}

class LocalCoreLoopTelemetry {
  LocalCoreLoopTelemetry._();

  static final instance = LocalCoreLoopTelemetry._();

  static String _consentKey(String userId) =>
      'handelha_telemetry_consent_$userId';
  static String _dataKey(String userId) => 'handelha_telemetry_counts_$userId';

  static bool isExcludedAccount(String? userId) {
    if (userId == null || userId.trim().isEmpty) return true;
    return userId == StudentPreviewAccount.userId;
  }

  Future<bool> isConsentGranted(String? userId) async {
    if (isExcludedAccount(userId)) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_consentKey(userId!)) == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setConsent(String? userId, bool granted) async {
    if (isExcludedAccount(userId)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey(userId!), granted);
    if (!granted) {
      await prefs.remove(_dataKey(userId));
    }
  }

  /// Stores optional anonymous pilot cohort metadata (segment, cohort tag,
  /// self-reported baseline completion ratio). No-op unless consent is granted.
  Future<void> setPilotMetadata(
    String? userId, {
    String? cohortTag,
    PilotSegment? segment,
    double? baselineCompletionRate,
  }) async {
    if (isExcludedAccount(userId)) return;
    if (!await isConsentGranted(userId)) return;
    final current = await load(userId);
    final sanitizedTag = CoreLoopTelemetrySnapshot._sanitizeTag(cohortTag);
    final next = CoreLoopTelemetrySnapshot(
      consentGranted: true,
      cohortTag: cohortTag != null ? sanitizedTag : current.cohortTag,
      segment: segment ?? current.segment,
      baselineCompletionRate: baselineCompletionRate != null
          ? baselineCompletionRate.clamp(0.0, 1.0)
          : current.baselineCompletionRate,
      firstActivatedAt: current.firstActivatedAt,
      previewsShown: current.previewsShown,
      draftsEdited: current.draftsEdited,
      draftsConfirmed: current.draftsConfirmed,
      draftsCancelled: current.draftsCancelled,
      confirmLatencyTotalMs: current.confirmLatencyTotalMs,
      confirmLatencySamples: current.confirmLatencySamples,
      voiceInputsUsed: current.voiceInputsUsed,
      textInputsUsed: current.textInputsUsed,
      tasksCreated: current.tasksCreated,
      tasksCompleted: current.tasksCompleted,
      focusSessionsStarted: current.focusSessionsStarted,
      focusSessionsCompleted: current.focusSessionsCompleted,
      alarmOutcomes: current.alarmOutcomes,
      activeDays: current.activeDays,
    );
    await _persist(userId!, next);
  }

  Future<CoreLoopTelemetrySnapshot> load(String? userId) async {
    if (isExcludedAccount(userId)) {
      return const CoreLoopTelemetrySnapshot(consentGranted: false);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final consent = prefs.getBool(_consentKey(userId!)) == true;
      if (!consent) {
        return const CoreLoopTelemetrySnapshot(consentGranted: false);
      }
      final raw = prefs.getString(_dataKey(userId));
      if (raw == null || raw.isEmpty) {
        return const CoreLoopTelemetrySnapshot(consentGranted: true);
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return CoreLoopTelemetrySnapshot.fromJson(
        decoded,
        consentGranted: true,
      );
    } catch (_) {
      return const CoreLoopTelemetrySnapshot(consentGranted: false);
    }
  }

  Future<void> recordEvent(
    String? userId,
    String eventName, {
    String? alarmStatus,
    int? latencyMs,
    DateTime? now,
  }) async {
    if (isExcludedAccount(userId)) return;
    if (!await isConsentGranted(userId)) return;

    final current = await load(userId);
    final dt = now ?? DateTime.now();
    final dayKey =
        '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final nextDays = current.activeDays.contains(dayKey)
        ? current.activeDays
        : [...current.activeDays, dayKey];

    final nextAlarms = Map<String, int>.from(current.alarmOutcomes);
    if (eventName == 'alarm_schedule_outcome' &&
        alarmStatus != null &&
        alarmStatus.isNotEmpty) {
      nextAlarms[alarmStatus] = (nextAlarms[alarmStatus] ?? 0) + 1;
    }

    final validLatency =
        (latencyMs != null && latencyMs >= 0 && latencyMs <= 600000)
            ? latencyMs
            : null;
    final isActivationEvent =
        eventName == 'task_created' || eventName == 'draft_confirmed';

    final next = CoreLoopTelemetrySnapshot(
      consentGranted: true,
      cohortTag: current.cohortTag,
      segment: current.segment,
      baselineCompletionRate: current.baselineCompletionRate,
      firstActivatedAt: current.firstActivatedAt ??
          (isActivationEvent ? dayKey : null),
      previewsShown:
          current.previewsShown + (eventName == 'preview_shown' ? 1 : 0),
      draftsEdited:
          current.draftsEdited + (eventName == 'draft_edited' ? 1 : 0),
      draftsConfirmed:
          current.draftsConfirmed + (eventName == 'draft_confirmed' ? 1 : 0),
      draftsCancelled:
          current.draftsCancelled + (eventName == 'draft_cancelled' ? 1 : 0),
      confirmLatencyTotalMs:
          current.confirmLatencyTotalMs + (validLatency ?? 0),
      confirmLatencySamples:
          current.confirmLatencySamples + (validLatency != null ? 1 : 0),
      voiceInputsUsed:
          current.voiceInputsUsed + (eventName == 'voice_input' ? 1 : 0),
      textInputsUsed:
          current.textInputsUsed + (eventName == 'text_input' ? 1 : 0),
      tasksCreated:
          current.tasksCreated + (eventName == 'task_created' ? 1 : 0),
      tasksCompleted:
          current.tasksCompleted + (eventName == 'task_completed' ? 1 : 0),
      focusSessionsStarted: current.focusSessionsStarted +
          (eventName == 'focus_started' ? 1 : 0),
      focusSessionsCompleted: current.focusSessionsCompleted +
          (eventName == 'focus_completed' ? 1 : 0),
      alarmOutcomes: nextAlarms,
      activeDays: nextDays,
    );

    await _persist(userId!, next);
  }

  Future<void> _persist(String userId, CoreLoopTelemetrySnapshot snap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _dataKey(userId),
        jsonEncode(snap.toAnonymousJson()),
      );
    } catch (_) {}
  }

  Future<void> clearForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_consentKey(userId));
      await prefs.remove(_dataKey(userId));
    } catch (_) {}
  }
}

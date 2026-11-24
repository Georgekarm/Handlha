import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../features/assistant/data/user_energy_preferences.dart';
import '../../features/notifications/alarm_reminder_store.dart';
import '../../features/notifications/notification_preferences.dart';
import '../../features/projects/data/exam_grades_store.dart';
import '../../features/projects/domain/focus_session.dart';
import '../../features/projects/domain/project.dart';
import '../../features/subscriptions/data/local_subscription_store.dart';
import '../../features/tasks/domain/task.dart';
import '../logger/app_logger.dart';
import '../result/result.dart';
import 'local_focus_session_database.dart';
import 'local_project_database.dart';
import 'local_task_database.dart';

/// Structured summary of what a backup contains / what a restore applied.
@immutable
class BackupRestoreSummary {
  const BackupRestoreSummary({
    required this.schemaVersion,
    required this.tasksCount,
    required this.projectsCount,
    required this.focusSessionsCount,
    required this.examGradesCount,
    required this.alarmRemindersCount,
    required this.hasEnergyPreferences,
    required this.hasNotificationPreferences,
  });

  final int schemaVersion;
  final int tasksCount;
  final int projectsCount;
  final int focusSessionsCount;
  final int examGradesCount;
  final int alarmRemindersCount;
  final bool hasEnergyPreferences;
  final bool hasNotificationPreferences;
}

class _ParsedBackupPayload {
  const _ParsedBackupPayload({
    required this.schemaVersion,
    required this.projects,
    required this.tasks,
    required this.focusSessions,
    required this.examGrades,
    required this.energyPreferences,
    required this.notificationPreferences,
    required this.alarmReminders,
    required this.alarmDefaultMode,
    required this.taskAlertModes,
  });

  final int schemaVersion;
  final List<({Project project, List<Map<String, dynamic>> phases})> projects;
  final List<Task> tasks;
  final List<FocusSession> focusSessions;
  final List<ExamGradeEntry> examGrades;
  final UserEnergyPreferences? energyPreferences;
  final NotificationPreferences? notificationPreferences;
  final List<AlarmReminderItem> alarmReminders;
  final String? alarmDefaultMode;
  final Map<String, String> taskAlertModes;

  BackupRestoreSummary toSummary() => BackupRestoreSummary(
        schemaVersion: schemaVersion,
        tasksCount: tasks.length,
        projectsCount: projects.length,
        focusSessionsCount: focusSessions.length,
        examGradesCount: examGrades.length,
        alarmRemindersCount: alarmReminders.length,
        hasEnergyPreferences: energyPreferences != null,
        hasNotificationPreferences: notificationPreferences != null,
      );
}

class _UserWorkspaceSnapshot {
  const _UserWorkspaceSnapshot({
    required this.tasks,
    required this.projects,
    required this.focusSessions,
    required this.examGrades,
    required this.energyPrefs,
    required this.notifPrefs,
    required this.alarmState,
  });

  final List<Task> tasks;
  final List<({Project project, List<Map<String, dynamic>> phases})> projects;
  final List<FocusSession> focusSessions;
  final List<ExamGradeEntry> examGrades;
  final UserEnergyPreferences energyPrefs;
  final NotificationPreferences notifPrefs;
  final AlarmReminderState alarmState;
}

/// User-controlled JSON backup for local-first Handelha workspaces.
///
/// Exports and restores all workspace entities symmetrically:
/// tasks, projects (including phases), focus sessions, exam grades,
/// energy preferences, notification preferences, and alarm/reminder items.
///
/// Restore is pre-validated, idempotent across repeated imports, and atomic
/// via pre-write snapshot + rollback on any partial failure. Subscription
/// metadata is exported read-only and never blindly activates unpaid tiers on import.
class LocalBackupService {
  LocalBackupService._();
  static final instance = LocalBackupService._();

  static const _tag = 'LocalBackup';
  static const schemaVersion = 2;
  static const supportedSchemas = {1, 2};

  Future<Result<String>> exportForUser(String userId) async {
    final tasksResult = await LocalTaskDatabase.instance.getTasksForUser(userId);
    final sessionsResult =
        await LocalFocusSessionDatabase.instance.forUser(userId);
    final projectsResult =
        await LocalProjectDatabase.instance.exportRecordsForUser(userId);
    if (tasksResult is Failure<List<Task>>) return Failure(tasksResult.failure);
    if (sessionsResult is Failure<List<FocusSession>>) {
      return Failure(sessionsResult.failure);
    }
    if (projectsResult
        is Failure<
            List<({Project project, List<Map<String, dynamic>> phases})>>) {
      return Failure(projectsResult.failure);
    }

    final tasks = (tasksResult as Success<List<Task>>).data;
    final sessions = (sessionsResult as Success<List<FocusSession>>).data;
    final projectRecords = (projectsResult
            as Success<
                List<({Project project, List<Map<String, dynamic>> phases})>>)
        .data;
    final subscription = await LocalSubscriptionStore.loadForUser(userId);
    final grades = await ExamGradesStore.load(userId);
    final energyPrefs = await UserEnergyPreferencesStore.load(userId);
    final notifPrefs = await LocalNotificationPreferences.load(userId);
    final alarmState = await AlarmReminderStore.load(userId);

    return Success(
      jsonEncode({
        'schema': schemaVersion,
        'product': 'handelha',
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'userId': userId,
        'subscription': subscription.toJson(),
        'tasks': tasks.map(_taskToJson).toList(),
        'projects': projectRecords
            .map(
              (entry) => _projectToJson(entry.project, phases: entry.phases),
            )
            .toList(),
        'focusSessions': sessions.map(_sessionToJson).toList(),
        'examGrades': grades.map((g) => g.toJson()).toList(),
        'energyPreferences': energyPrefs.toJson(),
        'notificationPreferences': notifPrefs.toJson(),
        'alarmReminders': {
          'defaultAlertMode': alarmState.defaultAlertMode,
          'items': alarmState.items.map((item) => item.toJson()).toList(),
          'taskAlertModes': alarmState.taskAlertModes,
        },
      }),
    );
  }

  /// Validates and parses [backupJson] without mutating any local store.
  Result<BackupRestoreSummary> validateBackup({
    required String userId,
    required String backupJson,
  }) {
    final parsed = _parseAndValidate(userId: userId, backupJson: backupJson);
    return switch (parsed) {
      Failure<_ParsedBackupPayload>(failure: final f) => Failure(f),
      Success<_ParsedBackupPayload>(data: final data) =>
        Success(data.toSummary()),
    };
  }

  /// Restores all exported workspace entities idempotently with rollback on error.
  Future<Result<BackupRestoreSummary>> restoreForUser({
    required String userId,
    required String backupJson,
    @visibleForTesting Future<void> Function(String stage)? onStageForTesting,
  }) async {
    final parsedResult = _parseAndValidate(
      userId: userId,
      backupJson: backupJson,
    );
    if (parsedResult is Failure<_ParsedBackupPayload>) {
      return Failure(parsedResult.failure);
    }
    final payload = (parsedResult as Success<_ParsedBackupPayload>).data;

    final snapshotResult = await _captureSnapshot(userId);
    if (snapshotResult is Failure<_UserWorkspaceSnapshot>) {
      return Failure(snapshotResult.failure);
    }
    final snapshot = (snapshotResult as Success<_UserWorkspaceSnapshot>).data;

    try {
      await onStageForTesting?.call('projects');
      final projRes =
          await LocalProjectDatabase.instance.upsertRecords(payload.projects);
      if (projRes is Failure<void>) {
        throw StateError(projRes.failure.message);
      }

      await onStageForTesting?.call('tasks');
      final taskRes = await LocalTaskDatabase.instance.upsertTasks(payload.tasks);
      if (taskRes is Failure<List<Task>>) {
        throw StateError(taskRes.failure.message);
      }

      await onStageForTesting?.call('focusSessions');
      final sessRes = await LocalFocusSessionDatabase.instance
          .upsertSessions(payload.focusSessions);
      if (sessRes is Failure<void>) {
        throw StateError(sessRes.failure.message);
      }

      await onStageForTesting?.call('examGrades');
      if (payload.examGrades.isNotEmpty) {
        await ExamGradesStore.upsertAll(userId, payload.examGrades);
      }

      await onStageForTesting?.call('energyPreferences');
      if (payload.energyPreferences != null) {
        await UserEnergyPreferencesStore.save(
          userId,
          payload.energyPreferences!,
        );
      }

      await onStageForTesting?.call('notificationPreferences');
      if (payload.notificationPreferences != null) {
        await LocalNotificationPreferences.save(
          userId,
          payload.notificationPreferences!,
        );
      }

      await onStageForTesting?.call('alarmReminders');
      if (payload.alarmReminders.isNotEmpty ||
          payload.taskAlertModes.isNotEmpty ||
          payload.alarmDefaultMode != null) {
        final mergedItemsById = <String, AlarmReminderItem>{
          for (final existing in snapshot.alarmState.items)
            existing.id: existing,
        };
        for (final incoming in payload.alarmReminders) {
          mergedItemsById[incoming.id] = incoming;
        }
        final mergedItems = mergedItemsById.values.toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        final mergedModes = <String, String>{
          ...snapshot.alarmState.taskAlertModes,
          ...payload.taskAlertModes,
        };
        final nextAlarmState = snapshot.alarmState.copyWith(
          defaultAlertMode:
              payload.alarmDefaultMode ?? snapshot.alarmState.defaultAlertMode,
          items: mergedItems,
          taskAlertModes: mergedModes,
        );
        await AlarmReminderStore.save(userId, nextAlarmState);
      }

      return Success(payload.toSummary());
    } catch (error, st) {
      AppLogger.error(
        'Backup restore failed; rolling back to pre-restore snapshot',
        tag: _tag,
        error: error,
        stackTrace: st,
      );
      await _rollbackSnapshot(userId, snapshot);
      return const Failure(
        LocalDatabaseFailure(
          'فشلت استعادة النسخة الاحتياطية وتم التراجع بالكامل لحماية بياناتك الحالية.',
        ),
      );
    }
  }

  /// Backwards-compatible wrapper returning the number of tasks restored while
  /// still performing the full atomic round-trip restore for all entities.
  Future<Result<int>> importTasksForUser({
    required String userId,
    required String backupJson,
  }) async {
    final res = await restoreForUser(userId: userId, backupJson: backupJson);
    return switch (res) {
      Failure<BackupRestoreSummary>(failure: final f) => Failure(f),
      Success<BackupRestoreSummary>(data: final summary) =>
        Success(summary.tasksCount),
    };
  }

  Future<Result<_UserWorkspaceSnapshot>> _captureSnapshot(String userId) async {
    final tasksRes = await LocalTaskDatabase.instance.getTasksForUser(userId);
    final projectsRes =
        await LocalProjectDatabase.instance.exportRecordsForUser(userId);
    final sessionsRes = await LocalFocusSessionDatabase.instance.forUser(userId);
    if (tasksRes is Failure<List<Task>>) return Failure(tasksRes.failure);
    if (projectsRes
        is Failure<
            List<({Project project, List<Map<String, dynamic>> phases})>>) {
      return Failure(projectsRes.failure);
    }
    if (sessionsRes is Failure<List<FocusSession>>) {
      return Failure(sessionsRes.failure);
    }
    return Success(
      _UserWorkspaceSnapshot(
        tasks: (tasksRes as Success<List<Task>>).data,
        projects: (projectsRes
                as Success<
                    List<({Project project, List<Map<String, dynamic>> phases})>>)
            .data,
        focusSessions: (sessionsRes as Success<List<FocusSession>>).data,
        examGrades: await ExamGradesStore.load(userId),
        energyPrefs: await UserEnergyPreferencesStore.load(userId),
        notifPrefs: await LocalNotificationPreferences.load(userId),
        alarmState: await AlarmReminderStore.load(userId),
      ),
    );
  }

  Future<void> _rollbackSnapshot(
    String userId,
    _UserWorkspaceSnapshot snapshot,
  ) async {
    try {
      await LocalProjectDatabase.instance
          .replaceAllForUser(userId, snapshot.projects);
      await LocalTaskDatabase.instance
          .replaceAllForUser(userId, snapshot.tasks);
      await LocalFocusSessionDatabase.instance
          .replaceAllForUser(userId, snapshot.focusSessions);
      await ExamGradesStore.replaceAll(userId, snapshot.examGrades);
      await UserEnergyPreferencesStore.save(userId, snapshot.energyPrefs);
      await LocalNotificationPreferences.save(userId, snapshot.notifPrefs);
      await AlarmReminderStore.save(userId, snapshot.alarmState);
    } catch (e, st) {
      AppLogger.error(
        'Rollback encountered an error',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
    }
  }

  Result<_ParsedBackupPayload> _parseAndValidate({
    required String userId,
    required String backupJson,
  }) {
    try {
      final decoded = jsonDecode(backupJson);
      if (decoded is! Map) {
        return const Failure(
          ValidationFailure('ملف النسخة الاحتياطية تالف أو غير صالح.'),
        );
      }
      final root = decoded.cast<String, dynamic>();
      final schema = (root['schema'] as num?)?.toInt();
      if (root['product'] != 'handelha' ||
          schema == null ||
          !supportedSchemas.contains(schema)) {
        return const Failure(
          ValidationFailure('ملف النسخة الاحتياطية غير مدعوم أو قديم.'),
        );
      }

      final projects =
          <({Project project, List<Map<String, dynamic>> phases})>[];
      final rawProjects = root['projects'];
      if (rawProjects != null) {
        if (rawProjects is! List) {
          return const Failure(
            ValidationFailure('بيانات المشاريع في النسخة الاحتياطية غير صالحة.'),
          );
        }
        for (final item in rawProjects) {
          if (item is! Map) {
            return const Failure(
              ValidationFailure('أحد المشاريع في النسخة الاحتياطية تالف.'),
            );
          }
          final map = item.cast<String, dynamic>();
          final project = _projectFromJson(map, userId);
          final rawPhases = map['phases'];
          final phases = <Map<String, dynamic>>[];
          if (rawPhases != null) {
            if (rawPhases is! List) {
              return const Failure(
                ValidationFailure('مراحل المشروع في النسخة الاحتياطية غير صالحة.'),
              );
            }
            for (final ph in rawPhases) {
              if (ph is! Map) {
                return const Failure(
                  ValidationFailure('مرحلة مشروع غير صالحة في النسخة الاحتياطية.'),
                );
              }
              phases.add(ph.cast<String, dynamic>());
            }
          }
          projects.add((project: project, phases: phases));
        }
      }

      final tasks = <Task>[];
      final rawTasks = root['tasks'];
      if (rawTasks != null) {
        if (rawTasks is! List) {
          return const Failure(
            ValidationFailure('بيانات المهام في النسخة الاحتياطية غير صالحة.'),
          );
        }
        for (final item in rawTasks) {
          if (item is! Map) {
            return const Failure(
              ValidationFailure('إحدى المهام في النسخة الاحتياطية تالفة.'),
            );
          }
          tasks.add(_taskFromJson(item.cast<String, dynamic>(), userId));
        }
      }

      final sessions = <FocusSession>[];
      final rawSessions = root['focusSessions'];
      if (rawSessions != null) {
        if (rawSessions is! List) {
          return const Failure(
            ValidationFailure('بيانات جلسات التركيز غير صالحة.'),
          );
        }
        for (final item in rawSessions) {
          if (item is! Map) {
            return const Failure(
              ValidationFailure('إحدى جلسات التركيز تالفة في النسخة الاحتياطية.'),
            );
          }
          sessions.add(_sessionFromJson(item.cast<String, dynamic>(), userId));
        }
      }

      final grades = <ExamGradeEntry>[];
      final rawGrades = root['examGrades'];
      if (rawGrades != null) {
        if (rawGrades is! List) {
          return const Failure(
            ValidationFailure('بيانات درجات الامتحانات غير صالحة.'),
          );
        }
        for (final item in rawGrades) {
          if (item is! Map) {
            return const Failure(
              ValidationFailure('إحدى درجات الامتحانات تالفة في النسخة الاحتياطية.'),
            );
          }
          final map = item.cast<String, dynamic>();
          final id = (map['id'] as String?)?.trim() ?? '';
          final examTitle = (map['examTitle'] as String?)?.trim() ?? '';
          if (id.isEmpty || examTitle.isEmpty) {
            return const Failure(
              ValidationFailure('بيانات درجة امتحان ناقصة في النسخة الاحتياطية.'),
            );
          }
          grades.add(ExamGradeEntry.fromJson(map));
        }
      }

      UserEnergyPreferences? energyPrefs;
      final rawEnergy = root['energyPreferences'];
      if (rawEnergy != null) {
        if (rawEnergy is! Map) {
          return const Failure(
            ValidationFailure('تفضيلات الطاقة في النسخة الاحتياطية غير صالحة.'),
          );
        }
        energyPrefs =
            UserEnergyPreferences.fromJson(rawEnergy.cast<String, dynamic>());
      }

      NotificationPreferences? notifPrefs;
      final rawNotif = root['notificationPreferences'];
      if (rawNotif != null) {
        if (rawNotif is! Map) {
          return const Failure(
            ValidationFailure('تفضيلات الإشعارات في النسخة الاحتياطية غير صالحة.'),
          );
        }
        notifPrefs = NotificationPreferences.fromJson(
          rawNotif.cast<String, Object?>(),
        );
      }

      final alarmItems = <AlarmReminderItem>[];
      String? alarmDefaultMode;
      final taskAlertModes = <String, String>{};
      final rawAlarms = root['alarmReminders'];
      if (rawAlarms != null) {
        if (rawAlarms is! Map) {
          return const Failure(
            ValidationFailure('بيانات المنبهات في النسخة الاحتياطية غير صالحة.'),
          );
        }
        final alarmMap = rawAlarms.cast<String, dynamic>();
        if (alarmMap['defaultAlertMode'] is String) {
          alarmDefaultMode = alarmMap['defaultAlertMode'] as String;
        }
        final rawItems = alarmMap['items'];
        if (rawItems != null) {
          if (rawItems is! List) {
            return const Failure(
              ValidationFailure('قائمة المنبهات في النسخة الاحتياطية غير صالحة.'),
            );
          }
          for (final item in rawItems) {
            if (item is! Map) {
              return const Failure(
                ValidationFailure('أحد المنبهات تالف في النسخة الاحتياطية.'),
              );
            }
            final m = item.cast<String, dynamic>();
            final id = (m['id'] as String?)?.trim() ?? '';
            final scheduledStr = (m['scheduledAt'] as String?)?.trim() ?? '';
            if (id.isEmpty || DateTime.tryParse(scheduledStr) == null) {
              return const Failure(
                ValidationFailure('بيانات منبه ناقصة أو تالفة في النسخة الاحتياطية.'),
              );
            }
            alarmItems.add(AlarmReminderItem.fromJson(m));
          }
        }
        final rawModes = alarmMap['taskAlertModes'];
        if (rawModes is Map) {
          for (final entry in rawModes.entries) {
            taskAlertModes[entry.key.toString()] = entry.value.toString();
          }
        }
      }

      return Success(
        _ParsedBackupPayload(
          schemaVersion: schema,
          projects: projects,
          tasks: tasks,
          focusSessions: sessions,
          examGrades: grades,
          energyPreferences: energyPrefs,
          notificationPreferences: notifPrefs,
          alarmReminders: alarmItems,
          alarmDefaultMode: alarmDefaultMode,
          taskAlertModes: taskAlertModes,
        ),
      );
    } catch (_) {
      return const Failure(
        ValidationFailure('ملف النسخة الاحتياطية تالف أو غير صالح.'),
      );
    }
  }

  Map<String, dynamic> _taskToJson(Task t) => {
        'id': t.id,
        'projectId': t.projectId,
        'parentTaskId': t.parentTaskId,
        'phaseId': t.phaseId,
        'dependsOnTaskIds': t.dependsOnTaskIds,
        'durationUncertainty': t.durationUncertainty,
        'title': t.title,
        'description': t.description,
        'status': t.status.name,
        'priority': t.priority.name,
        'dueAt': t.dueAt?.toIso8601String(),
        'scheduledStartAt': t.scheduledStartAt?.toIso8601String(),
        'estimatedDurationMinutes': t.estimatedDurationMinutes,
        'actualDurationMinutes': t.actualDurationMinutes,
        'energyLevel': t.energyLevel.name,
        'source': t.source.name,
        'aiConfidence': t.aiConfidence,
        'createdAt': t.createdAt.toIso8601String(),
        'updatedAt': t.updatedAt.toIso8601String(),
        'version': t.version,
        'syncStatus': t.syncStatus.name,
        'recurrence': t.recurrence.name,
        'deletedAt': t.deletedAt?.toIso8601String(),
      };

  Task _taskFromJson(Map<String, dynamic> j, String userId) {
    final id = (j['id'] as String).trim();
    final title = (j['title'] as String).trim();
    if (id.isEmpty || title.isEmpty) {
      throw const FormatException('Task missing required id or title');
    }
    return Task(
      id: id,
      userId: userId,
      projectId: j['projectId'] as String?,
      parentTaskId: j['parentTaskId'] as String?,
      phaseId: j['phaseId'] as String?,
      dependsOnTaskIds:
          (j['dependsOnTaskIds'] as List<dynamic>? ?? const []).cast<String>(),
      durationUncertainty: j['durationUncertainty'] as String?,
      title: title,
      description: j['description'] as String?,
      status: TaskStatus.values.byName(j['status'] as String),
      priority: TaskPriority.values.byName(j['priority'] as String),
      dueAt: _date(j['dueAt']),
      scheduledStartAt: _date(j['scheduledStartAt']),
      estimatedDurationMinutes: (j['estimatedDurationMinutes'] as num?)?.toInt(),
      actualDurationMinutes: (j['actualDurationMinutes'] as num?)?.toInt(),
      energyLevel: EnergyLevel.values.byName(j['energyLevel'] as String),
      source: TaskSource.values.firstWhere(
        (s) => s.name == j['source'],
        orElse: () => TaskSource.import,
      ),
      aiConfidence: (j['aiConfidence'] as num?)?.toDouble(),
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      version: (j['version'] as num?)?.toInt() ?? 1,
      syncStatus: SyncStatus.pending,
      recurrence: TaskRecurrence.values.byName(
        (j['recurrence'] as String?) ?? 'none',
      ),
      deletedAt: _date(j['deletedAt']),
    );
  }

  DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);

  Map<String, dynamic> _sessionToJson(FocusSession s) => {
        'id': s.id,
        'taskId': s.taskId,
        'taskTitle': s.taskTitle,
        'startedAt': s.startedAt.toIso8601String(),
        'endedAt': s.endedAt.toIso8601String(),
        'elapsedMinutes': s.elapsedMinutes,
        'completed': s.completed,
      };

  FocusSession _sessionFromJson(Map<String, dynamic> j, String userId) {
    final id = (j['id'] as String).trim();
    final taskTitle = (j['taskTitle'] as String).trim();
    final startedAt = DateTime.parse(j['startedAt'] as String);
    final endedAt = DateTime.parse(j['endedAt'] as String);
    final elapsedMinutes = (j['elapsedMinutes'] as num).toInt();
    if (id.isEmpty || elapsedMinutes < 0 || endedAt.isBefore(startedAt)) {
      throw const FormatException('Invalid focus session in backup');
    }
    return FocusSession(
      id: id,
      userId: userId,
      taskId: j['taskId'] as String?,
      taskTitle: taskTitle,
      startedAt: startedAt,
      endedAt: endedAt,
      elapsedMinutes: elapsedMinutes,
      completed: j['completed'] as bool,
    );
  }

  Map<String, dynamic> _projectToJson(
    Project p, {
    List<Map<String, dynamic>> phases = const [],
  }) =>
      {
        'id': p.id,
        'title': p.title,
        'description': p.description,
        'status': p.status.name,
        'progressPercent': p.progressPercent,
        'nextStepTitle': p.nextStepTitle,
        'targetDate': p.targetDate?.toIso8601String(),
        'taskIds': p.taskIds,
        'colorValue': p.colorValue,
        'createdAt': p.createdAt.toIso8601String(),
        'updatedAt': p.updatedAt.toIso8601String(),
        'phases': phases,
      };

  Project _projectFromJson(Map<String, dynamic> j, String userId) {
    final id = (j['id'] as String).trim();
    final title = (j['title'] as String).trim();
    if (id.isEmpty || title.isEmpty) {
      throw const FormatException('Project missing required id or title');
    }
    return Project(
      id: id,
      userId: userId,
      title: title,
      description: j['description'] as String?,
      status: ProjectStatus.values.byName((j['status'] as String?) ?? 'active'),
      progressPercent: (j['progressPercent'] as num?)?.toDouble() ?? 0.0,
      nextStepTitle: j['nextStepTitle'] as String?,
      targetDate: _date(j['targetDate']),
      taskIds: (j['taskIds'] as List<dynamic>? ?? const []).cast<String>(),
      colorValue: (j['colorValue'] as num?)?.toInt() ?? 0xFF007067,
      createdAt: _date(j['createdAt']) ?? DateTime.now(),
      updatedAt: _date(j['updatedAt']) ?? DateTime.now(),
    );
  }
}

import 'dart:convert';
import 'local_focus_session_database.dart';
import 'local_project_database.dart';
import 'local_task_database.dart';
import '../../features/assistant/data/user_energy_preferences.dart';
import '../../features/notifications/notification_preferences.dart';
import '../../features/projects/data/exam_grades_store.dart';
import '../../features/projects/domain/focus_session.dart';
import '../../features/projects/domain/project.dart';
import '../../features/subscriptions/data/local_subscription_store.dart';
import '../../features/tasks/domain/task.dart';
import '../result/result.dart';

/// User-controlled JSON backup for the local-first MVP.
/// Exports and restores all user workspace data (tasks, projects, focus
/// sessions, exam grades, energy & notification preferences, and subscription).
class LocalBackupService {
  LocalBackupService._();
  static final instance = LocalBackupService._();
  static const schemaVersion = 1;

  Future<Result<String>> exportForUser(String userId) async {
    final tasksResult = await LocalTaskDatabase.instance.getTasksForUser(userId);
    final sessionsResult = await LocalFocusSessionDatabase.instance.forUser(userId);
    final projectsResult = await LocalProjectDatabase.instance.forUser(userId);
    if (tasksResult is Failure<List<Task>>) return Failure(tasksResult.failure);
    if (sessionsResult is Failure<List<FocusSession>>) return Failure(sessionsResult.failure);
    final tasks = (tasksResult as Success<List<Task>>).data;
    final sessions = (sessionsResult as Success<List<FocusSession>>).data;
    final projects = projectsResult is Success<List<Project>>
        ? projectsResult.data
        : const <Project>[];
    final subscription = await LocalSubscriptionStore.loadForUser(userId);
    final grades = await ExamGradesStore.load(userId);
    final energyPrefs = await UserEnergyPreferencesStore.load(userId);
    final notifPrefs = await LocalNotificationPreferences.load(userId);
    return Success(jsonEncode({
      'schema': schemaVersion,
      'product': 'handelha',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'userId': userId,
      'subscription': subscription.toJson(),
      'tasks': tasks.map(_taskToJson).toList(),
      'projects': projects.map(_projectToJson).toList(),
      'focusSessions': sessions.map(_sessionToJson).toList(),
      'examGrades': grades.map((g) => g.toJson()).toList(),
      'energyPreferences': energyPrefs.toJson(),
      'notificationPreferences': {
        'enabled': notifPrefs.enabled,
        'tone': notifPrefs.tone.name,
        'quietHoursStartMinutes': notifPrefs.quietHoursStartMinutes,
        'quietHoursEndMinutes': notifPrefs.quietHoursEndMinutes,
      },
    }));
  }

  Future<Result<int>> importTasksForUser({required String userId, required String backupJson}) async {
    try {
      final root = jsonDecode(backupJson) as Map<String, dynamic>;
      if (root['product'] != 'handelha' || root['schema'] != schemaVersion) {
        return const Failure(ValidationFailure('ملف النسخة الاحتياطية غير مدعوم أو قديم.'));
      }
      final rawProjects = (root['projects'] as List<dynamic>? ?? const []);
      for (final item in rawProjects) {
        if (item is Map) {
          final p = _projectFromJson(item.cast<String, dynamic>(), userId);
          await LocalProjectDatabase.instance.save(p);
        }
      }
      final rawTasks = (root['tasks'] as List<dynamic>? ?? const []);
      final tasks = rawTasks.map((item) => _taskFromJson((item as Map).cast<String, dynamic>(), userId)).toList();
      if (tasks.isEmpty) return const Success(0);
      final result = await LocalTaskDatabase.instance.createApprovedTasks(tasks);
      if (result is Failure<List<Task>>) return Failure(result.failure);
      return Success(tasks.length);
    } catch (_) {
      return const Failure(ValidationFailure('ملف النسخة الاحتياطية تالف أو غير صالح.'));
    }
  }

  Map<String, dynamic> _taskToJson(Task t) => {
    'id': t.id, 'projectId': t.projectId, 'parentTaskId': t.parentTaskId, 'phaseId': t.phaseId,
    'dependsOnTaskIds': t.dependsOnTaskIds, 'durationUncertainty': t.durationUncertainty,
    'title': t.title, 'description': t.description, 'status': t.status.name, 'priority': t.priority.name,
    'dueAt': t.dueAt?.toIso8601String(), 'scheduledStartAt': t.scheduledStartAt?.toIso8601String(),
    'estimatedDurationMinutes': t.estimatedDurationMinutes, 'actualDurationMinutes': t.actualDurationMinutes,
    'energyLevel': t.energyLevel.name, 'source': t.source.name, 'aiConfidence': t.aiConfidence,
    'createdAt': t.createdAt.toIso8601String(), 'updatedAt': t.updatedAt.toIso8601String(),
    'version': t.version, 'syncStatus': t.syncStatus.name, 'recurrence': t.recurrence.name, 'deletedAt': t.deletedAt?.toIso8601String(),
  };

  Task _taskFromJson(Map<String, dynamic> j, String userId) => Task(
    id: j['id'] as String, userId: userId, projectId: j['projectId'] as String?, parentTaskId: j['parentTaskId'] as String?,
    phaseId: j['phaseId'] as String?, dependsOnTaskIds: (j['dependsOnTaskIds'] as List<dynamic>? ?? const []).cast<String>(),
    durationUncertainty: j['durationUncertainty'] as String?, title: j['title'] as String,
    description: j['description'] as String?, status: TaskStatus.values.byName(j['status'] as String),
    priority: TaskPriority.values.byName(j['priority'] as String), dueAt: _date(j['dueAt']),
    scheduledStartAt: _date(j['scheduledStartAt']), estimatedDurationMinutes: (j['estimatedDurationMinutes'] as num?)?.toInt(),
    actualDurationMinutes: (j['actualDurationMinutes'] as num?)?.toInt(), energyLevel: EnergyLevel.values.byName(j['energyLevel'] as String),
    source: TaskSource.import, aiConfidence: (j['aiConfidence'] as num?)?.toDouble(), createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String), version: (j['version'] as num?)?.toInt() ?? 1, syncStatus: SyncStatus.pending,
    recurrence: TaskRecurrence.values.byName((j['recurrence'] as String?) ?? 'none'),
    deletedAt: _date(j['deletedAt']),
  );

  DateTime? _date(dynamic value) => value == null ? null : DateTime.parse(value as String);
  Map<String, dynamic> _sessionToJson(FocusSession s) => {
    'id': s.id, 'taskId': s.taskId, 'taskTitle': s.taskTitle, 'startedAt': s.startedAt.toIso8601String(),
    'endedAt': s.endedAt.toIso8601String(), 'elapsedMinutes': s.elapsedMinutes, 'completed': s.completed,
  };
  Map<String, dynamic> _projectToJson(Project p) => {
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
  };
  Project _projectFromJson(Map<String, dynamic> j, String userId) => Project(
    id: j['id'] as String,
    userId: userId,
    title: j['title'] as String,
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

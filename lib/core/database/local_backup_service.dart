import 'dart:convert';
import 'local_focus_session_database.dart';
import 'local_task_database.dart';
import '../../features/projects/domain/focus_session.dart';
import '../../features/subscriptions/data/local_subscription_store.dart';
import '../../features/tasks/domain/task.dart';
import '../result/result.dart';

/// User-controlled JSON backup for the local-first MVP.
/// It is deliberately explicit about ownership and schema; encryption of the
/// exported file should be added before exposing file sharing in production.
class LocalBackupService {
  LocalBackupService._();
  static final instance = LocalBackupService._();
  static const schemaVersion = 1;

  Future<Result<String>> exportForUser(String userId) async {
    final tasksResult = await LocalTaskDatabase.instance.getTasksForUser(userId);
    final sessionsResult = await LocalFocusSessionDatabase.instance.forUser(userId);
    if (tasksResult is Failure<List<Task>>) return Failure(tasksResult.failure);
    if (sessionsResult is Failure<List<FocusSession>>) return Failure(sessionsResult.failure);
    final tasks = (tasksResult as Success<List<Task>>).data;
    final sessions = (sessionsResult as Success<List<FocusSession>>).data;
    final subscription = await LocalSubscriptionStore.loadForUser(userId);
    return Success(jsonEncode({
      'schema': schemaVersion,
      'product': 'handelha',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'userId': userId,
      'subscription': subscription.toJson(),
      'tasks': tasks.map(_taskToJson).toList(),
      'focusSessions': sessions.map(_sessionToJson).toList(),
    }));
  }

  Future<Result<int>> importTasksForUser({required String userId, required String backupJson}) async {
    try {
      final root = jsonDecode(backupJson) as Map<String, dynamic>;
      if (root['product'] != 'handelha' || root['schema'] != schemaVersion) {
        return const Failure(ValidationFailure('ملف النسخة الاحتياطية غير مدعوم أو قديم.'));
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
}

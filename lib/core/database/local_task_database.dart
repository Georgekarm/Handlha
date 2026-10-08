import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../features/tasks/domain/task.dart';
import '../result/result.dart';
import '../logger/app_logger.dart';

/// Lightweight local task store backed by SharedPreferences (JSON).
/// This is intentionally simple for Phase 1 (Offline-First foundation).
/// Replace with SQLite/Drift for production scale.
///
/// Design decisions:
/// - UUIDs for offline-safe IDs
/// - version + updatedAt for conflict detection
/// - soft delete via deletedAt
/// - SyncStatus tracking for future sync engine
class LocalTaskDatabase {
  LocalTaskDatabase._();
  static final LocalTaskDatabase instance = LocalTaskDatabase._();

  static const _tag = 'LocalTaskDB';
  static const _key = 'local_tasks_v1';
  static const _uuid = Uuid();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  Future<Result<List<Task>>> getTasksForUser(String userId) async {
    try {
      final store = await _store;
      final raw = store.getString(_key);
      if (raw == null) return const Success([]);

      final List<dynamic> json = jsonDecode(raw) as List<dynamic>;
      final tasks = json
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .where((t) => t.userId == userId && t.deletedAt == null)
          .toList();

      return Success(tasks);
    } catch (e, st) {
      AppLogger.error(
        'getTasksForUser failed',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      return const Failure(LocalDatabaseFailure());
    }
  }

  Future<Result<List<Task>>> getTasksForToday(String userId) async {
    final result = await getTasksForUser(userId);
    if (result is Failure<List<Task>>) return result;
    final tasks = (result as Success<List<Task>>).data;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final todayTasks = tasks.where((t) {
      if (t.status == TaskStatus.cancelled) return false;
      if (t.scheduledStartAt != null) {
        return t.scheduledStartAt!.isAfter(todayStart) &&
            t.scheduledStartAt!.isBefore(todayEnd);
      }
      if (t.dueAt != null) {
        return t.dueAt!.isBefore(todayEnd);
      }
      // Include inbox items with no date in today's view
      return t.status == TaskStatus.inbox || t.status == TaskStatus.inProgress;
    }).toList();

    // Sort: urgent > high > medium > low, then by time
    todayTasks.sort((a, b) {
      final pa = _priorityScore(a.priority);
      final pb = _priorityScore(b.priority);
      if (pa != pb) return pb.compareTo(pa);
      return (a.scheduledStartAt ?? a.dueAt ?? a.createdAt).compareTo(
        b.scheduledStartAt ?? b.dueAt ?? b.createdAt,
      );
    });

    return Success(todayTasks);
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  Future<Result<Task>> createTask({
    required String userId,
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueAt,
    DateTime? scheduledStartAt,
    int? estimatedDurationMinutes,
    TaskStatus status = TaskStatus.inbox,
    EnergyLevel energyLevel = EnergyLevel.medium,
    TaskSource source = TaskSource.manual,
    String? projectId,
  }) async {
    try {
      final now = DateTime.now();
      final task = Task(
        id: _uuid.v4(),
        userId: userId,
        projectId: projectId,
        title: title.trim(),
        description: description?.trim(),
        status: status,
        priority: priority,
        dueAt: dueAt,
        scheduledStartAt: scheduledStartAt,
        estimatedDurationMinutes: estimatedDurationMinutes,
        energyLevel: energyLevel,
        source: source,
        createdAt: now,
        updatedAt: now,
        version: 1,
        syncStatus: SyncStatus.pending,
      );

      await _saveTask(task);
      AppLogger.debug('Task created: ${task.id}', tag: _tag);
      return Success(task);
    } catch (e, st) {
      AppLogger.error('createTask failed', tag: _tag, error: e, stackTrace: st);
      return const Failure(LocalDatabaseFailure());
    }
  }

  Future<Result<Task>> updateTask(Task updated) async {
    try {
      final store = await _store;
      final allTasks = await _readAll();
      final idx = allTasks.indexWhere((t) => t.id == updated.id);
      if (idx == -1) {
        return const Failure(LocalDatabaseFailure('المهمة غير موجودة.'));
      }

      final newTask = updated.copyWith(
        updatedAt: DateTime.now(),
        version: updated.version + 1,
        syncStatus: SyncStatus.pending,
      );
      allTasks[idx] = newTask;
      await _writeAll(store, allTasks);
      return Success(newTask);
    } catch (e, st) {
      AppLogger.error('updateTask failed', tag: _tag, error: e, stackTrace: st);
      return const Failure(LocalDatabaseFailure());
    }
  }

  Future<Result<Task>> completeTask(String taskId) async {
    final allTasks = await _readAll();
    final idx = allTasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) {
      return const Failure(LocalDatabaseFailure('المهمة غير موجودة.'));
    }

    return updateTask(allTasks[idx].copyWith(status: TaskStatus.completed));
  }

  Future<Result<void>> deleteTask(String taskId) async {
    try {
      final allTasks = await _readAll();
      final idx = allTasks.indexWhere((t) => t.id == taskId);
      if (idx == -1) return const Success(null);

      // Soft delete — keeps record for sync engine
      allTasks[idx] = allTasks[idx].copyWith(
        deletedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      );
      final store = await _store;
      await _writeAll(store, allTasks);
      return const Success(null);
    } catch (e, st) {
      AppLogger.error('deleteTask failed', tag: _tag, error: e, stackTrace: st);
      return const Failure(LocalDatabaseFailure());
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _saveTask(Task task) async {
    final allTasks = await _readAll();
    final idx = allTasks.indexWhere((t) => t.id == task.id);
    if (idx == -1) {
      allTasks.add(task);
    } else {
      allTasks[idx] = task;
    }
    final store = await _store;
    await _writeAll(store, allTasks);
  }

  Future<List<Task>> _readAll() async {
    try {
      final store = await _store;
      final raw = store.getString(_key);
      if (raw == null) return [];
      final List<dynamic> json = jsonDecode(raw) as List<dynamic>;
      return json.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      AppLogger.error('_readAll failed', tag: _tag, error: e);
      return [];
    }
  }

  Future<void> _writeAll(SharedPreferences store, List<Task> tasks) async {
    final json = tasks.map(_toJson).toList();
    await store.setString(_key, jsonEncode(json));
  }

  int _priorityScore(TaskPriority p) {
    return switch (p) {
      TaskPriority.urgent => 4,
      TaskPriority.high => 3,
      TaskPriority.medium => 2,
      TaskPriority.low => 1,
    };
  }

  // ---------------------------------------------------------------------------
  // Serialization — isolated here so domain models stay clean
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _toJson(Task t) => {
    'id': t.id,
    'userId': t.userId,
    'projectId': t.projectId,
    'parentTaskId': t.parentTaskId,
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
    'deletedAt': t.deletedAt?.toIso8601String(),
  };

  Task _fromJson(Map<String, dynamic> j) => Task(
    id: j['id'] as String,
    userId: j['userId'] as String,
    projectId: j['projectId'] as String?,
    parentTaskId: j['parentTaskId'] as String?,
    title: j['title'] as String,
    description: j['description'] as String?,
    status: TaskStatus.values.byName(j['status'] as String),
    priority: TaskPriority.values.byName(j['priority'] as String),
    dueAt: j['dueAt'] != null ? DateTime.parse(j['dueAt'] as String) : null,
    scheduledStartAt: j['scheduledStartAt'] != null
        ? DateTime.parse(j['scheduledStartAt'] as String)
        : null,
    estimatedDurationMinutes: j['estimatedDurationMinutes'] as int?,
    actualDurationMinutes: j['actualDurationMinutes'] as int?,
    energyLevel: EnergyLevel.values.byName(j['energyLevel'] as String),
    source: TaskSource.values.byName(j['source'] as String),
    aiConfidence: j['aiConfidence'] as double?,
    createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    version: j['version'] as int,
    syncStatus: SyncStatus.values.byName(j['syncStatus'] as String),
    deletedAt: j['deletedAt'] != null
        ? DateTime.parse(j['deletedAt'] as String)
        : null,
  );
}

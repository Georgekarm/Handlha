import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../features/tasks/domain/task.dart';
import '../../features/tasks/data/task_recurrence_service.dart';
import '../result/result.dart';
import '../logger/app_logger.dart';
import '../secure_storage/secure_storage_service.dart';

/// Lightweight local task store backed by encrypted secure storage.
/// This is suitable for the small offline MVP; use an encrypted database when
/// task volume grows beyond this storage model.
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
  static const _schemaVersion = 2;
  static const _uuid = Uuid();

  Completer<void>? _activeLock;

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  Future<Result<List<Task>>> getTasksForUser(String userId) async {
    try {
      final all = await _readAll();
      final tasks = all
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
      if (t.isCompleted) {
        final doneAt = t.updatedAt;
        if (!doneAt.isBefore(todayStart) && doneAt.isBefore(todayEnd)) {
          return true;
        }
        final planned = t.scheduledStartAt ?? t.dueAt;
        return planned != null &&
            !planned.isBefore(todayStart) &&
            planned.isBefore(todayEnd);
      }
      if (t.scheduledStartAt != null) {
        return !t.scheduledStartAt!.isBefore(todayStart) &&
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
    TaskRecurrence recurrence = TaskRecurrence.none,
    String? projectId,
    String? phaseId,
    List<String> dependsOnTaskIds = const [],
    String? durationUncertainty,
  }) async {
    try {
      final now = DateTime.now();
      final task = Task(
        id: _uuid.v4(),
        userId: userId,
        projectId: projectId,
        phaseId: phaseId,
        dependsOnTaskIds: dependsOnTaskIds,
        durationUncertainty: durationUncertainty,
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
        recurrence: recurrence,
      );

      await _saveTask(task);
      AppLogger.debug('Task created: ${task.id}', tag: _tag);
      return Success(task);
    } catch (e, st) {
      AppLogger.error('createTask failed', tag: _tag, error: e, stackTrace: st);
      return const Failure(LocalDatabaseFailure());
    }
  }

  Future<Result<List<Task>>> createApprovedTasks(List<Task> tasks) => _serialized(() async {
    try {
      final all = await _readAll();
      final ids = all.map((t) => t.id).toSet();
      if (tasks.any((t) => !ids.add(t.id))) {
        return const Failure(LocalDatabaseFailure('فيه مهمة مكررة في الخطة.'));
      }
      all.addAll(tasks);
      await _writeAll(all);
      return Success(tasks);
    } catch (e, st) {
      AppLogger.error('createApprovedTasks failed', tag: _tag, error: e, stackTrace: st);
      return const Failure(LocalDatabaseFailure());
    }
  });

  /// Idempotent upsert by task ID — safe for repeated backup restores.
  Future<Result<List<Task>>> upsertTasks(List<Task> tasks) => _serialized(() async {
    try {
      final all = await _readAll();
      final byId = <String, int>{
        for (var i = 0; i < all.length; i++) all[i].id: i,
      };
      for (final task in tasks) {
        final existingIdx = byId[task.id];
        if (existingIdx == null) {
          byId[task.id] = all.length;
          all.add(task);
        } else {
          all[existingIdx] = task;
        }
      }
      await _writeAll(all);
      return Success(tasks);
    } catch (e, st) {
      AppLogger.error('upsertTasks failed', tag: _tag, error: e, stackTrace: st);
      return const Failure(LocalDatabaseFailure());
    }
  });

  /// Atomically replaces all stored tasks belonging to [userId] (used for rollback).
  Future<Result<void>> replaceAllForUser(String userId, List<Task> tasks) =>
      _serialized(() async {
        try {
          final others =
              (await _readAll()).where((t) => t.userId != userId).toList();
          others.addAll(tasks);
          await _writeAll(others);
          return const Success(null);
        } catch (e, st) {
          AppLogger.error(
            'replaceAllForUser failed',
            tag: _tag,
            error: e,
            stackTrace: st,
          );
          return const Failure(LocalDatabaseFailure());
        }
      });

  Future<Result<Task>> updateTask(Task updated) => _serialized(() async {
    try {
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
      await _writeAll(allTasks);
      return Success(newTask);
    } catch (e, st) {
      AppLogger.error('updateTask failed', tag: _tag, error: e, stackTrace: st);
      return const Failure(LocalDatabaseFailure());
    }
  });

  Future<Result<Task>> completeTask(String taskId) => _serialized(() async {
    try {
      final allTasks = await _readAll();
      final idx = allTasks.indexWhere((t) => t.id == taskId);
      if (idx == -1) return const Failure(LocalDatabaseFailure('المهمة غير موجودة.'));
      final current = allTasks[idx];
      final completed = current.copyWith(
        status: TaskStatus.completed,
        updatedAt: DateTime.now(),
        version: current.version + 1,
        syncStatus: SyncStatus.pending,
      );
      allTasks[idx] = completed;
      final nextDate = TaskRecurrenceService.nextOccurrence(current);
      if (nextDate != null) {
        allTasks.add(Task(
          id: _uuid.v4(), userId: current.userId, projectId: current.projectId,
          parentTaskId: current.parentTaskId, phaseId: current.phaseId,
          dependsOnTaskIds: current.dependsOnTaskIds, durationUncertainty: current.durationUncertainty,
          title: current.title, description: current.description, status: TaskStatus.planned,
          priority: current.priority, dueAt: nextDate, scheduledStartAt: nextDate,
          estimatedDurationMinutes: current.estimatedDurationMinutes, energyLevel: current.energyLevel,
          source: current.source, aiConfidence: current.aiConfidence, createdAt: DateTime.now(),
          updatedAt: DateTime.now(), version: 1, syncStatus: SyncStatus.pending,
          recurrence: current.recurrence,
        ));
      }
      await _writeAll(allTasks);
      return Success(completed);
    } catch (e, st) {
      AppLogger.error('completeTask failed', tag: _tag, error: e, stackTrace: st);
      return const Failure(LocalDatabaseFailure());
    }
  });

  Future<Result<void>> deleteTask(String taskId) => _serialized(() async {
    try {
      final allTasks = await _readAll();
      final idx = allTasks.indexWhere((t) => t.id == taskId);
      if (idx == -1) return const Success(null);

      // Soft delete — keeps record for sync engine
      allTasks[idx] = allTasks[idx].copyWith(
        deletedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      );
      await _writeAll(allTasks);
      return const Success(null);
    } catch (e, st) {
      AppLogger.error('deleteTask failed', tag: _tag, error: e, stackTrace: st);
      return const Failure(LocalDatabaseFailure());
    }
  });

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _saveTask(Task task) => _serialized(() async {
    final allTasks = await _readAll();
    final idx = allTasks.indexWhere((t) => t.id == task.id);
    if (idx == -1) {
      allTasks.add(task);
    } else {
      allTasks[idx] = task;
    }
    await _writeAll(allTasks);
  });

  Future<List<Task>> _readAll() async {
    final raw = await SecureStorageService.instance.readOrThrow(_key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    // v1 was a bare list. Read it for backwards compatibility and normalize
    // it on the next write to the versioned envelope.
    final List<dynamic> json = decoded is List<dynamic>
        ? decoded
        : ((decoded as Map<String, dynamic>)['items'] as List<dynamic>);
    return json.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _writeAll(List<Task> tasks) async {
    final json = tasks.map(_toJson).toList();
    await SecureStorageService.instance.writeOrThrow(_key, jsonEncode({
      'schema': _schemaVersion,
      'items': json,
    }));
  }

  Future<Result<void>> clearForUser(String userId) => _serialized(() async {
        try {
          final remaining = (await _readAll()).where((task) => task.userId != userId).toList();
          await _writeAll(remaining);
          return const Success(null);
        } catch (e, st) {
          AppLogger.error('clearForUser failed', tag: _tag, error: e, stackTrace: st);
          return const Failure(LocalDatabaseFailure());
        }
      });

  Future<T> _serialized<T>(Future<T> Function() operation) async {
    while (_activeLock != null) {
      try {
        await _activeLock!.future;
      } catch (_) {}
    }
    final lock = Completer<void>();
    _activeLock = lock;
    try {
      return await operation();
    } finally {
      _activeLock = null;
      lock.complete();
    }
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

  Task _fromJson(Map<String, dynamic> j) => Task(
    id: j['id'] as String,
    userId: j['userId'] as String,
    projectId: j['projectId'] as String?,
    parentTaskId: j['parentTaskId'] as String?,
    phaseId: j['phaseId'] as String?,
    dependsOnTaskIds: (j['dependsOnTaskIds'] as List<dynamic>? ?? const []).cast<String>(),
    durationUncertainty: j['durationUncertainty'] as String?,
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
    recurrence: TaskRecurrence.values.byName((j['recurrence'] as String?) ?? 'none'),
    deletedAt: j['deletedAt'] != null
        ? DateTime.parse(j['deletedAt'] as String)
        : null,
  );
}

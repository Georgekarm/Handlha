import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../features/notifications/alarm_reminder_store.dart';
import '../../features/notifications/local_notification_service.dart';
import '../../features/tasks/data/task_recurrence_service.dart';
import '../../features/tasks/domain/task.dart';
import '../logger/app_logger.dart';
import '../result/result.dart';
import '../secure_storage/secure_storage_service.dart';
import 'handelha_sqlite_store.dart';

/// Offline-first task repository backed by normalized SQLite ([HandelhaSqliteStore])
/// on Android/iOS (and FFI-enabled tests), with automatic outbox queueing for
/// incremental cloud delta sync.
///
/// Design decisions:
/// - UUIDs for offline-safe IDs
/// - version + updatedAt for per-item conflict detection
/// - soft delete tombstones via `deleted_at` so deletions propagate across devices
/// - durable `sync_outbox` entries written atomically inside each SQLite transaction
class LocalTaskDatabase {
  LocalTaskDatabase._();
  static final LocalTaskDatabase instance = LocalTaskDatabase._();

  static const _tag = 'LocalTaskDB';
  static const _key = 'local_tasks_v1';
  static const _schemaVersion = 2;
  static const _uuid = Uuid();

  Completer<void>? _activeLock;

  HandelhaSqliteStore get _sqlite => HandelhaSqliteStore.instance;

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  Future<Result<List<Task>>> getTasksForUser(String userId) async {
    try {
      if (await _sqlite.ensureReadyIfSupported()) {
        final rows = await _sqlite.database.query(
          'tasks',
          where: 'user_id = ? AND deleted_at IS NULL',
          whereArgs: [userId],
        );
        return Success(rows.map(_fromRow).toList());
      }
      final all = await _readAllLegacy();
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

  /// Fetches a single task by [taskId], including soft-deleted tombstones (used by sync).
  Future<Task?> getTaskIncludingDeleted(String taskId) async {
    if (await _sqlite.ensureReadyIfSupported()) {
      final rows = await _sqlite.database.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [taskId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _fromRow(rows.first);
    }
    final all = await _readAllLegacy();
    return all.where((t) => t.id == taskId).firstOrNull;
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
      return t.status == TaskStatus.inbox || t.status == TaskStatus.inProgress;
    }).toList();

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

      if (await _sqlite.ensureReadyIfSupported()) {
        await _sqlite.database.transaction((txn) async {
          final row = _toRow(task);
          await txn.insert(
            'tasks',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await _sqlite.enqueueOutbox(
            executor: txn,
            userId: task.userId,
            entityType: 'task',
            entityId: task.id,
            operation: 'upsert',
            payload: row,
            updatedAt: task.updatedAt,
          );
        });
      } else {
        await _saveTaskLegacy(task);
      }
      AppLogger.debug('Task created: ${task.id}', tag: _tag);
      return Success(task);
    } catch (e, st) {
      AppLogger.error('createTask failed', tag: _tag, error: e, stackTrace: st);
      return const Failure(LocalDatabaseFailure());
    }
  }

  Future<Result<List<Task>>> createApprovedTasks(List<Task> tasks) =>
      _serialized(() async {
        try {
          if (await _sqlite.ensureReadyIfSupported()) {
            final db = _sqlite.database;
            final seenIds = <String>{};
            for (final task in tasks) {
              if (!seenIds.add(task.id)) {
                return const Failure(
                  LocalDatabaseFailure('فيه مهمة مكررة في الخطة.'),
                );
              }
              final existing = await db.query(
                'tasks',
                columns: ['id'],
                where: 'id = ?',
                whereArgs: [task.id],
                limit: 1,
              );
              if (existing.isNotEmpty) {
                return const Failure(
                  LocalDatabaseFailure('فيه مهمة مكررة في الخطة.'),
                );
              }
            }
            await db.transaction((txn) async {
              for (final task in tasks) {
                final row = _toRow(task);
                await txn.insert('tasks', row);
                await _sqlite.enqueueOutbox(
                  executor: txn,
                  userId: task.userId,
                  entityType: 'task',
                  entityId: task.id,
                  operation: 'upsert',
                  payload: row,
                  updatedAt: task.updatedAt,
                );
              }
            });
            return Success(tasks);
          }

          final all = await _readAllLegacy();
          final ids = all.map((t) => t.id).toSet();
          if (tasks.any((t) => !ids.add(t.id))) {
            return const Failure(
              LocalDatabaseFailure('فيه مهمة مكررة في الخطة.'),
            );
          }
          all.addAll(tasks);
          await _writeAllLegacy(all);
          return Success(tasks);
        } catch (e, st) {
          AppLogger.error(
            'createApprovedTasks failed',
            tag: _tag,
            error: e,
            stackTrace: st,
          );
          return const Failure(LocalDatabaseFailure());
        }
      });

  /// Idempotent upsert by task ID — safe for repeated backup restores and cloud pulls.
  Future<Result<List<Task>>> upsertTasks(
    List<Task> tasks, {
    bool enqueueSync = true,
  }) =>
      _serialized(() async {
        try {
          if (await _sqlite.ensureReadyIfSupported()) {
            await _sqlite.database.transaction((txn) async {
              for (final task in tasks) {
                final row = _toRow(task);
                await txn.insert(
                  'tasks',
                  row,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
                if (enqueueSync) {
                  await _sqlite.enqueueOutbox(
                    executor: txn,
                    userId: task.userId,
                    entityType: 'task',
                    entityId: task.id,
                    operation: task.deletedAt != null ? 'delete' : 'upsert',
                    payload: row,
                    updatedAt: task.updatedAt,
                  );
                }
              }
            });
            return Success(tasks);
          }

          final all = await _readAllLegacy();
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
          await _writeAllLegacy(all);
          return Success(tasks);
        } catch (e, st) {
          AppLogger.error(
            'upsertTasks failed',
            tag: _tag,
            error: e,
            stackTrace: st,
          );
          return const Failure(LocalDatabaseFailure());
        }
      });

  /// Atomically replaces all stored tasks belonging to [userId] (used for rollback).
  Future<Result<void>> replaceAllForUser(String userId, List<Task> tasks) =>
      _serialized(() async {
        try {
          if (await _sqlite.ensureReadyIfSupported()) {
            await _sqlite.database.transaction((txn) async {
              await txn.delete(
                'tasks',
                where: 'user_id = ?',
                whereArgs: [userId],
              );
              for (final task in tasks) {
                await txn.insert(
                  'tasks',
                  _toRow(task),
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            });
            return const Success(null);
          }

          final others =
              (await _readAllLegacy()).where((t) => t.userId != userId).toList();
          others.addAll(tasks);
          await _writeAllLegacy(others);
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
          if (await _sqlite.ensureReadyIfSupported()) {
            final db = _sqlite.database;
            final existing = await db.query(
              'tasks',
              columns: ['id'],
              where: 'id = ?',
              whereArgs: [updated.id],
              limit: 1,
            );
            if (existing.isEmpty) {
              return const Failure(LocalDatabaseFailure('المهمة غير موجودة.'));
            }
            final newTask = updated.copyWith(
              updatedAt: DateTime.now(),
              version: updated.version + 1,
              syncStatus: SyncStatus.pending,
            );
            await db.transaction((txn) async {
              final row = _toRow(newTask);
              await txn.update(
                'tasks',
                row,
                where: 'id = ?',
                whereArgs: [newTask.id],
              );
              await _sqlite.enqueueOutbox(
                executor: txn,
                userId: newTask.userId,
                entityType: 'task',
                entityId: newTask.id,
                operation: newTask.deletedAt != null ? 'delete' : 'upsert',
                payload: row,
                updatedAt: newTask.updatedAt,
              );
            });
            return Success(newTask);
          }

          final allTasks = await _readAllLegacy();
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
          await _writeAllLegacy(allTasks);
          return Success(newTask);
        } catch (e, st) {
          AppLogger.error(
            'updateTask failed',
            tag: _tag,
            error: e,
            stackTrace: st,
          );
          return const Failure(LocalDatabaseFailure());
        }
      });

  Future<Result<Task>> completeTask(String taskId) => _serialized(() async {
        try {
          if (await _sqlite.ensureReadyIfSupported()) {
            final db = _sqlite.database;
            final rows = await db.query(
              'tasks',
              where: 'id = ?',
              whereArgs: [taskId],
              limit: 1,
            );
            if (rows.isEmpty) {
              return const Failure(LocalDatabaseFailure('المهمة غير موجودة.'));
            }
            final current = _fromRow(rows.first);
            final now = DateTime.now();
            final completed = current.copyWith(
              status: TaskStatus.completed,
              updatedAt: now,
              version: current.version + 1,
              syncStatus: SyncStatus.pending,
            );
            final nextDate = TaskRecurrenceService.nextOccurrence(current);
            final nextTask = nextDate == null
                ? null
                : Task(
                    id: _uuid.v4(),
                    userId: current.userId,
                    projectId: current.projectId,
                    parentTaskId: current.parentTaskId,
                    phaseId: current.phaseId,
                    dependsOnTaskIds: current.dependsOnTaskIds,
                    durationUncertainty: current.durationUncertainty,
                    title: current.title,
                    description: current.description,
                    status: TaskStatus.planned,
                    priority: current.priority,
                    dueAt: nextDate,
                    scheduledStartAt: nextDate,
                    estimatedDurationMinutes: current.estimatedDurationMinutes,
                    energyLevel: current.energyLevel,
                    source: current.source,
                    aiConfidence: current.aiConfidence,
                    createdAt: now,
                    updatedAt: now,
                    version: 1,
                    syncStatus: SyncStatus.pending,
                    recurrence: current.recurrence,
                  );

            await db.transaction((txn) async {
              final compRow = _toRow(completed);
              await txn.update(
                'tasks',
                compRow,
                where: 'id = ?',
                whereArgs: [completed.id],
              );
              await _sqlite.enqueueOutbox(
                executor: txn,
                userId: completed.userId,
                entityType: 'task',
                entityId: completed.id,
                operation: 'upsert',
                payload: compRow,
                updatedAt: completed.updatedAt,
              );
              if (nextTask != null) {
                final nextRow = _toRow(nextTask);
                await txn.insert('tasks', nextRow);
                await _sqlite.enqueueOutbox(
                  executor: txn,
                  userId: nextTask.userId,
                  entityType: 'task',
                  entityId: nextTask.id,
                  operation: 'upsert',
                  payload: nextRow,
                  updatedAt: nextTask.updatedAt,
                );
              }
            });
            if (nextTask != null) {
              await _rolloverRecurringReminder(current, nextTask);
            }
            return Success(completed);
          }

          final allTasks = await _readAllLegacy();
          final idx = allTasks.indexWhere((t) => t.id == taskId);
          if (idx == -1) {
            return const Failure(LocalDatabaseFailure('المهمة غير موجودة.'));
          }
          final current = allTasks[idx];
          final completed = current.copyWith(
            status: TaskStatus.completed,
            updatedAt: DateTime.now(),
            version: current.version + 1,
            syncStatus: SyncStatus.pending,
          );
          allTasks[idx] = completed;
          final nextDate = TaskRecurrenceService.nextOccurrence(current);
          Task? spawnedNext;
          if (nextDate != null) {
            spawnedNext = Task(
              id: _uuid.v4(),
              userId: current.userId,
              projectId: current.projectId,
              parentTaskId: current.parentTaskId,
              phaseId: current.phaseId,
              dependsOnTaskIds: current.dependsOnTaskIds,
              durationUncertainty: current.durationUncertainty,
              title: current.title,
              description: current.description,
              status: TaskStatus.planned,
              priority: current.priority,
              dueAt: nextDate,
              scheduledStartAt: nextDate,
              estimatedDurationMinutes: current.estimatedDurationMinutes,
              energyLevel: current.energyLevel,
              source: current.source,
              aiConfidence: current.aiConfidence,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              version: 1,
              syncStatus: SyncStatus.pending,
              recurrence: current.recurrence,
            );
            allTasks.add(spawnedNext);
          }
          await _writeAllLegacy(allTasks);
          if (spawnedNext != null) {
            await _rolloverRecurringReminder(current, spawnedNext);
          }
          return Success(completed);
        } catch (e, st) {
          AppLogger.error(
            'completeTask failed',
            tag: _tag,
            error: e,
            stackTrace: st,
          );
          return const Failure(LocalDatabaseFailure());
        }
      });

  Future<Result<void>> deleteTask(String taskId) => _serialized(() async {
        try {
          if (await _sqlite.ensureReadyIfSupported()) {
            final db = _sqlite.database;
            final rows = await db.query(
              'tasks',
              where: 'id = ?',
              whereArgs: [taskId],
              limit: 1,
            );
            if (rows.isEmpty) return const Success(null);
            final existing = _fromRow(rows.first);
            final now = DateTime.now();
            final tombstoned = existing.copyWith(
              deletedAt: now,
              updatedAt: now,
              version: existing.version + 1,
              syncStatus: SyncStatus.pending,
            );
            await db.transaction((txn) async {
              final row = _toRow(tombstoned);
              await txn.update(
                'tasks',
                row,
                where: 'id = ?',
                whereArgs: [taskId],
              );
              await _sqlite.enqueueOutbox(
                executor: txn,
                userId: tombstoned.userId,
                entityType: 'task',
                entityId: tombstoned.id,
                operation: 'delete',
                payload: row,
                updatedAt: tombstoned.updatedAt,
              );
            });
            return const Success(null);
          }

          final allTasks = await _readAllLegacy();
          final idx = allTasks.indexWhere((t) => t.id == taskId);
          if (idx == -1) return const Success(null);
          allTasks[idx] = allTasks[idx].copyWith(
            deletedAt: DateTime.now(),
            updatedAt: DateTime.now(),
            version: allTasks[idx].version + 1,
            syncStatus: SyncStatus.pending,
          );
          await _writeAllLegacy(allTasks);
          return const Success(null);
        } catch (e, st) {
          AppLogger.error(
            'deleteTask failed',
            tag: _tag,
            error: e,
            stackTrace: st,
          );
          return const Failure(LocalDatabaseFailure());
        }
      });

  Future<Result<void>> clearForUser(String userId) => _serialized(() async {
        try {
          if (await _sqlite.ensureReadyIfSupported()) {
            await _sqlite.database.delete(
              'tasks',
              where: 'user_id = ?',
              whereArgs: [userId],
            );
            return const Success(null);
          }
          final remaining = (await _readAllLegacy())
              .where((task) => task.userId != userId)
              .toList();
          await _writeAllLegacy(remaining);
          return const Success(null);
        } catch (e, st) {
          AppLogger.error(
            'clearForUser failed',
            tag: _tag,
            error: e,
            stackTrace: st,
          );
          return const Failure(LocalDatabaseFailure());
        }
      });

  /// Reassigns all tasks from [fromUserId] to [toUserId] in legacy fallback mode.
  Future<void> reassignUserLegacy(String fromUserId, String toUserId) =>
      _serialized(() async {
        if (await _sqlite.ensureReadyIfSupported()) return;
        final all = await _readAllLegacy();
        var changed = false;
        final next = [
          for (final t in all)
            if (t.userId == fromUserId)
              () {
                changed = true;
                return t.copyWith(
                  userId: toUserId,
                  syncStatus: SyncStatus.pending,
                );
              }()
            else
              t,
        ];
        if (changed) await _writeAllLegacy(next);
      });

  // ---------------------------------------------------------------------------
  // Row / JSON Mapping
  // ---------------------------------------------------------------------------

  Map<String, Object?> _toRow(Task t) => {
        'id': t.id,
        'user_id': t.userId,
        'project_id': t.projectId,
        'parent_task_id': t.parentTaskId,
        'phase_id': t.phaseId,
        'depends_on_json': jsonEncode(t.dependsOnTaskIds),
        'duration_uncertainty': t.durationUncertainty,
        'title': t.title,
        'description': t.description,
        'status': t.status.name,
        'priority': t.priority.name,
        'due_at': t.dueAt?.toIso8601String(),
        'scheduled_start_at': t.scheduledStartAt?.toIso8601String(),
        'estimated_duration_minutes': t.estimatedDurationMinutes,
        'actual_duration_minutes': t.actualDurationMinutes,
        'energy_level': t.energyLevel.name,
        'source': t.source.name,
        'ai_confidence': t.aiConfidence,
        'created_at': t.createdAt.toIso8601String(),
        'updated_at': t.updatedAt.toIso8601String(),
        'version': t.version,
        'sync_status': t.syncStatus.name,
        'recurrence': t.recurrence.name,
        'deleted_at': t.deletedAt?.toIso8601String(),
      };

  Task _fromRow(Map<String, Object?> r) {
    final depsRaw = (r['depends_on_json'] as String?) ?? '[]';
    final deps = (jsonDecode(depsRaw) as List<dynamic>).cast<String>();
    return Task(
      id: r['id'] as String,
      userId: r['user_id'] as String,
      projectId: r['project_id'] as String?,
      parentTaskId: r['parent_task_id'] as String?,
      phaseId: r['phase_id'] as String?,
      dependsOnTaskIds: deps,
      durationUncertainty: r['duration_uncertainty'] as String?,
      title: r['title'] as String,
      description: r['description'] as String?,
      status: TaskStatus.values.byName(r['status'] as String),
      priority: TaskPriority.values.byName(r['priority'] as String),
      dueAt: r['due_at'] != null ? DateTime.parse(r['due_at'] as String) : null,
      scheduledStartAt: r['scheduled_start_at'] != null
          ? DateTime.parse(r['scheduled_start_at'] as String)
          : null,
      estimatedDurationMinutes:
          (r['estimated_duration_minutes'] as num?)?.toInt(),
      actualDurationMinutes: (r['actual_duration_minutes'] as num?)?.toInt(),
      energyLevel: EnergyLevel.values.byName(r['energy_level'] as String),
      source: TaskSource.values.byName(r['source'] as String),
      aiConfidence: (r['ai_confidence'] as num?)?.toDouble(),
      createdAt: DateTime.parse(r['created_at'] as String),
      updatedAt: DateTime.parse(r['updated_at'] as String),
      version: (r['version'] as num?)?.toInt() ?? 1,
      syncStatus: SyncStatus.values.byName(r['sync_status'] as String),
      recurrence: TaskRecurrence.values.byName(
        (r['recurrence'] as String?) ?? 'none',
      ),
      deletedAt: r['deleted_at'] != null
          ? DateTime.parse(r['deleted_at'] as String)
          : null,
    );
  }

  /// Parses a SQLite/Firestore row map back into a [Task] domain model.
  Task taskFromRowMap(Map<String, dynamic> map) => _fromRow(map);

  // ---------------------------------------------------------------------------
  // Legacy SecureStorage helpers (used only in non-FFI legacy VM tests)
  // ---------------------------------------------------------------------------

  Future<void> _saveTaskLegacy(Task task) => _serialized(() async {
        final allTasks = await _readAllLegacy();
        final idx = allTasks.indexWhere((t) => t.id == task.id);
        if (idx == -1) {
          allTasks.add(task);
        } else {
          allTasks[idx] = task;
        }
        await _writeAllLegacy(allTasks);
      });

  Future<List<Task>> _readAllLegacy() async {
    final raw = await SecureStorageService.instance.readOrThrow(_key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    final List<dynamic> json = decoded is List<dynamic>
        ? decoded
        : ((decoded as Map<String, dynamic>)['items'] as List<dynamic>);
    return json.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _writeAllLegacy(List<Task> tasks) async {
    final json = tasks.map(_toJson).toList();
    await SecureStorageService.instance.writeOrThrow(
      _key,
      jsonEncode({'schema': _schemaVersion, 'items': json}),
    );
  }

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

  /// Carries over scheduled reminders and native alarms when a recurring task
  /// completes and spawns [nextTask] for the next occurrence.
  Future<void> _rolloverRecurringReminder(
    Task completedTask,
    Task nextTask,
  ) async {
    final nextWhen = nextTask.dueAt ?? nextTask.scheduledStartAt;
    if (nextWhen == null) return;
    try {
      await LocalNotificationService.instance.scheduleTask(nextTask);
      final currentAlarms = await AlarmReminderStore.load(completedTask.userId);
      final existingIdx = currentAlarms.items.indexWhere(
        (e) => e.taskId == completedTask.id || e.id == completedTask.id,
      );
      final mode = currentAlarms.taskAlertModes[completedTask.id] ??
          (existingIdx >= 0
              ? currentAlarms.items[existingIdx].alertMode
              : currentAlarms.defaultAlertMode);
      final outcome =
          await LocalNotificationService.instance.scheduleReminderItem(
        id: nextTask.id,
        title: nextTask.title,
        scheduledAt: nextWhen,
        alertMode: mode,
        taskId: nextTask.id,
        userId: nextTask.userId,
        requestPermission: false,
      );
      final nextItem = AlarmReminderItem(
        id: nextTask.id,
        title: nextTask.title,
        scheduledAt: nextWhen,
        alertMode: mode,
        isEnabled: true,
        taskId: nextTask.id,
        scheduleStatus: outcome.status.name,
      );
      final updatedItems = [
        for (final item in currentAlarms.items)
          if (item.taskId == completedTask.id || item.id == completedTask.id)
            item.copyWith(isEnabled: false)
          else if (item.id != nextTask.id)
            item,
        nextItem,
      ]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      final updatedModes = Map<String, String>.from(currentAlarms.taskAlertModes)
        ..[nextTask.id] = mode;
      await AlarmReminderStore.save(
        completedTask.userId,
        currentAlarms.copyWith(
          items: updatedItems,
          taskAlertModes: updatedModes,
        ),
      );
    } catch (_) {}
  }

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
        dependsOnTaskIds:
            (j['dependsOnTaskIds'] as List<dynamic>? ?? const []).cast<String>(),
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
        recurrence: TaskRecurrence.values.byName(
          (j['recurrence'] as String?) ?? 'none',
        ),
        deletedAt: j['deletedAt'] != null
            ? DateTime.parse(j['deletedAt'] as String)
            : null,
      );
}

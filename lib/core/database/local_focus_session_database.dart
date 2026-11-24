import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../features/projects/domain/focus_session.dart';
import '../result/result.dart';
import '../secure_storage/secure_storage_service.dart';
import '../telemetry/local_core_loop_telemetry.dart';
import 'handelha_sqlite_store.dart';

class LocalFocusSessionDatabase {
  LocalFocusSessionDatabase._();
  static final instance = LocalFocusSessionDatabase._();
  static const _key = 'local_focus_sessions_v1';
  static const _schemaVersion = 1;
  static const _uuid = Uuid();
  Completer<void>? _activeLock;

  HandelhaSqliteStore get _sqlite => HandelhaSqliteStore.instance;

  Future<Result<FocusSession>> record({
    required String userId,
    String? taskId,
    required String taskTitle,
    required DateTime startedAt,
    required DateTime endedAt,
    required int elapsedMinutes,
    required bool completed,
  }) =>
      _serialized(() async {
        try {
          if (elapsedMinutes < 0 || endedAt.isBefore(startedAt)) {
            return const Failure(
              ValidationFailure('مدة جلسة التركيز غير صالحة.'),
            );
          }
          final session = FocusSession(
            id: _uuid.v4(),
            userId: userId,
            taskId: taskId,
            taskTitle: taskTitle.trim(),
            startedAt: startedAt,
            endedAt: endedAt,
            elapsedMinutes: elapsedMinutes,
            completed: completed,
          );

          if (await _sqlite.ensureReadyIfSupported()) {
            await _sqlite.database.transaction((txn) async {
              final row = _toRow(session);
              await txn.insert(
                'focus_sessions',
                row,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              await _sqlite.enqueueOutbox(
                executor: txn,
                userId: userId,
                entityType: 'focus_session',
                entityId: session.id,
                operation: 'upsert',
                payload: row,
                updatedAt: endedAt,
              );
            });
          } else {
            final all = await _readAllLegacy();
            all.add(session);
            await _writeAllLegacy(all);
          }

          if (completed) {
            await LocalCoreLoopTelemetry.instance.recordEvent(
              userId,
              'focus_completed',
            );
          }
          return Success(session);
        } catch (_) {
          return const Failure(
            LocalDatabaseFailure('تعذّر حفظ جلسة التركيز.'),
          );
        }
      });

  Future<Result<List<FocusSession>>> forUser(String userId) async {
    try {
      if (await _sqlite.ensureReadyIfSupported()) {
        final rows = await _sqlite.database.query(
          'focus_sessions',
          where: 'user_id = ? AND deleted_at IS NULL',
          whereArgs: [userId],
          orderBy: 'ended_at DESC',
        );
        return Success(rows.map(_fromRow).toList());
      }
      final sessions = (await _readAllLegacy())
          .where((s) => s.userId == userId)
          .toList()
        ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
      return Success(sessions);
    } catch (_) {
      return const Failure(LocalDatabaseFailure());
    }
  }

  Future<Result<void>> clearForUser(String userId) => _serialized(() async {
        try {
          if (await _sqlite.ensureReadyIfSupported()) {
            await _sqlite.database.delete(
              'focus_sessions',
              where: 'user_id = ?',
              whereArgs: [userId],
            );
            return const Success(null);
          }
          final remaining = (await _readAllLegacy())
              .where((s) => s.userId != userId)
              .toList();
          await _writeAllLegacy(remaining);
          return const Success(null);
        } catch (_) {
          return const Failure(LocalDatabaseFailure());
        }
      });

  /// Idempotent upsert by session ID — safe for repeated backup restores and cloud pulls.
  Future<Result<void>> upsertSessions(
    List<FocusSession> sessions, {
    bool enqueueSync = true,
  }) =>
      _serialized(() async {
        try {
          if (await _sqlite.ensureReadyIfSupported()) {
            await _sqlite.database.transaction((txn) async {
              for (final session in sessions) {
                final row = _toRow(
                  session,
                  syncStatus: enqueueSync ? 'pending' : 'synced',
                );
                await txn.insert(
                  'focus_sessions',
                  row,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
                if (enqueueSync) {
                  await _sqlite.enqueueOutbox(
                    executor: txn,
                    userId: session.userId,
                    entityType: 'focus_session',
                    entityId: session.id,
                    operation: 'upsert',
                    payload: row,
                    updatedAt: session.endedAt,
                  );
                }
              }
            });
            return const Success(null);
          }

          final all = await _readAllLegacy();
          final byId = <String, int>{
            for (var i = 0; i < all.length; i++) all[i].id: i,
          };
          for (final session in sessions) {
            final idx = byId[session.id];
            if (idx == null) {
              byId[session.id] = all.length;
              all.add(session);
            } else {
              all[idx] = session;
            }
          }
          await _writeAllLegacy(all);
          return const Success(null);
        } catch (_) {
          return const Failure(LocalDatabaseFailure());
        }
      });

  Future<Result<void>> replaceAllForUser(
    String userId,
    List<FocusSession> sessions,
  ) =>
      _serialized(() async {
        try {
          if (await _sqlite.ensureReadyIfSupported()) {
            await _sqlite.database.transaction((txn) async {
              await txn.delete(
                'focus_sessions',
                where: 'user_id = ?',
                whereArgs: [userId],
              );
              for (final session in sessions) {
                await txn.insert(
                  'focus_sessions',
                  _toRow(session),
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            });
            return const Success(null);
          }

          final remaining = (await _readAllLegacy())
              .where((s) => s.userId != userId)
              .toList();
          remaining.addAll(sessions);
          await _writeAllLegacy(remaining);
          return const Success(null);
        } catch (_) {
          return const Failure(LocalDatabaseFailure());
        }
      });

  Future<void> reassignUserLegacy(String fromUserId, String toUserId) =>
      _serialized(() async {
        if (await _sqlite.ensureReadyIfSupported()) return;
        final all = await _readAllLegacy();
        var changed = false;
        final next = [
          for (final s in all)
            if (s.userId == fromUserId)
              () {
                changed = true;
                return FocusSession(
                  id: s.id,
                  userId: toUserId,
                  taskId: s.taskId,
                  taskTitle: s.taskTitle,
                  startedAt: s.startedAt,
                  endedAt: s.endedAt,
                  elapsedMinutes: s.elapsedMinutes,
                  completed: s.completed,
                );
              }()
            else
              s,
        ];
        if (changed) await _writeAllLegacy(next);
      });

  Map<String, Object?> _toRow(
    FocusSession s, {
    String syncStatus = 'pending',
  }) =>
      {
        'id': s.id,
        'user_id': s.userId,
        'task_id': s.taskId,
        'task_title': s.taskTitle,
        'started_at': s.startedAt.toIso8601String(),
        'ended_at': s.endedAt.toIso8601String(),
        'elapsed_minutes': s.elapsedMinutes,
        'completed': s.completed ? 1 : 0,
        'updated_at': s.endedAt.toIso8601String(),
        'deleted_at': null,
        'sync_status': syncStatus,
      };

  FocusSession _fromRow(Map<String, Object?> r) => FocusSession(
        id: r['id'] as String,
        userId: r['user_id'] as String,
        taskId: r['task_id'] as String?,
        taskTitle: r['task_title'] as String,
        startedAt: DateTime.parse(r['started_at'] as String),
        endedAt: DateTime.parse(r['ended_at'] as String),
        elapsedMinutes: (r['elapsed_minutes'] as num).toInt(),
        completed: (r['completed'] as num?)?.toInt() == 1,
      );

  Future<List<FocusSession>> _readAllLegacy() async {
    final raw = await SecureStorageService.instance.readOrThrow(_key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    if (decoded['schema'] != _schemaVersion) {
      throw const FormatException('Unsupported focus session schema');
    }
    return (decoded['items'] as List<dynamic>)
        .map((value) => _fromJson((value as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> _writeAllLegacy(List<FocusSession> sessions) async {
    await SecureStorageService.instance.writeOrThrow(
      _key,
      jsonEncode({
        'schema': _schemaVersion,
        'items': sessions.map(_toJson).toList(),
      }),
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

  Map<String, dynamic> _toJson(FocusSession s) => {
        'id': s.id,
        'userId': s.userId,
        'taskId': s.taskId,
        'taskTitle': s.taskTitle,
        'startedAt': s.startedAt.toIso8601String(),
        'endedAt': s.endedAt.toIso8601String(),
        'elapsedMinutes': s.elapsedMinutes,
        'completed': s.completed,
      };

  FocusSession _fromJson(Map<String, dynamic> j) => FocusSession(
        id: j['id'] as String,
        userId: j['userId'] as String,
        taskId: j['taskId'] as String?,
        taskTitle: j['taskTitle'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: DateTime.parse(j['endedAt'] as String),
        elapsedMinutes: (j['elapsedMinutes'] as num).toInt(),
        completed: j['completed'] as bool,
      );
}

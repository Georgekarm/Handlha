import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../features/projects/domain/project.dart';
import '../result/result.dart';
import '../secure_storage/secure_storage_service.dart';
import 'handelha_sqlite_store.dart';

class LocalProjectDatabase {
  LocalProjectDatabase._();
  static final instance = LocalProjectDatabase._();
  static const _key = 'local_projects_v1';
  Completer<void>? _activeLock;

  HandelhaSqliteStore get _sqlite => HandelhaSqliteStore.instance;

  Future<Result<void>> save(
    Project project, {
    List<Map<String, dynamic>> phases = const [],
    bool enqueueSync = true,
  }) =>
      _serialized(() async {
        try {
          if (await _sqlite.ensureReadyIfSupported()) {
            await _sqlite.database.transaction((txn) async {
              final row = _toRow(project);
              await txn.insert(
                'projects',
                row,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              await txn.delete(
                'project_phases',
                where: 'project_id = ?',
                whereArgs: [project.id],
              );
              for (var i = 0; i < phases.length; i++) {
                await txn.insert(
                  'project_phases',
                  {
                    'project_id': project.id,
                    'phase_order': i,
                    'payload_json': jsonEncode(phases[i]),
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
              if (enqueueSync) {
                await _sqlite.enqueueOutbox(
                  executor: txn,
                  userId: project.userId,
                  entityType: 'project',
                  entityId: project.id,
                  operation: 'upsert',
                  payload: {
                    ...row,
                    'phases_json': jsonEncode(phases),
                  },
                  updatedAt: project.updatedAt,
                );
              }
            });
            return const Success(null);
          }

          final records = await _readRecordsLegacy();
          final index = records.indexWhere(
            (r) => ((r['project'] as Map?) ?? r)['id'] == project.id,
          );
          final record = _toRecord(project, phases);
          if (index < 0) {
            records.add(record);
          } else {
            records[index] = record;
          }
          await SecureStorageService.instance
              .writeOrThrow(_key, jsonEncode(records));
          return const Success(null);
        } catch (_) {
          return const Failure(LocalDatabaseFailure());
        }
      });

  Future<Result<List<Project>>> forUser(String userId) async {
    try {
      if (await _sqlite.ensureReadyIfSupported()) {
        final rows = await _sqlite.database.query(
          'projects',
          where: 'user_id = ? AND deleted_at IS NULL',
          whereArgs: [userId],
        );
        return Success(rows.map(_fromRow).toList());
      }
      return Success(
        (await _readAllLegacy()).where((p) => p.userId == userId).toList(),
      );
    } catch (_) {
      return const Failure(LocalDatabaseFailure());
    }
  }

  Future<Result<List<({Project project, List<Map<String, dynamic>> phases})>>>
      exportRecordsForUser(String userId) async {
    try {
      if (await _sqlite.ensureReadyIfSupported()) {
        final db = _sqlite.database;
        final rows = await db.query(
          'projects',
          where: 'user_id = ? AND deleted_at IS NULL',
          whereArgs: [userId],
        );
        final out =
            <({Project project, List<Map<String, dynamic>> phases})>[];
        for (final row in rows) {
          final proj = _fromRow(row);
          final phaseRows = await db.query(
            'project_phases',
            where: 'project_id = ?',
            whereArgs: [proj.id],
            orderBy: 'phase_order ASC',
          );
          final phases = [
            for (final pr in phaseRows)
              (jsonDecode(pr['payload_json'] as String) as Map)
                  .cast<String, dynamic>(),
          ];
          out.add((project: proj, phases: phases));
        }
        return Success(out);
      }

      final records = await _readRecordsLegacy();
      final out = <({Project project, List<Map<String, dynamic>> phases})>[];
      for (final record in records) {
        final rawProj =
            (record['project'] as Map?)?.cast<String, dynamic>() ?? record;
        final project = _fromJson(rawProj);
        if (project.userId != userId) continue;
        final rawPhases = record['phases'];
        final phases = rawPhases is List
            ? rawPhases.map((e) => (e as Map).cast<String, dynamic>()).toList()
            : const <Map<String, dynamic>>[];
        out.add((project: project, phases: phases));
      }
      return Success(out);
    } catch (_) {
      return const Failure(LocalDatabaseFailure());
    }
  }

  Future<Result<void>> upsertRecords(
    List<({Project project, List<Map<String, dynamic>> phases})> entries, {
    bool enqueueSync = true,
  }) =>
      _serialized(() async {
        try {
          if (await _sqlite.ensureReadyIfSupported()) {
            await _sqlite.database.transaction((txn) async {
              for (final entry in entries) {
                final row = _toRow(entry.project);
                await txn.insert(
                  'projects',
                  row,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
                await txn.delete(
                  'project_phases',
                  where: 'project_id = ?',
                  whereArgs: [entry.project.id],
                );
                for (var i = 0; i < entry.phases.length; i++) {
                  await txn.insert(
                    'project_phases',
                    {
                      'project_id': entry.project.id,
                      'phase_order': i,
                      'payload_json': jsonEncode(entry.phases[i]),
                    },
                    conflictAlgorithm: ConflictAlgorithm.replace,
                  );
                }
                if (enqueueSync) {
                  await _sqlite.enqueueOutbox(
                    executor: txn,
                    userId: entry.project.userId,
                    entityType: 'project',
                    entityId: entry.project.id,
                    operation: 'upsert',
                    payload: {
                      ...row,
                      'phases_json': jsonEncode(entry.phases),
                    },
                    updatedAt: entry.project.updatedAt,
                  );
                }
              }
            });
            return const Success(null);
          }

          final records = await _readRecordsLegacy();
          for (final entry in entries) {
            final index = records.indexWhere(
              (r) => ((r['project'] as Map?) ?? r)['id'] == entry.project.id,
            );
            final record = _toRecord(entry.project, entry.phases);
            if (index < 0) {
              records.add(record);
            } else {
              records[index] = record;
            }
          }
          await SecureStorageService.instance
              .writeOrThrow(_key, jsonEncode(records));
          return const Success(null);
        } catch (_) {
          return const Failure(LocalDatabaseFailure());
        }
      });

  Future<Result<void>> replaceAllForUser(
    String userId,
    List<({Project project, List<Map<String, dynamic>> phases})> entries,
  ) =>
      _serialized(() async {
        try {
          if (await _sqlite.ensureReadyIfSupported()) {
            await _sqlite.database.transaction((txn) async {
              await txn.delete(
                'projects',
                where: 'user_id = ?',
                whereArgs: [userId],
              );
              for (final entry in entries) {
                await txn.insert(
                  'projects',
                  _toRow(entry.project),
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
                for (var i = 0; i < entry.phases.length; i++) {
                  await txn.insert(
                    'project_phases',
                    {
                      'project_id': entry.project.id,
                      'phase_order': i,
                      'payload_json': jsonEncode(entry.phases[i]),
                    },
                    conflictAlgorithm: ConflictAlgorithm.replace,
                  );
                }
              }
            });
            return const Success(null);
          }

          final records = await _readRecordsLegacy();
          records.removeWhere((record) {
            final project =
                (record['project'] as Map?)?.cast<String, dynamic>() ?? record;
            return project['userId'] == userId;
          });
          for (final entry in entries) {
            records.add(_toRecord(entry.project, entry.phases));
          }
          await SecureStorageService.instance
              .writeOrThrow(_key, jsonEncode(records));
          return const Success(null);
        } catch (_) {
          return const Failure(LocalDatabaseFailure());
        }
      });

  Future<Result<void>> clearForUser(String userId) => _serialized(() async {
        try {
          if (await _sqlite.ensureReadyIfSupported()) {
            await _sqlite.database.delete(
              'projects',
              where: 'user_id = ?',
              whereArgs: [userId],
            );
            return const Success(null);
          }
          final records = await _readRecordsLegacy();
          records.removeWhere((record) {
            final project =
                (record['project'] as Map?)?.cast<String, dynamic>() ?? record;
            return project['userId'] == userId;
          });
          await SecureStorageService.instance
              .writeOrThrow(_key, jsonEncode(records));
          return const Success(null);
        } catch (_) {
          return const Failure(LocalDatabaseFailure());
        }
      });

  Future<Result<void>> delete(String projectId) => _serialized(() async {
        try {
          if (await _sqlite.ensureReadyIfSupported()) {
            final db = _sqlite.database;
            final rows = await db.query(
              'projects',
              where: 'id = ?',
              whereArgs: [projectId],
              limit: 1,
            );
            if (rows.isEmpty) return const Success(null);
            final nowIso = DateTime.now().toIso8601String();
            final row = Map<String, Object?>.from(rows.first)
              ..['deleted_at'] = nowIso
              ..['updated_at'] = nowIso
              ..['sync_status'] = 'pending';
            await db.transaction((txn) async {
              await txn.update(
                'projects',
                {'deleted_at': nowIso, 'updated_at': nowIso, 'sync_status': 'pending'},
                where: 'id = ?',
                whereArgs: [projectId],
              );
              await _sqlite.enqueueOutbox(
                executor: txn,
                userId: row['user_id'] as String,
                entityType: 'project',
                entityId: projectId,
                operation: 'delete',
                payload: row,
              );
            });
            return const Success(null);
          }

          final records = await _readRecordsLegacy();
          records.removeWhere((record) {
            final project =
                (record['project'] as Map?)?.cast<String, dynamic>() ?? record;
            return project['id'] == projectId;
          });
          await SecureStorageService.instance
              .writeOrThrow(_key, jsonEncode(records));
          return const Success(null);
        } catch (_) {
          return const Failure(LocalDatabaseFailure());
        }
      });

  /// Applies a remote soft-deleted or updated project row from cloud delta pull.
  Future<void> applyRemoteRow(
    Map<String, dynamic> row, {
    List<Map<String, dynamic>> phases = const [],
  }) async {
    if (!await _sqlite.ensureReadyIfSupported()) return;
    await _sqlite.database.transaction((txn) async {
      await txn.insert(
        'projects',
        {
          'id': row['id'],
          'user_id': row['user_id'],
          'title': row['title'],
          'description': row['description'],
          'status': row['status'] ?? 'active',
          'progress_percent': (row['progress_percent'] as num?)?.toDouble() ?? 0.0,
          'next_step_title': row['next_step_title'],
          'target_date': row['target_date'],
          'task_ids_json': row['task_ids_json'] ?? '[]',
          'color_value': (row['color_value'] as num?)?.toInt() ?? 0xFF007067,
          'created_at': row['created_at'],
          'updated_at': row['updated_at'],
          'deleted_at': row['deleted_at'],
          'sync_status': 'synced',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'project_phases',
        where: 'project_id = ?',
        whereArgs: [row['id']],
      );
      for (var i = 0; i < phases.length; i++) {
        await txn.insert(
          'project_phases',
          {
            'project_id': row['id'],
            'phase_order': i,
            'payload_json': jsonEncode(phases[i]),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> phasesForProject(String projectId) async {
    try {
      if (await _sqlite.ensureReadyIfSupported()) {
        final rows = await _sqlite.database.query(
          'project_phases',
          where: 'project_id = ?',
          whereArgs: [projectId],
          orderBy: 'phase_order ASC',
        );
        return [
          for (final r in rows)
            (jsonDecode(r['payload_json'] as String) as Map)
                .cast<String, dynamic>(),
        ];
      }

      final records = await _readRecordsLegacy();
      for (final record in records) {
        final project =
            (record['project'] as Map?)?.cast<String, dynamic>() ?? record;
        if (project['id'] == projectId) {
          final rawPhases = record['phases'];
          if (rawPhases is List) {
            return rawPhases
                .map((e) => (e as Map).cast<String, dynamic>())
                .toList();
          }
        }
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> reassignUserLegacy(String fromUserId, String toUserId) =>
      _serialized(() async {
        if (await _sqlite.ensureReadyIfSupported()) return;
        final records = await _readRecordsLegacy();
        var changed = false;
        for (final rec in records) {
          final proj = (rec['project'] as Map?)?.cast<String, dynamic>() ?? rec;
          if (proj['userId'] == fromUserId) {
            proj['userId'] = toUserId;
            changed = true;
          }
        }
        if (changed) {
          await SecureStorageService.instance
              .writeOrThrow(_key, jsonEncode(records));
        }
      });

  Map<String, Object?> _toRow(Project p) => {
        'id': p.id,
        'user_id': p.userId,
        'title': p.title,
        'description': p.description,
        'status': p.status.name,
        'progress_percent': p.progressPercent,
        'next_step_title': p.nextStepTitle,
        'target_date': p.targetDate?.toIso8601String(),
        'task_ids_json': jsonEncode(p.taskIds),
        'color_value': p.colorValue,
        'created_at': p.createdAt.toIso8601String(),
        'updated_at': p.updatedAt.toIso8601String(),
        'deleted_at': null,
        'sync_status': 'pending',
      };

  Project _fromRow(Map<String, Object?> r) => Project(
        id: r['id'] as String,
        userId: r['user_id'] as String,
        title: r['title'] as String,
        description: r['description'] as String?,
        status: ProjectStatus.values.byName(r['status'] as String),
        progressPercent: (r['progress_percent'] as num).toDouble(),
        nextStepTitle: r['next_step_title'] as String?,
        targetDate: r['target_date'] == null
            ? null
            : DateTime.parse(r['target_date'] as String),
        taskIds:
            (jsonDecode((r['task_ids_json'] as String?) ?? '[]') as List<dynamic>)
                .cast<String>(),
        colorValue: (r['color_value'] as num?)?.toInt() ?? 0xFF007067,
        createdAt: DateTime.parse(r['created_at'] as String),
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );

  Future<List<Project>> _readAllLegacy() async {
    final records = await _readRecordsLegacy();
    return records.map((record) {
      return _fromJson(
        (record['project'] as Map?)?.cast<String, dynamic>() ?? record,
      );
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _readRecordsLegacy() async {
    final raw = await SecureStorageService.instance.readOrThrow(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((value) => (value as Map).cast<String, dynamic>()).toList();
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

  Map<String, dynamic> _toRecord(
    Project p,
    List<Map<String, dynamic>> phases,
  ) =>
      {
        'schema': 1,
        'phases': phases,
        'project': _toJson(p),
      };

  Map<String, dynamic> _toJson(Project p) => {
        'id': p.id,
        'userId': p.userId,
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

  Project _fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        userId: j['userId'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        status: ProjectStatus.values.byName(j['status'] as String),
        progressPercent: (j['progressPercent'] as num).toDouble(),
        nextStepTitle: j['nextStepTitle'] as String?,
        targetDate: j['targetDate'] == null
            ? null
            : DateTime.parse(j['targetDate'] as String),
        taskIds: (j['taskIds'] as List).cast<String>(),
        colorValue: (j['colorValue'] as num?)?.toInt() ?? 0xFF007067,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

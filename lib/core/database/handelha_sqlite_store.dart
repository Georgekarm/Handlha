import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../logger/app_logger.dart';
import '../result/result.dart';
import '../secure_storage/secure_storage_service.dart';

/// Outbox operation queued locally in SQLite until pushed to cloud subcollections.
@immutable
class SyncOutboxItem {
  const SyncOutboxItem({
    required this.opId,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.updatedAt,
    required this.attempts,
    this.nextRetryAt,
    this.lastError,
    required this.createdAt,
  });

  final String opId;
  final String userId;
  final String entityType; // 'task' | 'project' | 'focus_session'
  final String entityId;
  final String operation; // 'upsert' | 'delete'
  final String payloadJson;
  final DateTime updatedAt;
  final int attempts;
  final DateTime? nextRetryAt;
  final String? lastError;
  final DateTime createdAt;

  Map<String, dynamic> decodePayload() =>
      (jsonDecode(payloadJson) as Map).cast<String, dynamic>();
}

/// Summary returned after an automatic or explicit legacy JSON -> SQLite migration.
@immutable
class SqliteMigrationSummary {
  const SqliteMigrationSummary({
    required this.migratedTasks,
    required this.migratedProjects,
    required this.migratedFocusSessions,
    required this.alreadyMigrated,
  });

  final int migratedTasks;
  final int migratedProjects;
  final int migratedFocusSessions;
  final bool alreadyMigrated;
}

/// Normalized, WAL-enabled SQLite database for Handelha's offline-first local storage.
///
/// Tables:
/// - `schema_migrations`: explicit version & legacy migration audit log
/// - `tasks`: normalized tasks with soft-delete tombstones & sync_status
/// - `projects` + `project_phases`: normalized projects with cascading phases
/// - `focus_sessions`: focus session history with sync tracking
/// - `sync_outbox`: durable delta-sync queue with exponential backoff metadata
/// - `sync_cursors`: per-user, per-entity incremental pull timestamps
///
/// On Android/iOS, opens natively via `sqflite`. In desktop/VM tests, activates
/// whenever initialized with `sqflite_common_ffi` via [openInMemoryForTesting] or
/// [openAtPathForTesting]; legacy VM tests that do not initialize FFI cleanly keep
/// their pre-existing mock `SecureStorage` behavior.
class HandelhaSqliteStore {
  HandelhaSqliteStore._();

  static final HandelhaSqliteStore instance = HandelhaSqliteStore._();

  static const String _tag = 'HandelhaSqlite';
  static const String _dbFileName = 'handelha_workspace_v1.db';
  static const int currentDbVersion = 1;
  static const int _legacyJsonMigrationId = 100;
  static const String _legacyBackupKey = 'legacy_pre_sqlite_backup_v1';
  static const _uuid = Uuid();

  Database? _db;
  Completer<void>? _initLock;
  final Map<String, int> _cachedOutboxCounts = {};

  /// Optional observer notified whenever a local mutation is enqueued into `sync_outbox`.
  void Function(String userId)? onOutboxEnqueued;

  bool get isOpen => _db != null && _db!.isOpen;

  /// Synchronous last-known pending outbox count for immediate UI display.
  int cachedPendingOutboxCount(String userId) =>
      _cachedOutboxCounts[userId] ?? 0;

  /// True on real mobile platforms (Android/iOS) where native sqflite is bundled.
  static bool get isNativeMobilePlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Database get database {
    final d = _db;
    if (d == null || !d.isOpen) {
      throw StateError('HandelhaSqliteStore is not initialized.');
    }
    return d;
  }

  /// Ensures SQLite is ready when running on Android/iOS or when explicitly
  /// opened in tests. Returns `false` in legacy desktop/VM tests that rely on
  /// mocked `FlutterSecureStorage` without initializing FFI SQLite.
  Future<bool> ensureReadyIfSupported() async {
    if (isOpen) return true;
    if (!isNativeMobilePlatform) return false;
    await initialize();
    return isOpen;
  }

  /// Opens the production SQLite database on device and runs atomic legacy JSON
  /// migration once if legacy `local_*_v1` records exist.
  Future<void> initialize() async {
    if (isOpen) return;
    if (_initLock != null) {
      await _initLock!.future;
      return;
    }
    final lock = Completer<void>();
    _initLock = lock;
    try {
      final dbDir = await getDatabasesPath();
      final dbPath = p.join(dbDir, _dbFileName);
      _db = await openDatabase(
        dbPath,
        version: currentDbVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      await migrateLegacyJsonIfNeeded();
    } catch (e, st) {
      AppLogger.error(
        'Failed to initialize SQLite database',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      rethrow;
    } finally {
      _initLock = null;
      lock.complete();
    }
  }

  /// Opens an isolated in-memory SQLite database using the supplied [factory]
  /// (e.g. `databaseFactoryFfi`) for deterministic automated testing.
  @visibleForTesting
  Future<void> openInMemoryForTesting({
    required DatabaseFactory factory,
    bool runLegacyMigration = true,
  }) async {
    await closeForTesting();
    _db = await factory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: currentDbVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    if (runLegacyMigration) {
      await migrateLegacyJsonIfNeeded();
    }
  }

  /// Opens a file-backed SQLite database at [path] using [factory] to test
  /// cold-start persistence & reopen survival.
  @visibleForTesting
  Future<void> openAtPathForTesting({
    required DatabaseFactory factory,
    required String path,
    bool runLegacyMigration = true,
  }) async {
    await closeForTesting();
    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: currentDbVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    if (runLegacyMigration) {
      await migrateLegacyJsonIfNeeded();
    }
  }

  @visibleForTesting
  Future<void> closeForTesting() async {
    final existing = _db;
    _db = null;
    _cachedOutboxCounts.clear();
    if (existing != null && existing.isOpen) {
      await existing.close();
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    try {
      await db.rawQuery('PRAGMA journal_mode = WAL');
    } catch (_) {
      // In-memory SQLite databases stay in MEMORY journal mode cleanly.
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE schema_migrations (
        version INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        project_id TEXT,
        parent_task_id TEXT,
        phase_id TEXT,
        depends_on_json TEXT NOT NULL DEFAULT '[]',
        duration_uncertainty TEXT,
        title TEXT NOT NULL,
        description TEXT,
        status TEXT NOT NULL,
        priority TEXT NOT NULL,
        due_at TEXT,
        scheduled_start_at TEXT,
        estimated_duration_minutes INTEGER,
        actual_duration_minutes INTEGER,
        energy_level TEXT NOT NULL,
        source TEXT NOT NULL,
        ai_confidence REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        recurrence TEXT NOT NULL DEFAULT 'none',
        deleted_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_tasks_user_active ON tasks(user_id, deleted_at)',
    );
    await db.execute(
      'CREATE INDEX idx_tasks_user_updated ON tasks(user_id, updated_at)',
    );

    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        status TEXT NOT NULL,
        progress_percent REAL NOT NULL DEFAULT 0.0,
        next_step_title TEXT,
        target_date TEXT,
        task_ids_json TEXT NOT NULL DEFAULT '[]',
        color_value INTEGER NOT NULL DEFAULT 4278218855,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_projects_user ON projects(user_id, deleted_at)',
    );

    await db.execute('''
      CREATE TABLE project_phases (
        project_id TEXT NOT NULL,
        phase_order INTEGER NOT NULL,
        payload_json TEXT NOT NULL,
        PRIMARY KEY (project_id, phase_order),
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE focus_sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        task_id TEXT,
        task_title TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT NOT NULL,
        elapsed_minutes INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_sessions_user ON focus_sessions(user_id, ended_at)',
    );

    await db.execute('''
      CREATE TABLE sync_outbox (
        op_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_retry_at TEXT,
        last_error TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_outbox_user_retry ON sync_outbox(user_id, next_retry_at)',
    );

    await db.execute('''
      CREATE TABLE sync_cursors (
        user_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        last_synced_at TEXT NOT NULL,
        PRIMARY KEY (user_id, entity_type)
      )
    ''');

    await db.insert('schema_migrations', {
      'version': version,
      'applied_at': DateTime.now().toUtc().toIso8601String(),
      'note': 'initial_normalized_sqlite_schema',
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Reserved for future schema upgrades with recorded version audits.
    await db.insert(
      'schema_migrations',
      {
        'version': newVersion,
        'applied_at': DateTime.now().toUtc().toIso8601String(),
        'note': 'upgraded_from_$oldVersion',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Atomically migrates legacy JSON blobs (`local_tasks_v1`, `local_projects_v1`,
  /// `local_focus_sessions_v1`) into normalized SQLite tables inside a single
  /// transaction. Preserves an encrypted pre-migration backup snapshot before
  /// archiving the legacy keys, and rolls back automatically on any corruption.
  Future<Result<SqliteMigrationSummary>> migrateLegacyJsonIfNeeded() async {
    if (!isOpen) {
      return const Failure(LocalDatabaseFailure('SQLite is not open.'));
    }
    final db = database;
    final already = await db.query(
      'schema_migrations',
      where: 'version = ?',
      whereArgs: [_legacyJsonMigrationId],
      limit: 1,
    );
    if (already.isNotEmpty) {
      return const Success(
        SqliteMigrationSummary(
          migratedTasks: 0,
          migratedProjects: 0,
          migratedFocusSessions: 0,
          alreadyMigrated: true,
        ),
      );
    }

    try {
      final rawTasks = await SecureStorageService.instance.readOrThrow(
        'local_tasks_v1',
      );
      final rawProjects = await SecureStorageService.instance.readOrThrow(
        'local_projects_v1',
      );
      final rawSessions = await SecureStorageService.instance.readOrThrow(
        'local_focus_sessions_v1',
      );

      final parsedTasks = _parseLegacyTasks(rawTasks);
      final parsedProjects = _parseLegacyProjects(rawProjects);
      final parsedSessions = _parseLegacySessions(rawSessions);

      final hasLegacyData = parsedTasks.isNotEmpty ||
          parsedProjects.isNotEmpty ||
          parsedSessions.isNotEmpty;

      if (hasLegacyData) {
        // Persist a pre-migration encrypted safety copy before mutating anything.
        await SecureStorageService.instance.writeOrThrow(
          _legacyBackupKey,
          jsonEncode({
            'backedUpAt': DateTime.now().toUtc().toIso8601String(),
            'local_tasks_v1': ?rawTasks,
            'local_projects_v1': ?rawProjects,
            'local_focus_sessions_v1': ?rawSessions,
          }),
        );
      }

      await db.transaction((txn) async {
        for (final t in parsedTasks) {
          await txn.insert(
            'tasks',
            t,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final entry in parsedProjects) {
          await txn.insert(
            'projects',
            entry.projectRow,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await txn.delete(
            'project_phases',
            where: 'project_id = ?',
            whereArgs: [entry.projectRow['id']],
          );
          for (var i = 0; i < entry.phases.length; i++) {
            await txn.insert(
              'project_phases',
              {
                'project_id': entry.projectRow['id'],
                'phase_order': i,
                'payload_json': jsonEncode(entry.phases[i]),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        for (final s in parsedSessions) {
          await txn.insert(
            'focus_sessions',
            s,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Verify row-count integrity inside the transaction before committing.
        if (parsedTasks.isNotEmpty) {
          final taskCount = Sqflite.firstIntValue(
                await txn.rawQuery('SELECT COUNT(*) FROM tasks'),
              ) ??
              0;
          if (taskCount < parsedTasks.length) {
            throw StateError('Migrated task count verification failed.');
          }
        }
        if (parsedProjects.isNotEmpty) {
          final projCount = Sqflite.firstIntValue(
                await txn.rawQuery('SELECT COUNT(*) FROM projects'),
              ) ??
              0;
          if (projCount < parsedProjects.length) {
            throw StateError('Migrated project count verification failed.');
          }
        }
        if (parsedSessions.isNotEmpty) {
          final sessCount = Sqflite.firstIntValue(
                await txn.rawQuery('SELECT COUNT(*) FROM focus_sessions'),
              ) ??
              0;
          if (sessCount < parsedSessions.length) {
            throw StateError('Migrated focus session count verification failed.');
          }
        }

        await txn.insert(
          'schema_migrations',
          {
            'version': _legacyJsonMigrationId,
            'applied_at': DateTime.now().toUtc().toIso8601String(),
            'note':
                'legacy_json_v1_migrated(tasks=${parsedTasks.length},projects=${parsedProjects.length},sessions=${parsedSessions.length})',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });

      // Archive/clear legacy bulk keys ONLY after atomic SQLite commit succeeded.
      if (rawTasks != null) {
        await SecureStorageService.instance.delete('local_tasks_v1');
      }
      if (rawProjects != null) {
        await SecureStorageService.instance.delete('local_projects_v1');
      }
      if (rawSessions != null) {
        await SecureStorageService.instance.delete('local_focus_sessions_v1');
      }

      AppLogger.info(
        'Legacy JSON -> SQLite migration completed (tasks=${parsedTasks.length}, projects=${parsedProjects.length}, sessions=${parsedSessions.length})',
        tag: _tag,
      );
      return Success(
        SqliteMigrationSummary(
          migratedTasks: parsedTasks.length,
          migratedProjects: parsedProjects.length,
          migratedFocusSessions: parsedSessions.length,
          alreadyMigrated: false,
        ),
      );
    } catch (e, st) {
      AppLogger.error(
        'Legacy JSON -> SQLite migration failed; legacy keys left untouched',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      return Failure(
        LocalDatabaseFailure('تعذّر ترحيل البيانات القديمة إلى SQLite: $e'),
      );
    }
  }

  List<Map<String, Object?>> _parseLegacyTasks(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    final List<dynamic> items = decoded is List<dynamic>
        ? decoded
        : ((decoded as Map<String, dynamic>)['items'] as List<dynamic>);
    final out = <Map<String, Object?>>[];
    for (final rawItem in items) {
      final j = (rawItem as Map).cast<String, dynamic>();
      final id = (j['id'] as String).trim();
      final userId = (j['userId'] as String).trim();
      final title = (j['title'] as String).trim();
      if (id.isEmpty || userId.isEmpty || title.isEmpty) {
        throw const FormatException('Corrupt legacy task row');
      }
      out.add({
        'id': id,
        'user_id': userId,
        'project_id': j['projectId'] as String?,
        'parent_task_id': j['parentTaskId'] as String?,
        'phase_id': j['phaseId'] as String?,
        'depends_on_json': jsonEncode(j['dependsOnTaskIds'] ?? const []),
        'duration_uncertainty': j['durationUncertainty'] as String?,
        'title': title,
        'description': j['description'] as String?,
        'status': (j['status'] as String?) ?? 'inbox',
        'priority': (j['priority'] as String?) ?? 'medium',
        'due_at': j['dueAt'] as String?,
        'scheduled_start_at': j['scheduledStartAt'] as String?,
        'estimated_duration_minutes':
            (j['estimatedDurationMinutes'] as num?)?.toInt(),
        'actual_duration_minutes':
            (j['actualDurationMinutes'] as num?)?.toInt(),
        'energy_level': (j['energyLevel'] as String?) ?? 'medium',
        'source': (j['source'] as String?) ?? 'manual',
        'ai_confidence': (j['aiConfidence'] as num?)?.toDouble(),
        'created_at': j['createdAt'] as String,
        'updated_at': j['updatedAt'] as String,
        'version': (j['version'] as num?)?.toInt() ?? 1,
        'sync_status': (j['syncStatus'] as String?) ?? 'pending',
        'recurrence': (j['recurrence'] as String?) ?? 'none',
        'deleted_at': j['deletedAt'] as String?,
      });
    }
    return out;
  }

  List<({Map<String, Object?> projectRow, List<Map<String, dynamic>> phases})>
      _parseLegacyProjects(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    final out =
        <({Map<String, Object?> projectRow, List<Map<String, dynamic>> phases})>[];
    for (final item in list) {
      final rec = (item as Map).cast<String, dynamic>();
      final j = (rec['project'] as Map?)?.cast<String, dynamic>() ?? rec;
      final id = (j['id'] as String).trim();
      final userId = (j['userId'] as String).trim();
      final title = (j['title'] as String).trim();
      if (id.isEmpty || userId.isEmpty || title.isEmpty) {
        throw const FormatException('Corrupt legacy project row');
      }
      final rawPhases = rec['phases'];
      final phases = rawPhases is List
          ? rawPhases
              .whereType<Map>()
              .map((p) => p.cast<String, dynamic>())
              .toList()
          : const <Map<String, dynamic>>[];
      out.add((
        projectRow: {
          'id': id,
          'user_id': userId,
          'title': title,
          'description': j['description'] as String?,
          'status': (j['status'] as String?) ?? 'active',
          'progress_percent': (j['progressPercent'] as num?)?.toDouble() ?? 0.0,
          'next_step_title': j['nextStepTitle'] as String?,
          'target_date': j['targetDate'] as String?,
          'task_ids_json': jsonEncode(j['taskIds'] ?? const []),
          'color_value': (j['colorValue'] as num?)?.toInt() ?? 0xFF007067,
          'created_at': j['createdAt'] as String,
          'updated_at': j['updatedAt'] as String,
          'deleted_at': null,
          'sync_status': 'pending',
        },
        phases: phases,
      ));
    }
    return out;
  }

  List<Map<String, Object?>> _parseLegacySessions(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final items = decoded['items'] as List<dynamic>;
    final out = <Map<String, Object?>>[];
    for (final item in items) {
      final j = (item as Map).cast<String, dynamic>();
      final id = (j['id'] as String).trim();
      final userId = (j['userId'] as String).trim();
      if (id.isEmpty || userId.isEmpty) {
        throw const FormatException('Corrupt legacy focus session row');
      }
      out.add({
        'id': id,
        'user_id': userId,
        'task_id': j['taskId'] as String?,
        'task_title': (j['taskTitle'] as String?) ?? '',
        'started_at': j['startedAt'] as String,
        'ended_at': j['endedAt'] as String,
        'elapsed_minutes': (j['elapsedMinutes'] as num).toInt(),
        'completed': (j['completed'] == true) ? 1 : 0,
        'updated_at': (j['endedAt'] as String),
        'deleted_at': null,
        'sync_status': 'pending',
      });
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Durable Sync Outbox & Cursors (Phase 1 Delta Sync Backbone)
  // ---------------------------------------------------------------------------

  /// Enqueues (or coalesces) a pending sync mutation for `(userId, entityType, entityId)`
  /// inside the active SQLite transaction or DB handle.
  Future<void> enqueueOutbox({
    DatabaseExecutor? executor,
    required String userId,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    DateTime? updatedAt,
  }) async {
    if (!isOpen && executor == null) return;
    final db = executor ?? database;
    final ts = (updatedAt ?? DateTime.now()).toUtc().toIso8601String();
    // Coalesce repeated local edits to the same entity so only the latest state pushes.
    await db.delete(
      'sync_outbox',
      where: 'user_id = ? AND entity_type = ? AND entity_id = ?',
      whereArgs: [userId, entityType, entityId],
    );
    await db.insert('sync_outbox', {
      'op_id': _uuid.v4(),
      'user_id': userId,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload_json': jsonEncode(payload),
      'updated_at': ts,
      'attempts': 0,
      'next_retry_at': null,
      'last_error': null,
      'created_at': ts,
    });
    onOutboxEnqueued?.call(userId);
  }

  Future<List<SyncOutboxItem>> getDueOutboxItems(
    String userId, {
    DateTime? now,
    int limit = 100,
  }) async {
    if (!isOpen) return const [];
    final ref = (now ?? DateTime.now()).toUtc().toIso8601String();
    final rows = await database.query(
      'sync_outbox',
      where: 'user_id = ? AND (next_retry_at IS NULL OR next_retry_at <= ?)',
      whereArgs: [userId, ref],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(_outboxFromRow).toList();
  }

  Future<int> pendingOutboxCount(String userId) async {
    if (!isOpen) return 0;
    final count = Sqflite.firstIntValue(
          await database.rawQuery(
            'SELECT COUNT(*) FROM sync_outbox WHERE user_id = ?',
            [userId],
          ),
        ) ??
        0;
    _cachedOutboxCounts[userId] = count;
    return count;
  }

  Future<bool> hasPendingOutboxForEntity({
    required String userId,
    required String entityType,
    required String entityId,
  }) async {
    if (!isOpen) return false;
    final rows = await database.query(
      'sync_outbox',
      columns: ['op_id'],
      where: 'user_id = ? AND entity_type = ? AND entity_id = ?',
      whereArgs: [userId, entityType, entityId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> clearPendingOutboxForEntity({
    required String userId,
    required String entityType,
    required String entityId,
  }) async {
    if (!isOpen) return;
    await database.delete(
      'sync_outbox',
      where: 'user_id = ? AND entity_type = ? AND entity_id = ?',
      whereArgs: [userId, entityType, entityId],
    );
  }

  Future<void> markOutboxSynced(SyncOutboxItem item) async {
    if (!isOpen) return;
    await database.transaction((txn) async {
      await txn.delete(
        'sync_outbox',
        where: 'op_id = ?',
        whereArgs: [item.opId],
      );
      final table = switch (item.entityType) {
        'task' => 'tasks',
        'project' => 'projects',
        'focus_session' => 'focus_sessions',
        _ => null,
      };
      if (table != null) {
        await txn.update(
          table,
          {'sync_status': 'synced'},
          where: 'id = ? AND user_id = ?',
          whereArgs: [item.entityId, item.userId],
        );
      }
    });
  }

  Future<void> markOutboxFailed(
    SyncOutboxItem item, {
    required String error,
    DateTime? now,
  }) async {
    if (!isOpen) return;
    final nextAttempts = item.attempts + 1;
    final backoffSec = (30 * (1 << (nextAttempts - 1).clamp(0, 8))).clamp(30, 3600);
    final nextRetry = (now ?? DateTime.now())
        .toUtc()
        .add(Duration(seconds: backoffSec))
        .toIso8601String();
    await database.update(
      'sync_outbox',
      {
        'attempts': nextAttempts,
        'next_retry_at': nextRetry,
        'last_error': error,
      },
      where: 'op_id = ?',
      whereArgs: [item.opId],
    );
  }

  Future<DateTime?> getSyncCursor(String userId, String entityType) async {
    if (!isOpen) return null;
    final rows = await database.query(
      'sync_cursors',
      where: 'user_id = ? AND entity_type = ?',
      whereArgs: [userId, entityType],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['last_synced_at'].toString());
  }

  Future<void> setSyncCursor(
    String userId,
    String entityType,
    DateTime cursor,
  ) async {
    if (!isOpen) return;
    await database.insert(
      'sync_cursors',
      {
        'user_id': userId,
        'entity_type': entityType,
        'last_synced_at': cursor.toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Reassigns all local SQLite records from a local guest profile (`local_*`)
  /// to a newly authenticated cloud account [toUserId] and queues them for upload.
  Future<void> reassignUserWorkspace({
    required String fromUserId,
    required String toUserId,
  }) async {
    if (!isOpen || fromUserId == toUserId) return;
    await database.transaction((txn) async {
      await txn.update(
        'tasks',
        {'user_id': toUserId, 'sync_status': 'pending'},
        where: 'user_id = ?',
        whereArgs: [fromUserId],
      );
      await txn.update(
        'projects',
        {'user_id': toUserId, 'sync_status': 'pending'},
        where: 'user_id = ?',
        whereArgs: [fromUserId],
      );
      await txn.update(
        'focus_sessions',
        {'user_id': toUserId, 'sync_status': 'pending'},
        where: 'user_id = ?',
        whereArgs: [fromUserId],
      );
      await txn.update(
        'sync_outbox',
        {'user_id': toUserId},
        where: 'user_id = ?',
        whereArgs: [fromUserId],
      );
      await txn.delete(
        'sync_cursors',
        where: 'user_id = ?',
        whereArgs: [fromUserId],
      );

      // Ensure every migrated entity has a pending outbox entry so first sync pushes it.
      final tasks = await txn.query(
        'tasks',
        where: 'user_id = ?',
        whereArgs: [toUserId],
      );
      for (final row in tasks) {
        await enqueueOutbox(
          executor: txn,
          userId: toUserId,
          entityType: 'task',
          entityId: row['id'] as String,
          operation: row['deleted_at'] != null ? 'delete' : 'upsert',
          payload: Map<String, dynamic>.from(row),
          updatedAt: DateTime.tryParse(row['updated_at'].toString()),
        );
      }

      final projects = await txn.query(
        'projects',
        where: 'user_id = ?',
        whereArgs: [toUserId],
      );
      for (final row in projects) {
        final phases = await txn.query(
          'project_phases',
          where: 'project_id = ?',
          whereArgs: [row['id']],
          orderBy: 'phase_order ASC',
        );
        await enqueueOutbox(
          executor: txn,
          userId: toUserId,
          entityType: 'project',
          entityId: row['id'] as String,
          operation: row['deleted_at'] != null ? 'delete' : 'upsert',
          payload: {
            ...Map<String, dynamic>.from(row),
            'phases_json': jsonEncode([
              for (final ph in phases) jsonDecode(ph['payload_json'] as String),
            ]),
          },
          updatedAt: DateTime.tryParse(row['updated_at'].toString()),
        );
      }

      final sessions = await txn.query(
        'focus_sessions',
        where: 'user_id = ?',
        whereArgs: [toUserId],
      );
      for (final row in sessions) {
        await enqueueOutbox(
          executor: txn,
          userId: toUserId,
          entityType: 'focus_session',
          entityId: row['id'] as String,
          operation: row['deleted_at'] != null ? 'delete' : 'upsert',
          payload: Map<String, dynamic>.from(row),
          updatedAt: DateTime.tryParse(row['updated_at'].toString()),
        );
      }
    });
  }

  Future<void> clearAllSyncMetadataForUser(String userId) async {
    if (!isOpen) return;
    await database.transaction((txn) async {
      await txn.delete('sync_outbox', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('sync_cursors', where: 'user_id = ?', whereArgs: [userId]);
    });
  }

  SyncOutboxItem _outboxFromRow(Map<String, Object?> row) => SyncOutboxItem(
        opId: row['op_id'] as String,
        userId: row['user_id'] as String,
        entityType: row['entity_type'] as String,
        entityId: row['entity_id'] as String,
        operation: row['operation'] as String,
        payloadJson: row['payload_json'] as String,
        updatedAt: DateTime.parse(row['updated_at'] as String),
        attempts: (row['attempts'] as num?)?.toInt() ?? 0,
        nextRetryAt: row['next_retry_at'] == null
            ? null
            : DateTime.tryParse(row['next_retry_at'] as String),
        lastError: row['last_error'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}

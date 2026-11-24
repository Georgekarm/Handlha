import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/notifications/local_notification_service.dart';
import '../../features/projects/domain/focus_session.dart';
import '../../features/tasks/domain/task.dart';
import '../database/handelha_sqlite_store.dart';
import '../database/local_focus_session_database.dart';
import '../database/local_project_database.dart';
import '../database/local_task_database.dart';
import '../logger/app_logger.dart';
import '../result/result.dart';
import 'firebase_cloud_service.dart';

/// Vendor-agnostic contract for per-entity cloud delta synchronization.
///
/// Implementing this interface keeps Handelha's offline-first SQLite + outbox
/// layer decoupled from any single cloud vendor (Firebase Firestore today,
/// Supabase/Postgres or a custom REST API tomorrow).
abstract interface class CloudSyncGateway {
  bool get isEnabled;

  Future<Result<void>> pushEntity({
    required String userId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  });

  Future<Result<List<Map<String, dynamic>>>> pullEntities({
    required String userId,
    required String entityType,
    DateTime? since,
  });
}

/// Firestore subcollections implementation of [CloudSyncGateway].
///
/// Stores each entity independently under:
/// - `users/{uid}/tasks/{taskId}`
/// - `users/{uid}/projects/{projectId}`
/// - `users/{uid}/focus_sessions/{sessionId}`
/// avoiding the 1 MiB single-document ceiling and whole-workspace overwrite races.
final class FirebaseSubcollectionSyncGateway implements CloudSyncGateway {
  FirebaseSubcollectionSyncGateway({FirebaseCloudService? cloudService})
      : _cloud = cloudService ?? FirebaseCloudService.instance;

  final FirebaseCloudService _cloud;

  @override
  bool get isEnabled => _cloud.isEnabled;

  static String? _collectionFor(String entityType) => switch (entityType) {
        'task' => 'tasks',
        'project' => 'projects',
        'focus_session' => 'focus_sessions',
        _ => null,
      };

  @override
  Future<Result<void>> pushEntity({
    required String userId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final collection = _collectionFor(entityType);
    if (collection == null) {
      return Failure(ValidationFailure('نوع كيان مزامنة غير مدعوم: $entityType'));
    }
    final normalized = Map<String, dynamic>.from(payload);
    normalized['id'] = entityId;
    normalized['user_id'] = userId;
    final rawUpdated = normalized['updated_at']?.toString();
    final parsedUpdated = rawUpdated == null ? null : DateTime.tryParse(rawUpdated);
    normalized['updated_at'] =
        (parsedUpdated ?? DateTime.now()).toUtc().toIso8601String();
    return _cloud.upsertSubcollectionDoc(
      userId: userId,
      collection: collection,
      docId: entityId,
      fields: normalized,
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> pullEntities({
    required String userId,
    required String entityType,
    DateTime? since,
  }) async {
    final collection = _collectionFor(entityType);
    if (collection == null) {
      return const Success([]);
    }
    return _cloud.listSubcollectionDocs(
      userId: userId,
      collection: collection,
      updatedAfter: since,
    );
  }
}

/// Outcome report of a single [CloudSyncEngine.syncUser] delta cycle.
@immutable
class SyncRunSummary {
  const SyncRunSummary({
    required this.pushedCount,
    required this.pulledCount,
    required this.conflictsResolved,
    required this.failedCount,
    required this.remainingOutboxCount,
    required this.syncedAt,
    this.localOnly = false,
    this.lastError,
  });

  factory SyncRunSummary.localOnly(DateTime now) => SyncRunSummary(
        pushedCount: 0,
        pulledCount: 0,
        conflictsResolved: 0,
        failedCount: 0,
        remainingOutboxCount: 0,
        syncedAt: now.toUtc(),
        localOnly: true,
      );

  final int pushedCount;
  final int pulledCount;
  final int conflictsResolved;
  final int failedCount;
  final int remainingOutboxCount;
  final DateTime syncedAt;
  final bool localOnly;
  final String? lastError;

  bool get isClean => failedCount == 0 && lastError == null;
}

/// Offline-first delta sync coordinator:
/// 1. Drains due items from SQLite `sync_outbox` with exponential backoff on errors.
/// 2. Pulls remote documents changed since `sync_cursors` per subcollection.
/// 3. Resolves per-item conflicts deterministically (Last-Write-Wins on UTC `updated_at`,
///    preserving newer pending local mutations and applying soft-delete tombstones).
/// 4. Surfaces truthful [CloudSyncStatus] back to Settings UI.
class CloudSyncEngine {
  CloudSyncEngine({
    CloudSyncGateway? gateway,
    HandelhaSqliteStore? sqlite,
    LocalTaskDatabase? tasksDb,
    LocalProjectDatabase? projectsDb,
    LocalFocusSessionDatabase? focusDb,
    void Function(CloudSyncStatus status)? onStatusUpdate,
  })  : _gateway = gateway ?? FirebaseSubcollectionSyncGateway(),
        _sqlite = sqlite ?? HandelhaSqliteStore.instance,
        _tasksDb = tasksDb ?? LocalTaskDatabase.instance,
        _projectsDb = projectsDb ?? LocalProjectDatabase.instance,
        _focusDb = focusDb ?? LocalFocusSessionDatabase.instance,
        _onStatusUpdate =
            onStatusUpdate ?? FirebaseCloudService.instance.updateSyncStatus {
    _sqlite.onOutboxEnqueued ??= (uid) => scheduleAutoSync(uid);
  }

  static final CloudSyncEngine instance = CloudSyncEngine();

  static const String _tag = 'CloudSyncEngine';
  static const List<String> _entityTypes = ['task', 'project', 'focus_session'];

  final CloudSyncGateway _gateway;
  final HandelhaSqliteStore _sqlite;
  final LocalTaskDatabase _tasksDb;
  final LocalProjectDatabase _projectsDb;
  final LocalFocusSessionDatabase _focusDb;
  final void Function(CloudSyncStatus status) _onStatusUpdate;

  final Map<String, Future<Result<SyncRunSummary>>> _inFlight = {};
  final Map<String, Timer> _autoSyncTimers = {};

  bool get _isFlutterTestEnv {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Schedules a debounced automatic background delta sync for [userId] after
  /// local mutations or app resume. No-ops cleanly for local guest workspaces,
  /// unconfigured cloud builds, or widget tests (unless [allowInTests] is true).
  void scheduleAutoSync(
    String userId, {
    Duration delay = const Duration(seconds: 3),
    bool allowInTests = false,
  }) {
    final cleanId = userId.trim();
    if (!_gateway.isEnabled ||
        cleanId.isEmpty ||
        cleanId.startsWith('local_') ||
        (_isFlutterTestEnv && !allowInTests)) {
      return;
    }
    _autoSyncTimers.remove(cleanId)?.cancel();
    _autoSyncTimers[cleanId] = Timer(delay, () {
      _autoSyncTimers.remove(cleanId);
      unawaited(syncUser(cleanId));
    });
  }

  /// Cancels any pending auto-sync timer(s).
  void cancelAutoSync([String? userId]) {
    if (userId != null) {
      _autoSyncTimers.remove(userId)?.cancel();
      return;
    }
    for (final timer in _autoSyncTimers.values) {
      timer.cancel();
    }
    _autoSyncTimers.clear();
  }

  Future<Result<SyncRunSummary>> syncUser(
    String userId, {
    DateTime? now,
  }) {
    final existing = _inFlight[userId];
    if (existing != null) return existing;
    final run = _syncUserInternal(userId, now: now).whenComplete(() {
      _inFlight.remove(userId);
    });
    _inFlight[userId] = run;
    return run;
  }

  Future<Result<SyncRunSummary>> _syncUserInternal(
    String userId, {
    DateTime? now,
  }) async {
    final refNow = (now ?? DateTime.now()).toUtc();
    if (!_gateway.isEnabled ||
        userId.trim().isEmpty ||
        userId.startsWith('local_')) {
      return Success(SyncRunSummary.localOnly(refNow));
    }

    if (!await _sqlite.ensureReadyIfSupported()) {
      return Success(SyncRunSummary.localOnly(refNow));
    }

    var pushedCount = 0;
    var pulledCount = 0;
    var conflictsResolved = 0;
    var failedCount = 0;
    String? lastError;
    var authExpired = false;

    // -------------------------------------------------------------------------
    // Phase A: Push due local mutations from sync_outbox
    // -------------------------------------------------------------------------
    final dueItems = await _sqlite.getDueOutboxItems(userId, now: refNow);
    for (final item in dueItems) {
      Map<String, dynamic> payload;
      try {
        payload = item.decodePayload();
      } catch (e) {
        await _sqlite.markOutboxFailed(
          item,
          error: 'Corrupt outbox payload: $e',
          now: refNow,
        );
        failedCount++;
        lastError ??= 'تلف مؤقت في عنصر المزامنة.';
        continue;
      }

      final pushRes = await _gateway.pushEntity(
        userId: userId,
        entityType: item.entityType,
        entityId: item.entityId,
        payload: payload,
      );

      if (pushRes is Success<void>) {
        await _sqlite.markOutboxSynced(item);
        pushedCount++;
      } else {
        final failure = (pushRes as Failure<void>).failure;
        await _sqlite.markOutboxFailed(
          item,
          error: failure.message,
          now: refNow,
        );
        failedCount++;
        lastError ??= failure.message;
        if (failure is AuthFailure) {
          authExpired = true;
          break;
        }
      }
    }

    // -------------------------------------------------------------------------
    // Phase B: Pull incremental remote deltas per subcollection
    // -------------------------------------------------------------------------
    if (!authExpired) {
      for (final entityType in _entityTypes) {
        final cursor = await _sqlite.getSyncCursor(userId, entityType);
        final pullRes = await _gateway.pullEntities(
          userId: userId,
          entityType: entityType,
          since: cursor,
        );

        if (pullRes is Failure<List<Map<String, dynamic>>>) {
          failedCount++;
          lastError ??= pullRes.failure.message;
          if (pullRes.failure is AuthFailure) {
            authExpired = true;
            break;
          }
          continue;
        }

        final remoteRows = (pullRes as Success<List<Map<String, dynamic>>>).data;
        DateTime? maxRemoteUpdated = cursor;

        for (final rawRow in remoteRows) {
          final id = rawRow['id']?.toString().trim() ?? '';
          if (id.isEmpty) continue;

          final row = Map<String, dynamic>.from(rawRow);
          row['id'] = id;
          row['user_id'] = userId;

          final remoteUpdated = _parseUtc(row['updated_at']);
          if (remoteUpdated != null &&
              (maxRemoteUpdated == null ||
                  remoteUpdated.isAfter(maxRemoteUpdated))) {
            maxRemoteUpdated = remoteUpdated;
          }

          final outcome = await _applyRemoteEntity(
            userId: userId,
            entityType: entityType,
            entityId: id,
            row: row,
            remoteUpdated: remoteUpdated,
          );
          if (outcome.applied) pulledCount++;
          if (outcome.conflictResolved) conflictsResolved++;
        }

        await _sqlite.setSyncCursor(
          userId,
          entityType,
          maxRemoteUpdated ?? refNow,
        );
      }
    }

    final remaining = await _sqlite.pendingOutboxCount(userId);
    final summary = SyncRunSummary(
      pushedCount: pushedCount,
      pulledCount: pulledCount,
      conflictsResolved: conflictsResolved,
      failedCount: failedCount,
      remainingOutboxCount: remaining,
      syncedAt: refNow,
      lastError: lastError,
    );

    if (authExpired) {
      _onStatusUpdate(
        CloudSyncStatus(
          state: CloudSyncState.authExpired,
          lastError: lastError ?? 'انتهت جلسة المزامنة السحابية. سجّل الدخول مرة تانية.',
        ),
      );
    } else if (failedCount > 0) {
      _onStatusUpdate(
        CloudSyncStatus(
          state: CloudSyncState.failed,
          lastError: lastError ?? 'تعذّر إتمام بعض عمليات المزامنة وسيتم إعادة المحاولة تلقائيًا.',
        ),
      );
    } else {
      _onStatusUpdate(
        CloudSyncStatus(
          state: CloudSyncState.synced,
          lastSyncedAt: refNow,
        ),
      );
    }

    AppLogger.info(
      'Delta sync finished (pushed=$pushedCount, pulled=$pulledCount, conflicts=$conflictsResolved, failed=$failedCount, remaining=$remaining)',
      tag: _tag,
    );
    return Success(summary);
  }

  Future<({bool applied, bool conflictResolved})> _applyRemoteEntity({
    required String userId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> row,
    required DateTime? remoteUpdated,
  }) async {
    final hasPending = await _sqlite.hasPendingOutboxForEntity(
      userId: userId,
      entityType: entityType,
      entityId: entityId,
    );

    switch (entityType) {
      case 'task':
        final local = await _tasksDb.getTaskIncludingDeleted(entityId);
        if (local != null) {
          final localUpdated = local.updatedAt.toUtc();
          if (hasPending) {
            if (remoteUpdated == null || !remoteUpdated.isAfter(localUpdated)) {
              // Keep newer local pending edit; it will push to cloud.
              return (applied: false, conflictResolved: true);
            }
            // Remote is strictly newer: supersede local pending edit cleanly.
            await _sqlite.clearPendingOutboxForEntity(
              userId: userId,
              entityType: 'task',
              entityId: entityId,
            );
            final remoteTask = _parseRemoteTask(row);
            if (remoteTask == null) {
              return (applied: false, conflictResolved: false);
            }
            await _tasksDb.upsertTasks([remoteTask], enqueueSync: false);
            await _syncTaskNotification(remoteTask);
            return (applied: true, conflictResolved: true);
          }
          if (remoteUpdated != null && !remoteUpdated.isAfter(localUpdated)) {
            return (applied: false, conflictResolved: false);
          }
        }
        final remoteTask = _parseRemoteTask(row);
        if (remoteTask == null) {
          return (applied: false, conflictResolved: false);
        }
        await _tasksDb.upsertTasks([remoteTask], enqueueSync: false);
        await _syncTaskNotification(remoteTask);
        return (applied: true, conflictResolved: false);

      case 'project':
        final localRows = await _sqlite.database.query(
          'projects',
          columns: ['updated_at'],
          where: 'id = ?',
          whereArgs: [entityId],
          limit: 1,
        );
        if (localRows.isNotEmpty) {
          final localUpdated = _parseUtc(localRows.first['updated_at']);
          if (hasPending) {
            if (remoteUpdated == null ||
                (localUpdated != null && !remoteUpdated.isAfter(localUpdated))) {
              return (applied: false, conflictResolved: true);
            }
            await _sqlite.clearPendingOutboxForEntity(
              userId: userId,
              entityType: 'project',
              entityId: entityId,
            );
            await _applyRemoteProject(row);
            return (applied: true, conflictResolved: true);
          }
          if (localUpdated != null &&
              remoteUpdated != null &&
              !remoteUpdated.isAfter(localUpdated)) {
            return (applied: false, conflictResolved: false);
          }
        }
        await _applyRemoteProject(row);
        return (applied: true, conflictResolved: false);

      case 'focus_session':
        final localRows = await _sqlite.database.query(
          'focus_sessions',
          columns: ['updated_at'],
          where: 'id = ?',
          whereArgs: [entityId],
          limit: 1,
        );
        if (localRows.isNotEmpty) {
          final localUpdated = _parseUtc(localRows.first['updated_at']);
          if (hasPending) {
            if (remoteUpdated == null ||
                (localUpdated != null && !remoteUpdated.isAfter(localUpdated))) {
              return (applied: false, conflictResolved: true);
            }
            await _sqlite.clearPendingOutboxForEntity(
              userId: userId,
              entityType: 'focus_session',
              entityId: entityId,
            );
            await _applyRemoteFocusSession(row);
            return (applied: true, conflictResolved: true);
          }
          if (localUpdated != null &&
              remoteUpdated != null &&
              !remoteUpdated.isAfter(localUpdated)) {
            return (applied: false, conflictResolved: false);
          }
        }
        await _applyRemoteFocusSession(row);
        return (applied: true, conflictResolved: false);

      default:
        return (applied: false, conflictResolved: false);
    }
  }

  Future<void> _syncTaskNotification(Task task) async {
    try {
      if (task.deletedAt != null || task.isCompleted || task.isCancelled) {
        await LocalNotificationService.instance.cancelTask(task.id);
      } else {
        await LocalNotificationService.instance.scheduleTask(task);
      }
    } catch (_) {}
  }

  Task? _parseRemoteTask(Map<String, dynamic> row) {
    try {
      final normalized = Map<String, dynamic>.from(row);
      normalized['sync_status'] = SyncStatus.synced.name;
      normalized['depends_on_json'] ??= '[]';
      normalized['status'] ??= TaskStatus.inbox.name;
      normalized['priority'] ??= TaskPriority.medium.name;
      normalized['energy_level'] ??= EnergyLevel.medium.name;
      normalized['source'] ??= TaskSource.manual.name;
      normalized['recurrence'] ??= TaskRecurrence.none.name;
      normalized['created_at'] ??=
          normalized['updated_at'] ?? DateTime.now().toUtc().toIso8601String();
      normalized['updated_at'] ??= normalized['created_at'];
      return _tasksDb.taskFromRowMap(normalized);
    } catch (e) {
      AppLogger.warning(
        'Skipped malformed remote task document',
        tag: _tag,
        error: e,
      );
      return null;
    }
  }

  Future<void> _applyRemoteProject(Map<String, dynamic> row) async {
    var phases = const <Map<String, dynamic>>[];
    final rawPhases = row['phases_json'];
    if (rawPhases is String && rawPhases.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPhases);
        if (decoded is List) {
          phases = decoded
              .whereType<Map>()
              .map((m) => m.cast<String, dynamic>())
              .toList();
        }
      } catch (_) {}
    }
    await _projectsDb.applyRemoteRow(row, phases: phases);
  }

  Future<void> _applyRemoteFocusSession(Map<String, dynamic> row) async {
    if (row['deleted_at'] != null) {
      await _sqlite.database.insert(
        'focus_sessions',
        {
          'id': row['id'],
          'user_id': row['user_id'],
          'task_id': row['task_id'],
          'task_title': (row['task_title'] as String?) ?? '',
          'started_at':
              (row['started_at'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
          'ended_at':
              (row['ended_at'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
          'elapsed_minutes': (row['elapsed_minutes'] as num?)?.toInt() ?? 0,
          'completed': ((row['completed'] == true) ||
                  ((row['completed'] as num?)?.toInt() == 1))
              ? 1
              : 0,
          'updated_at':
              (row['updated_at'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
          'deleted_at': row['deleted_at'].toString(),
          'sync_status': 'synced',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }
    final session = FocusSession(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      taskId: row['task_id'] as String?,
      taskTitle: (row['task_title'] as String?) ?? '',
      startedAt: DateTime.parse(row['started_at'] as String),
      endedAt: DateTime.parse(row['ended_at'] as String),
      elapsedMinutes: (row['elapsed_minutes'] as num?)?.toInt() ?? 0,
      completed: (row['completed'] == true) ||
          ((row['completed'] as num?)?.toInt() == 1),
    );
    await _focusDb.upsertSessions([session], enqueueSync: false);
  }

  DateTime? _parseUtc(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toUtc();
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handelha/app/theme/app_theme.dart';
import 'package:handelha/core/cloud/cloud_sync_engine.dart';
import 'package:handelha/core/cloud/firebase_cloud_service.dart';
import 'package:handelha/core/database/handelha_sqlite_store.dart';
import 'package:handelha/core/database/local_focus_session_database.dart';
import 'package:handelha/core/database/local_project_database.dart';
import 'package:handelha/core/database/local_task_database.dart';
import 'package:handelha/core/result/result.dart';
import 'package:handelha/core/secure_storage/secure_storage_service.dart';
import 'package:handelha/features/assistant/data/user_energy_preferences.dart';
import 'package:handelha/features/authentication/data/local_auth_repository.dart';
import 'package:handelha/features/authentication/domain/app_user.dart';
import 'package:handelha/features/authentication/presentation/auth_providers.dart';
import 'package:handelha/features/authentication/presentation/login_screen.dart';
import 'package:handelha/features/notifications/alarm_reminder_store.dart';
import 'package:handelha/features/projects/data/exam_grades_store.dart';
import 'package:handelha/features/projects/domain/focus_session.dart';
import 'package:handelha/features/projects/domain/project.dart';
import 'package:handelha/features/settings/presentation/settings_screen.dart';
import 'package:handelha/features/tasks/domain/task.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await HandelhaSqliteStore.instance.closeForTesting();
  });

  tearDown(() async {
    await HandelhaSqliteStore.instance.closeForTesting();
  });

  group('Phase 1 — Normalized SQLite Store & Cold-Start Persistence', () {
    test('persists tasks, projects+phases, focus sessions & outbox across file reopen and honors soft-delete & cascade', () async {
      final tempDir = await Directory.systemTemp.createTemp('handelha_sqlite_');
      addTearDown(() async {
        await HandelhaSqliteStore.instance.closeForTesting();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final dbPath = p.join(tempDir.path, 'phase1_test.db');

      await HandelhaSqliteStore.instance.openAtPathForTesting(
        factory: databaseFactoryFfi,
        path: dbPath,
        runLegacyMigration: false,
      );

      const userId = 'u-sqlite-persist';
      final createdTask = await LocalTaskDatabase.instance.createTask(
        userId: userId,
        title: 'تجهيز ملف SQLite',
        priority: TaskPriority.high,
        recurrence: TaskRecurrence.monthly,
        dependsOnTaskIds: const ['dep-1'],
      );
      expect(createdTask, isA<Success<Task>>());
      final task = (createdTask as Success<Task>).data;

      final project = Project(
        id: 'proj-sql-1',
        userId: userId,
        title: 'إطلاق بلاي ستور',
        status: ProjectStatus.active,
        progressPercent: 0.4,
        taskIds: [task.id],
        createdAt: DateTime.utc(2026, 11, 20),
        updatedAt: DateTime.utc(2026, 11, 20),
      );
      final saveProj = await LocalProjectDatabase.instance.save(
        project,
        phases: const [
          {'id': 'ph-1', 'title': 'المرحلة الأولى', 'done': true},
          {'id': 'ph-2', 'title': 'المرحلة الثانية', 'done': false},
        ],
      );
      expect(saveProj, isA<Success<void>>());

      final recSess = await LocalFocusSessionDatabase.instance.record(
        userId: userId,
        taskId: task.id,
        taskTitle: task.title,
        startedAt: DateTime.utc(2026, 11, 20, 10, 0),
        endedAt: DateTime.utc(2026, 11, 20, 10, 25),
        elapsedMinutes: 25,
        completed: true,
      );
      expect(recSess, isA<Success<FocusSession>>());

      // Cold restart: close DB handle completely and reopen at the same file path.
      await HandelhaSqliteStore.instance.closeForTesting();
      await HandelhaSqliteStore.instance.openAtPathForTesting(
        factory: databaseFactoryFfi,
        path: dbPath,
        runLegacyMigration: false,
      );

      final loadedTasks =
          (await LocalTaskDatabase.instance.getTasksForUser(userId)
                  as Success<List<Task>>)
              .data;
      expect(loadedTasks, hasLength(1));
      expect(loadedTasks.single.title, 'تجهيز ملف SQLite');
      expect(loadedTasks.single.recurrence, TaskRecurrence.monthly);
      expect(loadedTasks.single.dependsOnTaskIds, ['dep-1']);

      final loadedProjects =
          (await LocalProjectDatabase.instance.forUser(userId)
                  as Success<List<Project>>)
              .data;
      expect(loadedProjects, hasLength(1));
      final loadedPhases =
          await LocalProjectDatabase.instance.phasesForProject('proj-sql-1');
      expect(loadedPhases, hasLength(2));
      expect(loadedPhases.first['title'], 'المرحلة الأولى');

      final loadedSessions =
          (await LocalFocusSessionDatabase.instance.forUser(userId)
                  as Success<List<FocusSession>>)
              .data;
      expect(loadedSessions, hasLength(1));
      expect(loadedSessions.single.elapsedMinutes, 25);

      // Soft-delete task keeps tombstone for sync while hiding from active query.
      await LocalTaskDatabase.instance.deleteTask(task.id);
      final activeAfterDelete =
          (await LocalTaskDatabase.instance.getTasksForUser(userId)
                  as Success<List<Task>>)
              .data;
      expect(activeAfterDelete, isEmpty);
      final tombstone =
          await LocalTaskDatabase.instance.getTaskIncludingDeleted(task.id);
      expect(tombstone, isNotNull);
      expect(tombstone!.deletedAt, isNotNull);

      final outbox = await HandelhaSqliteStore.instance.getDueOutboxItems(userId);
      final taskOp = outbox.firstWhere((o) => o.entityId == task.id);
      expect(taskOp.operation, 'delete');

      // Hard-clear project triggers ON DELETE CASCADE on project_phases.
      await LocalProjectDatabase.instance.clearForUser(userId);
      final phasesAfterCascade =
          await LocalProjectDatabase.instance.phasesForProject('proj-sql-1');
      expect(phasesAfterCascade, isEmpty);
    });
  });

  group('Phase 1 — Atomic Legacy JSON -> SQLite Migration', () {
    test('migrates legacy v1 tasks, projects+phases, and sessions once, saves rollback backup, and stays idempotent', () async {
      final nowIso = DateTime.utc(2026, 11, 21, 9, 0).toIso8601String();
      FlutterSecureStorage.setMockInitialValues({
        'local_tasks_v1': jsonEncode({
          'schema': 2,
          'items': [
            {
              'id': 'legacy-t1',
              'userId': 'u-legacy',
              'title': 'مهمة قديمة ١',
              'status': 'planned',
              'priority': 'high',
              'energyLevel': 'high',
              'source': 'manual',
              'createdAt': nowIso,
              'updatedAt': nowIso,
              'version': 2,
              'syncStatus': 'pending',
              'recurrence': 'weekly',
            },
            {
              'id': 'legacy-t2',
              'userId': 'u-legacy',
              'title': 'مهمة قديمة ٢',
              'status': 'inbox',
              'priority': 'medium',
              'energyLevel': 'medium',
              'source': 'manual',
              'createdAt': nowIso,
              'updatedAt': nowIso,
              'version': 1,
              'syncStatus': 'pending',
            },
          ],
        }),
        'local_projects_v1': jsonEncode([
          {
            'schema': 1,
            'project': {
              'id': 'legacy-p1',
              'userId': 'u-legacy',
              'title': 'مشروع قديم',
              'status': 'active',
              'progressPercent': 0.5,
              'taskIds': ['legacy-t1'],
              'createdAt': nowIso,
              'updatedAt': nowIso,
            },
            'phases': [
              {'id': 'lp-1', 'title': 'تحليل'},
              {'id': 'lp-2', 'title': 'تنفيذ'},
            ],
          },
        ]),
        'local_focus_sessions_v1': jsonEncode({
          'schema': 1,
          'items': [
            {
              'id': 'legacy-s1',
              'userId': 'u-legacy',
              'taskId': 'legacy-t1',
              'taskTitle': 'مهمة قديمة ١',
              'startedAt': nowIso,
              'endedAt': nowIso,
              'elapsedMinutes': 30,
              'completed': true,
            },
          ],
        }),
      });

      await HandelhaSqliteStore.instance.openInMemoryForTesting(
        factory: databaseFactoryFfi,
        runLegacyMigration: false,
      );

      final firstRun =
          await HandelhaSqliteStore.instance.migrateLegacyJsonIfNeeded();
      expect(firstRun, isA<Success<SqliteMigrationSummary>>());
      final summary = (firstRun as Success<SqliteMigrationSummary>).data;
      expect(summary.alreadyMigrated, isFalse);
      expect(summary.migratedTasks, 2);
      expect(summary.migratedProjects, 1);
      expect(summary.migratedFocusSessions, 1);

      // Verify pre-migration encrypted backup exists and old bulk keys were archived.
      final backupRaw = await SecureStorageService.instance.read(
        'legacy_pre_sqlite_backup_v1',
      );
      expect(backupRaw, isNotNull);
      expect(backupRaw, contains('legacy-t1'));
      expect(await SecureStorageService.instance.read('local_tasks_v1'), isNull);
      expect(
        await SecureStorageService.instance.read('local_projects_v1'),
        isNull,
      );
      expect(
        await SecureStorageService.instance.read('local_focus_sessions_v1'),
        isNull,
      );

      // Verify migrated rows in SQLite.
      final tasks = (await LocalTaskDatabase.instance.getTasksForUser('u-legacy')
              as Success<List<Task>>)
          .data;
      expect(tasks, hasLength(2));
      expect(tasks.firstWhere((t) => t.id == 'legacy-t1').recurrence,
          TaskRecurrence.weekly);
      final phases =
          await LocalProjectDatabase.instance.phasesForProject('legacy-p1');
      expect(phases, hasLength(2));
      final sessions =
          (await LocalFocusSessionDatabase.instance.forUser('u-legacy')
                  as Success<List<FocusSession>>)
              .data;
      expect(sessions, hasLength(1));

      // Second migration call is strictly idempotent.
      final secondRun =
          await HandelhaSqliteStore.instance.migrateLegacyJsonIfNeeded();
      expect((secondRun as Success<SqliteMigrationSummary>).data.alreadyMigrated,
          isTrue);
      expect(
        (await LocalTaskDatabase.instance.getTasksForUser('u-legacy')
                as Success<List<Task>>)
            .data,
        hasLength(2),
      );
    });

    test('fails safely on corrupt legacy JSON without erasing original keys', () async {
      FlutterSecureStorage.setMockInitialValues({
        'local_tasks_v1': '{broken_json',
      });
      await HandelhaSqliteStore.instance.openInMemoryForTesting(
        factory: databaseFactoryFfi,
        runLegacyMigration: false,
      );

      final res = await HandelhaSqliteStore.instance.migrateLegacyJsonIfNeeded();
      expect(res, isA<Failure<SqliteMigrationSummary>>());
      expect(
        await SecureStorageService.instance.read('local_tasks_v1'),
        '{broken_json',
      );
    });
  });

  group('Phase 1 — Outbox Backoff, Firestore Subcollections Delta Sync & Conflicts', () {
    test('coalesces outbox writes, backs off on 503, pushes per-entity subcollection doc on recovery, and resolves LWW conflicts + soft deletes', () async {
      FlutterSecureStorage.setMockInitialValues({
        SecureStorageKeys.accessToken: 'valid-id-token',
        SecureStorageKeys.refreshToken: 'valid-refresh',
      });
      await HandelhaSqliteStore.instance.openInMemoryForTesting(
        factory: databaseFactoryFfi,
        runLegacyMigration: false,
      );

      const uid = 'cloud-user-1';
      final t0 = DateTime.utc(2026, 11, 22, 12, 0, 0);

      // 1. Create and edit the same task twice -> outbox coalesces to 1 pending op.
      final created = (await LocalTaskDatabase.instance.createTask(
        userId: uid,
        title: 'نسخة أولى',
      ) as Success<Task>)
          .data;
      final edited = (await LocalTaskDatabase.instance.updateTask(
        created.copyWith(title: 'نسخة نهائية'),
      ) as Success<Task>)
          .data;
      expect(await HandelhaSqliteStore.instance.pendingOutboxCount(uid), 1);

      final calls = <({String method, String url, Map<String, dynamic>? body})>[];
      var simulateOutage = true;
      var remoteDocsByCollection = <String, List<Map<String, dynamic>>>{
        'tasks': const [],
        'projects': const [],
        'focus_sessions': const [],
      };

      final cloud = FirebaseCloudService.forTesting(
        enabled: true,
        projectId: 'handelha-prod',
        httpExecutor: ({
          required String method,
          required String url,
          Map<String, dynamic>? body,
          String? bearerToken,
        }) async {
          calls.add((method: method, url: url, body: body));
          if (simulateOutage) {
            return const CloudHttpResponse(statusCode: 503, body: {});
          }
          if (method == 'PATCH') {
            return const CloudHttpResponse(statusCode: 200, body: {});
          }
          if (method == 'GET') {
            for (final col in const ['tasks', 'projects', 'focus_sessions']) {
              if (url.contains('/$col?')) {
                return CloudHttpResponse(
                  statusCode: 200,
                  body: {'documents': remoteDocsByCollection[col] ?? const []},
                );
              }
            }
          }
          if (method == 'POST' && url.endsWith(':runQuery')) {
            final col = ((body?['structuredQuery'] as Map)['from'] as List)
                .first['collectionId'] as String;
            final docs = remoteDocsByCollection[col] ?? const [];
            return CloudHttpResponse(
              statusCode: 200,
              body: {
                'results': [
                  for (final d in docs) {'document': d},
                ],
              },
            );
          }
          return const CloudHttpResponse(statusCode: 200, body: {});
        },
      );

      final engine = CloudSyncEngine(
        gateway: FirebaseSubcollectionSyncGateway(cloudService: cloud),
        onStatusUpdate: cloud.updateSyncStatus,
      );

      // 2. Network outage -> item remains in outbox with exponential backoff (+30s).
      final failRun =
          (await engine.syncUser(uid, now: t0) as Success<SyncRunSummary>).data;
      expect(failRun.pushedCount, 0);
      expect(failRun.failedCount, greaterThan(0));
      expect(failRun.remainingOutboxCount, 1);
      expect(cloud.lastSyncStatus.state, CloudSyncState.failed);

      // Re-running before backoff window does NOT retry the backed-off push.
      final callsBeforeSkip = calls.length;
      simulateOutage = false;
      await engine.syncUser(uid, now: t0.add(const Duration(seconds: 10)));
      final patchCallsDuringBackoff = calls
          .skip(callsBeforeSkip)
          .where((c) => c.method == 'PATCH')
          .length;
      expect(patchCallsDuringBackoff, 0);

      // 3. After backoff expires -> pushes directly to users/{uid}/tasks/{id}!
      final pushRun = (await engine.syncUser(
        uid,
        now: t0.add(const Duration(seconds: 35)),
      ) as Success<SyncRunSummary>)
          .data;
      expect(pushRun.pushedCount, 1);
      expect(pushRun.failedCount, 0);
      expect(pushRun.remainingOutboxCount, 0);
      expect(cloud.lastSyncStatus.state, CloudSyncState.synced);

      final patchCall = calls.lastWhere((c) => c.method == 'PATCH');
      expect(
        patchCall.url,
        contains('/documents/users/$uid/tasks/${edited.id}'),
      );
      expect(patchCall.url, isNot(contains('/workspaces/primary')));

      final syncedLocal =
          await LocalTaskDatabase.instance.getTaskIncludingDeleted(edited.id);
      expect(syncedLocal!.syncStatus, SyncStatus.synced);

      // 4. Conflict Resolution + Soft-Delete Tombstone + Incremental :runQuery pull!
      final localKeep = Task(
        id: 't-local-wins',
        userId: uid,
        title: 'تعديل محلي أحدث',
        status: TaskStatus.planned,
        priority: TaskPriority.high,
        energyLevel: EnergyLevel.medium,
        source: TaskSource.manual,
        createdAt: t0,
        updatedAt: DateTime.utc(2026, 11, 22, 13, 0, 0),
        version: 2,
        syncStatus: SyncStatus.pending,
      );
      final localLose = Task(
        id: 't-remote-wins',
        userId: uid,
        title: 'تعديل محلي أقدم',
        status: TaskStatus.inbox,
        priority: TaskPriority.medium,
        energyLevel: EnergyLevel.medium,
        source: TaskSource.manual,
        createdAt: t0,
        updatedAt: DateTime.utc(2026, 11, 22, 12, 10, 0),
        version: 1,
        syncStatus: SyncStatus.pending,
      );
      await LocalTaskDatabase.instance.upsertTasks(
        [localKeep, localLose],
        enqueueSync: true,
      );
      // Mark both local outbox items as backed-off in future so pull exercises
      // pending-outbox conflict resolution directly before push drains them.
      final pendingNow =
          await HandelhaSqliteStore.instance.getDueOutboxItems(uid);
      for (final op in pendingNow) {
        await HandelhaSqliteStore.instance.markOutboxFailed(
          op,
          error: 'offline',
          now: DateTime.utc(2026, 11, 22, 13, 5, 0),
        );
      }

      remoteDocsByCollection = {
        'tasks': [
          {
            'name': 'projects/handelha-prod/databases/(default)/documents/users/$uid/tasks/t-local-wins',
            'fields': {
              'id': {'stringValue': 't-local-wins'},
              'user_id': {'stringValue': uid},
              'title': {'stringValue': 'تعديل سحابي أقدم'},
              'status': {'stringValue': 'planned'},
              'priority': {'stringValue': 'low'},
              'energy_level': {'stringValue': 'low'},
              'source': {'stringValue': 'manual'},
              'depends_on_json': {'stringValue': '[]'},
              'created_at': {'stringValue': t0.toIso8601String()},
              'updated_at': {'stringValue': DateTime.utc(2026, 11, 22, 12, 55, 0).toIso8601String()},
              'version': {'integerValue': '1'},
              'recurrence': {'stringValue': 'none'},
            },
          },
          {
            'name': 'projects/handelha-prod/databases/(default)/documents/users/$uid/tasks/t-remote-wins',
            'fields': {
              'id': {'stringValue': 't-remote-wins'},
              'user_id': {'stringValue': uid},
              'title': {'stringValue': 'تعديل سحابي أحدث'},
              'status': {'stringValue': 'completed'},
              'priority': {'stringValue': 'urgent'},
              'energy_level': {'stringValue': 'high'},
              'source': {'stringValue': 'manual'},
              'depends_on_json': {'stringValue': '[]'},
              'created_at': {'stringValue': t0.toIso8601String()},
              'updated_at': {'stringValue': DateTime.utc(2026, 11, 22, 13, 10, 0).toIso8601String()},
              'version': {'integerValue': '3'},
              'recurrence': {'stringValue': 'none'},
            },
          },
          {
            'name': 'projects/handelha-prod/databases/(default)/documents/users/$uid/tasks/${edited.id}',
            'fields': {
              'id': {'stringValue': edited.id},
              'user_id': {'stringValue': uid},
              'title': {'stringValue': 'محذوفة من جهاز تاني'},
              'status': {'stringValue': 'planned'},
              'priority': {'stringValue': 'medium'},
              'energy_level': {'stringValue': 'medium'},
              'source': {'stringValue': 'manual'},
              'depends_on_json': {'stringValue': '[]'},
              'created_at': {'stringValue': t0.toIso8601String()},
              'updated_at': {'stringValue': edited.updatedAt.toUtc().add(const Duration(minutes: 5)).toIso8601String()},
              'deleted_at': {'stringValue': edited.updatedAt.toUtc().add(const Duration(minutes: 5)).toIso8601String()},
              'version': {'integerValue': '4'},
              'recurrence': {'stringValue': 'none'},
            },
          },
        ],
        'projects': [
          {
            'name': 'projects/handelha-prod/databases/(default)/documents/users/$uid/projects/p-remote-1',
            'fields': {
              'id': {'stringValue': 'p-remote-1'},
              'user_id': {'stringValue': uid},
              'title': {'stringValue': 'مشروع من الموبايل التاني'},
              'status': {'stringValue': 'active'},
              'progress_percent': {'doubleValue': 0.25},
              'task_ids_json': {'stringValue': '[]'},
              'color_value': {'integerValue': '4278218855'},
              'created_at': {'stringValue': t0.toIso8601String()},
              'updated_at': {'stringValue': DateTime.utc(2026, 11, 22, 13, 15, 0).toIso8601String()},
              'phases_json': {
                'stringValue': jsonEncode([
                  {'id': 'rp-1', 'title': 'مرحلة سحابية'},
                ]),
              },
            },
          },
        ],
        'focus_sessions': const [],
      };

      final pullRun = (await engine.syncUser(
        uid,
        now: DateTime.utc(2026, 11, 22, 13, 5, 10),
      ) as Success<SyncRunSummary>)
          .data;

      // Cursor existed from previous run, so delta pull used :runQuery!
      expect(calls.any((c) => c.method == 'POST' && c.url.endsWith(':runQuery')),
          isTrue);
      expect(pullRun.conflictsResolved, 2);
      expect(pullRun.pulledCount, 3); // t-remote-wins, edited tombstone, p-remote-1

      final activeTasks =
          (await LocalTaskDatabase.instance.getTasksForUser(uid)
                  as Success<List<Task>>)
              .data;
      expect(
        activeTasks.firstWhere((t) => t.id == 't-local-wins').title,
        'تعديل محلي أحدث',
      );
      expect(
        activeTasks.firstWhere((t) => t.id == 't-remote-wins').title,
        'تعديل سحابي أحدث',
      );
      // Remote soft-delete hid edited.id locally!
      expect(activeTasks.any((t) => t.id == edited.id), isFalse);
      // Stale outbox entry for t-remote-wins was dropped while t-local-wins stayed queued.
      expect(
        await HandelhaSqliteStore.instance.hasPendingOutboxForEntity(
          userId: uid,
          entityType: 'task',
          entityId: 't-remote-wins',
        ),
        isFalse,
      );
      expect(
        await HandelhaSqliteStore.instance.hasPendingOutboxForEntity(
          userId: uid,
          entityType: 'task',
          entityId: 't-local-wins',
        ),
        isTrue,
      );

      final pulledPhases =
          await LocalProjectDatabase.instance.phasesForProject('p-remote-1');
      expect(pulledPhases, hasLength(1));
      expect(pulledPhases.single['title'], 'مرحلة سحابية');
    });

    test('deleteUserCloudData wipes every subcollection doc, legacy workspace, user doc, and auth account', () async {
      FlutterSecureStorage.setMockInitialValues({
        SecureStorageKeys.accessToken: 'delete-token',
      });
      final deletedUrls = <String>[];
      var authDeleted = false;

      final cloud = FirebaseCloudService.forTesting(
        enabled: true,
        projectId: 'handelha-prod',
        httpExecutor: ({
          required String method,
          required String url,
          Map<String, dynamic>? body,
          String? bearerToken,
        }) async {
          if (method == 'GET' && url.contains('/tasks?')) {
            return const CloudHttpResponse(
              statusCode: 200,
              body: {
                'documents': [
                  {
                    'name': 'projects/p/databases/(default)/documents/users/u-del/tasks/t1',
                    'fields': {'id': {'stringValue': 't1'}},
                  },
                ],
              },
            );
          }
          if (method == 'GET' && url.contains('/projects?')) {
            return const CloudHttpResponse(
              statusCode: 200,
              body: {
                'documents': [
                  {
                    'name': 'projects/p/databases/(default)/documents/users/u-del/projects/p1',
                    'fields': {'id': {'stringValue': 'p1'}},
                  },
                ],
              },
            );
          }
          if (method == 'GET' && url.contains('/focus_sessions?')) {
            return const CloudHttpResponse(
              statusCode: 200,
              body: {
                'documents': [
                  {
                    'name': 'projects/p/databases/(default)/documents/users/u-del/focus_sessions/s1',
                    'fields': {'id': {'stringValue': 's1'}},
                  },
                ],
              },
            );
          }
          if (method == 'DELETE') {
            deletedUrls.add(url);
            return const CloudHttpResponse(statusCode: 200, body: {});
          }
          if (method == 'POST' && url.contains('accounts:delete')) {
            authDeleted = true;
            return const CloudHttpResponse(statusCode: 200, body: {});
          }
          return const CloudHttpResponse(statusCode: 200, body: {});
        },
      );

      await cloud.deleteUserCloudData('u-del');

      expect(deletedUrls.any((u) => u.endsWith('/users/u-del/tasks/t1')), isTrue);
      expect(deletedUrls.any((u) => u.endsWith('/users/u-del/projects/p1')), isTrue);
      expect(
        deletedUrls.any((u) => u.endsWith('/users/u-del/focus_sessions/s1')),
        isTrue,
      );
      expect(
        deletedUrls.any((u) => u.endsWith('/users/u-del/workspaces/primary')),
        isTrue,
      );
      expect(deletedUrls.any((u) => u.endsWith('/users/u-del')), isTrue);
      expect(authDeleted, isTrue);
    });
  });

  group('Phase 1 — Isolate PBKDF2 (100k) & Zero-Friction Guest -> Account Upgrade', () {
    test('hashes local passwords at 100,000 PBKDF2 iterations in background Isolate and upgrades legacy hashes on sign-in', () async {
      final repo = LocalAuthRepository();
      final created = await repo.createAccountWithEmail(
        email: 'mina@handelha.app',
        password: 'Password123',
        displayName: 'مينا',
      );
      expect(created, isA<Success<AppUser>>());

      final storedHash = await SecureStorageService.instance.read(
        SecureStorageKeys.localPasswordHash,
      );
      expect(storedHash, isNotNull);
      expect(
        storedHash,
        startsWith('pbkdf2_sha256\$${LocalAuthRepository.kdfIterations}\$'),
      );
      expect(LocalAuthRepository.kdfIterations, 100000);

      await repo.signOut();

      // Sign-in verifies cleanly against 100k Isolate hash.
      final signedIn = await repo.signInWithEmail(
        email: 'mina@handelha.app',
        password: 'Password123',
      );
      expect(signedIn, isA<Success<AppUser>>());

      // Simulate a genuine legacy single-pass SHA-256 hash and verify transparent upgrade to 100k PBKDF2.
      await repo.signOut();
      final salt = await SecureStorageService.instance.read(
        SecureStorageKeys.localPasswordSalt,
      );
      expect(salt, isNotNull);
      final legacySha256 =
          sha256.convert(utf8.encode('$salt:Password123')).toString();
      await SecureStorageService.instance.write(
        SecureStorageKeys.localPasswordHash,
        legacySha256,
      );

      final upgradedRepo = LocalAuthRepository();
      final wrongPass = await upgradedRepo.signInWithEmail(
        email: 'mina@handelha.app',
        password: 'WrongPassword99',
      );
      expect(wrongPass, isA<Failure<AppUser>>());

      final legacyLogin = await upgradedRepo.signInWithEmail(
        email: 'mina@handelha.app',
        password: 'Password123',
      );
      expect(legacyLogin, isA<Success<AppUser>>());
      final upgradedHash = await SecureStorageService.instance.read(
        SecureStorageKeys.localPasswordHash,
      );
      expect(
        upgradedHash,
        startsWith('pbkdf2_sha256\$${LocalAuthRepository.kdfIterations}\$'),
      );
    });

    test('zero-friction local guest workspace persists across restart and migrates all SQLite entities when linking a real account', () async {
      await HandelhaSqliteStore.instance.openInMemoryForTesting(
        factory: databaseFactoryFfi,
        runLegacyMigration: false,
      );

      final repo = LocalAuthRepository();
      final guestRes = await repo.continueLocallyWithoutAccount();
      expect(guestRes, isA<Success<AppUser>>());
      final guest = (guestRes as Success<AppUser>).data;
      expect(guest.id, startsWith('local_'));
      expect(guest.onboardingComplete, isTrue);
      expect(guest.email, isNull);

      // Cold restart restores the exact same local guest session.
      final restored = await LocalAuthRepository().getCurrentUser();
      expect(restored, isNotNull);
      expect(restored!.id, guest.id);

      // Create tasks, project+phase, and focus session while in guest mode.
      await LocalTaskDatabase.instance.createTask(
        userId: guest.id,
        title: 'مذاكرة شابتر 1',
      );
      await LocalTaskDatabase.instance.createTask(
        userId: guest.id,
        title: 'حل شيت 2',
      );
      await LocalProjectDatabase.instance.save(
        Project(
          id: 'guest-proj-1',
          userId: guest.id,
          title: 'مشروع التخرج',
          status: ProjectStatus.active,
          progressPercent: 0.2,
          taskIds: const [],
          createdAt: DateTime.utc(2026, 11, 22),
          updatedAt: DateTime.utc(2026, 11, 22),
        ),
        phases: const [
          {'id': 'gp-1', 'title': 'تجميع المراجع'},
        ],
      );
      await LocalFocusSessionDatabase.instance.record(
        userId: guest.id,
        taskTitle: 'مذاكرة شابتر 1',
        startedAt: DateTime.utc(2026, 11, 22, 10, 0),
        endedAt: DateTime.utc(2026, 11, 22, 10, 20),
        elapsedMinutes: 20,
        completed: true,
      );

      // User decides to create an account -> ALL guest data migrates seamlessly!
      final upgradedRes = await repo.createAccountWithEmail(
        email: 'nour@handelha.app',
        password: 'Password123',
        displayName: 'نور',
      );
      expect(upgradedRes, isA<Success<AppUser>>());
      final upgraded = (upgradedRes as Success<AppUser>).data;
      expect(upgraded.id, isNot(startsWith('local_')));
      expect(upgraded.onboardingComplete, isTrue);

      // Zero items left stranded under old guest ID.
      final oldGuestTasks =
          (await LocalTaskDatabase.instance.getTasksForUser(guest.id)
                  as Success<List<Task>>)
              .data;
      expect(oldGuestTasks, isEmpty);

      // All 4 entities now belong to upgraded.id and are queued in sync_outbox!
      final newTasks =
          (await LocalTaskDatabase.instance.getTasksForUser(upgraded.id)
                  as Success<List<Task>>)
              .data;
      expect(newTasks, hasLength(2));
      final newProjects =
          (await LocalProjectDatabase.instance.forUser(upgraded.id)
                  as Success<List<Project>>)
              .data;
      expect(newProjects, hasLength(1));
      final newPhases =
          await LocalProjectDatabase.instance.phasesForProject('guest-proj-1');
      expect(newPhases, hasLength(1));
      final newSessions =
          (await LocalFocusSessionDatabase.instance.forUser(upgraded.id)
                  as Success<List<FocusSession>>)
              .data;
      expect(newSessions, hasLength(1));

      expect(
        await HandelhaSqliteStore.instance.pendingOutboxCount(upgraded.id),
        4,
      );
      expect(
        await SecureStorageService.instance.read(SecureStorageKeys.localGuestId),
        isNull,
      );
    });

    test('guest -> account upgrade also migrates exam grades, energy preferences, and scheduled alarms, and recurring task completion rolls over alarms', () async {
      await HandelhaSqliteStore.instance.openInMemoryForTesting(
        factory: databaseFactoryFfi,
        runLegacyMigration: false,
      );

      final repo = LocalAuthRepository();
      final guest =
          (await repo.continueLocallyWithoutAccount() as Success<AppUser>).data;

      await ExamGradesStore.addGrade(
        userId: guest.id,
        examTitle: 'امتحان الفيزياء',
        gradeTier: 'excellent',
        scoreLabel: 'امتياز',
      );
      await UserEnergyPreferencesStore.save(
        guest.id,
        const UserEnergyPreferences(
          peakEnergyPeriod: 'evening',
          preferredSessionMinutes: 60,
          completedWizard: true,
        ),
      );

      final dueDate = DateTime.now().add(const Duration(days: 1));
      final recTask = (await LocalTaskDatabase.instance.createTask(
        userId: guest.id,
        title: 'مراجعة يومية',
        dueAt: dueDate,
        scheduledStartAt: dueDate,
        recurrence: TaskRecurrence.daily,
      ) as Success<Task>)
          .data;

      await AlarmReminderStore.save(
        guest.id,
        AlarmReminderState(
          defaultAlertMode: 'alarm',
          items: [
            AlarmReminderItem(
              id: recTask.id,
              title: recTask.title,
              scheduledAt: dueDate,
              alertMode: 'alarm',
              isEnabled: true,
              taskId: recTask.id,
              scheduleStatus: 'exactScheduled',
            ),
          ],
          taskAlertModes: {recTask.id: 'alarm'},
        ),
      );

      // Completing recurring task rolls over alarm to the newly spawned task occurrence.
      await LocalTaskDatabase.instance.completeTask(recTask.id);
      final afterCompleteTasks =
          (await LocalTaskDatabase.instance.getTasksForUser(guest.id)
                  as Success<List<Task>>)
              .data;
      final spawned =
          afterCompleteTasks.firstWhere((t) => t.id != recTask.id);
      final alarmsAfterComplete = await AlarmReminderStore.load(guest.id);
      expect(
        alarmsAfterComplete.items.any(
          (a) => a.taskId == spawned.id && a.isEnabled && a.alertMode == 'alarm',
        ),
        isTrue,
      );

      // Upgrade guest -> account and verify auxiliary stores migrated.
      final upgraded = (await repo.createAccountWithEmail(
        email: 'salma@handelha.app',
        password: 'Password123',
        displayName: 'سلمى',
      ) as Success<AppUser>)
          .data;

      final migratedGrades = await ExamGradesStore.load(upgraded.id);
      expect(migratedGrades, hasLength(1));
      expect(migratedGrades.single.examTitle, 'امتحان الفيزياء');

      final migratedEnergy = await UserEnergyPreferencesStore.load(upgraded.id);
      expect(migratedEnergy.peakEnergyPeriod, 'evening');
      expect(migratedEnergy.preferredSessionMinutes, 60);

      final migratedAlarms = await AlarmReminderStore.load(upgraded.id);
      expect(
        migratedAlarms.items.any((a) => a.taskId == spawned.id),
        isTrue,
      );
    });
  });

  group('Phase 1 — UI Surface Verification', () {
    testWidgets('LoginScreen shows zero-friction local start button alongside email fields', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: LoginScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('ابدأ فورًا بدون إنشاء حساب'), findsOneWidget);
    });

    testWidgets('SettingsScreen displays normalized SQLite status and Link Account CTA for local guest', (tester) async {
      await tester.runAsync(
        () => HandelhaSqliteStore.instance.openInMemoryForTesting(
          factory: databaseFactoryFfi,
          runLegacyMigration: false,
        ),
      );
      FlutterSecureStorage.setMockInitialValues({
        SecureStorageKeys.userId: 'local_guest_ui_test',
        SecureStorageKeys.localGuestId: 'local_guest_ui_test',
        SecureStorageKeys.onboardingComplete: 'true',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(LocalAuthRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.scrollUntilVisible(
        find.text('ربط بحساب لحفظ ومزامنة بياناتك'),
        300,
      );
      expect(find.textContaining('SQLite محلي منظّم'), findsOneWidget);
      expect(find.text('ربط بحساب لحفظ ومزامنة بياناتك'), findsOneWidget);

      await tester.runAsync(
        () => HandelhaSqliteStore.instance.closeForTesting(),
      );
    });
  });
}

import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handelha/app/theme/app_theme.dart';
import 'package:handelha/core/cloud/firebase_cloud_service.dart';
import 'package:handelha/core/database/local_backup_service.dart';
import 'package:handelha/core/database/local_focus_session_database.dart';
import 'package:handelha/core/database/local_project_database.dart';
import 'package:handelha/core/database/local_task_database.dart';
import 'package:handelha/core/result/result.dart';
import 'package:handelha/core/secure_storage/secure_storage_service.dart';
import 'package:handelha/features/assistant/data/user_energy_preferences.dart';
import 'package:handelha/features/assistant/local_task_tool_executor.dart';
import 'package:handelha/features/authentication/data/local_auth_repository.dart';
import 'package:handelha/features/authentication/data/social_auth_service.dart';
import 'package:handelha/features/authentication/data/student_preview_seeder.dart';
import 'package:handelha/features/authentication/domain/app_user.dart';
import 'package:handelha/features/home/data/dashboard_task_selector.dart';
import 'package:handelha/features/notifications/alarm_reminder_store.dart';
import 'package:handelha/features/notifications/local_notification_service.dart';
import 'package:handelha/features/notifications/notification_preferences.dart';
import 'package:handelha/features/notifications/presentation/notifications_screen.dart';
import 'package:handelha/features/projects/data/exam_grades_store.dart';
import 'package:handelha/features/projects/domain/focus_session.dart';
import 'package:handelha/features/projects/domain/project.dart';
import 'package:handelha/features/settings/presentation/settings_screen.dart';
import 'package:handelha/features/subscriptions/data/local_subscription_store.dart';
import 'package:handelha/features/tasks/data/task_recurrence_service.dart';
import 'package:handelha/features/tasks/domain/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    StudentPreviewAccount.setTestOverrideEnabled(null);
    LocalNotificationService.instance.testPermissionProvider = null;
    LocalNotificationService.instance.testSchedulerOverride = null;
  });

  tearDown(() {
    StudentPreviewAccount.setTestOverrideEnabled(null);
    LocalNotificationService.instance.testPermissionProvider = null;
    LocalNotificationService.instance.testSchedulerOverride = null;
  });

  // ---------------------------------------------------------------------------
  // 1. QA Preview Account Release Safety Gate
  // ---------------------------------------------------------------------------
  group('Gate 1 — StudentPreviewAccount isolation', () {
    test('disabled by default and rejects hardcoded preview credentials', () async {
      expect(StudentPreviewAccount.enabled, isFalse);
      expect(
        StudentPreviewAccount.matchesCredentials(
          StudentPreviewAccount.email,
          StudentPreviewAccount.password,
        ),
        isFalse,
      );

      final repo = LocalAuthRepository();
      final res = await repo.signInWithEmail(
        email: StudentPreviewAccount.email,
        password: StudentPreviewAccount.password,
      );
      expect(res, isA<Failure<AppUser>>());
      expect(
        () => StudentPreviewAccount.ensureProvisioned(),
        throwsStateError,
      );
    });

    test('when explicitly enabled in QA debug override, marks activation as local QA (not store purchase)', () async {
      StudentPreviewAccount.setTestOverrideEnabled(true);
      final repo = LocalAuthRepository();
      final res = await repo.signInWithEmail(
        email: StudentPreviewAccount.email,
        password: StudentPreviewAccount.password,
      );
      expect(res, isA<Success<AppUser>>());
      final sub = await LocalSubscriptionStore.loadForUser(
        StudentPreviewAccount.userId,
      );
      expect(sub.isLocalActivation, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Honest Social OAuth vs Local Profile Distinction
  // ---------------------------------------------------------------------------
  group('Gate 2 — Verified OAuth guard & no placeholder fallback emails', () {
    test('rejects unverified Google & Facebook login by default', () async {
      final repo = LocalAuthRepository();
      final gRes = await repo.signInWithGoogle(email: 'user@gmail.com');
      final fbRes = await repo.signInWithFacebook(email: 'user@example.com');

      expect(gRes, isA<Failure<AppUser>>());
      expect(
        (gRes as Failure<AppUser>).failure,
        isA<SocialOAuthNotConfiguredFailure>(),
      );
      expect(fbRes, isA<Failure<AppUser>>());
      expect(
        (fbRes as Failure<AppUser>).failure,
        isA<SocialOAuthNotConfiguredFailure>(),
      );
    });

    test('even when OAuth flag is enabled, requires a non-empty idToken and real email (no fake defaults)', () async {
      final service = SocialAuthService(oauthEnabledOverride: true);

      final noToken = await service.signInWithGoogle(email: 'real@gmail.com');
      expect(noToken, isA<Failure<SocialProfile>>());
      expect(
        (noToken as Failure<SocialProfile>).failure,
        isA<SocialOAuthNotConfiguredFailure>(),
      );

      final noEmail = await service.signInWithGoogle(idToken: 'verified-jwt-123');
      expect(noEmail, isA<Failure<SocialProfile>>());
      expect(
        (noEmail as Failure<SocialProfile>).failure,
        isA<ValidationFailure>(),
      );

      final verified = await service.signInWithGoogle(
        email: 'verified.user@gmail.com',
        displayName: 'Verified User',
        idToken: 'verified-jwt-123',
      );
      expect(verified, isA<Success<SocialProfile>>());
      final profile = (verified as Success<SocialProfile>).data;
      expect(profile.isVerifiedOAuth, isTrue);
      expect(profile.email, 'verified.user@gmail.com');
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Full Round-Trip Atomic Idempotent Backup & Restore
  // ---------------------------------------------------------------------------
  group('Gate 3 — Full Round-Trip Backup, Idempotency & Atomic Rollback', () {
    const sourceUser = 'backup-user-src';
    const targetUser = 'backup-user-dst';

    Future<String> seedAndExportSourceUser() async {
      await LocalProjectDatabase.instance.save(
        Project(
          id: 'proj-1',
          userId: sourceUser,
          title: 'مشروع التخرج',
          description: 'تجهيز المناقشة',
          status: ProjectStatus.active,
          progressPercent: 60.0,
          nextStepTitle: 'كتابة الفصل الثالث',
          taskIds: const ['task-1'],
          colorValue: 0xFF007067,
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 5),
        ),
        phases: const [
          {'id': 'ph-1', 'title': 'المرحلة الأولى', 'order': 1},
        ],
      );

      await LocalTaskDatabase.instance.upsertTasks([
        Task(
          id: 'task-1',
          userId: sourceUser,
          projectId: 'proj-1',
          title: 'دفع اشتراك الإنترنت',
          status: TaskStatus.planned,
          priority: TaskPriority.high,
          dueAt: DateTime(2026, 11, 25, 14, 0),
          scheduledStartAt: DateTime(2026, 11, 25, 14, 0),
          estimatedDurationMinutes: 30,
          energyLevel: EnergyLevel.low,
          source: TaskSource.manual,
          createdAt: DateTime(2026, 11, 1),
          updatedAt: DateTime(2026, 11, 2),
          version: 2,
          syncStatus: SyncStatus.pending,
          recurrence: TaskRecurrence.monthly,
        ),
      ]);

      await LocalFocusSessionDatabase.instance.record(
        userId: sourceUser,
        taskId: 'task-1',
        taskTitle: 'دفع اشتراك الإنترنت',
        startedAt: DateTime(2026, 11, 20, 10, 0),
        endedAt: DateTime(2026, 11, 20, 10, 25),
        elapsedMinutes: 25,
        completed: true,
      );

      await ExamGradesStore.addGrade(
        userId: sourceUser,
        examTitle: 'خوارزميات',
        gradeTier: 'excellent',
        scoreLabel: '95%',
      );

      await UserEnergyPreferencesStore.save(
        sourceUser,
        const UserEnergyPreferences(
          peakEnergyPeriod: 'evening',
          preferredSessionMinutes: 60,
          hardTaskStrategy: 'warmup_first',
          projectBreakdownStyle: 'milestone_blocks',
          completedWizard: true,
        ),
      );

      await LocalNotificationPreferences.save(
        sourceUser,
        const NotificationPreferences(
          enabled: true,
          tone: ReminderTone.direct,
          quietHoursStartMinutes: 23 * 60,
          quietHoursEndMinutes: 7 * 60,
        ),
      );

      await AlarmReminderStore.save(
        sourceUser,
        AlarmReminderState(
          defaultAlertMode: 'notification',
          items: [
            AlarmReminderItem(
              id: 'alarm-1',
              title: 'منبه الفاتورة',
              scheduledAt: DateTime(2026, 11, 25, 13, 30),
              alertMode: 'alarm',
              isEnabled: true,
              taskId: 'task-1',
              scheduleStatus: 'exactScheduled',
            ),
          ],
          taskAlertModes: const {'task-1': 'alarm'},
        ),
      );

      final exported = await LocalBackupService.instance.exportForUser(sourceUser);
      expect(exported, isA<Success<String>>());
      return (exported as Success<String>).data;
    }

    test('round-trips every exported entity and is idempotent on repeated restore', () async {
      final backupJson = await seedAndExportSourceUser();

      final first = await LocalBackupService.instance.restoreForUser(
        userId: targetUser,
        backupJson: backupJson,
      );
      expect(first, isA<Success<BackupRestoreSummary>>());
      final summary = (first as Success<BackupRestoreSummary>).data;
      expect(summary.schemaVersion, LocalBackupService.schemaVersion);
      expect(summary.tasksCount, 1);
      expect(summary.projectsCount, 1);
      expect(summary.focusSessionsCount, 1);
      expect(summary.examGradesCount, 1);
      expect(summary.alarmRemindersCount, 1);
      expect(summary.hasEnergyPreferences, isTrue);
      expect(summary.hasNotificationPreferences, isTrue);

      // Importing the exact same backup a second time must succeed without duplicating.
      final second = await LocalBackupService.instance.restoreForUser(
        userId: targetUser,
        backupJson: backupJson,
      );
      expect(second, isA<Success<BackupRestoreSummary>>());

      final tasks =
          (await LocalTaskDatabase.instance.getTasksForUser(targetUser) as Success<List<Task>>).data;
      expect(tasks, hasLength(1));
      expect(tasks.single.recurrence, TaskRecurrence.monthly);

      final projects =
          (await LocalProjectDatabase.instance.forUser(targetUser) as Success<List<Project>>).data;
      expect(projects, hasLength(1));
      final phases = await LocalProjectDatabase.instance.phasesForProject('proj-1');
      expect(phases, hasLength(1));
      expect(phases.single['title'], 'المرحلة الأولى');

      final sessions =
          (await LocalFocusSessionDatabase.instance.forUser(targetUser) as Success<List<FocusSession>>)
              .data;
      expect(sessions, hasLength(1));
      expect(sessions.single.elapsedMinutes, 25);

      final grades = await ExamGradesStore.load(targetUser);
      expect(grades, hasLength(1));
      expect(grades.single.examTitle, 'خوارزميات');

      final energy = await UserEnergyPreferencesStore.load(targetUser);
      expect(energy.peakEnergyPeriod, 'evening');
      expect(energy.hardTaskStrategy, 'warmup_first');

      final notif = await LocalNotificationPreferences.load(targetUser);
      expect(notif.tone, ReminderTone.direct);
      expect(notif.quietHoursStartMinutes, 23 * 60);

      final alarms = await AlarmReminderStore.load(targetUser);
      expect(alarms.items, hasLength(1));
      expect(alarms.items.single.id, 'alarm-1');
      expect(alarms.taskAlertModes['task-1'], 'alarm');
    });

    test('rejects corrupted JSON without modifying existing user data', () async {
      await LocalTaskDatabase.instance.createTask(
        userId: targetUser,
        title: 'مهمة أصلية محمية',
      );

      final badJson = await LocalBackupService.instance.restoreForUser(
        userId: targetUser,
        backupJson: '{"product":"handelha","schema":2,"tasks":[{"id":"","title":""}]}',
      );
      expect(badJson, isA<Failure<BackupRestoreSummary>>());

      final tasks =
          (await LocalTaskDatabase.instance.getTasksForUser(targetUser) as Success<List<Task>>).data;
      expect(tasks, hasLength(1));
      expect(tasks.single.title, 'مهمة أصلية محمية');
    });

    test('rolls back ALL stores atomically if a mid-restore failure occurs', () async {
      final backupJson = await seedAndExportSourceUser();

      // Pre-existing user workspace before attempting restore.
      await LocalTaskDatabase.instance.upsertTasks([
        Task(
          id: 'existing-task',
          userId: targetUser,
          title: 'مهمتي قبل الاستعادة',
          status: TaskStatus.inbox,
          priority: TaskPriority.medium,
          energyLevel: EnergyLevel.medium,
          source: TaskSource.manual,
          createdAt: DateTime(2026, 11, 10),
          updatedAt: DateTime(2026, 11, 10),
          version: 1,
          syncStatus: SyncStatus.pending,
        ),
      ]);

      final failedRestore = await LocalBackupService.instance.restoreForUser(
        userId: targetUser,
        backupJson: backupJson,
        onStageForTesting: (stage) async {
          if (stage == 'focusSessions') {
            throw StateError('Simulated disk write failure mid-restore');
          }
        },
      );
      expect(failedRestore, isA<Failure<BackupRestoreSummary>>());

      // Projects & tasks written before focusSessions must be completely rolled back!
      final projectsAfter =
          (await LocalProjectDatabase.instance.forUser(targetUser) as Success<List<Project>>).data;
      expect(projectsAfter, isEmpty);

      final tasksAfter =
          (await LocalTaskDatabase.instance.getTasksForUser(targetUser) as Success<List<Task>>).data;
      expect(tasksAfter.map((t) => t.id).toList(), ['existing-task']);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Cloud Sync Failure, Expired Token, Payload Limit & Conflict Detection
  // ---------------------------------------------------------------------------
  group('Gate 4 — Cloud Sync transparency (network, 401 refresh, size cap, conflicts)', () {
    test('surfaces network error explicitly and records failed CloudSyncStatus', () async {
      await SecureStorageService.instance.write(
        SecureStorageKeys.accessToken,
        'token-1',
      );
      final cloud = FirebaseCloudService.forTesting(
        enabled: true,
        httpExecutor: ({required method, required url, body, bearerToken}) async {
          throw Exception('SocketException: offline');
        },
      );

      final res = await cloud.syncWorkspaceJson(
        userId: 'u1',
        backupJson: '{"schema":2}',
      );
      expect(res, isA<Failure<DateTime>>());
      expect((res as Failure<DateTime>).failure, isA<NetworkFailure>());
      expect(cloud.lastSyncStatus.state, CloudSyncState.failed);
      expect(cloud.lastSyncStatus.lastError, isNotNull);
    });

    test('refreshes expired token on 401 and succeeds on retry', () async {
      await SecureStorageService.instance.write(
        SecureStorageKeys.accessToken,
        'expired-token',
      );
      await SecureStorageService.instance.write(
        SecureStorageKeys.refreshToken,
        'refresh-token-valid',
      );

      var patchCalls = 0;
      final cloud = FirebaseCloudService.forTesting(
        enabled: true,
        httpExecutor: ({required method, required url, body, bearerToken}) async {
          if (url.contains('securetoken.googleapis.com')) {
            return const CloudHttpResponse(
              statusCode: 200,
              body: {'id_token': 'fresh-token', 'refresh_token': 'refresh-2'},
            );
          }
          patchCalls++;
          if (bearerToken == 'expired-token') {
            return const CloudHttpResponse(statusCode: 401, body: {});
          }
          expect(bearerToken, 'fresh-token');
          return const CloudHttpResponse(statusCode: 200, body: {});
        },
      );

      final res = await cloud.syncWorkspaceJson(
        userId: 'u1',
        backupJson: '{"schema":2}',
      );
      expect(res, isA<Success<DateTime>>());
      expect(patchCalls, 2);
      expect(cloud.lastSyncStatus.state, CloudSyncState.synced);
    });

    test('blocks payloads exceeding safe Firestore 900 KiB limit and detects remote timestamp conflicts', () async {
      await SecureStorageService.instance.write(
        SecureStorageKeys.accessToken,
        'token-ok',
      );

      final cloud = FirebaseCloudService.forTesting(
        enabled: true,
        httpExecutor: ({required method, required url, body, bearerToken}) async {
          if (method == 'GET') {
            return const CloudHttpResponse(
              statusCode: 200,
              body: {
                'fields': {
                  'updatedAt': {'timestampValue': '2026-11-22T15:00:00Z'},
                },
              },
            );
          }
          return const CloudHttpResponse(statusCode: 200, body: {});
        },
      );

      final hugePayload = 'x' * (FirebaseCloudService.maxSafePayloadBytes + 10);
      final sizeRes = await cloud.syncWorkspaceJson(
        userId: 'u1',
        backupJson: hugePayload,
      );
      expect(sizeRes, isA<Failure<DateTime>>());
      expect(cloud.lastSyncStatus.state, CloudSyncState.payloadTooLarge);

      final conflictRes = await cloud.syncWorkspaceJson(
        userId: 'u1',
        backupJson: '{"schema":2}',
        expectedRemoteUpdatedAt: DateTime.utc(2026, 11, 22, 12, 0),
      );
      expect(conflictRes, isA<Failure<DateTime>>());
      expect(cloud.lastSyncStatus.state, CloudSyncState.conflictDetected);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Transparent Alarm Permission States (No False Success)
  // ---------------------------------------------------------------------------
  group('Gate 5 — Alarm permission denial & exact-alarm fallback reporting', () {
    test('returns permissionDenied when OS notifications permission is denied', () async {
      LocalNotificationService.instance.testPermissionProvider = () async =>
          const NotificationPermissionStatus(
            notificationsGranted: false,
            exactAlarmsGranted: false,
            hasNativePlatform: true,
          );

      final outcome = await LocalNotificationService.instance.scheduleReminderItem(
        id: 'rem-denied',
        title: 'مراجعة الفيزياء',
        scheduledAt: DateTime.now().add(const Duration(hours: 2)),
        alertMode: 'alarm',
        userId: 'u-perm',
      );
      expect(outcome.status, AlarmScheduleStatus.permissionDenied);
      expect(outcome.isScheduled, isFalse);
    });

    test('returns inexactFallback when notifications granted but exact alarm denied', () async {
      LocalNotificationService.instance.testPermissionProvider = () async =>
          const NotificationPermissionStatus(
            notificationsGranted: true,
            exactAlarmsGranted: false,
            hasNativePlatform: true,
          );

      final outcome = await LocalNotificationService.instance.scheduleReminderItem(
        id: 'rem-inexact',
        title: 'موعد الدكتور',
        scheduledAt: DateTime.now().add(const Duration(hours: 2)),
        alertMode: 'alarm',
        userId: 'u-perm',
      );
      expect(outcome.status, AlarmScheduleStatus.inexactFallback);
      expect(outcome.isScheduled, isTrue);
      expect(outcome.isExact, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Monthly Recurrence End-to-End & Energy-Aware Dashboard Selection
  // ---------------------------------------------------------------------------
  group('Gate 6 — Monthly recurrence & energy-aware dashboard hero task', () {
    test('TaskRecurrenceService.monthly clamps end-of-month calendar dates safely', () {
      Task mk(DateTime date) => Task(
            id: 'r1',
            userId: 'u1',
            title: 'إيجار',
            status: TaskStatus.planned,
            priority: TaskPriority.high,
            dueAt: date,
            scheduledStartAt: date,
            energyLevel: EnergyLevel.low,
            source: TaskSource.manual,
            createdAt: date,
            updatedAt: date,
            version: 1,
            syncStatus: SyncStatus.pending,
            recurrence: TaskRecurrence.monthly,
          );

      // Non-leap year: Jan 31 -> Feb 28
      expect(
        TaskRecurrenceService.nextOccurrence(mk(DateTime(2026, 1, 31, 9, 30))),
        DateTime(2026, 2, 28, 9, 30),
      );
      // Leap year: Jan 31, 2028 -> Feb 29, 2028
      expect(
        TaskRecurrenceService.nextOccurrence(mk(DateTime(2028, 1, 31, 9, 30))),
        DateTime(2028, 2, 29, 9, 30),
      );
      // Year rollover: Dec 15 -> Jan 15 next year
      expect(
        TaskRecurrenceService.nextOccurrence(mk(DateTime(2026, 12, 15, 18, 0))),
        DateTime(2027, 1, 15, 18, 0),
      );
    });

    test('LocalTaskToolExecutor persists monthly recurrence and surfaces schedule_status', () async {
      LocalNotificationService.instance.testPermissionProvider = () async =>
          const NotificationPermissionStatus(
            notificationsGranted: true,
            exactAlarmsGranted: false,
            hasNativePlatform: true,
          );

      final executor = LocalTaskToolExecutor(
        database: LocalTaskDatabase.instance,
        userId: () => 'u-rec',
        nowProvider: () => DateTime(2026, 11, 22, 10, 0),
      );
      final res = await executor.execute(const ToolCall(
        id: 't1',
        name: 'create_task',
        arguments: {
          'title': 'مراجعة الميزانية الشهرية',
          'date': '2026-11-30',
          'time': '18:00',
          'recurrence': 'monthly',
        },
      ));
      expect(res.isSuccess, isTrue);
      expect(res.data['recurrence'], 'monthly');
      expect(res.data['schedule_status'], 'inexactFallback');
    });

    test('DashboardTaskSelector adapts hero task to peak energy & warmup strategy', () {
      final nowPeakMorning = DateTime(2026, 11, 22, 10, 0);
      final lowTask = Task(
        id: 'low-1',
        userId: 'u1',
        title: 'ترتيب المكتب',
        status: TaskStatus.planned,
        priority: TaskPriority.medium,
        energyLevel: EnergyLevel.low,
        source: TaskSource.manual,
        createdAt: DateTime(2026, 11, 22, 8, 0),
        updatedAt: DateTime(2026, 11, 22, 8, 0),
        version: 1,
        syncStatus: SyncStatus.pending,
      );
      final highTask = Task(
        id: 'high-1',
        userId: 'u1',
        title: 'حل مسائل تفاضل عميقة',
        status: TaskStatus.planned,
        priority: TaskPriority.medium,
        energyLevel: EnergyLevel.high,
        source: TaskSource.manual,
        createdAt: DateTime(2026, 11, 22, 9, 0),
        updatedAt: DateTime(2026, 11, 22, 9, 0),
        version: 1,
        syncStatus: SyncStatus.pending,
      );

      final peakFirstPrefs = const UserEnergyPreferences(
        peakEnergyPeriod: 'morning',
        hardTaskStrategy: 'peak_first',
      );
      final pickedPeak = DashboardTaskSelector.pickHeroTask(
        [lowTask, highTask],
        peakFirstPrefs,
        nowPeakMorning,
      );
      expect(pickedPeak?.task.id, 'high-1');
      expect(pickedPeak?.matchedByEnergy, isTrue);

      final warmupPrefs = const UserEnergyPreferences(
        peakEnergyPeriod: 'morning',
        hardTaskStrategy: 'warmup_first',
      );
      final pickedWarmup = DashboardTaskSelector.pickHeroTask(
        [highTask, lowTask],
        warmupPrefs,
        nowPeakMorning,
      );
      expect(pickedWarmup?.task.id, 'low-1');
      expect(pickedWarmup?.matchedByEnergy, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 7. No Hardcoded QA Auto-Heal Mutation in LocalTaskDatabase
  // ---------------------------------------------------------------------------
  group('Gate 7 — No hardcoded QA task mutation in production DB', () {
    test('does not silently split arbitrary user tasks matching legacy QA strings', () async {
      final created = await LocalTaskDatabase.instance.createTask(
        userId: 'u-clean',
        title: 'امتحان عربي وامتحان انجليزي',
      );
      expect(created, isA<Success<Task>>());

      final fetched = await LocalTaskDatabase.instance.getTasksForUser('u-clean');
      final tasks = (fetched as Success<List<Task>>).data;
      expect(tasks, hasLength(1));
      expect(tasks.single.title, 'امتحان عربي وامتحان انجليزي');
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Honest UI Surfaces (Settings & Alarm Status Banners)
  // ---------------------------------------------------------------------------
  group('Gate 8 — Honest Settings & Notifications UI states', () {
    Widget wrapArabic(Widget child) => ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Directionality(textDirection: TextDirection.rtl, child: child),
          ),
        );

    testWidgets('SettingsScreen shows Local-First status and hides unconfigured billing card', (tester) async {
      await tester.pumpWidget(wrapArabic(const SettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('التخزين محلي على جهازك'), findsOneWidget);
      expect(find.text('باقات الطلاب و Pro'), findsNothing);
    });

    testWidgets('NotificationsScreen explicitly warns on denied/approximate alarms', (tester) async {
      await AlarmReminderStore.save(
        'guest',
        AlarmReminderState(
          items: [
            AlarmReminderItem(
              id: 'a-denied',
              title: 'مراجعة نهائية',
              scheduledAt: DateTime.now().add(const Duration(hours: 3)),
              alertMode: 'alarm',
              isEnabled: true,
              scheduleStatus: 'permissionDenied',
            ),
            AlarmReminderItem(
              id: 'a-inexact',
              title: 'تسليم الشيت',
              scheduledAt: DateTime.now().add(const Duration(hours: 4)),
              alertMode: 'alarm',
              isEnabled: true,
              scheduleStatus: 'inexactFallback',
            ),
          ],
        ),
      );

      await tester.pumpWidget(wrapArabic(const NotificationsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.textContaining('لم تتم الجدولة'), findsOneWidget);
      expect(find.textContaining('منبه تقريبي'), findsOneWidget);
    });
  });
}

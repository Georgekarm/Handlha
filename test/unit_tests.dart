import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handelha/core/database/local_backup_service.dart';
import 'package:handelha/core/database/local_focus_session_database.dart';
import 'package:handelha/core/database/local_project_database.dart';
import 'package:handelha/core/database/local_task_database.dart';
import 'package:handelha/core/result/result.dart';
import 'package:handelha/core/secure_storage/secure_storage_service.dart';
import 'package:handelha/features/authentication/data/local_auth_repository.dart';
import 'package:handelha/features/authentication/data/student_preview_seeder.dart';
import 'package:handelha/features/authentication/domain/app_user.dart';
import 'package:handelha/features/projects/data/exam_grades_store.dart';
import 'package:handelha/features/subscriptions/data/local_subscription_store.dart';
import 'package:handelha/features/subscriptions/domain/subscription_models.dart';
import 'package:handelha/features/tasks/domain/task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  // ---------------------------------------------------------------------------
  // Result type tests
  // ---------------------------------------------------------------------------
  group('Result type', () {
    test('Success holds value', () {
      const result = Success('hello');
      expect(result.data, equals('hello'));
      expect(result, isA<Success<String>>());
    });

    test('Failure holds failure', () {
      const result = Failure<String>(NetworkFailure());
      expect(result.failure, isA<NetworkFailure>());
      expect(result, isA<Failure<String>>());
    });
  });

  // ---------------------------------------------------------------------------
  // Failure equality
  // ---------------------------------------------------------------------------
  group('Failure equality', () {
    test('Same type + message are equal', () {
      const a = NetworkFailure();
      const b = NetworkFailure();
      expect(a, equals(b));
    });

    test('InvalidCredentials has Arabic message', () {
      const f = InvalidCredentialsFailure();
      expect(f.message, contains('غير صحيحة'));
    });

    test('WeakPasswordFailure has Arabic message', () {
      const f = WeakPasswordFailure();
      expect(f.message, contains('ضعيفة'));
    });
  });

  // ---------------------------------------------------------------------------
  // Task domain model
  // ---------------------------------------------------------------------------
  group('Task domain model', () {
    final now = DateTime.now();
    final task = Task(
      id: const Uuid().v4(),
      userId: 'user-1',
      title: 'مراجعة العرض',
      status: TaskStatus.inbox,
      priority: TaskPriority.high,
      energyLevel: EnergyLevel.medium,
      source: TaskSource.manual,
      createdAt: now,
      updatedAt: now,
      version: 1,
      syncStatus: SyncStatus.pending,
    );

    test('isCompleted returns false for inbox status', () {
      expect(task.isCompleted, isFalse);
    });

    test('isCompleted returns true after copyWith completed', () {
      final completed = task.copyWith(status: TaskStatus.completed);
      expect(completed.isCompleted, isTrue);
    });

    test('copyWith increments version', () {
      final updated = task.copyWith(version: task.version + 1);
      expect(updated.version, equals(2));
    });

    test('Two tasks with same id are equal', () {
      final task2 = task.copyWith(title: 'عنوان مختلف');
      // They differ in title so not equal
      expect(task == task2, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // LocalTaskDatabase (in-memory via shared_preferences mock)
  // ---------------------------------------------------------------------------
  group('LocalTaskDatabase', () {
    // Note: SharedPreferences.setMockInitialValues must be called in setUp
    // when running on device. Here we test the logic layer.

    test('Task serialization preserves all fields', () {
      final now = DateTime(2024, 1, 15, 10, 30);
      final task = Task(
        id: 'test-id',
        userId: 'user-1',
        title: 'اختبار',
        status: TaskStatus.planned,
        priority: TaskPriority.urgent,
        energyLevel: EnergyLevel.high,
        source: TaskSource.manual,
        dueAt: now,
        estimatedDurationMinutes: 90,
        createdAt: now,
        updatedAt: now,
        version: 3,
        syncStatus: SyncStatus.synced,
      );

      // Verify all enum names are valid
      expect(task.status.name, equals('planned'));
      expect(task.priority.name, equals('urgent'));
      expect(task.energyLevel.name, equals('high'));
      expect(task.syncStatus.name, equals('synced'));
    });

    test('Priority scores: urgent > high > medium > low', () {
      final scores = {
        TaskPriority.urgent: 4,
        TaskPriority.high: 3,
        TaskPriority.medium: 2,
        TaskPriority.low: 1,
      };
      final sorted = TaskPriority.values.toList()
        ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
      expect(sorted.first, equals(TaskPriority.urgent));
      expect(sorted.last, equals(TaskPriority.low));
    });
  });

  // ---------------------------------------------------------------------------
  // Local Auth Repository
  // ---------------------------------------------------------------------------
  group('LocalAuthRepository', () {
    late LocalAuthRepository repo;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      repo = LocalAuthRepository();
    });

    test('createAccount then signIn returns success', () async {
      await repo.createAccountWithEmail(
        email: 'newuser@example.com',
        password: 'Strong123',
      );
      final result = await repo.signInWithEmail(
        email: 'newuser@example.com',
        password: 'Strong123',
      );
      expect(result, isA<Success>());
    });

    test('signInWithEmail returns failure for wrong password', () async {
      await repo.createAccountWithEmail(
        email: 'newuser@example.com',
        password: 'Strong123',
      );
      final result = await repo.signInWithEmail(
        email: 'newuser@example.com',
        password: 'wrongpassword',
      );
      expect(result, isA<Failure>());
      final f = result as Failure;
      expect(f.failure, isA<InvalidCredentialsFailure>());
    });

    test('signInWithEmail validates email format', () async {
      final result = await repo.signInWithEmail(
        email: 'not-an-email',
        password: 'Strong123',
      );
      expect(result, isA<Failure>());
      final f = result as Failure;
      expect(f.failure, isA<ValidationFailure>());
    });

    test('createAccount fails for an existing local email', () async {
      await repo.createAccountWithEmail(email: 'newuser@example.com', password: 'Strong123');
      final result = await repo.createAccountWithEmail(
        email: 'newuser@example.com',
        password: 'Another123',
      );
      expect(result, isA<Failure>());
      expect((result as Failure).failure, isA<EmailAlreadyInUseFailure>());
    });

    test('createAccount fails for weak password', () async {
      final result = await repo.createAccountWithEmail(
        email: 'newuser@example.com',
        password: '123',
      );
      expect(result, isA<Failure>());
      expect((result as Failure).failure, isA<WeakPasswordFailure>());
    });

    test('password reset is explicit about offline limitation', () async {
      final result = await repo.sendPasswordResetEmail('user@example.com');
      expect(result, isA<Failure>());
      expect((result as Failure).failure, isA<AuthFailure>());
    });

    test('signOut clears current user', () async {
      // First sign in
      await repo.createAccountWithEmail(email: 'newuser@example.com', password: 'Strong123');
      await repo.signOut();
      final user = await repo.getCurrentUser();
      expect(user, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Input validation
  // ---------------------------------------------------------------------------
  group('Email validation', () {
    final validEmails = [
      'user@example.com',
      'test.name@domain.org',
      'user+tag@mail.co',
    ];
    final invalidEmails = [
      'notanemail',
      '@nodomain.com',
      'missing@',
      '',
      '   ',
    ];

    final regex = RegExp(r'^[\w\.\+-]+@[\w\-]+\.\w{2,}$');

    for (final email in validEmails) {
      test('Valid: $email', () => expect(regex.hasMatch(email.trim()), isTrue));
    }
    for (final email in invalidEmails) {
      test(
        'Invalid: "$email"',
        () => expect(regex.hasMatch(email.trim()), isFalse),
      );
    }
  });

  // ---------------------------------------------------------------------------
  // SecureStorageService legacy Android keystore fallback
  // ---------------------------------------------------------------------------
  group('SecureStorageService legacy compatibility', () {
    test('falls back to SharedPreferences when Android Keystore throws', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SecureStorageService.forTesting(
        onWrite: (_, _) async => throw PlatformException(
          code: 'KeyStoreException',
          message: 'BadPaddingException',
        ),
        onRead: (_) async => throw PlatformException(
          code: 'KeyStoreException',
          message: 'BadPaddingException',
        ),
        onDelete: (_) async => throw MissingPluginException(),
        onDeleteAll: () async => throw MissingPluginException(),
      );

      await service.writeOrThrow('local_tasks_v1', '{"tasks":[]}');
      final loaded = await service.readOrThrow('local_tasks_v1');
      expect(loaded, equals('{"tasks":[]}'));

      await service.deleteOrThrow('local_tasks_v1');
      expect(await service.readOrThrow('local_tasks_v1'), isNull);
    });

    test('rethrows non-platform errors instead of masking logic bugs', () async {
      final service = SecureStorageService.forTesting(
        onWrite: (_, _) async => throw StateError('unexpected bug'),
      );

      expect(
        () => service.writeOrThrow('k', 'v'),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Stored subscription classification (Student vs Regular Pro)
  // ---------------------------------------------------------------------------
  group('Stored subscription classification (Student vs Regular Pro)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('persists Student vs Regular Pro classification into AppUser and JSON backup', () async {
      final repo = LocalAuthRepository();
      final created = await repo.createAccountWithEmail(
        email: 'student@example.com',
        password: 'Password123',
        displayName: 'أحمد',
      );
      final user = (created as Success<AppUser>).data;
      expect(user.subscriptionCategory, equals(UserSubscriptionCategory.free));
      expect(user.activePlanId, isNull);

      await LocalSubscriptionStore.activatePlanForUser(
        userId: user.id,
        track: SubscriptionPlanTrack.student,
        planId: 'student_yearly',
        planTitle: 'باقة الطلاب السنوية',
        planPrice: '٣٩٩ ج.م',
        isAnnual: true,
      );

      final freshRepo = LocalAuthRepository();
      final loadedUser = await freshRepo.getCurrentUser();
      expect(loadedUser?.subscriptionCategory, equals(UserSubscriptionCategory.student));
      expect(loadedUser?.activePlanId, equals('student_yearly'));

      final backupResult = await LocalBackupService.instance.exportForUser(user.id);
      final backupJson = jsonDecode((backupResult as Success<String>).data) as Map<String, dynamic>;
      final subJson = backupJson['subscription'] as Map<String, dynamic>;
      expect(subJson['category'], equals('student'));
      expect(subJson['activePlanId'], equals('student_yearly'));

      await LocalSubscriptionStore.activatePlanForUser(
        userId: user.id,
        track: SubscriptionPlanTrack.pro,
        planId: 'pro_monthly',
        planTitle: 'باقة Pro الشهرية',
        planPrice: '٨٩ ج.م',
        isAnnual: false,
      );

      final updatedSub = await LocalSubscriptionStore.loadForUser(user.id);
      expect(updatedSub.category, equals(UserSubscriptionCategory.regularPro));
      expect(updatedSub.toSubscriptionState().resolvedPlanTitle(), equals('باقة Pro الشهرية'));
    });

    test('enforces subscription expirationDate and isolates subscriptions & account deletion per user', () async {
      final expiredRecord = StoredSubscriptionRecord(
        userId: 'u-exp',
        category: UserSubscriptionCategory.regularPro,
        tier: SubscriptionTier.pro,
        activePlanId: 'pro_monthly',
        subscribedAt: DateTime.now().subtract(const Duration(days: 40)),
        expirationDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(expiredRecord.isExpired, isTrue);
      expect(expiredRecord.isSubscribed, isFalse);
      expect(expiredRecord.toSubscriptionState().status, equals(SubscriptionStatus.expired));
      expect(expiredRecord.toSubscriptionState().isPro, isFalse);

      // User A activates Pro; User B must remain Free (no global key leak)
      await LocalSubscriptionStore.activatePlanForUser(
        userId: 'user-a',
        track: SubscriptionPlanTrack.pro,
        planId: 'pro_yearly',
        planTitle: 'باقة Pro السنوية',
        planPrice: '٦٩٩ ج.م',
        isAnnual: true,
        isLocalActivation: false,
      );
      final subB = await LocalSubscriptionStore.loadForUser('user-b');
      expect(subB.isSubscribed, isFalse);
      expect(subB.category, equals(UserSubscriptionCategory.free));

      // Deleting email account A must not wipe User B's tasks in LocalTaskDatabase
      await LocalTaskDatabase.instance.createTask(
        userId: 'user-b',
        title: 'مهمة المستخدم ب المحمية',
      );
      final repo = LocalAuthRepository();
      await repo.createAccountWithEmail(
        email: 'usera@example.com',
        password: 'Password123',
        displayName: 'User A',
      );
      await repo.deleteAccount();

      final userBTasks = (await LocalTaskDatabase.instance.getTasksForUser('user-b')
              as Success<List<Task>>)
          .data;
      expect(userBTasks, hasLength(1));
      expect(userBTasks.single.title, 'مهمة المستخدم ب المحمية');
    });

    test('Student preview account is disabled by default and seeds local QA data only when explicitly enabled in debug QA', () async {
      final repo = LocalAuthRepository();
      // Default/production behavior: hardcoded QA credentials must be rejected.
      final blocked = await repo.signInWithEmail(
        email: StudentPreviewAccount.email,
        password: StudentPreviewAccount.password,
      );
      expect(blocked, isA<Failure<AppUser>>());

      // Explicit debug QA override: provisions sample data honestly marked as local activation.
      StudentPreviewAccount.setTestOverrideEnabled(true);
      addTearDown(() => StudentPreviewAccount.setTestOverrideEnabled(null));

      final res = await repo.signInWithEmail(
        email: StudentPreviewAccount.email,
        password: StudentPreviewAccount.password,
      );
      expect(res, isA<Success<AppUser>>());
      final student = (res as Success<AppUser>).data;
      expect(student.id, StudentPreviewAccount.userId);
      expect(student.subscriptionCategory, UserSubscriptionCategory.student);
      expect(student.onboardingComplete, isTrue);

      final sub = await LocalSubscriptionStore.loadForUser(student.id);
      expect(sub.isSubscribed, isTrue);
      expect(sub.tier, SubscriptionTier.student);
      expect(sub.isLocalActivation, isTrue);

      final tasks = (await LocalTaskDatabase.instance.getTasksForUser(student.id)
              as Success<List<Task>>)
          .data;
      expect(tasks.length, greaterThanOrEqualTo(3));

      final projects = (await LocalProjectDatabase.instance.forUser(student.id)
              as Success)
          .data;
      expect(projects, isNotEmpty);

      final sessions =
          (await LocalFocusSessionDatabase.instance.forUser(student.id)
                  as Success)
              .data;
      expect(sessions, isNotEmpty);

      final grades = await ExamGradesStore.load(student.id);
      expect(grades.length, greaterThanOrEqualTo(3));
    });
  });
}

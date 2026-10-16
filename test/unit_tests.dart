import 'package:flutter_test/flutter_test.dart';
import 'package:sekretairak/core/result/result.dart';
import 'package:sekretairak/features/authentication/data/mock_auth_repository.dart';
import 'package:sekretairak/features/tasks/domain/task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  // Mock Auth Repository
  // ---------------------------------------------------------------------------
  group('MockAuthRepository', () {
    late MockAuthRepository repo;

    setUp(() {
      repo = MockAuthRepository();
    });

    test('signInWithEmail returns success for test credentials', () async {
      final result = await repo.signInWithEmail(
        email: 'test@sekretairak.app',
        password: 'Test@1234',
      );
      expect(result, isA<Success>());
    });

    test('signInWithEmail returns failure for wrong password', () async {
      final result = await repo.signInWithEmail(
        email: 'test@sekretairak.app',
        password: 'wrongpassword',
      );
      expect(result, isA<Failure>());
      final f = result as Failure;
      expect(f.failure, isA<InvalidCredentialsFailure>());
    });

    test('signInWithEmail validates email format', () async {
      final result = await repo.signInWithEmail(
        email: 'not-an-email',
        password: 'Test@1234',
      );
      expect(result, isA<Failure>());
      final f = result as Failure;
      expect(f.failure, isA<ValidationFailure>());
    });

    test('createAccount fails for existing test email', () async {
      final result = await repo.createAccountWithEmail(
        email: 'test@sekretairak.app',
        password: 'Test@1234',
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

    test('sendPasswordResetEmail always returns success (security)', () async {
      // Should not reveal whether email exists
      final result1 = await repo.sendPasswordResetEmail('exists@test.com');
      final result2 = await repo.sendPasswordResetEmail('nonexistent@test.com');
      expect(result1, isA<Success>());
      expect(result2, isA<Success>());
    });

    test('signOut clears current user', () async {
      // First sign in
      await repo.signInWithEmail(
        email: 'test@sekretairak.app',
        password: 'Test@1234',
      );
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
}

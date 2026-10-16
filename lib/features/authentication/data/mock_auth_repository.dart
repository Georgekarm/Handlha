import 'package:uuid/uuid.dart';

import '../domain/app_user.dart';
import 'auth_repository.dart';
import '../../../core/result/result.dart';
import '../../../core/secure_storage/secure_storage_service.dart';
import '../../../core/logger/app_logger.dart';

/// Mock authentication implementation for development / testing.
/// Mirrors the exact contract of the real backend:
/// - No secrets in client
/// - Secure storage for session
/// - Proper error types
///
/// Replace with real implementation without changing callers.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository();

  static const _tag = 'MockAuth';
  static const _uuid = Uuid();

  // Test account
  static const _testEmail = 'test@sekretairak.app';
  static const _testPassword = 'Test@1234';

  AppUser? _currentUser;
  bool _onboardingComplete = false;

  @override
  Future<AppUser?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    try {
      final userId = await SecureStorageService.instance
          .read(SecureStorageKeys.userId)
          .timeout(const Duration(seconds: 2));
      if (userId == null) return null;

      _currentUser = _buildMockUser(userId: userId, email: _testEmail);
      return _currentUser;
    } catch (e) {
      AppLogger.warning(
        'Session restore skipped',
        tag: _tag,
        error: e,
      );
      return null;
    }
  }

  @override
  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    AppLogger.info('Mock sign-in attempt', tag: _tag);
    await Future.delayed(const Duration(milliseconds: 800));

    // Validate input first — never trust raw client input
    final emailError = _validateEmail(email);
    if (emailError != null) {
      return Failure(ValidationFailure(emailError));
    }

    // Simulate credential check
    if (email.toLowerCase() != _testEmail || password != _testPassword) {
      return const Failure(InvalidCredentialsFailure());
    }

    final user = _buildMockUser(userId: _uuid.v4(), email: email);
    await _persistSession(user);
    _currentUser = user;
    AppLogger.info('Mock sign-in success', tag: _tag);
    return Success(user);
  }

  @override
  Future<Result<AppUser>> createAccountWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    AppLogger.info('Mock create account attempt', tag: _tag);
    await Future.delayed(const Duration(milliseconds: 900));

    final emailError = _validateEmail(email);
    if (emailError != null) return Failure(ValidationFailure(emailError));

    final passwordError = _validatePassword(password);
    if (passwordError != null) return Failure(WeakPasswordFailure());

    // Simulate email already in use
    if (email.toLowerCase() == _testEmail) {
      return const Failure(EmailAlreadyInUseFailure());
    }

    final user = _buildMockUser(
      userId: _uuid.v4(),
      email: email,
      displayName: displayName,
    );
    await _persistSession(user);
    _currentUser = user;
    AppLogger.info('Mock account created', tag: _tag);
    return Success(user);
  }

  @override
  Future<Result<AppUser>> signInWithGoogle() async {
    AppLogger.info('Mock Google sign-in', tag: _tag);
    await Future.delayed(const Duration(milliseconds: 1200));

    // In production: launch Google sign-in SDK, get credential,
    // verify on backend, return app session.
    final user = _buildMockUser(
      userId: _uuid.v4(),
      email: 'google.user@gmail.com',
      displayName: 'مستخدم Google',
    );
    await _persistSession(user);
    _currentUser = user;
    return Success(user);
  }

  @override
  Future<Result<AppUser>> signInWithFacebook() async {
    AppLogger.info('Mock Facebook sign-in', tag: _tag);
    await Future.delayed(const Duration(milliseconds: 1200));

    final user = _buildMockUser(
      userId: _uuid.v4(),
      email: 'fb.user@facebook.com',
      displayName: 'مستخدم Facebook',
    );
    await _persistSession(user);
    _currentUser = user;
    return Success(user);
  }

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) async {
    AppLogger.info('Mock password reset requested', tag: _tag);
    await Future.delayed(const Duration(milliseconds: 700));
    // Always return success — never reveal whether email exists
    return const Success(null);
  }

  @override
  Future<void> signOut() async {
    AppLogger.info('Mock sign-out', tag: _tag);
    _currentUser = null;
    _onboardingComplete = false;
    // Wipe all sensitive local data
    await SecureStorageService.instance.clearAll();
  }

  @override
  Future<bool> isOnboardingComplete() async {
    if (_onboardingComplete) return true;
    final stored = await SecureStorageService.instance.read(
      SecureStorageKeys.onboardingComplete,
    );
    return stored == 'true';
  }

  @override
  Future<void> markOnboardingComplete() async {
    _onboardingComplete = true;
    await SecureStorageService.instance.write(
      SecureStorageKeys.onboardingComplete,
      'true',
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  AppUser _buildMockUser({
    required String userId,
    required String email,
    String? displayName,
  }) {
    return AppUser(
      id: userId,
      displayName: displayName ?? 'يوسف',
      email: email,
      usageType: OnboardingUsageType.mixed,
      tone: AssistantTone.friendly,
      focusHours: const [9, 10, 11, 14, 15, 16],
      onboardingComplete: false,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _persistSession(AppUser user) async {
    // Store only non-sensitive identifiers securely
    await SecureStorageService.instance.write(
      SecureStorageKeys.userId,
      user.id,
    );
    // In production: store access_token + refresh_token from backend response
    await SecureStorageService.instance.write(
      SecureStorageKeys.accessToken,
      'mock_access_token_${user.id}',
    );
  }

  String? _validateEmail(String email) {
    if (email.trim().isEmpty) return 'البريد الإلكتروني مطلوب.';
    final emailRegex = RegExp(r'^[\w\.\+-]+@[\w\-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(email.trim())) {
      return 'البريد الإلكتروني غير صالح.';
    }
    return null;
  }

  String? _validatePassword(String password) {
    if (password.length < 8) return 'كلمة المرور قصيرة.';
    return null;
  }
}

import '../domain/app_user.dart';
import '../../../core/result/result.dart';

/// Contract for authentication operations.
/// All implementations (mock, Firebase, custom backend) must conform to this.
abstract interface class AuthRepository {
  /// Returns current authenticated user, or null if not logged in.
  Future<AppUser?> getCurrentUser();

  /// Sign in with email + password.
  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  });

  /// Create account with email + password.
  Future<Result<AppUser>> createAccountWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  /// Initiate Google Sign-In flow.
  /// Verifies token on backend before creating session.
  Future<Result<AppUser>> signInWithGoogle();

  /// Initiate Facebook Login flow.
  Future<Result<AppUser>> signInWithFacebook();

  /// Send password reset email.
  /// Does NOT reveal whether email exists (security).
  Future<Result<void>> sendPasswordResetEmail(String email);

  /// Sign out and clear local session.
  Future<void> signOut();

  /// Whether onboarding has been completed for this user.
  Future<bool> isOnboardingComplete();

  /// Mark onboarding as complete (persisted to server + local).
  Future<void> markOnboardingComplete();
}

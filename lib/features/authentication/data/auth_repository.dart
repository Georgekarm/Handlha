import '../../subscriptions/domain/subscription_models.dart';
import '../domain/app_user.dart';
import '../../../core/result/result.dart';

/// Contract for authentication operations.
/// All implementations must conform to this.
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

  /// Initiate verified Google OAuth Sign-In flow.
  Future<Result<AppUser>> signInWithGoogle({
    String? email,
    String? displayName,
    String? idToken,
  });

  /// Initiate verified Facebook OAuth Login flow.
  Future<Result<AppUser>> signInWithFacebook({
    String? email,
    String? displayName,
    String? idToken,
  });

  /// Send password reset email.
  Future<Result<void>> sendPasswordResetEmail(String email);

  /// Reset the on-device password when the entered email matches the registered local account.
  Future<Result<void>> resetLocalPassword({
    required String email,
    required String newPassword,
  });

  /// Update preferred assistant tone.
  Future<void> updateAssistantTone(AssistantTone tone);

  /// Persist the user's stored subscription classification and active plan ID.
  Future<void> updateSubscriptionClassification({
    required UserSubscriptionCategory category,
    String? activePlanId,
  });

  /// Sign out and clear only the active session.
  Future<void> signOut();

  /// Permanently remove the local account and its credentials.
  Future<void> deleteAccount();

  /// Whether onboarding has been completed for this user.
  Future<bool> isOnboardingComplete();

  /// Mark onboarding as complete.
  Future<void> markOnboardingComplete();
}

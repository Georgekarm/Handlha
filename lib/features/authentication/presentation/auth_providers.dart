import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_focus_session_database.dart';
import '../../../core/database/local_project_database.dart';
import '../../../core/database/local_task_database.dart';
import '../../../core/database/shared_preferences_conversation_store.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/result/result.dart';
import '../../notifications/local_notification_service.dart';
import '../../notifications/notification_inbox_store.dart';
import '../../notifications/notification_preferences.dart';
import '../../subscriptions/data/local_subscription_store.dart';
import '../../subscriptions/domain/subscription_models.dart';
import '../data/auth_repository.dart';
import '../data/local_auth_repository.dart';
import '../domain/app_user.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return LocalAuthRepository();
});

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(
  AuthNotifier.new,
);

// ---------------------------------------------------------------------------
// Auth State Notifier
// ---------------------------------------------------------------------------

class AuthNotifier extends AsyncNotifier<AppUser?> {
  static const _tag = 'AuthNotifier';

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AppUser?> build() async {
    final user = await _repo.getCurrentUser();
    AppLogger.info(
      user != null ? 'Session restored' : 'No session found',
      tag: _tag,
    );
    return user;
  }

  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading<AppUser?>();
    final result = await _repo.signInWithEmail(
      email: email,
      password: password,
    );
    if (result is Success<AppUser>) {
      state = AsyncData(result.data);
    } else {
      state = const AsyncData(null);
    }
    return result;
  }

  Future<Result<AppUser>> createAccount({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncLoading<AppUser?>();
    final result = await _repo.createAccountWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
    if (result is Success<AppUser>) {
      state = AsyncData(result.data);
    } else {
      state = const AsyncData(null);
    }
    return result;
  }

  Future<Result<AppUser>> signInWithGoogle({
    String? email,
    String? displayName,
  }) async {
    state = const AsyncLoading<AppUser?>();
    final result = await _repo.signInWithGoogle(
      email: email,
      displayName: displayName,
    );
    if (result is Success<AppUser>) {
      state = AsyncData(result.data);
    } else {
      state = const AsyncData(null);
    }
    return result;
  }

  Future<Result<AppUser>> signInWithFacebook({
    String? email,
    String? displayName,
  }) async {
    state = const AsyncLoading<AppUser?>();
    final result = await _repo.signInWithFacebook(
      email: email,
      displayName: displayName,
    );
    if (result is Success<AppUser>) {
      state = AsyncData(result.data);
    } else {
      state = const AsyncData(null);
    }
    return result;
  }

  Future<Result<void>> sendPasswordResetEmail(String email) async {
    return _repo.sendPasswordResetEmail(email);
  }

  Future<void> updateAssistantTone(AssistantTone tone) async {
    await _repo.updateAssistantTone(tone);
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(tone: tone));
    }
  }

  Future<void> updateSubscriptionClassification({
    required UserSubscriptionCategory category,
    String? activePlanId,
  }) async {
    await _repo.updateSubscriptionClassification(
      category: category,
      activePlanId: activePlanId,
    );
    final current = state.value;
    if (current != null &&
        (current.subscriptionCategory != category ||
            current.activePlanId != activePlanId)) {
      state = AsyncData(
        current.copyWith(
          subscriptionCategory: category,
          activePlanId: activePlanId,
          clearActivePlan: activePlanId == null || activePlanId.isEmpty,
        ),
      );
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncData(null);
    AppLogger.info('User signed out', tag: _tag);
  }

  Future<void> deleteAccount() async {
    final userId = state.value?.id;
    if (userId != null) {
      await LocalTaskDatabase.instance.clearForUser(userId);
      await LocalProjectDatabase.instance.clearForUser(userId);
      await LocalFocusSessionDatabase.instance.clearForUser(userId);
      await SharedPreferencesConversationStore.clearForUser(userId);
      await LocalNotificationPreferences.clear(userId);
      await NotificationInboxStore.clearForUser(userId);
      await LocalSubscriptionStore.clearForUser(userId);
    }
    await LocalNotificationService.instance.cancelAll();
    await _repo.deleteAccount();
    state = const AsyncData(null);
    AppLogger.info('Local account deleted', tag: _tag);
  }

  Future<bool> isOnboardingComplete() => _repo.isOnboardingComplete();

  Future<void> markOnboardingComplete() async {
    await _repo.markOnboardingComplete();
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(onboardingComplete: true));
    }
  }
}

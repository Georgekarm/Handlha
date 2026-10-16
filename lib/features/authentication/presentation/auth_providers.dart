import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/mock_auth_repository.dart';
import '../domain/app_user.dart';
import '../../../core/result/result.dart';
import '../../../core/logger/app_logger.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// The auth repository — swap MockAuthRepository with real impl without
/// changing any downstream providers or UI code.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository();
});

/// Auth state notifier
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
    // Attempt to restore session on startup
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

  Future<Result<AppUser>> signInWithGoogle() async {
    state = const AsyncLoading<AppUser?>();
    final result = await _repo.signInWithGoogle();
    if (result is Success<AppUser>) {
      state = AsyncData(result.data);
    } else {
      state = const AsyncData(null);
    }
    return result;
  }

  Future<Result<AppUser>> signInWithFacebook() async {
    state = const AsyncLoading<AppUser?>();
    final result = await _repo.signInWithFacebook();
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

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncData(null);
    AppLogger.info('User signed out', tag: _tag);
  }

  Future<bool> isOnboardingComplete() => _repo.isOnboardingComplete();
  Future<void> markOnboardingComplete() => _repo.markOnboardingComplete();
}

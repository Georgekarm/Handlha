import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../app/mode/student_mode_controller.dart';
import '../../../core/cloud/firebase_cloud_service.dart';
import '../../../core/database/local_backup_service.dart';
import '../../../core/database/local_focus_session_database.dart';
import '../../../core/database/local_project_database.dart';
import '../../../core/database/local_task_database.dart';
import '../../../core/database/shared_preferences_conversation_store.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/result/result.dart';
import '../../../core/secure_storage/secure_storage_service.dart';
import '../../assistant/data/user_energy_preferences.dart';
import '../../assistant/presentation/token_balance_provider.dart';
import '../../notifications/alarm_reminder_store.dart';
import '../../notifications/local_notification_service.dart';
import '../../notifications/notification_inbox_store.dart';
import '../../notifications/notification_preferences.dart';
import '../../projects/data/exam_grades_store.dart';
import '../../subscriptions/data/local_subscription_store.dart';
import '../../subscriptions/domain/subscription_models.dart';
import '../domain/app_user.dart';
import 'auth_repository.dart';
import 'social_auth_service.dart';
import 'student_preview_seeder.dart';

/// On-device authentication: email/password accounts plus Google and
/// Facebook sign-in. All user data stays on the device, keyed by user id.
final class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository({SocialAuthService? socialAuth})
      : _social = socialAuth ?? SocialAuthService();

  static const _tag = 'Auth';
  static const _uuid = Uuid();

  final SocialAuthService _social;
  AppUser? _currentUser;
  bool _onboardingComplete = false;

  @override
  Future<AppUser?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    try {
      final userId = await SecureStorageService.instance.read(
        SecureStorageKeys.userId,
      );
      final email = await SecureStorageService.instance.read(
            SecureStorageKeys.userEmail,
          ) ??
          await SecureStorageService.instance.read(
            SecureStorageKeys.localEmail,
          );
      if (userId == null || email == null) return null;

      final displayName = await SecureStorageService.instance.read(
        SecureStorageKeys.userName,
      );
      final avatarUrl = await SecureStorageService.instance.read(
        SecureStorageKeys.userAvatarUrl,
      );
      final provider = _providerFrom(
        await SecureStorageService.instance.read(SecureStorageKeys.authProvider),
      );
      final isOnboardingDone = await isOnboardingComplete();
      final tone = await _loadTone();
      final subRecord = await LocalSubscriptionStore.loadForUser(userId);
      _currentUser = _buildUser(
        userId: userId,
        email: email,
        displayName: displayName,
        avatarUrl: avatarUrl,
        provider: provider,
        onboardingComplete: isOnboardingDone,
        tone: tone,
        subscriptionCategory: subRecord.category,
        activePlanId: subRecord.activePlanId,
      );
      return _currentUser;
    } catch (error) {
      AppLogger.warning(
        'Session restore skipped',
        tag: _tag,
        error: error,
      );
      return null;
    }
  }

  @override
  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final validation = _validateEmail(normalizedEmail);
    if (validation != null) return Failure(ValidationFailure(validation));

    if (StudentPreviewAccount.matchesCredentials(normalizedEmail, password)) {
      final subRecord = await StudentPreviewAccount.ensureProvisioned();
      final tone = await _loadTone();
      await markOnboardingComplete();
      final user = _buildUser(
        userId: StudentPreviewAccount.userId,
        email: StudentPreviewAccount.email,
        displayName: StudentPreviewAccount.displayName,
        provider: AuthProviderType.email,
        onboardingComplete: true,
        tone: tone,
        subscriptionCategory: subRecord.category,
        activePlanId: subRecord.activePlanId,
      );
      await _startSession(user);
      return Success(user);
    }

    if (FirebaseCloudService.instance.isEnabled) {
      final cloudRes = await FirebaseCloudService.instance.signInWithEmail(
        email: normalizedEmail,
        password: password,
      );
      if (cloudRes is Failure<FirebaseAuthSession>) {
        return Failure(cloudRes.failure);
      }
      final session = (cloudRes as Success<FirebaseAuthSession>).data;
      final cloudJson = await FirebaseCloudService.instance.fetchWorkspaceJson(
        session.uid,
      );
      if (cloudJson != null && cloudJson.trim().isNotEmpty) {
        await LocalBackupService.instance.importTasksForUser(
          userId: session.uid,
          backupJson: cloudJson,
        );
      }
      final isOnboardingDone = await isOnboardingComplete();
      final tone = await _loadTone();
      final subRecord = await LocalSubscriptionStore.loadForUser(session.uid);
      final user = _buildUser(
        userId: session.uid,
        email: session.email,
        displayName: session.displayName,
        provider: AuthProviderType.email,
        onboardingComplete: isOnboardingDone,
        tone: tone,
        subscriptionCategory: subRecord.category,
        activePlanId: subRecord.activePlanId,
      );
      await _startSession(user);
      return Success(user);
    }

    final savedEmail = await SecureStorageService.instance.read(
      SecureStorageKeys.localEmail,
    );
    final savedHash = await SecureStorageService.instance.read(
      SecureStorageKeys.localPasswordHash,
    );
    final salt = await SecureStorageService.instance.read(
      SecureStorageKeys.localPasswordSalt,
    );
    if (savedEmail == null || savedHash == null || salt == null) {
      return const Failure(UserNotFoundFailure());
    }
    if (savedEmail != normalizedEmail ||
        !_verifyPassword(password, salt, savedHash)) {
      return const Failure(InvalidCredentialsFailure());
    }

    // Transparently upgrade legacy single-pass SHA-256 hashes to PBKDF2-HMAC-SHA256.
    if (!savedHash.startsWith('$_kdfPrefix\$')) {
      await SecureStorageService.instance.write(
        SecureStorageKeys.localPasswordHash,
        _hash(password, salt),
      );
    }

    final userId = await SecureStorageService.instance.read(
      SecureStorageKeys.localAccountId,
    );
    if (userId == null) return const Failure(UserNotFoundFailure());

    final displayName = await SecureStorageService.instance.read(
          SecureStorageKeys.localAccountName,
        ) ??
        await SecureStorageService.instance.read(SecureStorageKeys.userName);
    final isOnboardingDone = await isOnboardingComplete();
    final tone = await _loadTone();
    final subRecord = await LocalSubscriptionStore.loadForUser(userId);
    final user = _buildUser(
      userId: userId,
      email: savedEmail,
      displayName: displayName,
      provider: AuthProviderType.email,
      onboardingComplete: isOnboardingDone,
      tone: tone,
      subscriptionCategory: subRecord.category,
      activePlanId: subRecord.activePlanId,
    );
    await _startSession(user);
    return Success(user);
  }

  @override
  Future<Result<AppUser>> createAccountWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final emailError = _validateEmail(normalizedEmail);
    if (emailError != null) return Failure(ValidationFailure(emailError));

    final passwordError = _validatePassword(password);
    if (passwordError != null) return const Failure(WeakPasswordFailure());

    if (FirebaseCloudService.instance.isEnabled) {
      final cloudRes = await FirebaseCloudService.instance.signUpWithEmail(
        email: normalizedEmail,
        password: password,
        displayName: displayName?.trim(),
      );
      if (cloudRes is Failure<FirebaseAuthSession>) {
        return Failure(cloudRes.failure);
      }
      final session = (cloudRes as Success<FirebaseAuthSession>).data;
      final user = _buildUser(
        userId: session.uid,
        email: session.email,
        displayName: session.displayName ?? displayName?.trim(),
        provider: AuthProviderType.email,
        tone: await _loadTone(),
      );
      await LocalSubscriptionStore.clearForUser(user.id);
      await _startSession(user);
      return Success(user);
    }

    final existingEmail = await SecureStorageService.instance.read(
      SecureStorageKeys.localEmail,
    );
    if (existingEmail != null) return const Failure(EmailAlreadyInUseFailure());

    final user = _buildUser(
      userId: _uuid.v4(),
      email: normalizedEmail,
      displayName: displayName?.trim(),
      provider: AuthProviderType.email,
      tone: await _loadTone(),
    );
    await SecureStorageService.instance.write(
      SecureStorageKeys.localAccountId,
      user.id,
    );
    await SecureStorageService.instance.write(
      SecureStorageKeys.localEmail,
      normalizedEmail,
    );
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      await SecureStorageService.instance.write(
        SecureStorageKeys.localAccountName,
        user.displayName!,
      );
    }
    final salt = _uuid.v4();
    await SecureStorageService.instance.write(
      SecureStorageKeys.localPasswordSalt,
      salt,
    );
    await SecureStorageService.instance.write(
      SecureStorageKeys.localPasswordHash,
      _hash(password, salt),
    );
    await LocalSubscriptionStore.clearForUser(user.id);
    await _startSession(user);
    return Success(user);
  }

  @override
  Future<Result<AppUser>> signInWithGoogle({
    String? email,
    String? displayName,
  }) =>
      _signInWithProvider(
        AuthProviderType.google,
        () => _social.signInWithGoogle(email: email, displayName: displayName),
      );

  @override
  Future<Result<AppUser>> signInWithFacebook({
    String? email,
    String? displayName,
  }) =>
      _signInWithProvider(
        AuthProviderType.facebook,
        () => _social.signInWithFacebook(
          email: email,
          displayName: displayName,
        ),
      );

  Future<Result<AppUser>> _signInWithProvider(
    AuthProviderType provider,
    Future<Result<SocialProfile>> Function() authenticate,
  ) async {
    final result = await authenticate();
    switch (result) {
      case Failure<SocialProfile>(failure: final f):
        return Failure(f);
      case Success<SocialProfile>(data: final profile):
        final userId = '${provider.name}_${profile.id}';
        final isOnboardingDone = await isOnboardingComplete();
        final tone = await _loadTone();
        final subRecord = await LocalSubscriptionStore.loadForUser(userId);
        final user = _buildUser(
          userId: userId,
          email: profile.email ?? '',
          displayName: profile.displayName,
          avatarUrl: profile.photoUrl,
          provider: provider,
          onboardingComplete: isOnboardingDone,
          tone: tone,
          subscriptionCategory: subRecord.category,
          activePlanId: subRecord.activePlanId,
        );
        await _startSession(user);
        AppLogger.info('Signed in with ${provider.name}', tag: _tag);
        return Success(user);
    }
  }

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    final validation = _validateEmail(normalized);
    if (validation != null) return Failure(ValidationFailure(validation));
    if (FirebaseCloudService.instance.isEnabled) {
      return FirebaseCloudService.instance.sendPasswordResetEmail(normalized);
    }
    return const Failure(
      AuthFailure(
        'حسابك ومهامك محفوظين على جهازك بس، فمش بنقدر نبعت رابط استعادة على الإيميل. تقدر تدخل بحساب جوجل أو فيسبوك بدل كده.',
      ),
    );
  }

  @override
  Future<Result<void>> resetLocalPassword({
    required String email,
    required String newPassword,
  }) async {
    final normalized = email.trim().toLowerCase();
    final emailErr = _validateEmail(normalized);
    if (emailErr != null) return Failure(ValidationFailure(emailErr));

    final passErr = _validatePassword(newPassword);
    if (passErr != null) return const Failure(WeakPasswordFailure());

    if (FirebaseCloudService.instance.isEnabled) {
      return FirebaseCloudService.instance.sendPasswordResetEmail(normalized);
    }

    final savedEmail = await SecureStorageService.instance.read(
      SecureStorageKeys.localEmail,
    );
    if (savedEmail == null || savedEmail.trim().toLowerCase() != normalized) {
      return const Failure(UserNotFoundFailure());
    }

    final salt = _uuid.v4();
    await SecureStorageService.instance.write(
      SecureStorageKeys.localPasswordSalt,
      salt,
    );
    await SecureStorageService.instance.write(
      SecureStorageKeys.localPasswordHash,
      _hash(newPassword, salt),
    );
    return const Success(null);
  }

  @override
  Future<void> updateAssistantTone(AssistantTone tone) async {
    await SecureStorageService.instance.write(
      SecureStorageKeys.assistantTone,
      tone.name,
    );
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(tone: tone);
    }
  }

  @override
  Future<void> updateSubscriptionClassification({
    required UserSubscriptionCategory category,
    String? activePlanId,
  }) async {
    await SecureStorageService.instance.write(
      SecureStorageKeys.subscriptionCategory,
      category.name,
    );
    if (activePlanId != null && activePlanId.isNotEmpty) {
      await SecureStorageService.instance.write(
        SecureStorageKeys.activePlanId,
        activePlanId,
      );
    } else {
      await SecureStorageService.instance.delete(SecureStorageKeys.activePlanId);
    }
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        subscriptionCategory: category,
        activePlanId: activePlanId,
        clearActivePlan: activePlanId == null || activePlanId.isEmpty,
      );
    }
  }

  @override
  Future<void> signOut() async {
    final provider = _currentUser?.authProvider ??
        _providerFrom(
          await SecureStorageService.instance.read(SecureStorageKeys.authProvider),
        );
    final userId = _currentUser?.id;
    if (userId != null &&
        userId.isNotEmpty &&
        FirebaseCloudService.instance.isEnabled) {
      final exported = await LocalBackupService.instance.exportForUser(userId);
      if (exported is Success<String>) {
        await FirebaseCloudService.instance.syncWorkspaceJson(
          userId: userId,
          backupJson: exported.data,
        );
      }
    }
    _currentUser = null;
    _onboardingComplete = false;
    StudentModeStore.setSync(false);
    await _social.signOut(provider);
    await SecureStorageService.instance.clearSession();
  }

  @override
  Future<void> deleteAccount() async {
    final provider = _currentUser?.authProvider ??
        _providerFrom(
          await SecureStorageService.instance.read(SecureStorageKeys.authProvider),
        );
    final userId = _currentUser?.id ??
        await SecureStorageService.instance.read(SecureStorageKeys.userId) ??
        await SecureStorageService.instance.read(
          SecureStorageKeys.localAccountId,
        );
    _currentUser = null;
    _onboardingComplete = false;

    await FirebaseCloudService.instance.deleteUserCloudData(userId);

    if (userId != null && userId.isNotEmpty) {
      await LocalTaskDatabase.instance.clearForUser(userId);
      await LocalProjectDatabase.instance.clearForUser(userId);
      await LocalFocusSessionDatabase.instance.clearForUser(userId);
      await SharedPreferencesConversationStore.clearForUser(userId);
      await LocalNotificationPreferences.clear(userId);
      await NotificationInboxStore.clearForUser(userId);
      await AlarmReminderStore.clearForUser(userId);
      await UserEnergyPreferencesStore.clearForUser(userId);
      await ExamGradesStore.clearForUser(userId);
      await TokenBalanceNotifier.clearForUser(userId);
      await LocalSubscriptionStore.clearForUser(userId);
    }
    await StudentModeController.clearSaved();
    await LocalNotificationService.instance.cancelAll();

    if (provider == AuthProviderType.email) {
      await SecureStorageService.instance.clearEmailAccountCredentials();
    } else {
      // Keep any separate email account on this device intact.
      await _social.disconnect(provider);
      await SecureStorageService.instance.clearSession();
      await SecureStorageService.instance.delete(SecureStorageKeys.assistantTone);
    }
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
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(onboardingComplete: true);
    }
    await SecureStorageService.instance.write(
      SecureStorageKeys.onboardingComplete,
      'true',
    );
  }

  Future<void> _startSession(AppUser user) async {
    await SecureStorageService.instance.write(
      SecureStorageKeys.userId,
      user.id,
    );
    await SecureStorageService.instance.write(
      SecureStorageKeys.userEmail,
      user.email ?? '',
    );
    await SecureStorageService.instance.write(
      SecureStorageKeys.authProvider,
      user.authProvider.name,
    );
    await SecureStorageService.instance.write(
      SecureStorageKeys.subscriptionCategory,
      user.subscriptionCategory.name,
    );
    if (user.activePlanId != null && user.activePlanId!.isNotEmpty) {
      await SecureStorageService.instance.write(
        SecureStorageKeys.activePlanId,
        user.activePlanId!,
      );
    } else {
      await SecureStorageService.instance.delete(SecureStorageKeys.activePlanId);
    }
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      await SecureStorageService.instance.write(
        SecureStorageKeys.userName,
        user.displayName!,
      );
    } else {
      await SecureStorageService.instance.delete(SecureStorageKeys.userName);
    }
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      await SecureStorageService.instance.write(
        SecureStorageKeys.userAvatarUrl,
        user.avatarUrl!,
      );
    } else {
      await SecureStorageService.instance.delete(SecureStorageKeys.userAvatarUrl);
    }
    _currentUser = user;
  }

  AuthProviderType _providerFrom(String? raw) {
    return AuthProviderType.values.firstWhere(
      (p) => p.name == raw,
      orElse: () => AuthProviderType.email,
    );
  }

  Future<AssistantTone> _loadTone() async {
    final raw = await SecureStorageService.instance.read(
      SecureStorageKeys.assistantTone,
    );
    if (raw == null) return AssistantTone.friendly;
    return AssistantTone.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => AssistantTone.friendly,
    );
  }

  AppUser _buildUser({
    required String userId,
    required String email,
    String? displayName,
    String? avatarUrl,
    AuthProviderType provider = AuthProviderType.email,
    bool onboardingComplete = false,
    AssistantTone tone = AssistantTone.friendly,
    UserSubscriptionCategory subscriptionCategory = UserSubscriptionCategory.free,
    String? activePlanId,
  }) {
    return AppUser(
      id: userId,
      displayName: displayName?.isEmpty == true ? null : displayName,
      email: email.isEmpty ? null : email,
      avatarUrl: avatarUrl?.isEmpty == true ? null : avatarUrl,
      authProvider: provider,
      usageType: OnboardingUsageType.mixed,
      tone: tone,
      focusHours: const [9, 10, 11, 14, 15, 16],
      onboardingComplete: onboardingComplete,
      subscriptionCategory: subscriptionCategory,
      activePlanId: activePlanId,
      createdAt: DateTime.now(),
    );
  }

  String? _validateEmail(String email) {
    if (email.isEmpty) return 'البريد الإلكتروني مطلوب.';
    final valid = RegExp(r'^[\w.\-+]+@[\w\-]+\.\w{2,}$').hasMatch(email);
    return valid ? null : 'البريد الإلكتروني غير صالح.';
  }

  String? _validatePassword(String password) {
    if (password.length < 8) {
      return 'كلمة المرور قصيرة. استخدم 8 أحرف أو أكثر.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return 'كلمة المرور لازم تحتوي على حروف وأرقام.';
    }
    return null;
  }

  static const String _kdfPrefix = 'pbkdf2_sha256';
  static const int _kdfIterations = 10000;

  String _hash(String password, String salt) {
    final derivedHex = _pbkdf2Sha256Hex(
      password: password,
      salt: salt,
      iterations: _kdfIterations,
    );
    return '$_kdfPrefix\$$_kdfIterations\$$derivedHex';
  }

  bool _verifyPassword(String password, String salt, String storedHash) {
    if (storedHash.startsWith('$_kdfPrefix\$')) {
      final parts = storedHash.split('\$');
      if (parts.length == 3) {
        final iterations = int.tryParse(parts[1]) ?? _kdfIterations;
        final expectedHex = parts[2];
        final actualHex = _pbkdf2Sha256Hex(
          password: password,
          salt: salt,
          iterations: iterations,
        );
        return _constantTimeEquals(actualHex, expectedHex);
      }
    }
    // Fallback verification for legacy single-pass SHA-256 hashes (upgraded on sign-in).
    final legacyHex = sha256.convert(utf8.encode('$salt:$password')).toString();
    return _constantTimeEquals(legacyHex, storedHash);
  }

  String _pbkdf2Sha256Hex({
    required String password,
    required String salt,
    required int iterations,
  }) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final saltBytes = utf8.encode(salt);
    final blockInput = Uint8List(saltBytes.length + 4);
    blockInput.setRange(0, saltBytes.length, saltBytes);
    blockInput[saltBytes.length] = 0;
    blockInput[saltBytes.length + 1] = 0;
    blockInput[saltBytes.length + 2] = 0;
    blockInput[saltBytes.length + 3] = 1;

    var u = hmac.convert(blockInput).bytes;
    final out = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    final sb = StringBuffer();
    for (final byte in out) {
      sb.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

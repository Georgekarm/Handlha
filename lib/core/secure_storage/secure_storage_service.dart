import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logger/app_logger.dart';

/// Secure key-value storage for sensitive data (tokens, session).
/// Backed by the Android KeyStore, with an automatic SharedPreferences fallback
/// on legacy OEM devices with a broken Keystore.
class SecureStorageService {
  SecureStorageService._([
    this._onWrite,
    this._onRead,
    this._onDelete,
    this._onDeleteAll,
  ]);

  @visibleForTesting
  factory SecureStorageService.forTesting({
    Future<void> Function(String key, String value)? onWrite,
    Future<String?> Function(String key)? onRead,
    Future<void> Function(String key)? onDelete,
    Future<void> Function()? onDeleteAll,
  }) => SecureStorageService._(onWrite, onRead, onDelete, onDeleteAll);

  static final SecureStorageService instance = SecureStorageService._();
  static const String _fallbackPrefix = 'handelha_sec_fb_';
  // Avoid Jetpack EncryptedSharedPreferences crashes on legacy Android 7-9 OEMs.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  final Future<void> Function(String key, String value)? _onWrite;
  final Future<String?> Function(String key)? _onRead;
  final Future<void> Function(String key)? _onDelete;
  final Future<void> Function()? _onDeleteAll;
  bool _usePrefsFallback = false;

  Future<void> _nativeWrite(String key, String value) =>
      _onWrite != null ? _onWrite(key, value) : _storage.write(key: key, value: value);

  Future<String?> _nativeRead(String key) =>
      _onRead != null ? _onRead(key) : _storage.read(key: key);

  Future<void> _nativeDelete(String key) =>
      _onDelete != null ? _onDelete(key) : _storage.delete(key: key);

  Future<void> _nativeDeleteAll() =>
      _onDeleteAll != null ? _onDeleteAll() : _storage.deleteAll();

  String get _prefsPrefix => _fallbackPrefix;

  bool _isPlatformStorageError(Object error) =>
      error is PlatformException || error is MissingPluginException;

  /// Legacy best-effort write kept for preferences/session compatibility.
  Future<void> write(String key, String value) async {
    try {
      await writeOrThrow(key, value);
    } catch (e) {
      AppLogger.error('SecureStorage write failed', tag: 'SecureStorage', error: e);
    }
  }

  /// Strict write for repositories. Persistence code must not report success
  /// when the platform storage rejected the mutation.
  Future<void> writeOrThrow(String key, String value) async {
    if (_usePrefsFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefsPrefix$key', value);
      return;
    }
    try {
      await _nativeWrite(key, value);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_fallbackPrefix$key');
      } catch (_) {}
    } catch (e) {
      if (!_isPlatformStorageError(e)) rethrow;
      _usePrefsFallback = true;
      AppLogger.info(
        'Falling back to SharedPreferences after keystore write error: $e',
        tag: 'SecureStorage',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_fallbackPrefix$key', value);
    }
  }

  /// Legacy best-effort read kept for optional session values.
  Future<String?> read(String key) async {
    try {
      return await readOrThrow(key);
    } catch (e) {
      AppLogger.error('SecureStorage read failed', tag: 'SecureStorage', error: e);
      return null;
    }
  }

  /// Strict read used by local databases where unavailable storage is not an
  /// empty database.
  Future<String?> readOrThrow(String key) async {
    if (_usePrefsFallback) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_prefsPrefix$key');
    }
    try {
      final stored = await _nativeRead(key);
      if (stored != null) return stored;
      return await _tryReadFallback(key);
    } catch (e) {
      if (!_isPlatformStorageError(e)) rethrow;
      _usePrefsFallback = true;
      AppLogger.info(
        'Falling back to SharedPreferences after keystore read error: $e',
        tag: 'SecureStorage',
      );
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_fallbackPrefix$key');
    }
  }

  Future<String?> _tryReadFallback(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_fallbackPrefix$key');
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String key) async {
    try {
      await deleteOrThrow(key);
    } catch (e) {
      AppLogger.error('SecureStorage delete failed', tag: 'SecureStorage', error: e);
    }
  }

  Future<void> deleteOrThrow(String key) async {
    if (_usePrefsFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefsPrefix$key');
      return;
    }
    try {
      await _nativeDelete(key);
    } catch (e) {
      if (!_isPlatformStorageError(e)) rethrow;
      _usePrefsFallback = true;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_fallbackPrefix$key');
    } catch (_) {}
  }

  /// Wipe all locally stored session data on logout.
  Future<void> clearAll() async {
    try {
      try {
        await _nativeDeleteAll();
      } catch (_) {}
      try {
        final prefs = await SharedPreferences.getInstance();
        final keys = prefs
            .getKeys()
            .where((k) => k.startsWith(_fallbackPrefix))
            .toList();
        for (final k in keys) {
          await prefs.remove(k);
        }
      } catch (_) {}
      AppLogger.info('Secure storage cleared', tag: 'SecureStorage');
    } catch (e) {
      AppLogger.error('SecureStorage clearAll failed', tag: 'SecureStorage', error: e);
    }
  }

  /// Removes only the active session and keeps the local account available.
  Future<void> clearSession() async {
    await delete(SecureStorageKeys.accessToken);
    await delete(SecureStorageKeys.refreshToken);
    await delete(SecureStorageKeys.userId);
    await delete(SecureStorageKeys.userEmail);
    await delete(SecureStorageKeys.userName);
    await delete(SecureStorageKeys.onboardingComplete);
    await delete(SecureStorageKeys.authProvider);
    await delete(SecureStorageKeys.userAvatarUrl);
    await delete(SecureStorageKeys.subscriptionCategory);
    await delete(SecureStorageKeys.activePlanId);
    await delete(SecureStorageKeys.activePlanTitle);
  }

  /// Removes only the local email account credentials and session keys without
  /// wiping other users' task/project/focus databases on the device.
  Future<void> clearEmailAccountCredentials() async {
    await clearSession();
    await delete(SecureStorageKeys.localAccountId);
    await delete(SecureStorageKeys.localEmail);
    await delete(SecureStorageKeys.localPasswordHash);
    await delete(SecureStorageKeys.localPasswordSalt);
    await delete(SecureStorageKeys.localAccountName);
    await delete(SecureStorageKeys.assistantTone);
  }
}

class SecureStorageKeys {
  SecureStorageKeys._();
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
  static const String userName = 'user_name';
  static const String onboardingComplete = 'onboarding_complete';
  static const String authProvider = 'auth_provider';
  static const String userAvatarUrl = 'user_avatar_url';
  static const String localAccountName = 'local_account_name';
  static const String assistantTone = 'assistant_tone';
  static const String localAccountId = 'local_account_id';
  static const String localEmail = 'local_email';
  static const String localPasswordHash = 'local_password_hash';
  static const String localPasswordSalt = 'local_password_salt';
  static const String subscriptionCategory = 'subscription_category';
  static const String activePlanId = 'active_plan_id';
  static const String activePlanTitle = 'active_plan_title';
}

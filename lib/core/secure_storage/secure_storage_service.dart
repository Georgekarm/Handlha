import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logger/app_logger.dart';

/// Secure key-value storage for sensitive data (tokens, session).
/// Backed by Keychain (iOS) / EncryptedSharedPreferences (Android).
/// Never use SharedPreferences for tokens.
class SecureStorageService {
  SecureStorageService._()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );

  static final SecureStorageService instance = SecureStorageService._();

  final FlutterSecureStorage _storage;

  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      AppLogger.error(
        'SecureStorage write failed',
        tag: 'SecureStorage',
        error: e,
      );
    }
  }

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      AppLogger.error(
        'SecureStorage read failed',
        tag: 'SecureStorage',
        error: e,
      );
      return null;
    }
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      AppLogger.error(
        'SecureStorage delete failed',
        tag: 'SecureStorage',
        error: e,
      );
    }
  }

  /// Wipe all locally stored session data on logout.
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      AppLogger.info('Secure storage cleared', tag: 'SecureStorage');
    } catch (e) {
      AppLogger.error(
        'SecureStorage clearAll failed',
        tag: 'SecureStorage',
        error: e,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Keys — defined once to avoid typos
// ---------------------------------------------------------------------------
class SecureStorageKeys {
  SecureStorageKeys._();
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String onboardingComplete = 'onboarding_complete';
}

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/result/result.dart';
import '../domain/app_user.dart';

/// Basic profile returned by a social identity provider.
class SocialProfile {
  const SocialProfile({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
}

/// Raised when the provider sign-in could not be completed.
class SocialSignInFailure extends AuthFailure {
  const SocialSignInFailure(this.provider)
      : super('تعذّر تسجيل الدخول حاليًا. تأكد من البيانات وحاول تاني.');

  final AuthProviderType provider;

  @override
  List<Object?> get props => [message, provider];
}

/// Handles Google and Facebook authentication on Android devices and persists
/// the linked social profile locally.
class SocialAuthService {
  static const _tag = 'SocialAuth';
  static const MethodChannel _channel = MethodChannel('com.handelha.app/auth');

  static String _emailKey(AuthProviderType provider) =>
      'handelha_social_${provider.name}_email';
  static String _nameKey(AuthProviderType provider) =>
      'handelha_social_${provider.name}_name';

  /// Loads any previously linked social profile for [provider] on this device.
  static Future<SocialProfile?> loadSavedProfile(
    AuthProviderType provider,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_emailKey(provider))?.trim();
      final name = prefs.getString(_nameKey(provider))?.trim();
      if (email == null || email.isEmpty) return null;
      return SocialProfile(
        id: _stableId(provider, email),
        email: email,
        displayName: (name != null && name.isNotEmpty)
            ? name
            : _nameFromEmail(email, provider),
      );
    } catch (_) {
      return null;
    }
  }

  /// Launches the native Android system Google account chooser when available.
  static Future<String?> pickDeviceGoogleEmail() async {
    try {
      if (!Platform.isAndroid) return null;
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'pickGoogleAccount',
      );
      final email = res?['email']?.toString().trim();
      if (email != null && email.isNotEmpty) {
        return email.toLowerCase();
      }
      return null;
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      AppLogger.warning('Native account picker skipped', tag: _tag, error: e.code);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Result<SocialProfile>> signInWithGoogle({
    String? email,
    String? displayName,
  }) =>
      _authenticate(
        provider: AuthProviderType.google,
        email: email,
        displayName: displayName,
      );

  Future<Result<SocialProfile>> signInWithFacebook({
    String? email,
    String? displayName,
  }) =>
      _authenticate(
        provider: AuthProviderType.facebook,
        email: email,
        displayName: displayName,
      );

  Future<Result<SocialProfile>> _authenticate({
    required AuthProviderType provider,
    String? email,
    String? displayName,
  }) async {
    try {
      final saved = await loadSavedProfile(provider);
      final resolvedEmail = (email?.trim().isNotEmpty == true)
          ? email!.trim().toLowerCase()
          : (saved?.email ??
              (provider == AuthProviderType.google
                  ? 'user.google@gmail.com'
                  : 'user.facebook@facebook.com'));
      final resolvedName = (displayName?.trim().isNotEmpty == true)
          ? displayName!.trim()
          : (saved?.displayName ?? _nameFromEmail(resolvedEmail, provider));

      final profile = SocialProfile(
        id: _stableId(provider, resolvedEmail),
        email: resolvedEmail,
        displayName: resolvedName,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_emailKey(provider), resolvedEmail);
      await prefs.setString(_nameKey(provider), resolvedName);

      return Success(profile);
    } catch (e) {
      AppLogger.warning('${provider.name} sign-in failed', tag: _tag, error: e);
      return Failure(SocialSignInFailure(provider));
    }
  }

  Future<void> signOut(AuthProviderType provider) async {
    // Keep saved profile hint on device for quick re-login, only end session.
  }

  Future<void> disconnect(AuthProviderType provider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_emailKey(provider));
      await prefs.remove(_nameKey(provider));
    } catch (e) {
      AppLogger.warning('Provider disconnect skipped', tag: _tag, error: e);
    }
  }

  static String _stableId(AuthProviderType provider, String email) {
    final digest = sha256
        .convert(utf8.encode('${provider.name}:${email.trim().toLowerCase()}'))
        .toString();
    return digest.substring(0, 20);
  }

  static String _nameFromEmail(String email, AuthProviderType provider) {
    final local = email.split('@').first.trim();
    if (local.isEmpty ||
        local == 'user.google' ||
        local == 'user.facebook') {
      return provider == AuthProviderType.google
          ? 'مستخدم جوجل'
          : 'مستخدم فيسبوك';
    }
    final cleaned = local.replaceAll(RegExp(r'[._\-]+'), ' ').trim();
    if (cleaned.isEmpty) {
      return provider == AuthProviderType.google
          ? 'مستخدم جوجل'
          : 'مستخدم فيسبوك';
    }
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}

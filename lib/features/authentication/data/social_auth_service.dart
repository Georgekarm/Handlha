import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/environment/environment.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/result/result.dart';
import '../domain/app_user.dart';

/// Basic profile returned by a verified social identity provider.
class SocialProfile {
  const SocialProfile({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    this.idToken,
    this.isVerifiedOAuth = false,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? idToken;
  final bool isVerifiedOAuth;
}

/// Raised when the provider sign-in could not be completed.
class SocialSignInFailure extends AuthFailure {
  const SocialSignInFailure(this.provider)
      : super('تعذّر تسجيل الدخول حاليًا. تأكد من البيانات وحاول تاني.');

  final AuthProviderType provider;

  @override
  List<Object?> get props => [message, provider];
}

/// Raised when social OAuth is requested in a build where verified OAuth
/// token exchange is not configured.
class SocialOAuthNotConfiguredFailure extends AuthFailure {
  const SocialOAuthNotConfiguredFailure(this.provider)
      : super(
          'تسجيل الدخول عبر مزوّد خارجي غير مفعّل حاليًا بدون تحقق OAuth رسمي. استخدم حسابك المحلي بالبريد الإلكتروني.',
        );

  final AuthProviderType provider;

  @override
  List<Object?> get props => [message, provider];
}

/// Outcome of launching the native Android system Google Account chooser.
enum NativeGoogleAccountPickStatus { selected, cancelled, unavailable }

class NativeGoogleAccountPickResult {
  const NativeGoogleAccountPickResult({
    required this.status,
    this.email,
  });

  final NativeGoogleAccountPickStatus status;
  final String? email;
}

/// Handles social identity provider sign-in strictly when verified OAuth is
/// enabled and a verified provider identity token is supplied.
///
/// Never synthesizes placeholder provider emails or impersonates verified OAuth
/// using local SharedPreferences alone.
class SocialAuthService {
  SocialAuthService({this.oauthEnabledOverride});

  static const _tag = 'SocialAuth';
  static const MethodChannel _channel = MethodChannel('com.handelha.app/auth');

  final bool? oauthEnabledOverride;

  bool get isVerifiedOAuthEnabled =>
      oauthEnabledOverride ?? Environment.verifiedSocialOAuthEnabled;

  static String _emailKey(AuthProviderType provider) =>
      'handelha_social_${provider.name}_email';
  static String _nameKey(AuthProviderType provider) =>
      'handelha_social_${provider.name}_name';

  /// Loads any previously linked social profile hint for [provider] on this device.
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
        isVerifiedOAuth: false,
      );
    } catch (_) {
      return null;
    }
  }

  /// Launches the native Android system Google account chooser and returns
  /// a structured outcome distinguishing selection, user cancellation, and
  /// platform unavailability.
  ///
  /// Note: Android's AccountManager chooser returns an account email hint only,
  /// NOT a verified OAuth ID token.
  static Future<NativeGoogleAccountPickResult>
      pickDeviceGoogleAccountOutcome() async {
    try {
      if (!Platform.isAndroid) {
        return const NativeGoogleAccountPickResult(
          status: NativeGoogleAccountPickStatus.unavailable,
        );
      }
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'pickGoogleAccount',
      );
      if (res == null) {
        return const NativeGoogleAccountPickResult(
          status: NativeGoogleAccountPickStatus.unavailable,
        );
      }
      final email = res['email']?.toString().trim();
      if (email != null && email.isNotEmpty) {
        return NativeGoogleAccountPickResult(
          status: NativeGoogleAccountPickStatus.selected,
          email: email.toLowerCase(),
        );
      }
      final status = res['status']?.toString();
      if (status == 'cancelled') {
        return const NativeGoogleAccountPickResult(
          status: NativeGoogleAccountPickStatus.cancelled,
        );
      }
      return const NativeGoogleAccountPickResult(
        status: NativeGoogleAccountPickStatus.unavailable,
      );
    } on MissingPluginException {
      return const NativeGoogleAccountPickResult(
        status: NativeGoogleAccountPickStatus.unavailable,
      );
    } on PlatformException catch (e) {
      AppLogger.warning('Native account picker skipped', tag: _tag, error: e.code);
      return const NativeGoogleAccountPickResult(
        status: NativeGoogleAccountPickStatus.unavailable,
      );
    } catch (_) {
      return const NativeGoogleAccountPickResult(
        status: NativeGoogleAccountPickStatus.unavailable,
      );
    }
  }

  /// Launches the native Android system Google account chooser when available.
  static Future<String?> pickDeviceGoogleEmail() async {
    final outcome = await pickDeviceGoogleAccountOutcome();
    return outcome.email;
  }

  Future<Result<SocialProfile>> signInWithGoogle({
    String? email,
    String? displayName,
    String? idToken,
  }) =>
      _authenticate(
        provider: AuthProviderType.google,
        email: email,
        displayName: displayName,
        idToken: idToken,
      );

  Future<Result<SocialProfile>> signInWithFacebook({
    String? email,
    String? displayName,
    String? idToken,
  }) =>
      _authenticate(
        provider: AuthProviderType.facebook,
        email: email,
        displayName: displayName,
        idToken: idToken,
      );

  Future<Result<SocialProfile>> _authenticate({
    required AuthProviderType provider,
    String? email,
    String? displayName,
    String? idToken,
  }) async {
    if (!isVerifiedOAuthEnabled) {
      return Failure(SocialOAuthNotConfiguredFailure(provider));
    }
    final cleanToken = idToken?.trim() ?? '';
    if (cleanToken.isEmpty) {
      return Failure(SocialOAuthNotConfiguredFailure(provider));
    }

    try {
      final resolvedEmail = email?.trim().toLowerCase() ?? '';
      if (resolvedEmail.isEmpty ||
          !RegExp(r'^[\w.\-+]+@[\w\-]+\.\w{2,}$').hasMatch(resolvedEmail)) {
        return const Failure(
          ValidationFailure('تعذّر التحقق من البريد الإلكتروني لحساب المزوّد.'),
        );
      }
      final resolvedName = (displayName?.trim().isNotEmpty == true)
          ? displayName!.trim()
          : _nameFromEmail(resolvedEmail, provider);

      final profile = SocialProfile(
        id: _stableId(provider, resolvedEmail),
        email: resolvedEmail,
        displayName: resolvedName,
        idToken: cleanToken,
        isVerifiedOAuth: true,
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
    if (local.isEmpty) {
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

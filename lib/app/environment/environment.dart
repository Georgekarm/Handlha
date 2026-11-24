import 'package:flutter/foundation.dart';

/// Environment configuration — injected at build time via --dart-define.
/// Never hard-code secrets here.
enum AppEnvironment { development, production }

class Environment {
  Environment._();

  static const String _env = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  /// QA preview seeding is opt-in only for debug development builds via:
  /// `--dart-define=APP_ENV=development --dart-define=ENABLE_QA_PREVIEW=true`.
  static const bool _qaPreviewFlag = bool.fromEnvironment(
    'ENABLE_QA_PREVIEW',
    defaultValue: false,
  );

  /// Social OAuth providers remain disabled & hidden until genuine verified
  /// OAuth token exchange is configured and explicitly enabled.
  static const bool _verifiedSocialOAuthFlag = bool.fromEnvironment(
    'ENABLE_VERIFIED_SOCIAL_OAUTH',
    defaultValue: false,
  );

  static AppEnvironment get current {
    return _env == 'production'
        ? AppEnvironment.production
        : AppEnvironment.development;
  }

  static bool get isDevelopment => current == AppEnvironment.development;
  static bool get isProduction => current == AppEnvironment.production;

  /// Log level — suppress in production
  static bool get enableVerboseLogs => isDevelopment && kDebugMode;

  /// Strictly disabled in release/profile builds and in production.
  static bool get enableQaPreviewAccount =>
      kDebugMode && !kReleaseMode && isDevelopment && _qaPreviewFlag;

  /// True only when verified social OAuth is enabled for this build.
  static bool get verifiedSocialOAuthEnabled => _verifiedSocialOAuthFlag;
}

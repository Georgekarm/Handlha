import 'package:flutter/foundation.dart';

/// Environment configuration — injected at build time via --dart-define.
/// Never hard-code secrets here.
enum AppEnvironment { development, production }

class Environment {
  Environment._();

  static const String _env = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static AppEnvironment get current {
    return _env == 'production'
        ? AppEnvironment.production
        : AppEnvironment.development;
  }

  static bool get isDevelopment => current == AppEnvironment.development;
  static bool get isProduction => current == AppEnvironment.production;

  /// Base URL — override via --dart-define=API_BASE_URL=https://...
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.sekretairak.dev/api/v1',
  );

  /// Log level — suppress in production
  static bool get enableVerboseLogs => isDevelopment && kDebugMode;
}

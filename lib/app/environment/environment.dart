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

  static AppEnvironment get current {
    return _env == 'production'
        ? AppEnvironment.production
        : AppEnvironment.development;
  }

  static bool get isDevelopment => current == AppEnvironment.development;
  static bool get isProduction => current == AppEnvironment.production;

  /// Log level — suppress in production
  static bool get enableVerboseLogs => isDevelopment && kDebugMode;
}

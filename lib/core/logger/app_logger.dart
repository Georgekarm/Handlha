import 'package:flutter/foundation.dart';

import '../../app/environment/environment.dart';

/// Structured logger — never logs secrets or PII.
/// In production, wire this to a crash reporting service (e.g., Sentry)
/// without including sensitive fields.
class AppLogger {
  AppLogger._();

  static void debug(String message, {String? tag}) {
    if (Environment.enableVerboseLogs) {
      _log('DEBUG', tag, message);
    }
  }

  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      _log('INFO', tag, message);
    }
  }

  static void warning(String message, {String? tag, Object? error}) {
    _log('WARN', tag, message, error: error);
  }

  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log('ERROR', tag, message, error: error);
    if (kDebugMode && stackTrace != null) {
      // ignore: avoid_print
      debugPrint(stackTrace.toString());
    }
  }

  static void _log(String level, String? tag, String message, {Object? error}) {
    final prefix = tag != null ? '[$tag]' : '';
    // ignore: avoid_print
    debugPrint('[$level]$prefix $message${error != null ? ' | $error' : ''}');
  }
}

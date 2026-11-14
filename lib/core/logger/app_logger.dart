import 'package:flutter/foundation.dart';

import '../../app/environment/environment.dart';

/// Structured logger — never logs secrets or PII.
/// Redacts email addresses, tokens, and oversized payloads before emitting.
class AppLogger {
  AppLogger._();

  static final RegExp _emailPattern = RegExp(
    r'[\w.\-+]+@[\w\-]+\.\w{2,}',
    caseSensitive: false,
  );
  static final RegExp _secretPattern = RegExp(
    r'(bearer\s+[A-Za-z0-9\-._~+/]+=*|password\s*[:=]\s*\S+|token\s*[:=]\s*\S+|api[_-]?key\s*[:=]\s*\S+)',
    caseSensitive: false,
  );

  static String redact(String input) {
    var sanitized = input
        .replaceAll(_emailPattern, '[REDACTED_EMAIL]')
        .replaceAll(_secretPattern, '[REDACTED_SECRET]');
    if (sanitized.length > 300) {
      sanitized = '${sanitized.substring(0, 300)}...[TRUNCATED]';
    }
    return sanitized;
  }

  static void debug(String message, {String? tag}) {
    if (Environment.enableVerboseLogs && kDebugMode) {
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
      debugPrint(redact(stackTrace.toString()));
    }
  }

  static void _log(String level, String? tag, String message, {Object? error}) {
    // Release builds never write to the device log.
    if (!kDebugMode) return;
    final prefix = tag != null ? '[$tag]' : '';
    final safeMsg = redact(message);
    final safeErr = error != null
        ? ' | ${redact(error.toString())}'
        : '';
    // ignore: avoid_print
    debugPrint('[$level]$prefix $safeMsg$safeErr');
  }
}

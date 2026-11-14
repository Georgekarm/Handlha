import 'dart:developer' as dev;

enum LogLevel { debug, info, warning, error }

/// Pluggable logger. Never log secrets. User content is only logged by the
/// controller when `AssistantConfig.logUserContent` is true.
abstract class AssistantLogger {
  void log(LogLevel level, String message, {Object? error, StackTrace? stackTrace});
}

class NoopLogger implements AssistantLogger {
  const NoopLogger();
  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stackTrace}) {}
}

/// Writes to dart:developer (visible in DevTools / flutter logs).
class DeveloperLogger implements AssistantLogger {
  const DeveloperLogger({this.minLevel = LogLevel.debug});
  final LogLevel minLevel;
  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stackTrace}) {
    if (level.index < minLevel.index) return;
    dev.log(message,
        name: 'ai_assistant',
        level: 500 + level.index * 300,
        error: error,
        stackTrace: stackTrace);
  }
}

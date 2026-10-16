import 'dart:async';

import '../models/tool_models.dart';
import '../util/logger.dart';
import 'tool_definitions.dart';

/// The application implements this. Called ONLY with validated calls.
///
/// The implementation MUST (the AI layer cannot do this for you):
///  * resolve the user from the authenticated session (never from arguments),
///  * enforce task/reminder ownership on every read and write,
///  * re-validate business rules,
///  * return AMBIGUOUS instead of guessing when a selector matches > 1 item.
abstract class ToolExecutor {
  Future<ToolResult> execute(ToolCall call);

  /// Tools this executor implements; null = all. The controller only offers
  /// these to the LLM, so you can ship incrementally.
  Set<String>? get supportedTools => null;
}

typedef ToolHandler = Future<ToolResult> Function(Map<String, dynamic> args);

/// Convenience executor: register one handler per tool.
///
/// Exceptions and timeouts become `FAILED` results; their details are logged
/// but never sent to the LLM or the user.
class ToolRegistry implements ToolExecutor {
  ToolRegistry({this.timeout = const Duration(seconds: 15), AssistantLogger? logger})
      : _logger = logger ?? const NoopLogger();

  final Duration timeout;
  final AssistantLogger _logger;
  final Map<String, ToolHandler> _handlers = {};

  void register(String name, ToolHandler handler) {
    if (!AssistantTools.byName.containsKey(name)) {
      throw ArgumentError('Unknown tool "$name".');
    }
    _handlers[name] = handler;
  }

  List<String> get missingTools =>
      [for (final t in AssistantTools.all) if (!_handlers.containsKey(t.name)) t.name];

  @override
  Set<String>? get supportedTools => _handlers.keys.toSet();

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final h = _handlers[call.name];
    if (h == null) return ToolResult.failed(message: 'tool_not_available');
    try {
      return await h(call.arguments).timeout(timeout);
    } on TimeoutException catch (e, st) {
      _logger.log(LogLevel.error, 'Tool ${call.name} timed out', error: e, stackTrace: st);
      return ToolResult.failed();
    } catch (e, st) {
      _logger.log(LogLevel.error, 'Tool ${call.name} threw', error: e, stackTrace: st);
      return ToolResult.failed();
    }
  }
}

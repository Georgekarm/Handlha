import 'dart:convert';

class ToolCall {
  const ToolCall({required this.id, required this.name, required this.arguments});
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    Object? args = json['arguments'] ?? json['input'];
    if (args is String) {
      try {
        args = jsonDecode(args);
      } catch (_) {
        args = null;
      }
    }
    return ToolCall(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      arguments: args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'arguments': arguments};
}

enum ToolStatus { success, failed, notFound, ambiguous, permissionDenied, invalidArgument }

extension ToolStatusX on ToolStatus {
  String get wire {
    switch (this) {
      case ToolStatus.success:
        return 'SUCCESS';
      case ToolStatus.failed:
        return 'FAILED';
      case ToolStatus.notFound:
        return 'NOT_FOUND';
      case ToolStatus.ambiguous:
        return 'AMBIGUOUS';
      case ToolStatus.permissionDenied:
        return 'PERMISSION_DENIED';
      case ToolStatus.invalidArgument:
        return 'INVALID_ARGUMENT';
    }
  }

  /// Lower-case form used in the Flutter-facing response contract.
  String get actionStatus => wire.toLowerCase();

  static ToolStatus parse(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'SUCCESS':
        return ToolStatus.success;
      case 'NOT_FOUND':
        return ToolStatus.notFound;
      case 'AMBIGUOUS':
        return ToolStatus.ambiguous;
      case 'PERMISSION_DENIED':
        return ToolStatus.permissionDenied;
      case 'INVALID_ARGUMENT':
        return ToolStatus.invalidArgument;
      default:
        return ToolStatus.failed;
    }
  }
}

/// Result of executing a tool inside the application.
///
/// `message` is a short, non-technical hint for the LLM only. Never put stack
/// traces or exception text in it.
class ToolResult {
  const ToolResult(this.status, {this.data = const {}, this.message});
  final ToolStatus status;
  final Map<String, dynamic> data;
  final String? message;

  bool get isSuccess => status == ToolStatus.success;

  factory ToolResult.success([Map<String, dynamic> data = const {}]) =>
      ToolResult(ToolStatus.success, data: data);
  factory ToolResult.failed({String? message}) =>
      ToolResult(ToolStatus.failed, message: message);
  factory ToolResult.notFound({String? message}) =>
      ToolResult(ToolStatus.notFound, message: message);
  factory ToolResult.permissionDenied() => const ToolResult(ToolStatus.permissionDenied);

  /// [candidates]: e.g. [{task_id, title, date, time}, ...] (max ~5).
  factory ToolResult.ambiguous(List<Map<String, dynamic>> candidates) =>
      ToolResult(ToolStatus.ambiguous, data: {'candidates': candidates});
  factory ToolResult.invalid(List<String> errors) =>
      ToolResult(ToolStatus.invalidArgument, data: {'errors': errors});

  factory ToolResult.fromJson(Map<String, dynamic> j) => ToolResult(
        ToolStatusX.parse(j['status']?.toString()),
        data: j['data'] is Map ? Map<String, dynamic>.from(j['data'] as Map) : const {},
        message: j['message']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'status': status.wire,
        'data': data,
        if (message != null) 'message': message,
      };
}

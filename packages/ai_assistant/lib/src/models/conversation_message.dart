import 'dart:convert';
import 'tool_models.dart';

enum MessageRole { user, assistant, tool }

int _messageSequence = 0;
String _newMessageId() =>
    'msg_${DateTime.now().microsecondsSinceEpoch}_${_messageSequence++}';

class ConversationMessage {
  const ConversationMessage._({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.toolCalls = const [],
    this.toolCallId,
    this.toolName,
  });

  final String id;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final List<ToolCall> toolCalls; // assistant only
  final String? toolCallId; // tool only
  final String? toolName; // tool only

  factory ConversationMessage.user(
    String text, {
    String? id,
    DateTime? createdAt,
  }) =>
      ConversationMessage._(
        id: id ?? _newMessageId(),
        role: MessageRole.user,
        content: text,
        createdAt: createdAt ?? DateTime.now(),
      );

  factory ConversationMessage.assistant(
    String text, {
    List<ToolCall> toolCalls = const [],
    String? id,
    DateTime? createdAt,
  }) =>
      ConversationMessage._(
        id: id ?? _newMessageId(),
        role: MessageRole.assistant,
        content: text,
        toolCalls: toolCalls,
        createdAt: createdAt ?? DateTime.now(),
      );

  factory ConversationMessage.tool(
    ToolCall call,
    ToolResult result, {
    String? id,
    DateTime? createdAt,
  }) =>
      ConversationMessage._(
        id: id ?? _newMessageId(),
        role: MessageRole.tool,
        content: jsonEncode(result.toJson()),
        toolCallId: call.id,
        toolName: call.name,
        createdAt: createdAt ?? DateTime.now(),
      );

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    final role = MessageRole.values.byName(json['role'] as String);
    final calls = json['tool_calls'] is List
        ? (json['tool_calls'] as List)
            .whereType<Map>()
            .map((c) => ToolCall.fromJson(Map<String, dynamic>.from(c)))
            .toList()
        : <ToolCall>[];
    return ConversationMessage._(
      id: (json['id'] ?? _newMessageId()).toString(),
      role: role,
      content: (json['content'] ?? '').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
      toolCalls: calls,
      toolCallId: json['tool_call_id']?.toString(),
      toolName: json['name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        ...toLlmJson(),
        'id': id,
        'created_at': createdAt.toIso8601String(),
      };

  Map<String, dynamic> toLlmJson() => {
        'role': role.name,
        'content': content,
        if (toolCalls.isNotEmpty)
          'tool_calls': toolCalls.map((c) => c.toJson()).toList(),
        if (toolCallId != null) 'tool_call_id': toolCallId,
        if (toolName != null) 'name': toolName,
      };
}

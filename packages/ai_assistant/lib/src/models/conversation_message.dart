import 'dart:convert';
import 'tool_models.dart';

enum MessageRole { user, assistant, tool }

class ConversationMessage {
  const ConversationMessage._({
    required this.role,
    required this.content,
    this.toolCalls = const [],
    this.toolCallId,
    this.toolName,
  });

  final MessageRole role;
  final String content;
  final List<ToolCall> toolCalls; // assistant only
  final String? toolCallId; // tool only
  final String? toolName; // tool only

  factory ConversationMessage.user(String text) =>
      ConversationMessage._(role: MessageRole.user, content: text);

  factory ConversationMessage.assistant(String text, {List<ToolCall> toolCalls = const []}) =>
      ConversationMessage._(role: MessageRole.assistant, content: text, toolCalls: toolCalls);

  factory ConversationMessage.tool(ToolCall call, ToolResult result) => ConversationMessage._(
        role: MessageRole.tool,
        content: jsonEncode(result.toJson()),
        toolCallId: call.id,
        toolName: call.name,
      );

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        if (toolCalls.isNotEmpty) 'tool_calls': toolCalls.map((c) => c.toJson()).toList(),
        if (toolCallId != null) 'tool_call_id': toolCallId,
        if (toolName != null) 'name': toolName,
      };
}

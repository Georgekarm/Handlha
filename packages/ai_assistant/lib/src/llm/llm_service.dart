import '../models/conversation_message.dart';
import '../models/tool_models.dart';

class LlmRequest {
  const LlmRequest({
    required this.systemPrompt,
    required this.messages,
    required this.tools,
    required this.conversationId,
  });
  final String systemPrompt;
  final List<ConversationMessage> messages;
  final List<Map<String, dynamic>> tools;
  final String conversationId;

  Map<String, dynamic> toJson() => {
        'conversation_id': conversationId,
        'system': systemPrompt,
        'messages': messages.map((m) => m.toJson()).toList(),
        'tools': tools,
      };
}

class LlmReply {
  const LlmReply({this.text, this.toolCalls = const []});
  final String? text;
  final List<ToolCall> toolCalls;
}

enum LlmErrorKind { network, timeout, unauthorized, rateLimited, invalidResponse }

class LlmException implements Exception {
  const LlmException(this.kind, [this.detail]);
  final LlmErrorKind kind;
  final String? detail; // technical, logs only
  @override
  String toString() => 'LlmException(${kind.name}: $detail)';
}

/// Provider-neutral LLM access. It only DECIDES (text and/or tool calls); it
/// never touches application data.
abstract class LLMService {
  Future<LlmReply> complete(LlmRequest request);
}

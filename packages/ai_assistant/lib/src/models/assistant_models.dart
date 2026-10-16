import 'tool_models.dart';

enum InputType { voice, text }

/// Transport-independent input contract.
class AssistantRequest {
  const AssistantRequest({
    required this.type,
    required this.text,
    required this.conversationId,
    required this.currentDatetime,
  });

  final InputType type;
  final String text;
  final String conversationId;

  /// ISO-8601 with offset, e.g. 2026-10-04T18:00:00+03:00 (Africa/Cairo).
  final String currentDatetime;

  factory AssistantRequest.fromJson(Map<String, dynamic> j) => AssistantRequest(
        type: j['type'] == 'voice' ? InputType.voice : InputType.text,
        text: (j['text'] ?? '').toString(),
        conversationId: (j['conversation_id'] ?? 'default').toString(),
        currentDatetime: (j['current_datetime'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'text': text,
        'conversation_id': conversationId,
        'current_datetime': currentDatetime,
      };
}

enum AssistantErrorCode {
  micPermissionDenied,
  micUnavailable,
  emptySpeech,
  sttFailure,
  network,
  llmTimeout,
  llmInvalidResponse,
  invalidToolCall,
  toolFailure,
  ttsFailure,
  contextFailure,
  unauthorized,
  rateLimited,
  invalidRequest,
  unknown,
}

class ActionSummary {
  const ActionSummary(this.type, this.status);
  final String type; // tool name, e.g. create_task
  final ToolStatus status;
  Map<String, dynamic> toJson() => {'type': type, 'status': status.actionStatus};
}

class AssistantResponse {
  static const typeResponse = 'assistant_response';
  static const typeError = 'error';
  static const typeCancelled = 'cancelled';

  const AssistantResponse({
    this.type = typeResponse,
    required this.text,
    this.actions = const [],
    required this.conversationId,
    this.needsUserInput = false,
    this.errorCode,
  });

  factory AssistantResponse.error({
    required String text,
    required AssistantErrorCode code,
    required String conversationId,
    List<ActionSummary> actions = const [],
  }) =>
      AssistantResponse(
          type: typeError,
          text: text,
          errorCode: code,
          conversationId: conversationId,
          actions: actions);

  factory AssistantResponse.cancelled(String conversationId) =>
      AssistantResponse(type: typeCancelled, text: '', conversationId: conversationId);

  final String type;
  final String text;

  /// Every tool executed this turn (invalid/rejected calls are excluded).
  final List<ActionSummary> actions;
  final String conversationId;

  /// True when the assistant asked a question: the UI may re-open the mic.
  final bool needsUserInput;
  final AssistantErrorCode? errorCode;

  /// Primary action for the simple contract (the last executed one).
  ActionSummary? get action => actions.isEmpty ? null : actions.last;

  Map<String, dynamic> toJson() => {
        'type': type,
        'text': text,
        if (action != null) 'action': action!.toJson(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'conversation_id': conversationId,
        'needs_user_input': needsUserInput,
        if (errorCode != null) 'error_code': errorCode!.name,
      };
}

enum AssistantState { idle, listening, transcribing, thinking, executing, speaking, error }

enum AssistantEventKind {
  partialTranscript,
  finalTranscript,
  toolStarted,
  toolFinished,
  response,
  speakingStarted,
  speakingEnded,
  error,
}

class AssistantEvent {
  const AssistantEvent(this.kind,
      {this.text, this.toolName, this.toolStatus, this.errorCode, this.response});
  final AssistantEventKind kind;
  final String? text;
  final String? toolName;
  final ToolStatus? toolStatus;
  final AssistantErrorCode? errorCode;
  final AssistantResponse? response;
}

class AssistantConfig {
  const AssistantConfig({
    this.maxToolRounds = 6,
    this.maxToolCallsPerTurn = 8,
    this.speakResponses = true,
    this.finalTranscriptGrace = const Duration(seconds: 2),
    this.errorStateHold = const Duration(milliseconds: 1200),
    this.logUserContent = false,
  });
  final int maxToolRounds;
  final int maxToolCallsPerTurn;
  final bool speakResponses;

  /// After stopListening(), how long to wait for a final transcript before
  /// falling back to the last partial transcript.
  final Duration finalTranscriptGrace;

  /// How long the ERROR state is held when the error is not spoken.
  final Duration errorStateHold;

  /// Privacy: transcripts/responses are only logged when true.
  final bool logUserContent;
}

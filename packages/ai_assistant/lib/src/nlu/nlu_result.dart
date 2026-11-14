import '../nlu/egyptian_intent_model.dart';

/// Strict structured NLU output produced before any validation or tool execution.
/// Contains zero user identifiers (`user_id` always comes from the app session).
class AssistantUnderstandingResult {
  static const currentSchemaVersion = '1.0';

  const AssistantUnderstandingResult({
    this.schemaVersion = currentSchemaVersion,
    required this.modelVersion,
    required this.originalText,
    required this.normalizedText,
    required this.intent,
    required this.confidence,
    required this.margin,
    required this.slots,
    required this.sourceTextSpan,
    required this.needsClarification,
    this.clarificationQuestion,
    this.pendingAction,
    this.safetyFlags = const NluSafetyFlags(),
    required this.rationale,
  });

  final String schemaVersion;
  final String modelVersion;
  final String originalText;
  final String normalizedText;
  final EgyptianIntent intent;
  final double confidence;
  final double margin;
  final Map<String, dynamic> slots;
  final TextSpanRef sourceTextSpan;
  final bool needsClarification;
  final String? clarificationQuestion;
  final String? pendingAction;
  final NluSafetyFlags safetyFlags;
  final String rationale;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'model_version': modelVersion,
        'original_text': originalText,
        'normalized_text': normalizedText,
        'intent': intent.wireName,
        'confidence': confidence,
        'margin': margin,
        'slots': slots,
        'source_text_span': sourceTextSpan.toJson(),
        'needs_clarification': needsClarification,
        if (clarificationQuestion != null)
          'clarification_question': clarificationQuestion,
        if (pendingAction != null) 'pending_action': pendingAction,
        'safety_flags': safetyFlags.toJson(),
        'rationale': rationale,
      };
}

class TextSpanRef {
  const TextSpanRef({
    required this.start,
    required this.end,
    required this.text,
  });

  final int start;
  final int end;
  final String text;

  Map<String, dynamic> toJson() => {'start': start, 'end': end, 'text': text};
}

class NluSafetyFlags {
  const NluSafetyFlags({
    this.negated = false,
    this.hypotheticalOrQuestion = false,
    this.futureNotCompleted = false,
    this.quotedExample = false,
    this.selfCorrected = false,
    this.lowConfidence = false,
  });

  final bool negated;
  final bool hypotheticalOrQuestion;
  final bool futureNotCompleted;
  final bool quotedExample;
  final bool selfCorrected;
  final bool lowConfidence;

  bool get blocksWrite =>
      negated ||
      hypotheticalOrQuestion ||
      futureNotCompleted ||
      quotedExample ||
      lowConfidence;

  Map<String, dynamic> toJson() => {
        'negated': negated,
        'hypothetical_or_question': hypotheticalOrQuestion,
        'future_not_completed': futureNotCompleted,
        'quoted_example': quotedExample,
        'self_corrected': selfCorrected,
        'low_confidence': lowConfidence,
      };
}


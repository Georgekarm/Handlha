import 'assistant_models.dart';
import 'tool_models.dart';

/// All user-facing fallback strings (Egyptian Arabic). Technical details are
/// never shown to the user.
class EgyptianMessages {
  EgyptianMessages._();

  static const micPermission = 'محتاج إذن الميكروفون عشان أقدر أسمعك.';
  static const micUnavailable = 'الميكروفون مش شغال دلوقتي، جرب تاني كمان شوية.';
  static const emptySpeech = 'مسمعتش حاجة، ممكن تعيد تاني؟';
  static const sttFailure = 'معلش، معرفتش أسمعك كويس. جرب تاني.';
  static const network = 'شكلها مفيش نت دلوقتي، جرب تاني كمان شوية.';
  static const timeout = 'الموضوع أخد وقت أطول من اللازم، ممكن تجرب تاني؟';
  static const rateLimited = 'الخدمة مشغولة شوية، جرب تاني كمان لحظة.';
  static const unauthorized = 'محتاج تسجل دخول تاني عشان أكمل.';
  static const unknownCommand = 'معلش، مش فاهم قصدك قوي. ممكن تقولها بطريقة تانية؟';
  static const toolFailure = 'معلش، حصلت مشكلة وأنا بحاول أنفذ الطلب.';
  static const notFound = 'مش لاقي التاسك دي.';
  static const ambiguous = 'لقيت أكتر من Task شبه دي، تقصد أنهي واحدة؟';
  static const permissionDenied = 'معلش، مش مسموحلي أعمل ده.';
  static const generic = 'معلش، حصلت مشكلة. جرب تاني.';
  static const unverifiedClaim = 'معلش، مقدرتش أنفذ الطلب ده. ممكن تقولهولي تاني؟';
  static const allDone = 'تمام، خلصت.';

  static String forError(AssistantErrorCode c) {
    switch (c) {
      case AssistantErrorCode.micPermissionDenied:
        return micPermission;
      case AssistantErrorCode.micUnavailable:
        return micUnavailable;
      case AssistantErrorCode.emptySpeech:
        return emptySpeech;
      case AssistantErrorCode.sttFailure:
        return sttFailure;
      case AssistantErrorCode.network:
        return network;
      case AssistantErrorCode.llmTimeout:
        return timeout;
      case AssistantErrorCode.rateLimited:
        return rateLimited;
      case AssistantErrorCode.unauthorized:
        return unauthorized;
      case AssistantErrorCode.llmInvalidResponse:
      case AssistantErrorCode.invalidToolCall:
        return unknownCommand;
      case AssistantErrorCode.toolFailure:
        return toolFailure;
      case AssistantErrorCode.ttsFailure:
      case AssistantErrorCode.contextFailure:
      case AssistantErrorCode.invalidRequest:
      case AssistantErrorCode.unknown:
        return generic;
    }
  }

  /// Deterministic text used when the LLM cannot produce a final answer after
  /// tools ran. Never claims success unless every result was SUCCESS.
  static String fallbackFor(List<ToolResult> results) {
    for (final r in results) {
      switch (r.status) {
        case ToolStatus.ambiguous:
          return ambiguous;
        case ToolStatus.notFound:
          return notFound;
        case ToolStatus.permissionDenied:
          return permissionDenied;
        case ToolStatus.failed:
        case ToolStatus.invalidArgument:
          return toolFailure;
        case ToolStatus.success:
          break;
      }
    }
    return allDone;
  }
}

/// Detects first-person "I did it" claims in assistant text. Used to stop the
/// model from claiming success when no tool returned SUCCESS this turn.
class ClaimGuard {
  ClaimGuard._();
  static final _claims = RegExp(
      r'(ضفتلك|ضفتها|ضفتهالك|ضفت لك|خليتها|خليتهالك|مسحتها|مسحتلك|شيلتها|فكرتك|علمتها|أجلتها|اجلتها|عدلتها|حطيتلك|سجلتلك)');
  static bool looksLikeUnverifiedClaim(String text) => _claims.hasMatch(text);
}

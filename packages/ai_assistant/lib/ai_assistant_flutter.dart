/// Flutter-plugin-backed providers (speech_to_text + flutter_tts).
/// Import this in the app; swap for other providers by implementing
/// SpeechToTextService / TextToSpeechService.
library;

export 'ai_assistant.dart';
export 'src/stt/speech_to_text_stt_service.dart';
export 'src/tts/flutter_tts_service.dart';

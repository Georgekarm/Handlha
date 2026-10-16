import 'dart:async';
import 'dart:convert';

import '../llm/conversation_manager.dart';
import '../llm/llm_service.dart';
import '../llm/system_prompt.dart';
import '../models/assistant_models.dart';
import '../models/conversation_message.dart';
import '../models/egyptian_messages.dart';
import '../models/tool_models.dart';
import '../stt/stt_models.dart';
import '../stt/stt_service.dart';
import '../tools/tool_definitions.dart';
import '../tools/tool_executor.dart';
import '../tools/tool_validator.dart';
import '../tts/tts_service.dart';
import '../util/arabic_text.dart';
import '../util/logger.dart';
import '../util/wall_clock.dart';

/// Orchestrates SPEECH -> STT -> LLM -> TOOLS -> LLM -> TTS -> SPEECH.
///
/// The Flutter app only needs:
///   startVoiceInteraction() / stopVoiceInteraction() / sendTextMessage() /
///   cancelInteraction(), plus the `stateStream`, `events` and `responses`
///   streams for UI.
class AIAssistantController {
  AIAssistantController({
    required this.stt,
    required this.llm,
    required this.tts,
    required this.tools,
    required this.nowProvider,
    ConversationManager? conversations,
    this.config = const AssistantConfig(),
    AssistantLogger? logger,
    this.defaultConversationId = 'default',
  })  : conversations = conversations ?? ConversationManager(),
        logger = logger ?? const NoopLogger();

  final SpeechToTextService stt;
  final LLMService llm;
  final TextToSpeechService tts;
  final ToolExecutor tools;

  /// Returns the current Cairo date-time as ISO-8601 WITH offset, supplied by
  /// the app (e.g. `() => '2026-10-04T18:00:00+03:00'`). The module never
  /// assumes the date. `WallClock.deviceNowIso` is a ready-made helper.
  final String Function() nowProvider;

  final ConversationManager conversations;
  final AssistantConfig config;
  final AssistantLogger logger;
  final String defaultConversationId;

  final _stateCtrl = StreamController<AssistantState>.broadcast();
  final _eventCtrl = StreamController<AssistantEvent>.broadcast();
  final _responseCtrl = StreamController<AssistantResponse>.broadcast();

  AssistantState _state = AssistantState.idle;
  int _runId = 0;
  int _handledFinalRun = -1;
  Timer? _grace;
  String _lastPartial = '';
  String _voiceCid = 'default';
  StreamSubscription<String>? _partialSub;
  StreamSubscription<String>? _finalSub;
  StreamSubscription<SttError>? _errSub;

  AssistantState get state => _state;
  Stream<AssistantState> get stateStream => _stateCtrl.stream;
  Stream<AssistantEvent> get events => _eventCtrl.stream;
  Stream<AssistantResponse> get responses => _responseCtrl.stream;

  // ------------------------------------------------------------ public API

  /// Mic button pressed: starts listening. Barge-in: interrupts any speech.
  Future<void> startVoiceInteraction({String? conversationId}) async {
    await _interrupt();
    final run = ++_runId;
    _voiceCid = conversationId ?? defaultConversationId;
    _lastPartial = '';
    _setState(AssistantState.listening);
    _bindStt(run);
    try {
      await stt.startListening();
    } on SttException catch (e) {
      logger.log(LogLevel.warning, 'STT start failed: $e');
      await _failVoice(run, _mapStt(e.error.code));
    } catch (e, st) {
      logger.log(LogLevel.error, 'STT start failed', error: e, stackTrace: st);
      await _failVoice(run, AssistantErrorCode.sttFailure);
    }
  }

  /// Mic released / "done" pressed. The final transcript then flows into the
  /// LLM automatically. (STT may also finish by itself on silence.)
  Future<void> stopVoiceInteraction() async {
    if (_state != AssistantState.listening) return;
    final run = _runId;
    _setState(AssistantState.transcribing);
    await _safe(stt.stopListening);
    _grace?.cancel();
    _grace = Timer(config.finalTranscriptGrace, () {
      if (run != _runId || _handledFinalRun == run) return;
      _onFinalTranscript(run, _lastPartial); // empty => "didn't hear you"
    });
  }

  /// Text input (or a transcript produced elsewhere). The returned future
  /// completes when the response TEXT is ready; speech continues afterwards
  /// (watch [stateStream]).
  Future<AssistantResponse> sendTextMessage(String text,
      {String? conversationId, bool? speak}) {
    return handleRequest(
      AssistantRequest(
        type: InputType.text,
        text: text,
        conversationId: conversationId ?? defaultConversationId,
        currentDatetime: nowProvider(),
      ),
      speak: speak,
    );
  }

  /// Transport-independent entry point implementing the JSON contract
  /// (AssistantRequest -> AssistantResponse).
  Future<AssistantResponse> handleRequest(AssistantRequest req, {bool? speak}) async {
    await _interrupt();
    final run = ++_runId;
    final resp = await _runTurn(run, req);
    unawaited(_finish(run, resp, speak: speak));
    return resp;
  }

  /// Stops listening, thinking and speaking and returns to IDLE.
  Future<void> cancelInteraction() async {
    await _interrupt();
  }

  void resetConversation([String? conversationId]) =>
      conversations.reset(conversationId ?? defaultConversationId);

  void dispose() {
    _runId++;
    _grace?.cancel();
    _unbindStt();
    _stateCtrl.close();
    _eventCtrl.close();
    _responseCtrl.close();
  }

  // ------------------------------------------------------------ voice flow

  void _bindStt(int run) {
    _unbindStt();
    _partialSub = stt.partialTranscripts.listen((t) {
      if (run != _runId) return;
      _lastPartial = t;
      _emit(AssistantEvent(AssistantEventKind.partialTranscript, text: t));
    });
    _finalSub = stt.finalTranscripts.listen((t) => _onFinalTranscript(run, t));
    _errSub = stt.errors.listen((e) {
      if (run != _runId || _handledFinalRun == run) return;
      logger.log(LogLevel.warning, 'STT error: ${e.code.name} ${e.detail ?? ''}');
      _failVoice(run, _mapStt(e.code));
    });
  }

  void _unbindStt() {
    _partialSub?.cancel();
    _finalSub?.cancel();
    _errSub?.cancel();
    _partialSub = _finalSub = null;
    _errSub = null;
  }

  Future<void> _onFinalTranscript(int run, String text) async {
    if (run != _runId || _handledFinalRun == run) return;
    _handledFinalRun = run;
    _grace?.cancel();
    _unbindStt();
    if (stt.isListening) await _safe(stt.stopListening);
    if (run != _runId) return;

    final cleaned = text.trim();
    if (cleaned.isEmpty) {
      final resp = _error(_voiceCid, AssistantErrorCode.emptySpeech);
      await _finish(run, resp);
      return;
    }
    _setState(AssistantState.transcribing);
    _emit(AssistantEvent(AssistantEventKind.finalTranscript, text: cleaned));
    final resp = await _runTurn(
      run,
      AssistantRequest(
        type: InputType.voice,
        text: cleaned,
        conversationId: _voiceCid,
        currentDatetime: nowProvider(),
      ),
    );
    await _finish(run, resp);
  }

  Future<void> _failVoice(int run, AssistantErrorCode code) async {
    if (run != _runId) return;
    _handledFinalRun = run;
    _grace?.cancel();
    _unbindStt();
    await _safe(stt.cancel);
    if (run != _runId) return;
    await _finish(run, _error(_voiceCid, code));
  }

  // ------------------------------------------------------------ core turn

  Future<AssistantResponse> _runTurn(int run, AssistantRequest req) async {
    final cid = req.conversationId.isEmpty ? defaultConversationId : req.conversationId;

    // Never assume the date: the app must supply a valid current datetime.
    final now = WallClock.tryParse(req.currentDatetime);
    if (now == null) {
      return _error(cid, AssistantErrorCode.invalidRequest, 'invalid current_datetime');
    }
    final text = ArabicText.normalizeDigits(req.text).trim();
    if (text.isEmpty) return _error(cid, AssistantErrorCode.emptySpeech);
    if (config.logUserContent) logger.log(LogLevel.debug, 'USER: $text');

    _setState(AssistantState.thinking);

    final pending = conversations.takePending(cid);
    final turn = <ConversationMessage>[ConversationMessage.user(text)];
    final actions = <ActionSummary>[];
    final results = <ToolResult>[];
    final validator = ToolValidator(now: now);
    final toolDefs = AssistantTools.definitions(only: tools.supportedTools);
    var executedAny = false;
    var askedClarification = false;
    String? finalText;

    try {
      for (var round = 0; round < config.maxToolRounds; round++) {
        final reply = await llm.complete(LlmRequest(
          systemPrompt: SystemPrompt.build(
            now: now,
            contextBlock: conversations.buildContext(cid, pending),
          ),
          messages: [...conversations.history(cid), ...turn],
          tools: toolDefs,
          conversationId: cid,
        ));
        if (run != _runId) return _cancelled(cid, turn, actions);

        final calls = _normalizeCalls(reply.toolCalls);
        if (calls.isEmpty) {
          finalText = reply.text?.trim();
          break;
        }
        turn.add(ConversationMessage.assistant(reply.text?.trim() ?? '', toolCalls: calls));

        final onlyClarification = calls.every((c) => c.name == AssistantTools.clarificationName);
        if (!onlyClarification) _setState(AssistantState.executing);

        String? question;
        for (final call in calls) {
          if (run != _runId) return _cancelled(cid, turn, actions);

          if (call.name == AssistantTools.clarificationName) {
            final v = validator.validate(call);
            if (v.ok) {
              question = v.args['question'] as String;
              final known = v.args['known_fields'];
              conversations.setPending(
                cid,
                PendingAction(
                  action: (v.args['pending_action'] as String?) ?? 'other',
                  knownFields: known is Map ? Map<String, dynamic>.from(known) : <String, dynamic>{},
                  question: question,
                ),
              );
              askedClarification = true;
              turn.add(ConversationMessage.tool(call, ToolResult.success({'noted': true})));
            } else {
              turn.add(ConversationMessage.tool(call, ToolResult.invalid(v.errors)));
            }
            continue;
          }

          final result = await _executeOne(call, validator, cid);
          results.add(result);
          turn.add(ConversationMessage.tool(call, _limitForLlm(result)));
          if (result.status != ToolStatus.invalidArgument) {
            actions.add(ActionSummary(call.name, result.status));
            if (result.isSuccess) executedAny = true;
          }
        }
        if (run != _runId) return _cancelled(cid, turn, actions);

        if (onlyClarification && question != null) {
          finalText = question; // deterministic: speak exactly the question
          break;
        }
        _setState(AssistantState.thinking);
      }
    } on LlmException catch (e, st) {
      logger.log(LogLevel.error, 'LLM failure: $e', stackTrace: st);
      return _failTurn(cid, turn, actions, _mapLlm(e.kind));
    } catch (e, st) {
      logger.log(LogLevel.error, 'Turn failure', error: e, stackTrace: st);
      return _failTurn(cid, turn, actions, AssistantErrorCode.unknown);
    }

    var answer = finalText ?? '';
    if (answer.isEmpty) {
      answer = results.isEmpty ? EgyptianMessages.unknownCommand : EgyptianMessages.fallbackFor(results);
    } else if (!executedAny && ClaimGuard.looksLikeUnverifiedClaim(answer)) {
      // The model claimed it did something but no tool returned SUCCESS.
      logger.log(LogLevel.warning, 'Blocked unverified success claim');
      answer = results.isEmpty ? EgyptianMessages.unverifiedClaim : EgyptianMessages.fallbackFor(results);
    }
    if (config.logUserContent) logger.log(LogLevel.debug, 'ASSISTANT: $answer');

    turn.add(ConversationMessage.assistant(answer));
    conversations.commitTurn(cid, turn);

    return AssistantResponse(
      text: answer,
      actions: actions,
      conversationId: cid,
      needsUserInput: askedClarification || answer.endsWith('؟') || answer.endsWith('?'),
    );
  }

  Future<ToolResult> _executeOne(ToolCall call, ToolValidator validator, String cid) async {
    final v = validator.validate(call);
    if (!v.ok) {
      logger.log(LogLevel.warning, 'Rejected tool call ${call.name}: ${v.errors.join(' | ')}');
      return ToolResult.invalid(v.errors);
    }
    _emit(AssistantEvent(AssistantEventKind.toolStarted, toolName: call.name));
    ToolResult result;
    try {
      result = await tools.execute(ToolCall(id: call.id, name: call.name, arguments: v.args));
    } catch (e, st) {
      logger.log(LogLevel.error, 'Executor threw for ${call.name}', error: e, stackTrace: st);
      result = ToolResult.failed();
    }
    conversations.recordEntity(cid, call, result);
    _emit(AssistantEvent(AssistantEventKind.toolFinished,
        toolName: call.name, toolStatus: result.status));
    return result;
  }

  /// Keeps oversized/unencodable results from blowing up the LLM request.
  ToolResult _limitForLlm(ToolResult r) {
    try {
      if (jsonEncode(r.data).length > 8000) {
        return ToolResult(r.status,
            data: const {'truncated': true, 'note': 'Too many results; ask the user to narrow down.'},
            message: r.message);
      }
      return r;
    } catch (_) {
      return ToolResult.failed();
    }
  }

  List<ToolCall> _normalizeCalls(List<ToolCall> raw) {
    final out = <ToolCall>[];
    final seen = <String>{};
    for (var i = 0; i < raw.length && out.length < config.maxToolCallsPerTurn; i++) {
      var id = raw[i].id;
      if (id.isEmpty || seen.contains(id)) {
        id = 'call_${DateTime.now().microsecondsSinceEpoch}_$i';
      }
      seen.add(id);
      out.add(ToolCall(id: id, name: raw[i].name, arguments: raw[i].arguments));
    }
    return out;
  }

  // ------------------------------------------------------------ finishing

  Future<void> _finish(int run, AssistantResponse resp, {bool? speak}) async {
    if (run != _runId) return;
    if (resp.type == AssistantResponse.typeCancelled) return;

    _responseCtrl.add(resp);
    _emit(AssistantEvent(AssistantEventKind.response, text: resp.text, response: resp));

    final isError = resp.type == AssistantResponse.typeError;
    final shouldSpeak = (speak ?? config.speakResponses) && resp.text.isNotEmpty;
    if (isError) {
      _emit(AssistantEvent(AssistantEventKind.error, errorCode: resp.errorCode, text: resp.text));
      _setState(AssistantState.error);
    } else if (shouldSpeak) {
      _setState(AssistantState.speaking);
    }

    if (shouldSpeak) {
      _emit(const AssistantEvent(AssistantEventKind.speakingStarted));
      try {
        await tts.speak(resp.text);
      } catch (e, st) {
        // TTS failure is non-fatal: the text response was already delivered.
        logger.log(LogLevel.error, 'TTS failed', error: e, stackTrace: st);
        _emit(const AssistantEvent(AssistantEventKind.error,
            errorCode: AssistantErrorCode.ttsFailure));
      }
      if (run != _runId) return;
      _emit(const AssistantEvent(AssistantEventKind.speakingEnded));
    } else if (isError) {
      await Future<void>.delayed(config.errorStateHold);
      if (run != _runId) return;
    }
    _setState(AssistantState.idle);
  }

  AssistantResponse _failTurn(String cid, List<ConversationMessage> turn,
      List<ActionSummary> actions, AssistantErrorCode code) {
    final msg = EgyptianMessages.forError(code);
    if (actions.isNotEmpty) {
      // Some tools already ran: keep that in history so a retry doesn't repeat them.
      turn.add(ConversationMessage.assistant(msg));
      conversations.commitTurn(cid, turn);
    }
    return AssistantResponse.error(text: msg, code: code, conversationId: cid, actions: actions);
  }

  AssistantResponse _cancelled(String cid, List<ConversationMessage> turn, List<ActionSummary> actions) {
    if (actions.isNotEmpty) conversations.commitTurn(cid, turn);
    return AssistantResponse.cancelled(cid);
  }

  AssistantResponse _error(String cid, AssistantErrorCode code, [String? detail]) {
    if (detail != null) logger.log(LogLevel.warning, 'Error ${code.name}: $detail');
    return AssistantResponse.error(
        text: EgyptianMessages.forError(code), code: code, conversationId: cid);
  }

  // ------------------------------------------------------------ helpers

  Future<void> _interrupt() async {
    _runId++;
    _grace?.cancel();
    _unbindStt();
    await _safe(stt.cancel);
    await _safe(tts.stop);
    _setState(AssistantState.idle);
  }

  Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } catch (e, st) {
      logger.log(LogLevel.warning, 'Ignored error', error: e, stackTrace: st);
    }
  }

  void _setState(AssistantState s) {
    if (_state == s) return;
    _state = s;
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  void _emit(AssistantEvent e) {
    if (!_eventCtrl.isClosed) _eventCtrl.add(e);
  }

  AssistantErrorCode _mapStt(SttErrorCode c) {
    switch (c) {
      case SttErrorCode.permissionDenied:
        return AssistantErrorCode.micPermissionDenied;
      case SttErrorCode.unavailable:
        return AssistantErrorCode.micUnavailable;
      case SttErrorCode.noSpeech:
        return AssistantErrorCode.emptySpeech;
      case SttErrorCode.network:
        return AssistantErrorCode.network;
      case SttErrorCode.unsupportedLanguage:
      case SttErrorCode.failure:
        return AssistantErrorCode.sttFailure;
    }
  }

  AssistantErrorCode _mapLlm(LlmErrorKind k) {
    switch (k) {
      case LlmErrorKind.network:
        return AssistantErrorCode.network;
      case LlmErrorKind.timeout:
        return AssistantErrorCode.llmTimeout;
      case LlmErrorKind.unauthorized:
        return AssistantErrorCode.unauthorized;
      case LlmErrorKind.rateLimited:
        return AssistantErrorCode.rateLimited;
      case LlmErrorKind.invalidResponse:
        return AssistantErrorCode.llmInvalidResponse;
    }
  }
}

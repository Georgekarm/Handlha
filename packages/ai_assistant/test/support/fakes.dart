import 'dart:async';

import 'package:ai_assistant/ai_assistant.dart';

const kNow = '2026-10-04T18:00:00+03:00'; // Sunday, Cairo (UTC+3)

AssistantRequest textReq(String t, {String cid = 'c1', String now = kNow}) => AssistantRequest(
    type: InputType.text, text: t, conversationId: cid, currentDatetime: now);

ToolCall call(String name, Map<String, dynamic> args, {String? id}) =>
    ToolCall(id: id ?? 'id_${name}_${args.length}_${args.hashCode}', name: name, arguments: args);

LlmReply toolReply(List<ToolCall> calls, {String? text}) => LlmReply(text: text, toolCalls: calls);
LlmReply textReply(String t) => LlmReply(text: t);

typedef Step = FutureOr<LlmReply> Function(LlmRequest request);

class ScriptedLLM implements LLMService {
  ScriptedLLM(this.script);
  final List<Step> script;
  final List<LlmRequest> requests = [];
  int _i = 0;

  @override
  Future<LlmReply> complete(LlmRequest r) async {
    requests.add(r);
    if (_i >= script.length) throw StateError('No more scripted LLM replies');
    return await script[_i++](r);
  }
}

class RecordingExecutor implements ToolExecutor {
  RecordingExecutor({this.overrides = const {}});
  final Map<String, ToolResult Function(ToolCall)> overrides;
  final List<ToolCall> calls = [];
  int _n = 0;

  @override
  Set<String>? get supportedTools => null;

  @override
  Future<ToolResult> execute(ToolCall c) async {
    calls.add(c);
    final o = overrides[c.name];
    if (o != null) return o(c);
    _n++;
    final a = c.arguments;
    switch (c.name) {
      case 'create_task':
        return ToolResult.success({
          'task_id': 't_$_n',
          'title': a['title'],
          if (a['date'] != null) 'date': a['date'],
          if (a['time'] != null) 'time': a['time'],
        });
      case 'create_reminder':
        return ToolResult.success({'reminder_id': 'r_$_n', 'title': a['title']});
      case 'update_task':
      case 'complete_task':
      case 'delete_task':
        return ToolResult.success({'task_id': a['task_id'] ?? 't_1', 'title': a['query'] ?? 'task'});
      case 'get_tasks':
      case 'search_tasks':
      case 'get_upcoming_tasks':
        return ToolResult.success({'tasks': <Object>[]});
      default:
        return ToolResult.success();
    }
  }
}

class FakeTts implements TextToSpeechService {
  final List<String> spoken = [];
  bool stopped = false;
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async => stopped = true;
  @override
  Future<bool> pause() async => false;
  @override
  Future<bool> resume() async => false;
  @override
  bool get isSpeaking => false;
  @override
  Stream<bool> get speakingChanges => const Stream<bool>.empty();
  @override
  void dispose() {}
}

class FakeStt implements SpeechToTextService {
  final _p = StreamController<String>.broadcast();
  final _f = StreamController<String>.broadcast();
  final _e = StreamController<SttError>.broadcast();
  bool listening = false;
  SttException? failOnStart;

  void emitPartial(String t) => _p.add(t);
  void emitFinal(String t) => _f.add(t);
  void emitError(SttError e) => _e.add(e);

  @override
  Future<bool> initialize() async => true;
  @override
  Future<void> startListening() async {
    if (failOnStart != null) throw failOnStart!;
    listening = true;
  }

  @override
  Future<void> stopListening() async => listening = false;
  @override
  Future<void> cancel() async => listening = false;
  @override
  bool get isListening => listening;
  @override
  Stream<String> get partialTranscripts => _p.stream;
  @override
  Stream<String> get finalTranscripts => _f.stream;
  @override
  Stream<SttError> get errors => _e.stream;
  @override
  Future<void> handlePermissionError() async {}
  @override
  void dispose() {}
}

class Harness {
  Harness(List<Step> script,
      {RecordingExecutor? executor, bool speak = true, ConversationManager? conversations,
      Duration grace = const Duration(milliseconds: 30)})
      : llm = ScriptedLLM(script),
        ex = executor ?? RecordingExecutor(),
        tts = FakeTts(),
        stt = FakeStt() {
    c = AIAssistantController(
      stt: stt,
      llm: llm,
      tts: tts,
      tools: ex,
      nowProvider: () => kNow,
      conversations: conversations,
      config: AssistantConfig(
          speakResponses: speak,
          finalTranscriptGrace: grace,
          errorStateHold: const Duration(milliseconds: 5)),
    );
  }
  final ScriptedLLM llm;
  final RecordingExecutor ex;
  final FakeTts tts;
  final FakeStt stt;
  late final AIAssistantController c;

  Future<void> settle() async {
    for (var i = 0; i < 200 && c.state != AssistantState.idle; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }
}

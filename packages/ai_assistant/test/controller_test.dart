import 'dart:async';

import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  test('happy path: tool call -> SUCCESS -> final reply -> TTS, with state sequence', () async {
    final h = Harness([
      (r) => toolReply([call('create_task', {
            'title': 'مذاكرة Machine Learning',
            'date': '2026-10-05',
            'time': '20:00',
            'priority': 'medium'
          })]),
      (r) {
        expect(r.messages.last.role, MessageRole.tool);
        expect(r.messages.last.content, contains('SUCCESS'));
        return textReply('تمام، ضفتلك مذاكرة Machine Learning بكرة الساعة 8 بالليل.');
      },
    ]);
    final states = <AssistantState>[];
    h.c.stateStream.listen(states.add);

    final resp = await h.c.handleRequest(textReq('ضيفلي مذاكرة Machine Learning بكرة الساعة 8 بالليل'));
    await h.settle();

    expect(resp.type, AssistantResponse.typeResponse);
    expect(resp.action!.type, 'create_task');
    expect(resp.action!.status, ToolStatus.success);
    expect(resp.toJson()['action'], {'type': 'create_task', 'status': 'success'});
    expect(h.ex.calls.single.arguments['time'], '20:00');
    expect(h.tts.spoken, [resp.text]);
    expect(states, [
      AssistantState.thinking,
      AssistantState.executing,
      AssistantState.thinking,
      AssistantState.speaking,
      AssistantState.idle,
    ]);
  });

  test('system prompt carries the app-supplied date (never assumed)', () async {
    final h = Harness([(r) => textReply('أهلا')]);
    await h.c.handleRequest(textReq('اهلا'));
    expect(h.llm.requests.single.systemPrompt, contains('2026-10-04 18:00'));
    expect(h.llm.requests.single.tools.length, 13); // 12 + request_clarification
  });

  test('missing/invalid current_datetime -> friendly error, LLM never called', () async {
    final h = Harness([(r) => textReply('x')]);
    final resp = await h.c.handleRequest(textReq('ضيفلي تاسك', now: ''));
    await h.settle();
    expect(resp.type, AssistantResponse.typeError);
    expect(resp.errorCode, AssistantErrorCode.invalidRequest);
    expect(h.llm.requests, isEmpty);
  });

  test('invalid tool call is NEVER executed; the model gets INVALID_ARGUMENT and self-corrects', () async {
    final h = Harness([
      (r) => toolReply([call('create_task', {'title': 'x', 'time': '8pm', 'user_id': 'someone-else'}, id: 'a')]),
      (r) {
        expect(r.messages.last.content, contains('INVALID_ARGUMENT'));
        return toolReply([call('create_task', {'title': 'x', 'date': '2026-10-05', 'time': '20:00'}, id: 'b')]);
      },
      (r) => textReply('تمام، ضفتلك التاسك.'),
    ]);
    final resp = await h.c.handleRequest(textReq('ضيفلي x بكرة 8'));
    expect(h.ex.calls.length, 1);
    expect(h.ex.calls.single.arguments.containsKey('user_id'), isFalse);
    expect(resp.actions.length, 1);
    expect(resp.actions.single.status, ToolStatus.success);
  });

  test('multiple actions in one message execute in order', () async {
    final h = Harness([
      (r) => toolReply([
            call('create_reminder', {'title': 'المحاضرة', 'date': '2026-10-05', 'time': '09:30'}, id: '1'),
            call('create_task', {'title': 'مذاكرة Neural Networks', 'date': '2026-10-05', 'time': '08:00'}, id: '2'),
          ]),
      (r) => textReply('تمام، فكرّتك بالمحاضرة قبلها بنص ساعة وضفتلك مذاكرة Neural Networks الساعة 8 الصبح.'),
    ]);
    final resp = await h.c.handleRequest(textReq('...'));
    expect(h.ex.calls.map((c) => c.name), ['create_reminder', 'create_task']);
    expect(resp.actions.length, 2);
  });

  test('AMBIGUOUS result and an empty LLM answer -> deterministic Egyptian fallback', () async {
    final h = Harness([
      (r) => toolReply([call('delete_task', {'query': 'مذاكرة'})]),
      (r) => const LlmReply(text: '', toolCalls: []),
    ], executor: RecordingExecutor(overrides: {
      'delete_task': (_) => ToolResult.ambiguous([
            {'task_id': '1', 'title': 'مذاكرة ML'},
            {'task_id': '2', 'title': 'مذاكرة AI'}
          ])
    }));
    final resp = await h.c.handleRequest(textReq('امسح المذاكرة'));
    expect(resp.text, EgyptianMessages.ambiguous);
    expect(resp.needsUserInput, isTrue);
  });

  test('success claim without any SUCCESS tool result is blocked', () async {
    final h = Harness([(r) => textReply('تمام، ضفتلك التاسك.')]);
    final resp = await h.c.handleRequest(textReq('ضيفلي تاسك'));
    expect(resp.text, EgyptianMessages.unverifiedClaim);
  });

  test('success claim after a FAILED tool is replaced by honest failure text', () async {
    final h = Harness([
      (r) => toolReply([call('create_task', {'title': 'x'})]),
      (r) => textReply('تمام، ضفتلك التاسك.'),
    ], executor: RecordingExecutor(overrides: {'create_task': (_) => ToolResult.failed()}));
    final resp = await h.c.handleRequest(textReq('ضيفلي x'));
    expect(resp.text, EgyptianMessages.toolFailure);
    expect(resp.action!.status, ToolStatus.failed);
  });

  test('clarification: one question, pending state merged on the next turn', () async {
    final h = Harness([
      (r) => toolReply([call('request_clarification', {
            'question': 'تمام، تحبها إمتى؟',
            'pending_action': 'create_task',
            'known_fields': {'title': 'مذاكرة Deep Learning'}
          })]),
      (r) {
        expect(r.systemPrompt, contains('Pending clarification'));
        expect(r.systemPrompt, contains('مذاكرة Deep Learning'));
        return toolReply([call('create_task', {'title': 'مذاكرة Deep Learning', 'date': '2026-10-05', 'time': '07:00'})]);
      },
      (r) => textReply('تمام، ضفتلك مذاكرة Deep Learning بكرة الساعة 7 الصبح.'),
    ]);
    final r1 = await h.c.handleRequest(textReq('ضيفلي مذاكرة Deep Learning'));
    expect(r1.text, 'تمام، تحبها إمتى؟');
    expect(r1.needsUserInput, isTrue);
    expect(h.ex.calls, isEmpty);
    expect(h.llm.requests.length, 1); // no extra round trip

    final r2 = await h.c.handleRequest(textReq('بكرة الساعة 7'));
    expect(r2.action!.type, 'create_task');
    expect(h.ex.calls.single.arguments['title'], 'مذاكرة Deep Learning');
  });

  test('follow-up refers to the last created task ("قبلها")', () async {
    final h = Harness([
      (r) => toolReply([call('create_task', {'title': 'محاضرة Neural Networks', 'date': '2026-10-11', 'time': '10:00'})]),
      (r) => textReply('تمام، ضفتلك المحاضرة.'),
      (r) {
        expect(r.systemPrompt, contains('Last referenced task'));
        expect(r.systemPrompt, contains('محاضرة Neural Networks'));
        expect(r.messages.first.content, contains('محاضرة')); // earlier turn is in history
        return textReply('تمام.');
      },
    ]);
    await h.c.handleRequest(textReq('ضيفلي محاضرة Neural Networks الأحد الساعة 10'));
    await h.c.handleRequest(textReq('فكرني قبلها بنص ساعة'));
  });

  test('LLM timeout -> Egyptian error, ERROR state, history untouched', () async {
    final h = Harness([(r) => throw const LlmException(LlmErrorKind.timeout)]);
    final states = <AssistantState>[];
    h.c.stateStream.listen(states.add);
    final resp = await h.c.handleRequest(textReq('ضيفلي تاسك'));
    await h.settle();
    expect(resp.type, AssistantResponse.typeError);
    expect(resp.text, EgyptianMessages.timeout);
    expect(states, contains(AssistantState.error));
    expect(h.c.conversations.history('c1'), isEmpty);
    expect(h.tts.spoken, [EgyptianMessages.timeout]);
  });

  test('cancelInteraction during thinking -> cancelled, nothing spoken, IDLE', () async {
    final gate = Completer<LlmReply>();
    final h = Harness([(r) => gate.future]);
    final fut = h.c.handleRequest(textReq('ضيفلي تاسك'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await h.c.cancelInteraction();
    gate.complete(textReply('تمام'));
    final resp = await fut;
    expect(resp.type, AssistantResponse.typeCancelled);
    expect(h.c.state, AssistantState.idle);
    expect(h.tts.spoken, isEmpty);
  });

  test('voice flow: partial -> final -> LLM -> tool -> speech', () async {
    final h = Harness([
      (r) {
        expect(r.messages.last.content, contains('8')); // ٨ normalised to 8
        return toolReply([call('create_task', {'title': 'مذاكرة', 'date': '2026-10-05', 'time': '08:00'})]);
      },
      (r) => textReply('تمام، ضفتلك المذاكرة بكرة الساعة 8 الصبح.'),
    ]);
    final kinds = <AssistantEventKind>[];
    h.c.events.listen((e) => kinds.add(e.kind));

    await h.c.startVoiceInteraction();
    expect(h.c.state, AssistantState.listening);
    h.stt.emitPartial('ضيفلي مذاكرة');
    h.stt.emitFinal('ضيفلي مذاكرة بكرة الساعة ٨');
    await h.settle();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(h.tts.spoken.single, contains('تمام'));
    expect(kinds, containsAllInOrder([
      AssistantEventKind.partialTranscript,
      AssistantEventKind.finalTranscript,
      AssistantEventKind.toolStarted,
      AssistantEventKind.toolFinished,
      AssistantEventKind.response,
      AssistantEventKind.speakingStarted,
      AssistantEventKind.speakingEnded,
    ]));
    expect(h.c.state, AssistantState.idle);
  });

  test('stop with no final transcript falls back to the last partial', () async {
    final h = Harness([
      (r) {
        expect(r.messages.last.content, 'اهلا');
        return textReply('أهلا بيك');
      },
    ]);
    await h.c.startVoiceInteraction();
    h.stt.emitPartial('اهلا');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await h.c.stopVoiceInteraction();
    await h.settle();
    expect(h.tts.spoken, ['أهلا بيك']);
  });

  test('empty speech -> friendly message', () async {
    final h = Harness([]);
    await h.c.startVoiceInteraction();
    h.stt.emitFinal('   ');
    await h.settle();
    expect(h.tts.spoken, [EgyptianMessages.emptySpeech]);
  });

  test('microphone permission denied -> friendly message', () async {
    final h = Harness([]);
    h.stt.failOnStart = const SttException(SttError(SttErrorCode.permissionDenied));
    await h.c.startVoiceInteraction();
    await h.settle();
    expect(h.tts.spoken, [EgyptianMessages.micPermission]);
  });
}

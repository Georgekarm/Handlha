// Live Egyptian-Arabic evaluation against YOUR backend/LLM.
//
//   flutter test test/egyptian_arabic_live_test.dart \
//     --dart-define=AI_API_BASE_URL=http://localhost:8080 \
//     --dart-define=AI_API_TOKEN=dev        # only if your backend needs a token
//
// Skipped automatically when AI_API_BASE_URL is not set. Tools are faked
// (always SUCCESS) so the test checks understanding: which tools were called
// and with which arguments. LLM output is probabilistic: treat failures as
// prompts to improve system_prompt.dart, not as flaky infrastructure.
import 'dart:convert';
import 'dart:io';

import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

const _base = String.fromEnvironment('AI_API_BASE_URL');
const _token = String.fromEnvironment('AI_API_TOKEN');
const _writes = {
  'create_task', 'update_task', 'delete_task', 'complete_task',
  'create_reminder', 'update_reminder', 'delete_reminder'
};

void main() {
  final spec = jsonDecode(File('test/egyptian_cases.json').readAsStringSync()) as Map<String, dynamic>;
  final now = spec['now'] as String;

  group('Egyptian Arabic (live LLM)', () {
    for (final raw in spec['cases'] as List<dynamic>) {
      final cse = raw as Map<String, dynamic>;
      test(cse['id'] as String, () async {
        final ex = RecordingExecutor();
        final c = AIAssistantController(
          stt: FakeStt(),
          llm: HttpLLMService(baseUrl: _base, authTokenProvider: () async => _token.isEmpty ? null : _token),
          tts: NoopTextToSpeechService(),
          tools: ex,
          nowProvider: () => now,
          config: const AssistantConfig(speakResponses: false),
        );

        var mark = 0;
        AssistantResponse? last;
        for (final turn in (cse['turns'] as List<dynamic>).cast<String>()) {
          mark = ex.calls.length;
          last = await c.handleRequest(AssistantRequest(
              type: InputType.text, text: turn, conversationId: 'live_${cse['id']}', currentDatetime: now));
          expect(last.type, AssistantResponse.typeResponse, reason: 'turn "$turn" -> ${last.text}');
        }

        final calls = ex.calls.sublist(mark);
        final names = calls.map((x) => x.name).toList();
        final e = cse['expect'] as Map<String, dynamic>;
        final why = 'calls=${calls.map((x) => '${x.name}${jsonEncode(x.arguments)}').join(' ; ')} reply="${last?.text}"';

        for (final t in (e['tools'] as List<dynamic>? ?? const [])) {
          expect(names, contains(t), reason: why);
        }
        final either = e['either'] as List<dynamic>?;
        if (either != null) {
          expect(names.any(either.contains), isTrue, reason: why);
        }
        for (final t in (e['forbidden'] as List<dynamic>? ?? const [])) {
          expect(names, isNot(contains(t)), reason: why);
        }
        if (e['noWrites'] == true) {
          expect(names.where(_writes.contains), isEmpty, reason: why);
          expect(last?.needsUserInput, isTrue, reason: 'should ask a question. $why');
        }
        (e['args'] as Map<String, dynamic>? ?? const {}).forEach((tool, want) {
          final call = calls.lastWhere((x) => x.name == tool, orElse: () => fail('no $tool call. $why'));
          (want as Map<String, dynamic>).forEach((k, v) {
            expect(call.arguments[k], v, reason: '$tool.$k. $why');
          });
        });
        (e['contains'] as Map<String, dynamic>? ?? const {}).forEach((tool, want) {
          final call = calls.lastWhere((x) => x.name == tool, orElse: () => fail('no $tool call. $why'));
          (want as Map<String, dynamic>).forEach((k, subs) {
            for (final s in (subs as List<dynamic>).cast<String>()) {
              expect((call.arguments[k] ?? '').toString().toLowerCase(), contains(s.toLowerCase()),
                  reason: '$tool.$k. $why');
            }
          });
        });
      }, skip: _base.isEmpty ? 'Set --dart-define=AI_API_BASE_URL=... to run live evals.' : false,
          timeout: const Timeout(Duration(seconds: 90)));
    }
  });
}

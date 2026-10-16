# ai_assistant: Egyptian Arabic Voice Agent module

```
USER SPEAKS → STT → text → LLM → tool call → (validate) → APP executes → tool result → LLM → Egyptian reply → TTS → USER HEARS
```

Only the AI layer lives here. UI, Firebase, auth, navigation and rendering stay in the Flutter app.

```
lib/
  ai_assistant.dart            pure-Dart core (no plugins)
  ai_assistant_flutter.dart    + speech_to_text / flutter_tts providers
  src/
    stt/         SpeechToTextService (interface) + SpeechToTextPackageService
    tts/         TextToSpeechService (interface) + FlutterTtsService + Noop
    llm/         LLMService (interface), HttpLLMService, SystemPrompt, ConversationManager
    tools/       tool schemas (12 tools), ToolValidator, ToolExecutor/ToolRegistry
    models/      request/response/tool/message models, Egyptian fallback strings
    controller/  AIAssistantController   <- the only class Flutter talks to
test/            offline unit tests + live Egyptian-Arabic eval (egyptian_cases.json)
```

## 1. Wire it into Flutter

```dart
import 'package:ai_assistant/ai_assistant_flutter.dart';

final registry = ToolRegistry();                       // you implement the handlers
registry.register('create_task', (args) async {
  // args are ALREADY validated. Use the signed-in user from your auth session,
  // never from args. Enforce ownership in your data layer.
  final id = await tasksRepo.create(args);
  return ToolResult.success({'task_id': id, 'title': args['title'],
                             'date': args['date'], 'time': args['time']});
});
// ... register the other 11 tools (registry.missingTools tells you what is left)

final assistant = AIAssistantController(
  stt: SpeechToTextPackageService(),
  tts: FlutterTtsService(),
  llm: HttpLLMService(
    baseUrl: HttpLLMService.envBaseUrl,                // --dart-define=AI_API_BASE_URL=https://...
    authTokenProvider: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
  ),
  tools: registry,
  nowProvider: () => cairoNowIso(),                    // YOU supply Cairo time with offset
);

assistant.stateStream.listen(updateMicAnimation);      // idle/listening/transcribing/thinking/executing/speaking/error
assistant.responses.listen(showBubble);                // AssistantResponse (text + actions + needsUserInput)

micButton.onDown = assistant.startVoiceInteraction;
micButton.onUp   = assistant.stopVoiceInteraction;
await assistant.sendTextMessage('ضيفلي مذاكرة ML بكرة'); // typed input, same pipeline
assistant.cancelInteraction();                         // barge-in / cancel
```

`startVoiceInteraction()` also interrupts speech (barge-in). When `response.needsUserInput` is true the assistant asked a question, so you may re-open the mic automatically.

`nowProvider` must return ISO-8601 **with offset**, e.g. `2026-10-04T18:00:00+03:00`. Egypt observes DST, so the offset changes between +02:00 and +03:00 and is never hard-coded. `WallClock.deviceNowIso()` is available if the device is already on Cairo time. A missing or invalid value produces an error response, and the module never assumes a date.

## 2. Backend proxy (API key security)

The Flutter app never sees the vendor key. It calls **your** endpoint with the user's ID token.

```
cd backend && npm i && cp .env.example .env     # put ANTHROPIC_API_KEY in .env (git-ignored) or a secret manager
DEV_ALLOW_ANON=true node --env-file=.env server.js   # local dev only
```

Before production, implement `authenticate()` in `backend/server.js` (Firebase Admin `verifyIdToken` is sketched there) and replace the naive rate limiter. To change LLM vendor, rewrite only `callLlm()`. The app talks a neutral format: `POST /v1/chat {system, messages, tools}` → `{text?, tool_calls?}`.

## 3. Contracts

Request → response (`controller.handleRequest`, transport-agnostic, so it can sit behind REST/WebSocket):

```json
{"type":"voice","text":"ضيفلي تاسك أذاكر Machine Learning بكرة الساعة 8","conversation_id":"conversation_123","current_datetime":"2026-10-04T18:00:00+03:00"}
```
```json
{"type":"assistant_response","text":"تمام، ضفتلك مذاكرة Machine Learning بكرة الساعة 8 الصبح.",
 "action":{"type":"create_task","status":"success"},
 "actions":[{"type":"create_task","status":"success"}],
 "conversation_id":"conversation_123","needs_user_input":false}
```
`action` is the last executed action. `actions` lists all of them (multi-action messages). `type` can also be `error` (with `error_code`) or `cancelled`.

**Tool results** the app returns (`status`: SUCCESS · FAILED · NOT_FOUND · AMBIGUOUS · PERMISSION_DENIED · INVALID_ARGUMENT):

| Situation | Return |
|---|---|
| ok | `ToolResult.success({'task_id','title','date','time'})`. Always include `task_id` / `reminder_id` and `title` so "قبلها / أجلها / خليها" resolve |
| `query`/`created_on` matches 0 | `ToolResult.notFound()` |
| matches > 1 | `ToolResult.ambiguous([{task_id,title,date,time}, ...≤5])`. **Never guess**; the assistant asks "تقصد أنهي واحدة؟" |
| not the user's item | `ToolResult.permissionDenied()` |
| anything else | `ToolResult.failed()` (no technical text) |

Lists (`get_*`) return `{'tasks': [...]}` (or `reminders`). Results above ~8 KB are truncated before reaching the LLM.

Tools: `create_task update_task delete_task complete_task get_tasks search_tasks create_reminder update_reminder delete_reminder get_schedule get_daily_summary get_upcoming_tasks`. The schemas in `tools/tool_definitions.dart` are the single source of truth, used both for the LLM tool definitions and for validation. Existing items are referenced by `task_id` (from earlier results), `query` (title words), `created_on` or `due_date`; the model never invents ids. Reminders support three modes: absolute `date+time`, `in_minutes`, or task-relative `task_id|task_query + minutes_before`.

## 4. How the requirements are met

- **Validation (§29/30):** every call is checked by `ToolValidator` before the app sees it. Unknown tool/param, wrong type, bad enum, malformed or impossible date/time, missing required fields and bad cross-field combos are all rejected. The model gets `INVALID_ARGUMENT` and can retry; the app never sees the bad call. There is no `user_id` parameter at all, so the model cannot address another user's data. The app must still enforce identity and ownership (see `ToolExecutor` docs).
- **No false success (§19/20/33):** the final reply is only generated after real tool results. A deterministic `ClaimGuard` also replaces first-person "I did it" text when no tool returned SUCCESS this turn. If the LLM fails after tools ran, a fixed Egyptian fallback is built from the real statuses.
- **Pending state (§21):** the internal `request_clarification` tool stores `{action, known_fields, question}`; the next turn receives it in the prompt so "بكرة الساعة 7" completes the earlier create. The last created or referenced task and reminder are tracked for "قبلها".
- **Errors (§27):** every failure maps to an `AssistantErrorCode` and an Egyptian message in `egyptian_messages.dart` (mic permission, empty speech, STT failure, network, timeout, invalid LLM reply, tool failure, TTS failure…). Technical detail goes only to the logger. TTS failure is non-fatal because the text was already delivered.
- **Providers (§34):** the controller depends only on `SpeechToTextService`, `LLMService`, `TextToSpeechService` and `ToolExecutor`. STT/TTS/LLM can each be replaced independently.

### Behaviour choices you may want to change (all in `llm/system_prompt.dart`)

- **Time without AM/PM:** 1–6 → PM; 7–11 → AM on a future day (next occurrence if today). The assistant always repeats the interpreted time with its period word so the user can correct it.
- **Bare statements** like "عندي محاضرة بكرة الساعة 10" create a task and say so. If the same message only asks for a reminder about that event, only the reminder is created (your multi-action example).
- **Missing time for a task** → asks once ("تحبها إمتى؟"). **Bulk delete** needs an explicit "all" plus confirmation.
- **"رتبلي يومي"** reads the schedule and suggests an order out loud; it does not modify anything.

## 5. Tests

```
flutter pub get
flutter test                                   # offline: validator, context, controller loop, states, errors, cancel, voice flow
flutter test test/egyptian_arabic_live_test.dart \
  --dart-define=AI_API_BASE_URL=http://localhost:8080      # live Egyptian-Arabic eval (23 cases incl. mixed language, Arabic digits, multi-turn, negatives)
```
Live cases are in `test/egyptian_cases.json` (fixed "now" = Sunday 2026-10-04 18:00 +03:00). LLM output is probabilistic: if a case fails, read the printed calls and tune the prompt or add a few-shot example. The suite also checks the traps from §32 ("خلصت" vs "لسه هخلص") and that ambiguous references produce a question, not a write.

## 6. Known limits

- **STT quality for Egyptian dialect depends on the device.** Android's recognizer usually offers `ar-EG`; iOS often only Arabic (Saudi). If accuracy is not good enough, implement `SpeechToTextService` over a cloud ar-EG recognizer. Nothing else changes.
- **TTS:** system Arabic voices may mispronounce English words inside Arabic sentences. `pause()` works on iOS only; `resume()` is unsupported by `flutter_tts` and reports `false`.
- Conversation memory is in-memory (`InMemoryConversationStore`). Implement `ConversationStore` to persist it.
- Plugin APIs (`speech_to_text`, `flutter_tts`) move between versions, so pin the versions you test.

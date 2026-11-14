import 'dart:async';
import 'dart:convert';

import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handelha/core/database/local_task_database.dart';
import 'package:handelha/core/database/shared_preferences_conversation_store.dart';
import 'package:handelha/core/result/result.dart';
import 'package:handelha/features/assistant/planning/ai_planning_models.dart';
import 'package:handelha/features/assistant/planning/ai_planning_service.dart';
import 'package:handelha/features/assistant/presentation/chat_session_controller.dart';
import 'package:handelha/features/tasks/domain/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('conversation state survives a new store instance and isolates users', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = await SharedPreferencesConversationStore.open(userId: 'u1', preferences: prefs);
    final manager = ConversationManager(store: store);
    await manager.commitTurn('c1', [ConversationMessage.user('خطتي', id: 'm1'), ConversationMessage.assistant('تمام', id: 'm2')]);
    await manager.setPending('c1', const PendingAction(action: 'plan', knownFields: {'goal': 'إطلاق'}, question: 'إيه الميزانية؟'));
    await manager.recordPlanningDecision('c1', 'scope', 'MVP');
    await store.flush();

    final restored = await SharedPreferencesConversationStore.open(userId: 'u1', preferences: prefs);
    final state = await restored.load('c1');
    expect(state.messages.map((m) => m.id), ['m1', 'm2']);
    expect(state.pending?.question, 'إيه الميزانية؟');
    expect(state.planningDecisions['scope'], 'MVP');
    final other = await SharedPreferencesConversationStore.open(userId: 'u2', preferences: prefs);
    expect(await other.list(), isEmpty);
  });

  test('chat coalesces duplicate sends and retries with the same message id', () async {
    final gate = Completer<LlmReply>();
    final llm = _QueueLlm([gate.future, Future.value(const LlmReply(text: 'أهلاً'))]);
    final assistant = _assistant(llm);
    final session = ChatSessionController(assistant: assistant);
    await session.initialize();
    final first = session.send('مساء الخير', messageId: 'stable-1');
    await session.send('مساء الخير', messageId: 'stable-1');
    gate.complete(const LlmReply(text: 'أهلاً'));
    await first;
    expect(llm.requests, 1);
    expect(session.messages.map((m) => m.id).where((id) => id == 'stable-1'), hasLength(1));
    session.dispose();
    assistant.dispose();
  });

  test('conversation switching restores isolated history and multi-turn context', () async {
    final llm = _QueueLlm([
      Future.value(const LlmReply(text: 'رد أول')),
      Future.value(const LlmReply(text: 'رد تاني')),
      Future.value(const LlmReply(text: 'رد مستقل')),
    ]);
    final assistant = _assistant(llm);
    final session = ChatSessionController(assistant: assistant);
    await session.initialize();
    final firstId = session.currentConversationId;
    await session.send('الأول');
    await session.send('كمّل');
    expect(llm.seen[1].messages.map((m) => m.content), contains('الأول'));
    await session.newConversation();
    await session.send('محادثة تانية');
    expect(llm.seen[2].messages.map((m) => m.content), isNot(contains('الأول')));
    await session.selectConversation(firstId);
    expect(session.messages.map((m) => m.content), containsAll(['الأول', 'رد أول', 'كمّل', 'رد تاني']));
    session.dispose();
    assistant.dispose();
  });

  test('failed chat keeps the user turn for retry', () async {
    final llm = _QueueLlm([
      Future<LlmReply>(() => throw const LlmException(LlmErrorKind.timeout)),
      Future.value(const LlmReply(text: 'وصلت')),
    ]);
    final assistant = _assistant(llm);
    final session = ChatSessionController(assistant: assistant);
    await session.initialize();
    await session.send('اختبار', messageId: 'retry-1');
    expect(session.canRetry, isTrue);
    expect(session.messages.single.id, 'retry-1');
    await session.retry();
    expect(session.error, isNull);
    expect(session.messages.where((m) => m.id == 'retry-1'), hasLength(1));
    expect(session.messages.last.content, 'وصلت');
    session.dispose();
    assistant.dispose();
  });

  test('task database reports corruption and persists approved dependencies', () async {
    FlutterSecureStorage.setMockInitialValues({'local_tasks_v1': '{broken'});
    final db = LocalTaskDatabase.instance;
    expect(await db.getTasksForUser('u1'), isA<Failure<List<Task>>>());
    FlutterSecureStorage.setMockInitialValues({});
    final saved = await db.createApprovedTasks([_task('backend-1')]);
    expect(saved, isA<Success<List<Task>>>());
    final loaded = await db.getTasksForUser('u1');
    expect((loaded as Success<List<Task>>).data.single.id, 'backend-1');
  });

  test('task extraction preserves absent values and resolves existing dependency ids', () async {
    final service = AiPlanningService(_ReplyLlm('{"title":"واجهة الدخول","description":null,"estimated_duration_minutes":null,"due_at":null,"priority":null,"depends_on":["backend-1"],"clarification_question":null}'));
    final extraction = await service.extractTask(text: 'الواجهة بعد الباك إند', currentDatetime: '2026-11-01T10:00:00+02:00', existingTasks: [_task('backend-1')]);
    expect(extraction.estimatedDurationMinutes, isNull);
    expect(extraction.dueAt, isNull);
    expect(extraction.priority, isNull);
    expect(extraction.dependsOn, ['backend-1']);
  });

  test('planning parses phases and rejects dependency cycles without a plan', () async {
    const valid = '{"title":"تطبيق","goal":"MVP","clarification_question":null,"phases":[{"id":"p1","title":"التنفيذ","description":null,"estimated_duration_minutes":240,"suggested_deadline":null,"tasks":[{"id":"backend","title":"API","description":null,"estimated_duration_minutes":120,"duration_uncertainty":"تقدير أولي","priority":"high","suggested_deadline":null,"depends_on":[]},{"id":"frontend","title":"UI","description":null,"estimated_duration_minutes":null,"duration_uncertainty":null,"priority":null,"suggested_deadline":null,"depends_on":["backend"]}]}]}';
    final plan = await AiPlanningService(_ReplyLlm(valid)).breakdownProject(title: 'تطبيق', goal: 'MVP', currentDatetime: '2026-11-01T10:00:00+02:00');
    expect(plan.phases.single.estimatedDurationMinutes, 240);
    expect(plan.phases.single.tasks[1].dependsOn, ['backend']);
    const cyclic = '{"title":"تطبيق","goal":"MVP","phases":[{"id":"p1","title":"التنفيذ","tasks":[{"id":"a","title":"A","depends_on":["b"]},{"id":"b","title":"B","depends_on":["a"]}]}]}';
    expect(() => AiPlanningService(_ReplyLlm(cyclic)).breakdownProject(title: 'تطبيق', goal: 'MVP', currentDatetime: '2026-11-01T10:00:00+02:00'), throwsA(isA<PlanningException>()));
  });

  test('planning sends existing project context and keeps existing dependencies', () async {
    const reply = '{"title":"تطبيق","goal":"MVP","phases":[{"id":"p2","title":"الواجهة","estimated_duration_minutes":90,"tasks":[{"id":"frontend-2","title":"ربط الواجهة","depends_on":["backend-1"]}]}]}';
    final llm = _ReplyLlm(reply);
    final plan = await AiPlanningService(llm).breakdownProject(
      title: 'تطبيق',
      goal: 'MVP',
      refinement: 'ركّز على الواجهة',
      currentDatetime: '2026-11-01T10:00:00+02:00',
      existingTasks: [_task('backend-1')],
      existingPhases: const [PlanPhase(id: 'p1', title: 'الباك إند', tasks: [])],
    );

    expect(plan.phases.single.tasks.single.dependsOn, ['backend-1']);
    final input = jsonDecode(llm.request!.messages.single.content) as Map<String, dynamic>;
    expect(input['refinement'], 'ركّز على الواجهة');
    expect((input['existing_tasks'] as List).single['id'], 'backend-1');
    expect((input['existing_phases'] as List).single['id'], 'p1');
  });
}

AIAssistantController _assistant(LLMService llm) => AIAssistantController(
  stt: _FakeStt(), llm: llm, tts: NoopTextToSpeechService(), tools: _NoTools(),
  nowProvider: () => '2026-11-01T10:00:00+02:00');

Task _task(String id) {
  final now = DateTime(2026);
  return Task(id: id, userId: 'u1', title: 'Backend', status: TaskStatus.inbox, priority: TaskPriority.medium,
    energyLevel: EnergyLevel.medium, source: TaskSource.manual, createdAt: now, updatedAt: now, version: 1, syncStatus: SyncStatus.pending);
}

class _ReplyLlm implements LLMService {
  _ReplyLlm(this.text);
  final String text;
  LlmRequest? request;
  @override
  Future<LlmReply> complete(LlmRequest request) async {
    this.request = request;
    return LlmReply(text: text);
  }
}

class _QueueLlm implements LLMService {
  _QueueLlm(this.replies);
  final List<Future<LlmReply>> replies;
  int requests = 0;
  final seen = <LlmRequest>[];
  @override
  Future<LlmReply> complete(LlmRequest request) {
    seen.add(request);
    return replies[requests++];
  }
}

class _NoTools implements ToolExecutor {
  @override
  Set<String>? get supportedTools => const {};
  @override
  Future<ToolResult> execute(ToolCall call) async => ToolResult.permissionDenied();
}

class _FakeStt implements SpeechToTextService {
  @override bool get isListening => false;
  @override Stream<String> get partialTranscripts => const Stream.empty();
  @override Stream<String> get finalTranscripts => const Stream.empty();
  @override Stream<SttError> get errors => const Stream.empty();
  @override Future<bool> initialize() async => true;
  @override Future<void> startListening() async {}
  @override Future<void> stopListening() async {}
  @override Future<void> cancel() async {}
  @override Future<void> handlePermissionError() async {}
  @override void dispose() {}
}

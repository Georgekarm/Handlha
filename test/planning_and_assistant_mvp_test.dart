import 'dart:async';

import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handelha/app/locale/language_controller.dart';
import 'package:handelha/core/database/local_task_database.dart';
import 'package:handelha/core/result/result.dart';
import 'package:handelha/features/assistant/data/local_egyptian_llm_service.dart';
import 'package:handelha/features/assistant/local_task_tool_executor.dart';
import 'package:handelha/features/assistant/planning/deterministic_planner.dart';
import 'package:handelha/features/tasks/domain/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubSttService implements SpeechToTextService {
  final _partials = StreamController<String>.broadcast();
  final _finals = StreamController<String>.broadcast();
  final _errs = StreamController<SttError>.broadcast();
  bool _listening = false;

  @override
  bool get isListening => _listening;
  @override
  Stream<String> get partialTranscripts => _partials.stream;
  @override
  Stream<String> get finalTranscripts => _finals.stream;
  @override
  Stream<SttError> get errors => _errs.stream;
  @override
  Future<bool> initialize() async => true;
  @override
  Future<void> startListening() async => _listening = true;
  @override
  Future<void> stopListening() async => _listening = false;
  @override
  Future<void> cancel() async => _listening = false;
  @override
  Future<void> handlePermissionError() async {}
  @override
  Future<void> dispose() async {
    await _partials.close();
    await _finals.close();
    await _errs.close();
  }
}

class _StubTtsService implements TextToSpeechService {
  final _changes = StreamController<bool>.broadcast();
  @override
  bool get isSpeaking => false;
  @override
  Stream<bool> get speakingChanges => _changes.stream;
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<bool> pause() async => false;
  @override
  Future<bool> resume() async => false;
  @override
  void dispose() => _changes.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeterministicSchedulePlanner algorithms & constraints', () {
    const planner = DeterministicSchedulePlanner();
    final now = DateTime(2026, 11, 13, 10, 0);

    test('computes canonical inputHash that changes whenever tasks or windows shift', () {
      final p1 = PlanningProblem(
        now: now,
        tasks: [
          PlanningTaskInput(
            id: 't1',
            title: 'مراجعة جبر',
            estimatedMinutes: 60,
            dueDate: DateTime(2026, 11, 14),
            priority: 'high',
          ),
        ],
      );
      final p2 = PlanningProblem(
        now: now,
        tasks: [
          PlanningTaskInput(
            id: 't1',
            title: 'مراجعة جبر',
            estimatedMinutes: 90,
            dueDate: DateTime(2026, 11, 14),
            priority: 'high',
          ),
        ],
      );
      expect(planner.computeInputHash(p1), planner.computeInputHash(p1));
      expect(planner.computeInputHash(p1), isNot(planner.computeInputHash(p2)));
    });

    test('enforces explicit DAG topological order & rejects cycles honestly', () {
      final cyclic = PlanningProblem(
        now: now,
        tasks: const [
          PlanningTaskInput(
            id: 'a',
            title: 'خطوة أ',
            estimatedMinutes: 30,
            dependsOnIds: ['b'],
          ),
          PlanningTaskInput(
            id: 'b',
            title: 'خطوة ب',
            estimatedMinutes: 30,
            dependsOnIds: ['a'],
          ),
        ],
      );
      final cycleProposal = planner.plan(cyclic);
      expect(cycleProposal.items, isEmpty);
      expect(cycleProposal.unresolvedConflicts, isNotEmpty);
      expect(
        cycleProposal.unresolvedConflicts.first.type,
        ScheduleConflictType.dependencyCycle,
      );

      final ordered = PlanningProblem(
        now: now,
        availableWindows: [
          TimeWindow(
            start: DateTime(2026, 11, 13, 14, 0),
            end: DateTime(2026, 11, 13, 20, 0),
          ),
        ],
        tasks: [
          PlanningTaskInput(
            id: 'b',
            title: 'حل تمارين',
            estimatedMinutes: 45,
            dueDate: DateTime(2026, 11, 14),
            priority: 'high',
            dependsOnIds: const ['a'],
          ),
          PlanningTaskInput(
            id: 'a',
            title: 'فهم المحاضرة',
            estimatedMinutes: 60,
            dueDate: DateTime(2026, 11, 14),
            priority: 'low',
          ),
        ],
      );
      final dagProposal = planner.plan(ordered);
      expect(dagProposal.hasConflicts, isFalse);
      final itemA = dagProposal.items.firstWhere((e) => e.taskId == 'a');
      final itemB = dagProposal.items.firstWhere((e) => e.taskId == 'b');
      expect(
        itemA.suggestedEnd.isBefore(itemB.suggestedStart) ||
            itemA.suggestedEnd == itemB.suggestedStart,
        isTrue,
      );
    });

    test('runs CPM only when explicit durations, dependencies & deadline exist and detects critical path', () {
      final problemWithCpm = PlanningProblem(
        now: now,
        tasks: [
          PlanningTaskInput(
            id: 'a',
            title: 'التصميم',
            estimatedMinutes: 120,
            dueDate: DateTime(2026, 11, 13),
          ),
          PlanningTaskInput(
            id: 'b',
            title: 'التنفيذ',
            estimatedMinutes: 180,
            dueDate: DateTime(2026, 11, 13),
            dependsOnIds: const ['a'],
          ),
          PlanningTaskInput(
            id: 'c',
            title: 'تجهيز مراجع',
            estimatedMinutes: 45,
            dueDate: DateTime(2026, 11, 15),
          ),
        ],
      );
      final proposal = planner.plan(problemWithCpm);
      expect(proposal.cpmMetrics.containsKey('a'), isTrue);
      expect(proposal.cpmMetrics.containsKey('b'), isTrue);
      expect(proposal.cpmMetrics.containsKey('c'), isFalse);

      final withoutDur = PlanningProblem(
        now: now,
        tasks: [
          PlanningTaskInput(
            id: 'x',
            title: 'الأولى',
            dueDate: DateTime(2026, 11, 14),
          ),
          PlanningTaskInput(
            id: 'y',
            title: 'التانية',
            dueDate: DateTime(2026, 11, 14),
            dependsOnIds: const ['x'],
          ),
        ],
      );
      final noCpmProposal = planner.plan(withoutDur);
      expect(noCpmProposal.cpmMetrics, isEmpty);
      expect(noCpmProposal.assumptions, isNotEmpty);
    });

    test('respects fixed commitments without overlap & computes rolling diff', () {
      final winStart = DateTime(2026, 11, 13, 18, 0);
      final winEnd = DateTime(2026, 11, 13, 21, 0);
      final fixedStart = DateTime(2026, 11, 13, 18, 30);
      final fixedEnd = DateTime(2026, 11, 13, 19, 30);

      final v1 = planner.plan(
        PlanningProblem(
          now: now,
          availableWindows: [TimeWindow(start: winStart, end: winEnd)],
          fixedCommitments: [TimeWindow(start: fixedStart, end: fixedEnd)],
          tasks: const [
            PlanningTaskInput(id: 't1', title: 'تقرير', estimatedMinutes: 60),
          ],
        ),
        planVersion: 1,
      );
      expect(v1.items.single.suggestedStart, DateTime(2026, 11, 13, 19, 30));

      final v2 = planner.plan(
        PlanningProblem(
          now: now,
          availableWindows: [TimeWindow(start: winStart, end: winEnd)],
          fixedCommitments: [TimeWindow(start: fixedStart, end: fixedEnd)],
          tasks: const [
            PlanningTaskInput(id: 't1', title: 'تقرير', estimatedMinutes: 60),
            PlanningTaskInput(id: 't2', title: 'كود', estimatedMinutes: 30),
          ],
        ),
        planVersion: 2,
        previousProposal: v1,
      );
      expect(
        v2.diffFromPrevious.any((d) => d.kind == PlanDiffKind.added && d.taskId == 't2'),
        isTrue,
      );
      expect(
        v2.diffFromPrevious.any((d) => d.kind == PlanDiffKind.preserved && d.taskId == 't1'),
        isTrue,
      );
    });
  });

  group('End-to-end Egyptian Assistant MVP via AIAssistantController', () {
    late LocalTaskDatabase db;
    late LocalEgyptianLlmService llm;
    late AIAssistantController controller;
    const nowIso = '2026-11-13T10:00:00+02:00';
    const userId = 'u-mvp-test';
    final secureMemory = <String, String>{};
    const secureChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

    setUpAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, (call) async {
        final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return key != null ? secureMemory[key] : null;
          case 'write':
            if (key != null) {
              final value = args['value'] as String?;
              if (value == null) {
                secureMemory.remove(key);
              } else {
                secureMemory[key] = value;
              }
            }
            return null;
          case 'delete':
            if (key != null) secureMemory.remove(key);
            return null;
          case 'deleteAll':
            secureMemory.clear();
            return null;
          case 'readAll':
            return Map<String, String>.from(secureMemory);
          case 'containsKey':
            return key != null && secureMemory.containsKey(key);
          default:
            return null;
        }
      });
    });

    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, null);
    });

    setUp(() async {
      secureMemory.clear();
      SharedPreferences.setMockInitialValues({});
      db = LocalTaskDatabase.instance;
      await db.clearForUser(userId);
      llm = LocalEgyptianLlmService();
      final executor = LocalTaskToolExecutor(database: db, userId: () => userId);
      controller = AIAssistantController(
        stt: _StubSttService(),
        llm: llm,
        tts: _StubTtsService(),
        tools: executor,
        nowProvider: () => nowIso,
        config: const AssistantConfig(speakResponses: false),
      );
    });

    Future<List<Task>> allTasks() async {
      final res = await db.getTasksForUser(userId);
      return (res as Success<List<Task>>).data;
    }

    test('asks clarifying question for bare "ضيف العربي" and merges follow-up cleanly', () async {
      final r1 = await controller.sendTextMessage(
        'ضيف العربي',
        conversationId: 'c-arabi',
      );
      expect(r1.needsUserInput, isTrue);
      expect(r1.text, contains('العربي'));
      expect(await allTasks(), isEmpty);

      final r2 = await controller.sendTextMessage(
        'مذاكرة عربي بكرة الساعة 6',
        conversationId: 'c-arabi',
      );
      final saved = await allTasks();
      expect(saved, hasLength(1));
      expect(saved.first.title, 'مذاكرة عربي');
      expect(saved.first.title, isNot(startsWith('ضيف')));
      expect(saved.first.dueAt?.day, 14);
      expect(saved.first.dueAt?.hour, 18);
      expect(r2.text, contains('مذاكرة عربي'));
    });

    test('asks clarification for undated "عاوز اذاكر فرنساوي" & "ضيفلي مذاكرة Deep Learning"', () async {
      final f1 = await controller.sendTextMessage(
        'عاوز اذاكر فرنساوي',
        conversationId: 'c-fr',
      );
      expect(f1.needsUserInput, isTrue);
      expect(await allTasks(), isEmpty);

      await controller.sendTextMessage(
        'بكرة الساعة 7 بالليل',
        conversationId: 'c-fr',
      );
      var tasks = await allTasks();
      expect(tasks, hasLength(1));
      expect(tasks.first.title, 'مذاكرة فرنساوي');
      expect(tasks.first.dueAt?.hour, 19);

      final dl1 = await controller.sendTextMessage(
        'ضيفلي مذاكرة Deep Learning',
        conversationId: 'c-dl',
      );
      expect(dl1.needsUserInput, isTrue);
      expect(dl1.text, contains('Deep Learning'));
      expect(await allTasks(), hasLength(1));

      await controller.sendTextMessage(
        'من غير ميعاد محدد',
        conversationId: 'c-dl',
      );
      tasks = await allTasks();
      expect(tasks, hasLength(2));
      expect(tasks.last.title, 'مذاكرة Deep Learning');
      expect(tasks.last.dueAt, isNull);
    });

    test('splits multi-clause exams and clarifies ambiguous pronoun "أجلها يوم الخميس"', () async {
      await controller.sendTextMessage(
        'عندي امتحان بكره عربي و بعده انجليزي',
        conversationId: 'c-exams',
      );
      final created = await allTasks();
      expect(created, hasLength(2));
      expect(created[0].title, contains('عربي'));
      expect(created[0].dueAt?.day, 14);
      expect(created[1].title, contains('انجليزي'));
      expect(created[1].dueAt?.day, 15);

      final amb = await controller.sendTextMessage(
        'أجلها يوم الخميس',
        conversationId: 'c-exams',
      );
      expect(amb.needsUserInput, isTrue);
      expect((await allTasks())[1].dueAt?.day, 15);

      await controller.sendTextMessage(
        'التانية',
        conversationId: 'c-exams',
      );
      final updated = await allTasks();
      expect(updated[0].dueAt?.day, 14);
      expect(updated[1].dueAt?.weekday, DateTime.thursday);
    });

    test('blocks all hard negative traps from mutating tasks', () async {
      await db.createTask(userId: userId, title: 'ميعاد الدكتور');
      final traps = [
        'ما تمسحش ميعاد الدكتور لو سمحت',
        'ممكن تضيف تاسك لو حبيت؟',
        'لسه هخلّص كورس البايثون الأسبوع الجاي',
        'المدرس قال أكتب "امسح الورقة" في الدفتر',
        'لو كنت مسحت المهمة دي كان حصل إيه',
      ];
      for (var i = 0; i < traps.length; i++) {
        final r = await controller.sendTextMessage(
          traps[i],
          conversationId: 'c-trap-$i',
        );
        expect(r.text, isNot(contains('تم ')));
        final current = await allTasks();
        expect(current, hasLength(1));
        expect(current.first.title, 'ميعاد الدكتور');
      }
    });

    test('honestly reports unimplemented reminder tool in app executor', () async {
      final r = await controller.sendTextMessage(
        'فكرني بعد نص ساعة بمكالمة أحمد',
        conversationId: 'c-rem',
      );
      expect(r.needsUserInput, isTrue);
      expect(r.text, contains('مش مفعّلة'));
      expect(await allTasks(), isEmpty);
    });

    test('interactive planning Q&A -> Draft -> drift inputHash invalidation -> confirm', () async {
      await db.createTask(
        userId: userId,
        title: 'مراجعة المشروع',
        priority: TaskPriority.high,
        estimatedDurationMinutes: 60,
      );
      await db.createTask(
        userId: userId,
        title: 'حل الشيت',
        priority: TaskPriority.medium,
        estimatedDurationMinutes: 45,
      );

      final q = await controller.sendTextMessage(
        'خطط معايا جدولي اليوم',
        conversationId: 'c-plan',
      );
      expect(q.text, contains('الساعات الفاضية'));
      expect((await allTasks()).every((t) => t.dueAt == null), isTrue);

      final draft1 = await controller.sendTextMessage(
        'متاحلي من 6 لـ 9 بالليل',
        conversationId: 'c-plan',
      );
      expect(draft1.text, contains('نسخة 1'));
      expect(draft1.text, contains('مسودة'));
      expect((await allTasks()).every((t) => t.dueAt == null), isTrue);

      await db.createTask(
        userId: userId,
        title: 'مهمة طارئة',
        priority: TaskPriority.high,
        estimatedDurationMinutes: 30,
      );

      final staleConfirm = await controller.sendTextMessage(
        'اعتمد الخطة',
        conversationId: 'c-plan',
      );
      expect(staleConfirm.text, contains('الموافقة القديمة اتلغت'));
      expect(staleConfirm.text, contains('نسخة 2'));
      expect((await allTasks()).every((t) => t.dueAt == null), isTrue);

      final approved = await controller.sendTextMessage(
        'اعتمد الخطة',
        conversationId: 'c-plan',
      );
      expect(approved.text, contains('اعتمدت'));
      final persisted = await allTasks();
      expect(persisted.every((t) => t.dueAt != null), isTrue);
    });

    test('structured understanding schema v1.0 excludes user_id & captures self-correction', () {
      final result = llm.analyzeUtterance(
        'ضيفلي مراجعة الفيزيا بكرة لا قصدي الخميس الساعة 8 بالليل',
        now: DateTime(2026, 11, 13, 10, 0),
      );
      final json = result.toJson();
      expect(json['schema_version'], '1.0');
      expect(json.containsKey('user_id'), isFalse);
      expect(json['safety_flags']['self_corrected'], isTrue);
      expect(result.intent, EgyptianIntent.createTask);
      final taskSlot = (json['slots']['tasks'] as List).first as Map;
      expect(taskSlot['date'], '2026-11-19');
      expect(taskSlot['time'], '20:00');
    });

    test('supports full English assistant & planning switch alongside Egyptian Arabic', () async {
      var activeLang = 'en-US';
      final biLlm = LocalEgyptianLlmService(languageCodeProvider: () => activeLang);
      final biExecutor = LocalTaskToolExecutor(database: db, userId: () => userId);
      final biCtrl = AIAssistantController(
        stt: _StubSttService(),
        llm: biLlm,
        tts: _StubTtsService(),
        tools: biExecutor,
        nowProvider: () => nowIso,
        config: const AssistantConfig(speakResponses: false),
      );
      addTearDown(biCtrl.dispose);

      // English negation trap must block write and reply in English.
      final blocked = await biCtrl.sendTextMessage(
        "don't delete any tasks tomorrow",
        conversationId: 'c-en',
      );
      expect(blocked.needsUserInput, isTrue);
      expect(blocked.text.toLowerCase(), contains('left your tasks unchanged'));
      expect(await allTasks(), isEmpty);

      // Clear previous pending state by creating an English task directly.
      final created = await biCtrl.sendTextMessage(
        'add a task to review calculus tomorrow at 7 pm',
        conversationId: 'c-en-add',
      );
      expect(created.text, contains('Added'));
      expect(created.text, contains('review calculus'));
      var tasks = await allTasks();
      expect(tasks, hasLength(1));
      expect(tasks.first.title.toLowerCase(), contains('calculus'));
      expect(tasks.first.dueAt?.day, 14);
      expect(tasks.first.dueAt?.hour, 19);

      // Second undated task -> add via English Q&A or direct.
      await biCtrl.sendTextMessage(
        'create a new task study algorithms tomorrow morning',
        conversationId: 'c-en-add2',
      );
      tasks = await allTasks();
      expect(tasks, hasLength(2));

      // Interactive English planning Q&A -> Draft -> Confirm.
      final draft = await biCtrl.sendTextMessage(
        'plan my day from 6 to 9 pm',
        conversationId: 'c-en-plan',
      );
      expect(draft.text, contains('Prepared your schedule draft'));
      expect(draft.text, contains('draft only'));

      final confirmed = await biCtrl.sendTextMessage(
        'confirm schedule',
        conversationId: 'c-en-plan',
      );
      expect(confirmed.text, contains('Done! Applied'));

      // Dynamic switch back to Egyptian Arabic inside same LLM instance.
      activeLang = 'ar-EG';
      final arGreet = await biCtrl.sendTextMessage(
        'اهلا',
        conversationId: 'c-switch-ar',
      );
      expect(arGreet.text, contains('أهلًا بيك'));
    });
  });

  group('AppLanguageNotifier persistence & properties', () {
    test('persists ar-EG and en-US selection locally via SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appLanguageProvider), AppLanguage.arEg);
      expect(container.read(appLanguageProvider).textDirection, TextDirection.rtl);
      expect(container.read(appLanguageProvider).sttLocaleId, 'ar_EG');

      await container.read(appLanguageProvider.notifier).setLanguage(AppLanguage.en);
      expect(container.read(appLanguageProvider), AppLanguage.en);
      expect(container.read(appLanguageProvider).textDirection, TextDirection.ltr);
      expect(container.read(appLanguageProvider).locale, const Locale('en', 'US'));
      expect(container.read(appLanguageProvider).ttsCandidates.first, 'en-US');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('handelha_app_language'), AppLanguage.en.name);

      // Reload fresh container with saved SharedPreferences and verify cold-start restore.
      SharedPreferences.setMockInitialValues({
        'handelha_app_language': AppLanguage.en.name,
      });
      final reloaded = ProviderContainer();
      addTearDown(reloaded.dispose);
      reloaded.read(appLanguageProvider);
      await Future<void>.delayed(Duration.zero);
      expect(reloaded.read(appLanguageProvider), AppLanguage.en);
    });
  });
}

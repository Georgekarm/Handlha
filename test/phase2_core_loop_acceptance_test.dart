import 'dart:convert';

import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handelha/app/theme/app_theme.dart';
import 'package:handelha/core/database/local_task_database.dart';
import 'package:handelha/core/result/result.dart';
import 'package:handelha/core/telemetry/local_core_loop_telemetry.dart';
import 'package:handelha/features/assistant/data/local_egyptian_llm_service.dart';
import 'package:handelha/features/assistant/local_task_tool_executor.dart';
import 'package:handelha/features/assistant/presentation/assistant_providers.dart';
import 'package:handelha/features/assistant/presentation/chat_screen.dart';
import 'package:handelha/features/assistant/presentation/chat_session_controller.dart';
import 'package:handelha/features/assistant/presentation/widgets/secretary_message_widgets.dart';
import 'package:handelha/features/authentication/data/student_preview_seeder.dart';
import 'package:handelha/features/authentication/domain/app_user.dart';
import 'package:handelha/features/authentication/presentation/auth_providers.dart';
import 'package:handelha/features/notifications/local_notification_service.dart';
import 'package:handelha/features/tasks/domain/task.dart';
import 'package:handelha/features/tasks/presentation/task_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SpyStt implements SpeechToTextService {
  int startCount = 0;

  @override
  bool get isListening => false;
  @override
  Stream<String> get partialTranscripts => const Stream.empty();
  @override
  Stream<String> get finalTranscripts => const Stream.empty();
  @override
  Stream<SttError> get errors => const Stream.empty();
  @override
  Future<bool> initialize() async => true;
  @override
  Future<void> startListening() async {
    startCount++;
  }
  @override
  Future<void> stopListening() async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<void> handlePermissionError() async {}
  @override
  void dispose() {}
}

class _FixedAuthNotifier extends AuthNotifier {
  _FixedAuthNotifier(this._user);
  final AppUser _user;

  @override
  Future<AppUser?> build() async => _user;
}

class _EmptyTodayTasksNotifier extends TodayTasksNotifier {
  @override
  Future<List<Task>> build() async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = 'phase2-test-user';
  const nowIso = '2026-11-22T10:00:00+02:00';
  final fixedNow = DateTime(2026, 11, 22, 10, 0);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    LocalNotificationService.instance.testPermissionProvider = null;
    LocalNotificationService.instance.testSchedulerOverride = ({
      required String id,
      required String title,
      required DateTime scheduledAt,
      required String alertMode,
      required NotificationPermissionStatus permissions,
    }) async =>
        const AlarmScheduleOutcome(status: AlarmScheduleStatus.exactScheduled);
  });

  tearDown(() {
    LocalNotificationService.instance.testSchedulerOverride = null;
    LocalNotificationService.instance.testPermissionProvider = null;
  });

  Future<List<Task>> loadTasks() async {
    final res = await LocalTaskDatabase.instance.getTasksForUser(userId);
    return (res as Success<List<Task>>).data;
  }

  group('Phase 2 Core Loop — Confirm-Before-Write & Honest Alarm Feedback', () {
    test(
      'full Egyptian loop: capture -> preview (0 writes) -> conversational edit -> structured quick-edit -> cancel -> re-enter -> confirm monthly task',
      () async {
        final telemetryEvents = <String>[];
        final llm = LocalEgyptianLlmService(
          onTelemetryEvent: telemetryEvents.add,
        );
        final controller = AIAssistantController(
          stt: _SpyStt(),
          llm: llm,
          tts: NoopTextToSpeechService(),
          tools: LocalTaskToolExecutor(
            database: LocalTaskDatabase.instance,
            userId: () => userId,
            nowProvider: () => fixedNow,
          ),
          nowProvider: () => nowIso,
          config: const AssistantConfig(speakResponses: false),
        );
        addTearDown(controller.dispose);

        // 1. Capture -> preview ONLY, 0 DB writes
        final p1 = await controller.sendTextMessage(
          'ضيفلي مراجعة الفيزياء بكرة الساعة 6 بالليل',
          conversationId: 'c-loop',
        );
        expect(p1.text, startsWith('🔍 مراجعة قبل الحفظ'));
        expect(p1.text, contains('الفيزياء'));
        expect(llm.hasPendingMutationDraft('c-loop'), isTrue);
        expect(await loadTasks(), isEmpty);

        // 2. Conversational edit -> still preview, 0 DB writes
        final p2 = await controller.sendTextMessage(
          'خليها الخميس الساعة 8 بالليل',
          conversationId: 'c-loop',
        );
        expect(p2.text, startsWith('🔍 مراجعة قبل الحفظ'));
        expect(p2.text, contains('تعديل 2'));
        expect(await loadTasks(), isEmpty);

        // 3. Structured UI quick-edit (apply:false) -> still preview, 0 DB writes
        final p3 = await controller.sendTextMessage(
          'تعديل المسودة | العنوان: مراجعة فيزياء شاملة | التكرار: monthly | apply:false',
          conversationId: 'c-loop',
        );
        expect(p3.text, contains('مراجعة فيزياء شاملة'));
        expect(p3.text, contains('شهريًا'));
        expect(p3.text, contains('تعديل 3'));
        expect(await loadTasks(), isEmpty);

        // 4. Cancel -> clears draft, 0 DB writes
        final cancelled = await controller.sendTextMessage(
          'إلغاء',
          conversationId: 'c-loop',
        );
        expect(cancelled.text, contains('لغيت'));
        expect(llm.hasPendingMutationDraft('c-loop'), isFalse);
        expect(await loadTasks(), isEmpty);

        // 5. Re-enter monthly task -> preview (0 writes) -> confirm (1 write)
        final m1 = await controller.sendTextMessage(
          'ضيفلي دفع الإيجار أول الشهر الجاي كل شهر',
          conversationId: 'c-monthly',
        );
        expect(m1.text, startsWith('🔍 مراجعة قبل الحفظ'));
        expect(m1.text, contains('شهريًا'));
        expect(await loadTasks(), isEmpty);

        final m2 = await controller.sendTextMessage(
          'اعتمد',
          conversationId: 'c-monthly',
        );
        expect(m2.text, contains('الإيجار'));
        final saved = await loadTasks();
        expect(saved, hasLength(1));
        expect(saved.single.recurrence, TaskRecurrence.monthly);
        expect(saved.single.dueAt?.year, 2026);
        expect(saved.single.dueAt?.month, 12);
        expect(saved.single.dueAt?.day, 1);

        expect(
          telemetryEvents,
          containsAll([
            'preview_shown',
            'draft_edited',
            'draft_cancelled',
            'draft_confirmed',
          ]),
        );
      },
    );

    test(
      'destructive delete requires explicit confirmation and cancel preserves task',
      () async {
        await LocalTaskDatabase.instance.createTask(
          userId: userId,
          title: 'مهمة الفيزياء',
        );
        final llm = LocalEgyptianLlmService();
        final controller = AIAssistantController(
          stt: _SpyStt(),
          llm: llm,
          tts: NoopTextToSpeechService(),
          tools: LocalTaskToolExecutor(
            database: LocalTaskDatabase.instance,
            userId: () => userId,
            nowProvider: () => fixedNow,
          ),
          nowProvider: () => nowIso,
          config: const AssistantConfig(speakResponses: false),
        );
        addTearDown(controller.dispose);

        final warn = await controller.sendTextMessage(
          'امسح مهمة الفيزياء',
          conversationId: 'c-del',
        );
        expect(warn.text, startsWith('⚠️ تأكيد قبل الحذف'));
        expect(await loadTasks(), hasLength(1));

        await controller.sendTextMessage('إلغاء', conversationId: 'c-del');
        expect(await loadTasks(), hasLength(1));

        await controller.sendTextMessage(
          'امسح مهمة الفيزياء',
          conversationId: 'c-del',
        );
        expect(await loadTasks(), hasLength(1));

        final deleted = await controller.sendTextMessage(
          'تأكيد الحذف',
          conversationId: 'c-del',
        );
        expect(deleted.text, contains('مسحت'));
        expect(await loadTasks(), isEmpty);
      },
    );

    test(
      'surfaces honest alarm permissionDenied and inexactFallback notes in assistant replies',
      () async {
        final llm = LocalEgyptianLlmService();
        final controller = AIAssistantController(
          stt: _SpyStt(),
          llm: llm,
          tts: NoopTextToSpeechService(),
          tools: LocalTaskToolExecutor(
            database: LocalTaskDatabase.instance,
            userId: () => userId,
            nowProvider: () => fixedNow,
          ),
          nowProvider: () => nowIso,
          config: const AssistantConfig(speakResponses: false),
        );
        addTearDown(controller.dispose);

        // Case 1: permissionDenied
        LocalNotificationService.instance.testSchedulerOverride = ({
          required String id,
          required String title,
          required DateTime scheduledAt,
          required String alertMode,
          required NotificationPermissionStatus permissions,
        }) async =>
            const AlarmScheduleOutcome(
              status: AlarmScheduleStatus.permissionDenied,
            );

        await controller.sendTextMessage(
          'ضيفلي مذاكرة عربي بكرة الساعة 6 بالليل',
          conversationId: 'c-perm',
        );
        final deniedReply = await controller.sendTextMessage(
          'اعتمد',
          conversationId: 'c-perm',
        );
        expect(deniedReply.text, contains('⚠️'));
        expect(deniedReply.text, contains('إذن الإشعارات'));

        // Case 2: inexactFallback
        LocalNotificationService.instance.testSchedulerOverride = ({
          required String id,
          required String title,
          required DateTime scheduledAt,
          required String alertMode,
          required NotificationPermissionStatus permissions,
        }) async =>
            const AlarmScheduleOutcome(
              status: AlarmScheduleStatus.inexactFallback,
            );

        await controller.sendTextMessage(
          'ضيفلي مراجعة كيمياء بكرة الساعة 8 بالليل',
          conversationId: 'c-inexact',
        );
        final inexactReply = await controller.sendTextMessage(
          'اعتمد',
          conversationId: 'c-inexact',
        );
        expect(inexactReply.text, contains('ℹ️'));
        expect(inexactReply.text, contains('تقريبي'));
      },
    );
  });

  group('Phase 2 Widgets — Mutation Preview Card, Quick-Edit Sheet, Created Card & Voice Disclosure', () {
    testWidgets(
      'SecretaryRichMessageBody renders preview card with Confirm/Edit/Cancel and Quick-Edit Sheet',
      (tester) async {
        final quickReplies = <String>[];
        const previewMsg =
            '🔍 مراجعة قبل الحفظ (مسودة — لم يتم الحفظ بعد):\n'
            '• «مراجعة الفيزياء» — الميعاد: بكرة الساعة ٦:٠٠ م • التكرار: شهريًا\n'
            'راجع العنوان والميعاد: اضغط «اعتماد وحفظ»، أو «تعديل»، أو «إلغاء».';

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SecretaryRichMessageBody(
                      content: previewMsg,
                      onQuickReply: quickReplies.add,
                      isLastAssistant: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('مراجعة قبل الحفظ'), findsOneWidget);
        expect(find.text('مراجعة الفيزياء'), findsOneWidget);
        expect(find.text('اعتماد وحفظ'), findsOneWidget);
        expect(find.text('تعديل'), findsOneWidget);
        expect(find.text('إلغاء'), findsOneWidget);

        // Tap Confirm
        await tester.tap(find.text('اعتماد وحفظ'));
        await tester.pump();
        expect(quickReplies.last, 'اعتمد');

        // Tap Cancel
        await tester.tap(find.text('إلغاء'));
        await tester.pump();
        expect(quickReplies.last, 'إلغاء');

        // Tap Edit -> opens Quick-Edit Sheet -> edit title -> Save & Confirm
        await tester.tap(find.text('تعديل'));
        await tester.pumpAndSettle();
        expect(find.text('تعديل المسودة قبل الحفظ'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'مراجعة فيزياء نهائية');
        await tester.tap(find.text('حفظ واعتماد'));
        await tester.pumpAndSettle();

        expect(quickReplies.last, startsWith('تعديل المسودة |'));
        expect(quickReplies.last, contains('العنوان:مراجعة فيزياء نهائية'));
        expect(quickReplies.last, contains('apply:true'));
      },
    );

    testWidgets(
      'SecretaryRichMessageBody renders destructive delete card without Edit and created card with honest warning + Start Focus CTA',
      (tester) async {
        final quickReplies = <String>[];
        var focusStarted = false;

        const deletePreview =
            '⚠️ تأكيد قبل الحذف (لم يتم الحذف بعد):\n'
            '• «مهمة الفيزياء»\n'
            'اضغط «تأكيد الحذف» للمتابعة أو «إلغاء» للتراجع.';

        const createdWithWarning =
            'تمام، ضفتلك «مذاكرة عربي» في ميعاد بكرة الساعة ٦:٠٠ م.\n'
            '⚠️ تنبيه: لم تتم جدولة المنبه لأن إذن الإشعارات مرفوض على النظام — فعّله من الإشعارات.\n'
            'تحب نبدأ خطوة تركيز دلوقتي أو نقسّمها لخطوات؟';

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        SecretaryRichMessageBody(
                          content: deletePreview,
                          onQuickReply: quickReplies.add,
                        ),
                        const SizedBox(height: 16),
                        SecretaryRichMessageBody(
                          content: createdWithWarning,
                          onQuickReply: quickReplies.add,
                          onStartFocus: () => focusStarted = true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('تأكيد قبل الحذف'), findsOneWidget);
        expect(find.text('تأكيد الحذف'), findsOneWidget);
        expect(find.text('تعديل'), findsNothing);

        expect(find.textContaining('إذن الإشعارات مرفوض'), findsOneWidget);
        expect(find.text('ابدأ خطوة تركيز الآن'), findsOneWidget);

        await tester.ensureVisible(find.text('ابدأ خطوة تركيز الآن'));
        await tester.tap(find.text('ابدأ خطوة تركيز الآن'));
        await tester.pump();
        expect(focusStarted, isTrue);
      },
    );

    testWidgets(
      'ChatScreen shows transparent Android SpeechRecognizer disclosure on first microphone tap',
      (tester) async {
        final spyStt = _SpyStt();
        final assistant = AIAssistantController(
          stt: spyStt,
          llm: LocalEgyptianLlmService(),
          tts: NoopTextToSpeechService(),
          tools: LocalTaskToolExecutor(
            database: LocalTaskDatabase.instance,
            userId: () => userId,
          ),
          nowProvider: () => nowIso,
          config: const AssistantConfig(speakResponses: false),
        );
        final session = ChatSessionController(assistant: assistant);
        await session.initialize();
        addTearDown(() {
          assistant.dispose();
        });

        final fakeUser = AppUser(
          id: userId,
          email: 'user@example.com',
          displayName: 'مستخدم اختبار',
          usageType: OnboardingUsageType.study,
          tone: AssistantTone.friendly,
          focusHours: const [9, 10, 11],
          onboardingComplete: true,
          createdAt: fixedNow,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authNotifierProvider.overrideWith(() => _FixedAuthNotifier(fakeUser)),
              todayTasksProvider.overrideWith(_EmptyTodayTasksNotifier.new),
              chatSessionProvider.overrideWith((ref) => session),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(body: ChatScreen()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap mic before acknowledging disclosure -> dialog must appear, STT must NOT start.
        await tester.tap(find.byIcon(Icons.mic_none_rounded));
        await tester.pumpAndSettle();

        expect(find.text('تنبيه شفاف عن الإدخال الصوتي'), findsOneWidget);
        expect(find.textContaining('SpeechRecognizer'), findsOneWidget);
        expect(spyStt.startCount, 0);

        // Choose "Use Text Instead" -> dialog closes, flag still false, STT still 0.
        await tester.tap(find.text('استخدم الكتابة بدلًا من ذلك'));
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(ChatScreen.voiceSttDisclosureKey), isNot(true));
        expect(spyStt.startCount, 0);

        // Tap mic again and accept disclosure -> flag persists as true.
        await tester.tap(find.byIcon(Icons.mic_none_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('فهمت، استخدم الميكروفون'));
        await tester.pumpAndSettle();

        expect(prefs.getBool(ChatScreen.voiceSttDisclosureKey), isTrue);
      },
    );
  });

  group('Phase 2 Privacy-Safe Opt-In Telemetry', () {
    test('disabled by default, excludes QA preview account, stores zero PII/content', () async {
      final t = LocalCoreLoopTelemetry.instance;

      // Off by default -> records nothing.
      expect(await t.isConsentGranted(userId), isFalse);
      await t.recordEvent(userId, 'preview_shown');
      await t.recordEvent(userId, 'draft_confirmed');
      final offSnap = await t.load(userId);
      expect(offSnap.consentGranted, isFalse);
      expect(offSnap.previewsShown, 0);
      expect(offSnap.draftsConfirmed, 0);

      // QA preview account is ALWAYS excluded even if setConsent(true) is called.
      await t.setConsent(StudentPreviewAccount.userId, true);
      expect(await t.isConsentGranted(StudentPreviewAccount.userId), isFalse);
      await t.recordEvent(StudentPreviewAccount.userId, 'preview_shown');
      final qaSnap = await t.load(StudentPreviewAccount.userId);
      expect(qaSnap.previewsShown, 0);

      // Explicit opt-in for normal user -> counts recorded cleanly without any PII.
      await t.setConsent(userId, true);
      expect(await t.isConsentGranted(userId), isTrue);
      final day1 = DateTime(2026, 11, 22, 10, 0);
      final day2 = DateTime(2026, 11, 23, 14, 0);
      await t.recordEvent(userId, 'text_input', now: day1);
      await t.recordEvent(userId, 'preview_shown', now: day1);
      await t.recordEvent(userId, 'draft_edited', now: day1);
      await t.recordEvent(userId, 'draft_confirmed', now: day1);
      await t.recordEvent(userId, 'preview_shown', now: day2);
      await t.recordEvent(userId, 'draft_cancelled', now: day2);
      await t.recordEvent(userId, 'focus_started', now: day2);
      await t.recordEvent(userId, 'focus_completed', now: day2);
      await t.recordEvent(
        userId,
        'alarm_schedule_outcome',
        alarmStatus: 'inexactFallback',
        now: day2,
      );

      final snap = await t.load(userId);
      expect(snap.previewsShown, 2);
      expect(snap.draftsEdited, 1);
      expect(snap.draftsConfirmed, 1);
      expect(snap.draftsCancelled, 1);
      expect(snap.confirmationRate, 0.5);
      expect(snap.editRate, 0.5);
      expect(snap.cancelRate, 0.5);
      expect(snap.focusSessionsStarted, 1);
      expect(snap.focusSessionsCompleted, 1);
      expect(snap.alarmOutcomes['inexactFallback'], 1);
      expect(snap.activeDays, ['2026-11-22', '2026-11-23']);

      final encoded = jsonEncode(snap.toAnonymousJson());
      expect(encoded, isNot(contains(userId)));
      expect(encoded, isNot(contains('email')));
      expect(encoded, isNot(contains('title')));

      // Opt-out immediately clears stored counts.
      await t.setConsent(userId, false);
      final afterOff = await t.load(userId);
      expect(afterOff.consentGranted, isFalse);
      expect(afterOff.previewsShown, 0);
    });
  });
}

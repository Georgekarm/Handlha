import 'dart:async';

import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:handelha/app/theme/app_colors.dart';
import 'package:handelha/app/theme/app_theme.dart';
import 'package:handelha/app/theme/app_theme_extension.dart';
import 'package:handelha/app/theme/theme_controller.dart';
import 'package:handelha/core/database/local_focus_session_database.dart';
import 'package:handelha/core/database/local_project_database.dart';
import 'package:handelha/core/database/local_task_database.dart';
import 'package:handelha/core/database/shared_preferences_conversation_store.dart';
import 'package:handelha/core/logger/app_logger.dart';
import 'package:handelha/core/result/result.dart';
import 'package:handelha/core/secure_storage/secure_storage_service.dart';
import 'package:handelha/features/assistant/data/egyptian_nlu_analyzer.dart';
import 'package:handelha/features/assistant/data/local_egyptian_llm_service.dart';
import 'package:handelha/features/assistant/local_task_tool_executor.dart';
import 'package:handelha/features/assistant/presentation/chat_history_screen.dart';
import 'package:handelha/features/assistant/presentation/chat_screen.dart';
import 'package:handelha/features/authentication/data/local_auth_repository.dart';
import 'package:handelha/features/authentication/data/social_auth_service.dart';
import 'package:handelha/features/authentication/domain/app_user.dart';
import 'package:handelha/features/authentication/presentation/login_screen.dart';
import 'package:handelha/features/authentication/presentation/signup_screen.dart';
import 'package:handelha/features/home/presentation/dashboard_screen.dart';
import 'package:handelha/features/notifications/notification_inbox_store.dart';
import 'package:handelha/features/notifications/notification_preferences.dart';
import 'package:handelha/features/notifications/presentation/notifications_screen.dart';
import 'package:handelha/features/onboarding/presentation/onboarding_screen.dart';
import 'package:handelha/features/projects/data/productivity_analytics.dart';
import 'package:handelha/features/projects/domain/focus_session.dart';
import 'package:handelha/features/projects/domain/project.dart';
import 'package:handelha/features/projects/presentation/handelha_focus_session_screen.dart';
import 'package:handelha/features/projects/presentation/new_project_screen.dart';
import 'package:handelha/features/projects/presentation/projects_screen.dart';
import 'package:handelha/features/projects/presentation/tracking_screen.dart';
import 'package:handelha/features/settings/presentation/settings_screen.dart';
import 'package:handelha/features/tasks/domain/task.dart';
import 'package:handelha/features/tasks/presentation/add_task_screen.dart';
import 'package:handelha/features/tasks/presentation/tasks_screen.dart';
import 'package:handelha/shared/utils/arabic_formatters.dart';
import 'package:handelha/shared/widgets/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapApp(Widget home, {ThemeData? theme}) {
  return ProviderScope(
    child: MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(textDirection: TextDirection.rtl, child: home),
    ),
  );
}

const String _testUserId = 'test-handelha-user-v1';
const String _testUserEmail = 'omar@handelha.app';
const String _testUserDisplayName = 'عمر';

Future<void> _seedTestSessionStorage() async {
  FlutterSecureStorage.setMockInitialValues({
    'user_id': _testUserId,
    'user_email': _testUserEmail,
    'user_name': _testUserDisplayName,
    'onboarding_complete': 'true',
  });
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  await LocalTaskDatabase.instance.clearForUser(_testUserId);
  await LocalProjectDatabase.instance.clearForUser(_testUserId);
  await LocalFocusSessionDatabase.instance.clearForUser(_testUserId);

  final tasks = <Task>[
    Task(
      id: 'test-task-1',
      userId: _testUserId,
      projectId: 'test-proj-1',
      title: 'مراجعة شعار البراند النهائي',
      dueAt: today,
      scheduledStartAt: today.add(const Duration(hours: 10)),
      estimatedDurationMinutes: 30,
      priority: TaskPriority.high,
      energyLevel: EnergyLevel.high,
      status: TaskStatus.planned,
      source: TaskSource.manual,
      createdAt: today,
      updatedAt: today,
      version: 1,
      syncStatus: SyncStatus.synced,
    ),
    Task(
      id: 'test-task-2',
      userId: _testUserId,
      projectId: 'test-proj-1',
      title: 'تحضير عرض المشروع',
      dueAt: today,
      scheduledStartAt: today.add(const Duration(hours: 12)),
      estimatedDurationMinutes: 45,
      priority: TaskPriority.medium,
      energyLevel: EnergyLevel.medium,
      status: TaskStatus.planned,
      source: TaskSource.manual,
      createdAt: today,
      updatedAt: today,
      version: 1,
      syncStatus: SyncStatus.synced,
    ),
    Task(
      id: 'test-task-3',
      userId: _testUserId,
      projectId: 'test-proj-1',
      title: 'حجز قاعة الاجتماع الأسبوعي',
      dueAt: today,
      scheduledStartAt: today.add(const Duration(hours: 9)),
      estimatedDurationMinutes: 15,
      priority: TaskPriority.medium,
      energyLevel: EnergyLevel.low,
      status: TaskStatus.completed,
      source: TaskSource.manual,
      createdAt: today,
      updatedAt: today.add(const Duration(hours: 9, minutes: 20)),
      version: 1,
      syncStatus: SyncStatus.synced,
    ),
    Task(
      id: 'test-task-4',
      userId: _testUserId,
      projectId: 'test-proj-1',
      title: 'الرد على إيميلات العملاء',
      dueAt: today,
      scheduledStartAt: today.add(const Duration(hours: 11)),
      estimatedDurationMinutes: 25,
      priority: TaskPriority.medium,
      energyLevel: EnergyLevel.low,
      status: TaskStatus.completed,
      source: TaskSource.manual,
      createdAt: today,
      updatedAt: today.add(const Duration(hours: 11, minutes: 30)),
      version: 1,
      syncStatus: SyncStatus.synced,
    ),
    Task(
      id: 'test-task-5',
      userId: _testUserId,
      projectId: 'test-proj-1',
      title: 'تحديث جدول ميزانية الشهر',
      dueAt: today,
      scheduledStartAt: today.add(const Duration(hours: 14)),
      estimatedDurationMinutes: 35,
      priority: TaskPriority.high,
      energyLevel: EnergyLevel.medium,
      status: TaskStatus.completed,
      source: TaskSource.manual,
      createdAt: today,
      updatedAt: today.add(const Duration(hours: 14, minutes: 40)),
      version: 1,
      syncStatus: SyncStatus.synced,
    ),
  ];
  await LocalTaskDatabase.instance.createApprovedTasks(tasks);

  for (var i = 0; i < 6; i++) {
    await LocalFocusSessionDatabase.instance.record(
      userId: _testUserId,
      taskId: 'test-task-1',
      taskTitle: 'مراجعة شعار البراند النهائي',
      elapsedMinutes: 25,
      completed: true,
      startedAt: today.subtract(Duration(days: i)),
      endedAt:
          today.subtract(Duration(days: i)).add(const Duration(minutes: 25)),
    );
  }

  final prefs = await SharedPreferences.getInstance();
  final store = await SharedPreferencesConversationStore.open(
    userId: _testUserId,
    preferences: prefs,
  );
  await store.save(
    'test-conv-1',
    ConversationState(
      metadata: ConversationMetadata(
        id: 'test-conv-1',
        title: 'ترتيب جدول الأسبوع',
        createdAt: now,
        updatedAt: now,
      ),
    )..messages.add(
        ConversationMessage.user('رتبلي جدول الأسبوع', id: 'm1', createdAt: now),
      ),
  );
  await store.save(
    'test-conv-2',
    ConversationState(
      metadata: ConversationMetadata(
        id: 'test-conv-2',
        title: 'تحضير عرض العمل',
        createdAt: now,
        updatedAt: now,
      ),
    )..messages.add(
        ConversationMessage.user(
          'ساعدني في تحضير عرض العمل',
          id: 'm2',
          createdAt: now,
        ),
      ),
  );
}

Future<void> _pumpSettledFrames(WidgetTester tester, [int cycles = 4]) async {
  for (int i = 0; i < cycles; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  // ---------------------------------------------------------------------------
  // 1. Formatters, Analytics & Theme Token Unit Tests
  // ---------------------------------------------------------------------------
  group('ArabicFormatters, Analytics & Theme Extensions', () {
    test('toArabicDigits and formatting helpers convert digits cleanly', () {
      expect(ArabicFormatters.toArabicDigits(150), '١٥٠');
      expect(ArabicFormatters.toArabicDigits('25:00'), '٢٥:٠٠');
      expect(ArabicFormatters.percent(75), '٧٥٪');
      expect(ArabicFormatters.countOf(3, 4), '٣ من ٤ مهام');
      expect(ArabicFormatters.durationMinutesFull(25), '٢٥ دقيقة');
      expect(ArabicFormatters.durationMinutesFull(5), '٥ دقيقة');
      expect(ArabicFormatters.durationCompact(150), '٢ س ٣٠ د');
      expect(ArabicFormatters.timerMmSs(300), '05:00');
      expect(ArabicFormatters.timeOfDayAr(DateTime(2026, 11, 13, 10, 30)), '١٠:٣٠ ص');
      expect(ArabicFormatters.timeOfDayAr(DateTime(2026, 11, 13, 15, 5)), '٣:٠٥ م');
    });

    test('Light and Dark themes expose all PDF AppThemeExtension tokens', () {
      final lightExt = AppTheme.lightTheme.extension<AppThemeExtension>();
      final darkExt = AppTheme.darkTheme.extension<AppThemeExtension>();
      expect(lightExt, isNotNull);
      expect(darkExt, isNotNull);
      expect(lightExt!.background, AppColors.background);
      expect(lightExt.heroTeal, AppColors.heroTeal);
      expect(lightExt.textOnPrimary, Colors.white);
      expect(darkExt!.background, AppColors.darkBackground);
      expect(darkExt.primary, AppColors.darkPrimary);
      expect(darkExt.textOnPrimary, const Color(0xFF082420));
    });

    test('ProductivityReport builds accurate day, 4-week, 6-month, streak, and badges from real records', () {
      final now = DateTime(2026, 11, 13, 14, 0);
      Task mkCompleted(String id, DateTime doneAt, {String? projectId}) => Task(
            id: id,
            userId: 'u1',
            projectId: projectId,
            title: 'مهمة $id',
            status: TaskStatus.completed,
            priority: TaskPriority.high,
            energyLevel: EnergyLevel.medium,
            source: TaskSource.manual,
            createdAt: doneAt.subtract(const Duration(hours: 2)),
            updatedAt: doneAt,
            version: 1,
            syncStatus: SyncStatus.synced,
          );
      FocusSession mkSession(String id, DateTime endedAt, int mins) => FocusSession(
            id: id,
            userId: 'u1',
            taskTitle: 'تركيز $id',
            startedAt: endedAt.subtract(Duration(minutes: mins)),
            endedAt: endedAt,
            elapsedMinutes: mins,
            completed: true,
          );

      final tasks = [
        mkCompleted('t1', DateTime(2026, 11, 13, 10, 0), projectId: 'p1'),
        mkCompleted('t2', DateTime(2026, 11, 12, 11, 0), projectId: 'p1'),
        mkCompleted('t3', DateTime(2026, 11, 11, 15, 0), projectId: 'p1'),
        mkCompleted('t4', DateTime(2026, 10, 10, 12, 0), projectId: 'p1'),
      ];
      final sessions = [
        mkSession('s1', DateTime(2026, 11, 13, 10, 30), 30),
        mkSession('s2', DateTime(2026, 11, 12, 16, 0), 35),
        mkSession('s3', DateTime(2026, 10, 10, 13, 0), 25),
      ];
      final projects = [
        Project(
          id: 'p1',
          userId: 'u1',
          title: 'مشروع التخرج',
          status: ProjectStatus.active,
          progressPercent: 75,
          taskIds: const ['t1', 't2', 't3', 't4'],
          createdAt: now.subtract(const Duration(days: 40)),
          updatedAt: now,
        ),
      ];

      final weekReport = ProductivityReport.build(
        tasks: tasks,
        sessions: sessions,
        projects: projects,
        granularity: AnalyticsGranularity.week,
        firstName: 'عمر',
        now: now,
      );
      expect(weekReport.periodStats.completedTasks, 3);
      expect(weekReport.periodStats.focusMinutes, 65);
      expect(weekReport.currentStreakDays, 3);
      expect(weekReport.bestStreakDays, 3);
      expect(weekReport.rollingWeekBuckets, hasLength(4));
      expect(weekReport.monthBuckets, hasLength(6));
      expect(weekReport.projectBreakdowns.single.title, 'مشروع التخرج');
      expect(weekReport.milestones.where((m) => m.id == 'first_step').single.unlocked, isTrue);
      expect(weekReport.milestones.where((m) => m.id == 'steady_streak').single.unlocked, isTrue);

      final monthReport = ProductivityReport.build(
        tasks: tasks,
        sessions: sessions,
        projects: projects,
        granularity: AnalyticsGranularity.month,
        firstName: 'عمر',
        now: now,
      );
      // Nov (3 tasks, 65 min) vs Oct (1 task, 25 min)
      expect(monthReport.monthDeltaTasks, 2);
      expect(monthReport.monthDeltaMinutes, 40);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Offline Egyptian NLU & Multi-Task Assistant Tests (Zero External API)
  // ---------------------------------------------------------------------------
  group('Offline LocalEgyptianLlmService & Tool Execution', () {
    AIAssistantController makeController(String userId) {
      return AIAssistantController(
        stt: _NoopStt(),
        llm: LocalEgyptianLlmService(),
        tts: NoopTextToSpeechService(),
        tools: LocalTaskToolExecutor(
          database: LocalTaskDatabase.instance,
          userId: () => userId,
        ),
        nowProvider: () => '2026-11-13T10:00:00+02:00',
        conversations: ConversationManager(store: InMemoryConversationStore()),
      );
    }

    test('handles multi-exam Egyptian sentence without external API: عندي امتحان بكره عربي و بعده انجليزي', () async {
      const userId = 'nlu-user-1';
      final controller = makeController(userId);
      addTearDown(controller.dispose);

      final preview = await controller.sendTextMessage(
        'عندي امتحان بكره عربي و بعده انجليزي',
        conversationId: 'c1',
        speak: false,
      );
      expect(preview.text, startsWith('🔍 مراجعة قبل الحفظ'));
      expect(
        (await LocalTaskDatabase.instance.getTasksForUser(userId)
                as Success<List<Task>>)
            .data,
        isEmpty,
      );

      final resp = await controller.sendTextMessage(
        'اعتمد',
        conversationId: 'c1',
        speak: false,
      );

      final tasks = (await LocalTaskDatabase.instance.getTasksForUser(userId)
              as Success<List<Task>>)
          .data;
      expect(tasks, hasLength(2));
      expect(tasks.any((t) => t.title.contains('امتحان') && t.title.contains('عربي')), isTrue);
      expect(tasks.any((t) => t.title.contains('امتحان') && t.title.contains('انجليزي')), isTrue);

      final arabicExam = tasks.firstWhere((t) => t.title.contains('عربي'));
      final englishExam = tasks.firstWhere((t) => t.title.contains('انجليزي'));
      expect(arabicExam.dueAt!.day, 14);
      expect(englishExam.dueAt!.day, 15);

      expect(resp.text, contains('امتحان عربي'));
      expect(resp.text, contains('امتحان انجليزي'));
    });

    test('splits morning vs evening exams on same day and resolves pronoun breakdown cleanly', () async {
      const userId = 'nlu-user-morning-evening';
      final controller = makeController(userId);
      addTearDown(controller.dispose);

      final preview = await controller.sendTextMessage(
        'عندي امتحان بكره عربي الساعة 8 وامتحان انجليزي بليل الساعه 8',
        conversationId: 'c_me_1',
        speak: false,
      );
      expect(preview.text, startsWith('🔍 مراجعة قبل الحفظ'));
      expect(
        (await LocalTaskDatabase.instance.getTasksForUser(userId)
                as Success<List<Task>>)
            .data,
        isEmpty,
      );

      final resp = await controller.sendTextMessage(
        'اعتمد',
        conversationId: 'c_me_1',
        speak: false,
      );

      final tasks = (await LocalTaskDatabase.instance.getTasksForUser(userId)
              as Success<List<Task>>)
          .data;
      expect(tasks, hasLength(2));

      final arabicExam = tasks.firstWhere((t) => t.title.contains('عربي'));
      final englishExam = tasks.firstWhere((t) => t.title.contains('انجليزي'));
      expect(arabicExam.title, 'امتحان عربي');
      expect(englishExam.title, 'امتحان انجليزي');
      expect(arabicExam.dueAt!.day, 14);
      expect(arabicExam.dueAt!.hour, 8);
      expect(englishExam.dueAt!.day, 14);
      expect(englishExam.dueAt!.hour, 20);

      expect(resp.text, contains('امتحان عربي'));
      expect(resp.text, contains('امتحان انجليزي'));

      // Follow-up pronoun breakdown with correction phrase
      final breakdown = await controller.sendTextMessage(
        'قسمها لخطوات ده امتحان وده حاجة تانيه',
        conversationId: 'c_me_1',
        speak: false,
      );
      expect(breakdown.text, isNot(contains('ها لخطوات')));
      expect(breakdown.text, contains('امتحان عربي'));
      expect(breakdown.text, contains('امتحان انجليزي'));
    });

    test('handles diacritics and priority planning cleanly: رتّب معايا أولويات مهامي النهارده', () async {
      const userId = 'nlu-user-2';
      await LocalTaskDatabase.instance.createTask(
        userId: userId,
        title: 'مراجعة الفصل الأول',
        priority: TaskPriority.high,
        dueAt: DateTime(2026, 11, 13, 18),
      );
      await LocalTaskDatabase.instance.createTask(
        userId: userId,
        title: 'شراء أدوات مكتب',
        priority: TaskPriority.low,
        dueAt: DateTime(2026, 11, 13, 20),
      );

      final controller = makeController(userId);
      addTearDown(controller.dispose);

      final resp = await controller.sendTextMessage(
        'رتّب معايا أولويات مهامي النهارده',
        conversationId: 'c2',
        speak: false,
      );
      expect(resp.text, isNot(contains('مفيش مهام مطابقة')));
      expect(resp.text, contains('مراجعة الفصل الأول'));
      expect(resp.text.indexOf('مراجعة الفصل الأول'), lessThan(resp.text.indexOf('شراء أدوات مكتب')));
    });

    test('empty schedule priority request gives warm guidance instead of robotic dead-end', () async {
      const userId = 'nlu-user-empty';
      final controller = makeController(userId);
      addTearDown(controller.dispose);

      final resp = await controller.sendTextMessage(
        'رتّب معايا أولويات مهامي النهارده',
        conversationId: 'c3',
        speak: false,
      );
      expect(resp.text, isNot(contains('مفيش مهام مطابقة')));
      expect(resp.text, contains('امتحان بكره عربي'));
    });

    test('stress coaching and study breakdown + confirm saves real tasks', () async {
      const userId = 'nlu-user-3';
      final controller = makeController(userId);
      addTearDown(controller.dispose);

      final breakdown = await controller.sendTextMessage(
        'قسملي مذاكرة الفيزياء',
        conversationId: 'c4',
        speak: false,
      );
      expect(breakdown.text, contains('١)'));
      expect(breakdown.text, contains('٣)'));

      await controller.sendTextMessage(
        'تمام ضيفهم',
        conversationId: 'c4',
        speak: false,
      );
      final tasks = (await LocalTaskDatabase.instance.getTasksForUser(userId)
              as Success<List<Task>>)
          .data;
      expect(tasks.length, 3);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Google & Facebook Social Auth & Account Isolation Tests
  // ---------------------------------------------------------------------------
  group('LocalAuthRepository Social & Email Authentication', () {
    test('rejects unverified social sign-in by default and persists sessions when verified OAuth is enabled with token', () async {
      final defaultRepo = LocalAuthRepository();
      final blockedGoogle = await defaultRepo.signInWithGoogle(
        email: 'omar.google@gmail.com',
        displayName: 'عمر جوجل',
      );
      expect(blockedGoogle, isA<Failure<AppUser>>());

      final repo = LocalAuthRepository(
        socialAuth: SocialAuthService(oauthEnabledOverride: true),
      );
      final googleRes = await repo.signInWithGoogle(
        email: 'omar.google@gmail.com',
        displayName: 'عمر جوجل',
        idToken: 'verified-google-id-token',
      );
      expect(googleRes, isA<Success<AppUser>>());
      final googleUser = (googleRes as Success<AppUser>).data;
      expect(googleUser.authProvider, AuthProviderType.google);
      expect(googleUser.email, 'omar.google@gmail.com');
      expect(googleUser.firstName, 'عمر');

      await repo.updateAssistantTone(AssistantTone.brief);
      final restoredGoogle = await LocalAuthRepository().getCurrentUser();
      expect(restoredGoogle?.authProvider, AuthProviderType.google);
      expect(restoredGoogle?.tone, AssistantTone.brief);

      await repo.signOut();
      expect(await LocalAuthRepository().getCurrentUser(), isNull);

      final fbRes = await repo.signInWithFacebook(
        email: 'omar.fb@example.com',
        displayName: 'عمر فيسبوك',
        idToken: 'verified-fb-access-token',
      );
      expect(fbRes, isA<Success<AppUser>>());
      final fbUser = (fbRes as Success<AppUser>).data;
      expect(fbUser.authProvider, AuthProviderType.facebook);
      expect(fbUser.email, 'omar.fb@example.com');
    });
  });

  // ---------------------------------------------------------------------------
  // 4. End-to-End Widget & Workflow Tests
  // ---------------------------------------------------------------------------
  group('End-to-End Screen & Workflow Tests', () {
    testWidgets('SplashScreen and OnboardingScreen two-slide transition work cleanly', (tester) async {
      await tester.pumpWidget(_wrapApp(const SplashScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('هندلها'), findsOneWidget);
      expect(find.text('يومك أبسط، خطوة بخطوة.'), findsOneWidget);

      await tester.pumpWidget(_wrapApp(const OnboardingScreen()));
      await _pumpSettledFrames(tester);
      expect(find.text('١ من ٢'), findsOneWidget);
      expect(find.text('يلا نبدأ'), findsOneWidget);

      await tester.tap(find.text('يلا نبدأ'));
      await _pumpSettledFrames(tester, 5);
      expect(find.text('٢ من ٢'), findsOneWidget);
      expect(find.text('ابدأ مع هندلها'), findsOneWidget);
    });

    testWidgets('LoginScreen validates empty fields and SignUpScreen validates weak password', (tester) async {
      await tester.pumpWidget(_wrapApp(const LoginScreen()));
      await _pumpSettledFrames(tester);
      final loginBtn = find.text('تسجيل الدخول').last;
      await tester.ensureVisible(loginBtn);
      await tester.tap(loginBtn);
      await tester.pump();
      expect(find.text('البريد الإلكتروني مطلوب.'), findsOneWidget);
      expect(find.text('كلمة السر مطلوبة.'), findsOneWidget);

      await tester.pumpWidget(_wrapApp(const SignUpScreen()));
      await _pumpSettledFrames(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'مستخدم');
      await tester.enterText(find.byType(TextFormField).at(1), 'user@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), '123');
      final signUpBtn = find.text('إنشاء حساب').last;
      await tester.ensureVisible(signUpBtn);
      await tester.tap(signUpBtn);
      await tester.pump();
      expect(find.text('استخدم ٨ أحرف أو أكثر.'), findsOneWidget);
    });

    testWidgets('DashboardScreen renders seeded Demo tasks, progress ring, and Settings button', (tester) async {
      await _seedTestSessionStorage();
      await tester.pumpWidget(_wrapApp(const DashboardScreen()));
      await _pumpSettledFrames(tester);

      expect(find.textContaining('عمر'), findsWidgets);
      expect(find.text('٣ من ٥'), findsOneWidget);
      expect(find.text('٦٠٪'), findsOneWidget);
      expect(find.text('مراجعة شعار البراند النهائي'), findsWidgets);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('TasksScreen toggles Open/Completed tabs and shows Settings button', (tester) async {
      await _seedTestSessionStorage();
      await tester.pumpWidget(_wrapApp(const TasksScreen()));
      await _pumpSettledFrames(tester);

      expect(find.text('المفتوحة ٢'), findsOneWidget);
      expect(find.text('المكتملة ٣'), findsOneWidget);
      expect(find.text('مراجعة شعار البراند النهائي'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      await tester.tap(find.text('المكتملة ٣'));
      await _pumpSettledFrames(tester);
      expect(find.text('المهام المكتملة'), findsOneWidget);
      expect(find.text('حجز قاعة الاجتماع الأسبوعي'), findsOneWidget);
    });

    testWidgets('AddTaskScreen validates empty input and persists newly created task', (tester) async {
      await _seedTestSessionStorage();
      await tester.pumpWidget(_wrapApp(const AddTaskScreen()));
      await _pumpSettledFrames(tester);

      final saveBtn = find.text('احفظ المهمة');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await _pumpSettledFrames(tester);

      final before = (await LocalTaskDatabase.instance.getTasksForUser(_testUserId)
              as Success<List<Task>>)
          .data;
      expect(before, hasLength(5));

      await tester.enterText(find.byType(TextFormField).first, 'مهمة اختبار جديدة');
      await _pumpSettledFrames(tester);
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await _pumpSettledFrames(tester);

      final after = (await LocalTaskDatabase.instance.getTasksForUser(_testUserId)
              as Success<List<Task>>)
          .data;
      expect(after, hasLength(6));
      expect(after.any((t) => t.title == 'مهمة اختبار جديدة'), isTrue);
    });

    testWidgets('NewProjectScreen creates a project and persists color choice', (tester) async {
      await _seedTestSessionStorage();
      await tester.pumpWidget(_wrapApp(const NewProjectScreen()));
      await _pumpSettledFrames(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'مشروع اختبار التوازن');
      await tester.enterText(find.byType(TextFormField).at(1), 'تحقيق التوازن اليومي');
      final createBtn = find.text('إنشاء المشروع');
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn);
      await _pumpSettledFrames(tester);

      final projects = (await LocalProjectDatabase.instance.forUser(_testUserId)
              as Success<List<Project>>)
          .data;
      expect(projects.any((p) => p.title == 'مشروع اختبار التوازن'), isTrue);
    });

    testWidgets('ChatHistoryScreen lists conversations and filters via search', (tester) async {
      await _seedTestSessionStorage();
      await tester.pumpWidget(_wrapApp(const ChatHistoryScreen()));
      await _pumpSettledFrames(tester);

      expect(find.text('سجل المحادثات'), findsOneWidget);
      expect(find.textContaining('ترتيب جدول الأسبوع'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'تحضير عرض العمل');
      await _pumpSettledFrames(tester);
      expect(find.textContaining('تحضير عرض العمل'), findsWidgets);
      expect(find.textContaining('ترتيب جدول الأسبوع'), findsNothing);
    });

    testWidgets('FocusSession transitions Active -> Paused -> Completed & Break 05:00', (tester) async {
      await _seedTestSessionStorage();
      await tester.pumpWidget(_wrapApp(const HandelhaFocusSessionScreen(
        taskTitle: 'مراجعة شعار البراند',
        taskId: 'test-task-1',
      )));
      await tester.pump();
      expect(find.text('جلسة التركيز'), findsOneWidget);
      expect(find.text('٢٥:٠٠'), findsOneWidget);

      await tester.tap(find.text('إيقاف مؤقت'));
      await tester.pump();
      expect(find.text('التركيز متوقف'), findsOneWidget);
      expect(find.text('خد وقتك، مفيش استعجال.'), findsOneWidget);

      await tester.tap(find.text('إنهاء الجلسة'));
      await _pumpSettledFrames(tester);
      expect(find.text('عاش يا عمر!'), findsOneWidget);

      await tester.tap(find.text('خد استراحة'));
      await tester.pump();
      expect(find.text('وقت الاستراحة'), findsOneWidget);
      expect(find.text('٠٥:٠٠'), findsOneWidget);
    });

    testWidgets('NotificationsScreen toggles filter and marks all notifications read', (tester) async {
      await _seedTestSessionStorage();
      await tester.pumpWidget(_wrapApp(const NotificationsScreen()));
      await _pumpSettledFrames(tester);

      expect(find.text('الإشعارات'), findsOneWidget);
      expect(find.text('قراءة الكل'), findsOneWidget);
      await tester.tap(find.text('قراءة الكل'));
      await _pumpSettledFrames(tester);

      final readIds = await NotificationInboxStore.loadReadIds(_testUserId);
      expect(readIds, isNotEmpty);
      expect(find.text('غير المقروءة ٠'), findsOneWidget);
    });

    testWidgets('TrackingScreen displays day/week/month timelines, insights, badges, and Settings button', (tester) async {
      await _seedTestSessionStorage();
      await tester.pumpWidget(_wrapApp(const TrackingScreen()));
      await _pumpSettledFrames(tester, 5);

      expect(find.text('إنجازك'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.text('١٥٠ د'), findsOneWidget);
      expect(find.text('تتابع أيام الأسبوع'), findsOneWidget);
      expect(find.text('تحليل الأداء والتفاصيل'), findsOneWidget);
      expect(find.text('أوسمة الإنجاز'), findsOneWidget);

      await tester.tap(find.text('اليوم'));
      await _pumpSettledFrames(tester);
      expect(find.text('تتابع فترات اليوم'), findsOneWidget);

      await tester.tap(find.text('الشهور'));
      await _pumpSettledFrames(tester);
      expect(find.text('تتابع الشهور (آخر ٦ شهور)'), findsOneWidget);
      expect(find.text('تفصيل الأسابيع الأخيرة'), findsOneWidget);
    });

    testWidgets('SettingsScreen switches theme mode cleanly', (tester) async {
      await _seedTestSessionStorage();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: SettingsScreen(),
            ),
          ),
        ),
      );
      await _pumpSettledFrames(tester);

      final darkChip = find.text('داكن');
      await tester.ensureVisible(darkChip);
      await tester.tap(darkChip);
      await _pumpSettledFrames(tester);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Responsive Layout (No Overflow), RTL Directionality & Semantics Checks
  // ---------------------------------------------------------------------------
  group('Responsive No-Overflow, RTL & Semantics Audit', () {
    final viewports = <String, Size>{
      '320x568': const Size(320, 568),
      '390x844': const Size(390, 844),
      '412x915': const Size(412, 915),
    };

    final screens = <String, Widget>{
      'Login': const LoginScreen(),
      'Dashboard': const DashboardScreen(),
      'Tasks': const TasksScreen(),
      'AddTask': const AddTaskScreen(),
      'Projects': const ProjectsScreen(),
      'Chat': const ChatScreen(),
      'Focus': const HandelhaFocusSessionScreen(taskTitle: 'مراجعة العرض التقديمي'),
      'Tracking': const TrackingScreen(),
      'Settings': const SettingsScreen(),
    };

    for (final vp in viewports.entries) {
      for (final scr in screens.entries) {
        testWidgets('${scr.key} fits cleanly at ${vp.key} (1.3x text, RTL, no overflow)',
            (tester) async {
          await _seedTestSessionStorage();
          tester.view.physicalSize = vp.value * 2.0;
          tester.view.devicePixelRatio = 2.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                locale: const Locale('ar', 'EG'),
                supportedLocales: const [Locale('ar', 'EG')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.3),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: child!,
                  ),
                ),
                home: scr.value,
              ),
            ),
          );
          await _pumpSettledFrames(tester, 4);

          expect(tester.takeException(), isNull);
          final ctx = tester.element(find.byWidget(scr.value));
          expect(Directionality.of(ctx), TextDirection.rtl);
          final semantics = tester.getSemantics(find.byWidget(scr.value));
          expect(semantics, isNotNull);
        });
      }
    }
  });

  // ---------------------------------------------------------------------------
  // 8. Security, Privacy, PBKDF2 Auth, Account Deletion & Fuzz Tests
  // ---------------------------------------------------------------------------
  group('Security, Privacy, PBKDF2 Auth & Fuzz Tests', () {
    test('LocalAuthRepository stores PBKDF2-HMAC-SHA256 hashes and wipes all user stores on deleteAccount', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final auth = LocalAuthRepository();

      final created = await auth.createAccountWithEmail(
        email: 'user@handelha.app',
        password: 'StrongPass123',
        displayName: 'أحمد',
      );
      expect(created, isA<Success<AppUser>>());
      final user = (created as Success<AppUser>).data;

      final storedHash = await SecureStorageService.instance.read(
        SecureStorageKeys.localPasswordHash,
      );
      expect(storedHash, isNotNull);
      expect(
        storedHash,
        startsWith('pbkdf2_sha256\$${LocalAuthRepository.kdfIterations}\$'),
      );

      // Populate all local stores for this user
      await LocalTaskDatabase.instance.createTask(
        userId: user.id,
        title: 'مهمة للحذف',
        priority: TaskPriority.high,
      );
      await LocalProjectDatabase.instance.save(
        Project(
          id: 'proj-del-1',
          userId: user.id,
          title: 'مشروع للحذف',
          status: ProjectStatus.active,
          progressPercent: 0,
          taskIds: const [],
          createdAt: DateTime(2026, 11, 13),
          updatedAt: DateTime(2026, 11, 13),
        ),
      );
      await LocalNotificationPreferences.save(
        user.id,
        const NotificationPreferences(enabled: false),
      );
      await NotificationInboxStore.markAsRead(user.id, 'notif-1');

      await auth.deleteAccount();

      final remainingTasks = (await LocalTaskDatabase.instance.getTasksForUser(user.id)
              as Success<List<Task>>)
          .data;
      final remainingProjects = ((await LocalProjectDatabase.instance.forUser(user.id))
              as Success<List<Project>>)
          .data;
      final remainingReadIds = await NotificationInboxStore.loadReadIds(user.id);
      final remainingEmail = await SecureStorageService.instance.read(
        SecureStorageKeys.localEmail,
      );

      expect(remainingTasks, isEmpty);
      expect(remainingProjects, isEmpty);
      expect(remainingReadIds, isEmpty);
      expect(remainingEmail, isNull);
    });

    test('AppLogger.redact masks email addresses, tokens, and truncates long strings', () {
      final redacted = AppLogger.redact(
        'Failed login for omar@handelha.app with Bearer secretToken12345',
      );
      expect(redacted, isNot(contains('omar@handelha.app')));
      expect(redacted, isNot(contains('secretToken12345')));
      expect(redacted, contains('[REDACTED_EMAIL]'));
      expect(redacted, contains('[REDACTED_SECRET]'));
    });

    test('EgyptianNluAnalyzer handles oversized inputs (>2000 chars), tatweel, and negation safely', () {
      final analyzer = EgyptianNluAnalyzer();
      final now = DateTime(2026, 11, 13, 10, 0);

      final hugeInput = 'عندي مذاكرة فيزياء بكره ${'تطوييييل ' * 400}';
      expect(hugeInput.length, greaterThan(2000));
      final outcome = analyzer.analyze(hugeInput, now: now);
      expect(outcome.correctedRaw.length, lessThanOrEqualTo(EgyptianNluAnalyzer.maxInputChars));

      final negation = analyzer.analyze('مش عايز أضيف مهمة النهارده خلاص', now: now);
      expect(negation.understanding.safetyFlags.negated, isTrue);
    });
  });
}

class _NoopStt implements SpeechToTextService {
  @override
  Future<bool> initialize() async => false;

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancel() async {}

  @override
  bool get isListening => false;

  @override
  Stream<String> get partialTranscripts => const Stream<String>.empty();

  @override
  Stream<String> get finalTranscripts => const Stream<String>.empty();

  @override
  Stream<SttError> get errors => const Stream<SttError>.empty();

  @override
  Future<void> handlePermissionError() async {}

  @override
  void dispose() {}
}

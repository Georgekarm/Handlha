import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handelha/app/mode/student_mode_controller.dart';
import 'package:handelha/app/theme/app_theme.dart';
import 'package:handelha/core/database/local_project_database.dart';
import 'package:handelha/core/database/local_task_database.dart';
import 'package:handelha/core/result/result.dart';
import 'package:handelha/features/assistant/planning/ai_planning_service.dart';
import 'package:handelha/features/assistant/presentation/assistant_providers.dart';
import 'package:handelha/features/home/presentation/dashboard_screen.dart';
import 'package:handelha/features/notifications/alarm_reminder_store.dart';
import 'package:handelha/features/notifications/presentation/alarm_ringing_dialog.dart';
import 'package:handelha/features/notifications/presentation/notifications_screen.dart';
import 'package:handelha/features/projects/domain/project.dart';
import 'package:handelha/features/projects/presentation/handelha_focus_session_screen.dart';
import 'package:handelha/features/projects/presentation/project_workspace_screen.dart';
import 'package:handelha/features/projects/presentation/tracking_screen.dart';
import 'package:handelha/features/projects/presentation/widgets/ai_breakdown_sheet.dart';
import 'package:handelha/features/settings/presentation/settings_screen.dart';
import 'package:handelha/features/subscriptions/presentation/subscription_screen.dart';
import 'package:handelha/features/tasks/domain/task.dart';
import 'package:handelha/features/tasks/presentation/add_task_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp(Widget home, {AiPlanningService? planningService}) {
  return ProviderScope(
    overrides: [
      if (planningService != null)
        aiPlanningServiceProvider.overrideWithValue(planningService),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: home,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('Productivity Screen Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      StudentModeStore.setSync(false);
    });

    testWidgets('1. DashboardScreen renders calm greeting and honest empty state', (tester) async {
      await tester.pumpWidget(_buildTestApp(const DashboardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              ((w.data?.contains('صباح الخير') ?? false) ||
                  (w.data?.contains('مساء الخير') ?? false)),
        ),
        findsOneWidget,
      );
      expect(find.text('مهام خلصوا النهارده'), findsOneWidget);
      expect(find.text('باقي يومك'), findsOneWidget);
      expect(find.text('عرض الكل'), findsOneWidget);
      expect(find.textContaining('يومك رايق!'), findsOneWidget);
    });

    testWidgets('2. ProjectWorkspaceScreen renders project summary and honest empty steps', (tester) async {
      await tester.pumpWidget(_buildTestApp(const ProjectWorkspaceScreen(
        projectId: 'p-1',
        projectTitle: 'مشروع جديد',
        projectGoal: 'تنظيم الخطوات',
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('تفاصيل المشروع'), findsOneWidget);
      expect(find.text('مشروع جديد'), findsOneWidget);
      expect(find.text('الخطوات اللي جاية'), findsOneWidget);
      expect(find.textContaining('لسه مفيش خطوات متسجلة'), findsOneWidget);
    });

    testWidgets('3. AddTaskScreen renders clean form with mode switcher and validation fields', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        const AddTaskScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('إضافة مهمة'), findsOneWidget);
      expect(find.text('يدوي'), findsOneWidget);
      expect(find.text('بمساعدة هندلها'), findsOneWidget);
      expect(find.text('اسم المهمة'), findsOneWidget);
      expect(find.text('الموعد والأولوية'), findsOneWidget);
      expect(find.text('احفظ المهمة'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'مراجعة شاشة الدخول');
      await tester.pumpAndSettle();

      expect(find.text('مراجعة شاشة الدخول'), findsOneWidget);
    });

    testWidgets('4. AiBreakdownModal renders a generated plan for review', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        const Scaffold(body: AiBreakdownModal(projectTitle: 'تطبيق', projectGoal: 'إطلاق MVP')),
        planningService: AiPlanningService(_PlanLlm()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('تقسيم المشروع بالذكاء الاصطناعي'), findsOneWidget);
      expect(find.text('تطبيق'), findsOneWidget);
      expect(find.text('إطلاق MVP'), findsOneWidget);
      expect(find.text('التنفيذ'), findsOneWidget);
      expect(find.text('بناء الواجهة'), findsOneWidget);
      expect(find.textContaining('سؤال للمراجعة:'), findsOneWidget);
      expect(find.text('عدّل الخطة بكلامك'), findsOneWidget);
      expect(find.text('مراجعة تمت • اعتماد الخطة'), findsOneWidget);
    });

    testWidgets('5. Plan rejection saves nothing and approval persists tasks and project', (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'user_id': 'test-user',
        'user_email': 'test@example.com',
      });
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await tester.pumpWidget(_buildTestApp(
        const _PlanHost(),
        planningService: AiPlanningService(_PlanLlm()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('افتح الخطة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('رفض'));
      await tester.pumpAndSettle();
      expect((await LocalTaskDatabase.instance.getTasksForUser('test-user') as Success<List<Task>>).data, isEmpty);
      expect((await LocalProjectDatabase.instance.forUser('test-user') as Success<List<Project>>).data, isEmpty);

      await tester.tap(find.text('افتح الخطة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مراجعة تمت • اعتماد الخطة'));
      await tester.pumpAndSettle();
      final tasks = (await LocalTaskDatabase.instance.getTasksForUser('test-user') as Success<List<Task>>).data;
      final projects = (await LocalProjectDatabase.instance.forUser('test-user') as Success<List<Project>>).data;
      expect(tasks.single.title, 'بناء الواجهة');
      expect(tasks.single.projectId, projects.single.id);
      expect(projects.single.taskIds, [tasks.single.id]);
    });

    testWidgets('6. SettingsScreen renders settings sections', (tester) async {
      await tester.pumpWidget(_buildTestApp(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('وضع التطبيق'), findsOneWidget);
      expect(find.text('نبرة المساعد'), findsOneWidget);
      expect(find.text('المظهر'), findsOneWidget);
      expect(find.text('خصوصيتك تحت سيطرتك'), findsOneWidget);
      expect(find.text('فكّرني باللي يهمّني'), findsOneWidget);
    });

    testWidgets(
      '7. SubscriptionScreen shows strictly Student and Regular Pro tracks with distinct pricing & Student perks',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(const SubscriptionScreen()));
        await tester.pumpAndSettle();

        expect(find.text('باقات الطلاب'), findsOneWidget);
        expect(find.text('باقات Pro العادية'), findsOneWidget);
        expect(find.text('٦٩٩ ج.م'), findsOneWidget);
        expect(find.text('٨٩ ج.م'), findsOneWidget);
        expect(find.text('مزايا خاصة بباقات الطلاب فقط'), findsNothing);

        await tester.tap(find.text('باقات الطلاب'));
        await tester.pumpAndSettle();

        expect(find.text('٣٩٩ ج.م'), findsOneWidget);
        expect(find.text('٤٩ ج.م'), findsOneWidget);
        expect(find.text('مزايا خاصة بباقات الطلاب فقط'), findsOneWidget);
      },
    );

    testWidgets(
      '7b. SubscriptionScreen activates Student or Regular Pro plan, shows active plan details, and allows switching tracks',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(const SubscriptionScreen()));
        await tester.pumpAndSettle();

        expect(find.text('تصنيف الحساب الحالي: مجاني'), findsOneWidget);

        await tester.tap(find.text('باقات الطلاب'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('اختار باقة الطلاب').first);
        await tester.tap(find.text('اختار باقة الطلاب').first);
        await tester.pumpAndSettle();

        expect(find.text('تصنيف الطلاب'), findsOneWidget);
        expect(find.text('أنت مشترك حاليًا في: باقة الطلاب السنوية'), findsOneWidget);
        expect(find.text('خطتك الحالية ✓'), findsOneWidget);
        expect(find.text('أنت مشترك في هذه الخطة ✓'), findsOneWidget);

        await tester.tap(find.text('باقات Pro العادية'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('التحويل لهذه الخطة').last);
        await tester.tap(find.text('التحويل لهذه الخطة').last);
        await tester.pumpAndSettle();

        expect(
          find.text('تصنيف المشتركين العاديين (Pro)'),
          findsOneWidget,
        );
        expect(find.text('أنت مشترك حاليًا في: باقة Pro الشهرية'), findsOneWidget);
      },
    );

    testWidgets(
      '8. TrackingScreen restricts Exam Grades & Exam Hero milestone to Student Mode only',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(const TrackingScreen()));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pumpAndSettle();

        expect(find.text('إنجازك'), findsOneWidget);
        expect(find.text('تقديرات الامتحانات'), findsNothing);
        expect(find.text('بطل الامتحانات والتقدير'), findsNothing);

        SharedPreferences.setMockInitialValues({'handelha_student_mode': true});
        StudentModeStore.setSync(true);

        await tester.pumpWidget(_buildTestApp(const TrackingScreen()));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pumpAndSettle();

        expect(find.text('وضع الطالب شغّال'), findsOneWidget);
        expect(find.text('تقديرات الامتحانات'), findsOneWidget);
        expect(find.text('بطل الامتحانات والتقدير'), findsOneWidget);
      },
    );

    testWidgets(
      '9. AddTaskScreen reveals alarm vs notification selector when scheduled and handles alarm selection permission flow',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(const AddTaskScreen()));
        await tester.pumpAndSettle();

        expect(find.text('طريقة التنبيه عند الموعد'), findsNothing);

        await tester.ensureVisible(find.text('الموعد'));
        await tester.tap(find.text('الموعد'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('بكرة'));
        await tester.tap(find.text('بكرة'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('تم'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('طريقة التنبيه عند الموعد'));
        expect(find.text('طريقة التنبيه عند الموعد'), findsOneWidget);
        expect(find.text('رسالة إشعار'), findsOneWidget);
        expect(find.text('منبه يرن'), findsOneWidget);

        await tester.ensureVisible(find.text('منبه يرن'));
        await tester.tap(find.text('منبه يرن'));
        await tester.pumpAndSettle();

        expect(find.text('تفعيل إذن الإشعارات والمنبه'), findsOneWidget);
        await tester.tap(find.text('تخطي الآن'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '10. NotificationsScreen omits removed permission card and keeps scheduled alarm items',
      (tester) async {
        await AlarmReminderStore.save(
          'guest',
          AlarmReminderState(
            permissionGranted: false,
            defaultAlertMode: 'alarm',
            items: [
              AlarmReminderItem(
                id: 'rem-exam-1',
                title: 'امتحان رياضة',
                scheduledAt: DateTime(2026, 11, 20, 9, 0),
                alertMode: 'alarm',
              ),
            ],
          ),
        );

        await tester.pumpWidget(_buildTestApp(const NotificationsScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        expect(find.text('إذن الإشعارات والمنبه الذكي'), findsNothing);
        expect(find.text('تفعيل إذن الإشعارات والمنبه الآن'), findsNothing);
        expect(
          find.text('السماح بالظهور فوق التطبيقات للمنبه الخارجي'),
          findsNothing,
        );
        expect(
          find.text('معاينة وتجربة شاشة وصوت المنبه'),
          findsNothing,
        );
        expect(find.text('المنبهات والتذكيرات المجدولة'), findsOneWidget);
        expect(find.text('امتحان رياضة'), findsOneWidget);
      },
    );

    testWidgets(
      '12. HandelhaAlarmRingingDialog renders modern Handelha alarm controls without overflow',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            const HandelhaAlarmRingingDialog(
              title: 'مراجعة الفيزياء',
              taskId: 'task-physics-1',
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.text('هندلها  •  منبه المواعيد'), findsOneWidget);
        expect(find.text('مراجعة الفيزياء'), findsOneWidget);
        expect(find.text('جه ميعاد مهمتك دلوقتي'), findsOneWidget);
        expect(find.text('إيقاف المنبه'), findsOneWidget);
        expect(find.text('غفوة ٥ د'), findsOneWidget);
        expect(find.text('غفوة ١٠ د'), findsOneWidget);
        expect(find.text('فتح المهمة وبدء التركيز الآن'), findsOneWidget);

        // Unmount before test completion to cleanly cancel periodic ticker & animations.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      '11. HandelhaFocusSessionScreen supports ruler duration bar, soundscapes without volume slider, and growing tree tab',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            const HandelhaFocusSessionScreen(
              taskTitle: 'مذاكرة الفيزياء',
              initialMinutes: 25,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        expect(find.text('مدة الجلسة'), findsOneWidget);
        expect(find.text('أصوات هادئة للتركيز'), findsOneWidget);
        expect(find.text('أمواج البحر'), findsOneWidget);
        expect(find.text('هدوء الليل'), findsOneWidget);
        expect(find.text('ضوضاء دافئة'), findsOneWidget);
        // Volume slider was explicitly removed per user request.
        expect(find.byType(Slider), findsNothing);

        await tester.ensureVisible(find.text('أمواج البحر'));
        await tester.tap(find.text('أمواج البحر'));
        await tester.pump(const Duration(milliseconds: 120));

        expect(find.textContaining('الموج الهادئة'), findsOneWidget);

        await tester.ensureVisible(find.text('شجرتك'));
        await tester.tap(find.text('شجرتك'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('جنينة شجرك'), findsOneWidget);
        expect(find.text('أوسمة شجرتك'), findsOneWidget);
        expect(find.text('فاتحة خير'), findsOneWidget);
        expect(find.text('شدّيت حيلك'), findsOneWidget);
        expect(find.text('بطل التركيز'), findsOneWidget);
        expect(find.text('رايق ومركّز'), findsOneWidget);

        // Verify direct openTreeTab route opens directly onto شجرتك tab.
        await tester.pumpWidget(
          _buildTestApp(
            const HandelhaFocusSessionScreen(
              taskTitle: 'جلسة تركيز هادئة',
              openTreeTab: true,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('جنينة شجرك'), findsOneWidget);

        // Unmount before test completion to cleanly cancel periodic ticker.
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}

class _PlanHost extends StatelessWidget {
  const _PlanHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => AiBreakdownModal.show(
            context,
            projectTitle: 'تطبيق',
            projectGoal: 'إطلاق MVP',
          ),
          child: const Text('افتح الخطة'),
        ),
      ),
    );
  }
}

class _PlanLlm implements LLMService {
  @override
  Future<LlmReply> complete(LlmRequest request) async {
    return const LlmReply(text: '{"title":"تطبيق","goal":"إطلاق MVP","clarification_question":"مين المستخدم الأساسي؟","phases":[{"id":"p1","title":"التنفيذ","description":null,"suggested_deadline":null,"tasks":[{"id":"t1","title":"بناء الواجهة","description":null,"estimated_duration_minutes":120,"duration_uncertainty":"تقدير أولي","priority":"high","suggested_deadline":null,"depends_on":[]}]}]}');
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sekretairak/app/theme/app_theme.dart';
import 'package:sekretairak/features/home/presentation/home_screen.dart';
import 'package:sekretairak/features/projects/presentation/project_settings_screen.dart';
import 'package:sekretairak/features/projects/presentation/project_workspace_screen.dart';
import 'package:sekretairak/features/projects/presentation/widgets/activity_tab_view.dart';
import 'package:sekretairak/features/projects/presentation/widgets/ai_breakdown_sheet.dart';
import 'package:sekretairak/features/projects/presentation/widgets/analytics_tab_view.dart';
import 'package:sekretairak/features/projects/presentation/widgets/overview_tab_view.dart';
import 'package:sekretairak/features/projects/presentation/widgets/phases_tab_view.dart';
import 'package:sekretairak/features/projects/presentation/widgets/smart_add_task_sheet.dart';
import 'package:sekretairak/features/projects/presentation/widgets/tasks_tab_view.dart';

Widget _buildTestApp(Widget home) {
  return ProviderScope(
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

  group('Calm Productivity 2.0 Screen Tests', () {
    testWidgets('1. HomeScreen renders calm header, next task, and priorities', (tester) async {
      await tester.pumpWidget(_buildTestApp(const HomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header
      expect(find.textContaining('نخلّص خطوة واحدة دلوقتي.'), findsOneWidget);
      expect(find.textContaining('أولويات النهار'), findsOneWidget);
    });

    testWidgets('2. ProjectWorkspaceScreen renders Header and 5 Tabs', (tester) async {
      await tester.pumpWidget(_buildTestApp(const ProjectWorkspaceScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('إطلاق نسخة هندلها'), findsWidgets);
      expect(find.textContaining('تجربة مريحة لتنظيم اليوم'), findsOneWidget);

      // 5 tabs
      expect(find.text('نظرة عامة'), findsOneWidget);
      expect(find.text('المهام'), findsOneWidget);
      expect(find.text('المراحل'), findsOneWidget);
      expect(find.text('النشاط'), findsOneWidget);
      expect(find.text('التحليلات'), findsOneWidget);
    });

    testWidgets('3. OverviewTabView renders goal and due date', (tester) async {
      await tester.pumpWidget(_buildTestApp(Scaffold(
        body: OverviewTabView(
          onOpenTasksTab: () {},
          onOpenPhasesTab: () {},
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('نشر نسخة تجريبية قابلة للاستخدام'), findsOneWidget);
      expect(find.text('تاريخ الاستحقاق'), findsOneWidget);
      expect(find.text('20 أكتوبر 2026'), findsOneWidget);
      expect(find.text('حالة المشروع'), findsOneWidget);
    });

    testWidgets('4. TasksTabView renders project tasks', (tester) async {
      await tester.pumpWidget(_buildTestApp(const Scaffold(body: TasksTabView())));
      await tester.pumpAndSettle();

      expect(find.text('تحديث نظام الألوان الهادئ'), findsOneWidget);
      expect(find.text('ضبط تدفق الشات والمقترحات'), findsOneWidget);
      expect(find.text('إعداد جلسة التركيز التفاعلية'), findsOneWidget);
    });

    testWidgets('5. PhasesTabView renders vertical phases and open detail view', (tester) async {
      await tester.pumpWidget(_buildTestApp(const Scaffold(body: PhasesTabView())));
      await tester.pumpAndSettle();

      expect(find.text('مراحل المشروع (4 مراحل)'), findsOneWidget);
      expect(find.textContaining('التخطيط'), findsWidgets);
      expect(find.textContaining('التصميم'), findsWidgets);
      expect(find.textContaining('مرحلة التطوير'), findsWidgets);
      expect(find.textContaining('الاختبار'), findsWidgets);

      // Opened detail
      expect(find.textContaining('ملاحظة المرحلة'), findsOneWidget);
      expect(find.textContaining('الاعتماديات'), findsOneWidget);
      expect(find.textContaining('الخطوة التالية'), findsOneWidget);
    });

    testWidgets('6. AnalyticsTabView renders 3 states and KPI cards', (tester) async {
      await tester.pumpWidget(_buildTestApp(const Scaffold(body: AnalyticsTabView())));
      await tester.pumpAndSettle();

      // Full State
      expect(find.text('نسبة الإنجاز الإجمالية'), findsOneWidget);
      expect(find.text('62%'), findsOneWidget);
      expect(find.text('18 / 29'), findsOneWidget);
      expect(find.text('15س 20د'), findsOneWidget);
      expect(find.text('مقارنة التقدم بمرور الوقت'), findsOneWidget);
      expect(find.textContaining('أسباب التأخير'), findsOneWidget);
      expect(find.textContaining('ملاحظة ذكية مبنية على تحليلاتك:'), findsOneWidget);

      // Partial State
      await tester.tap(find.text('جزئية'));
      await tester.pumpAndSettle();
      expect(find.text('لسه بنجمع صورة أوضح عن الشغل'), findsOneWidget);

      // Empty State
      await tester.tap(find.text('فارغة'));
      await tester.pumpAndSettle();
      expect(find.text('ابدأ الشغل علشان التحليلات تظهر هنا'), findsOneWidget);
    });

    testWidgets('7. ActivityTabView renders filter chips and activity items', (tester) async {
      await tester.pumpWidget(_buildTestApp(const Scaffold(body: ActivityTabView())));
      await tester.pumpAndSettle();

      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('أنا 👤'), findsOneWidget);
      expect(find.text('الذكاء الاصطناعي 🌿'), findsOneWidget);

      expect(find.textContaining('تم اقتراح ترتيب جديد للمهام'), findsOneWidget);
      expect(find.textContaining('أنهيت إعداد قاعدة البيانات'), findsOneWidget);
    });

    testWidgets('8. SmartAddTaskBottomSheet renders smart input and extracted chips', (tester) async {
      await tester.pumpWidget(_buildTestApp(const Scaffold(
        body: SmartAddTaskBottomSheet(),
      )));
      await tester.pumpAndSettle();

      expect(find.text('إضافة مهمة ذكية'), findsOneWidget);
      expect(find.textContaining('اكتبها بطريقتك أو قولها'), findsOneWidget);
      expect(find.textContaining('فهمت منك'), findsOneWidget);
      expect(find.text('النموذج اليدوي للتأكيد والتعديل'), findsOneWidget);
      expect(find.text('إضافة المهمة للمشروع'), findsOneWidget);
    });

    testWidgets('9. AiBreakdownModal renders goal summary, accordion, and clarification', (tester) async {
      await tester.pumpWidget(_buildTestApp(const Scaffold(
        body: AiBreakdownModal(),
      )));
      await tester.pumpAndSettle();

      expect(find.text('تقسيم المشروع بالذكاء الاصطناعي'), findsOneWidget);
      expect(find.text('24 ساعة'), findsOneWidget);
      expect(find.text('4 مراحل'), findsOneWidget);
      expect(find.text('18 مهمة'), findsOneWidget);
      expect(find.textContaining('نقط محتاجة توضيح:'), findsOneWidget);
      expect(find.text('أجاوب دلوقتي'), findsOneWidget);
      expect(find.text('قبول الكل واعتماد الخطة'), findsOneWidget);
    });

    testWidgets('10. ProjectSettingsScreen renders settings and danger zone', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestApp(const ProjectSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('إعدادات المشروع'), findsOneWidget);
      expect(find.text('البيانات الأساسية'), findsOneWidget);
      expect(find.text('الوقت والجهد'), findsOneWidget);
      expect(find.text('إدارة المشروع'), findsOneWidget);
      expect(find.text('أرشفة المشروع'), findsOneWidget);
      expect(find.text('حذف المشروع'), findsOneWidget);
    });
  });
}

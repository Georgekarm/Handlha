import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  group('Calm Productivity 2.0 Screen Tests', () {
    testWidgets('1. HomeScreen renders calm header, smart input, chips, and inbox', (tester) async {
      await tester.pumpWidget(_buildTestApp(const HomeScreen()));
      await tester.pumpAndSettle();

      // Header
      expect(find.textContaining('خلي يومك أهدى وأسهل'), findsOneWidget);

      // Smart Input prompt
      expect(find.text('مش محتاج ترتب كلامك قبل ما تقوله'), findsOneWidget);

      // Chips
      expect(find.text('خطط على قد طاقتك'), findsOneWidget);
      expect(find.text('إيه الطريقة اللي تريحك؟'), findsOneWidget);
      expect(find.text('تحب تتكلم معاك إزاي؟'), findsOneWidget);
      expect(find.text('قول أول حاجة شاغلاك'), findsOneWidget);

      // Inbox
      expect(find.textContaining('صباح الفل يا يوسف'), findsOneWidget);
      expect(find.textContaining('مراجعة أول 5 شرائح'), findsOneWidget);
    });

    testWidgets('2. ProjectWorkspaceScreen renders Header and 4 Tabs', (tester) async {
      await tester.pumpWidget(_buildTestApp(const ProjectWorkspaceScreen()));
      await tester.pumpAndSettle();

      expect(find.text('مشروع تطبيق Flutter'), findsWidgets);
      expect(find.textContaining('إطلاق أول نسخة تجريبية من التطبيق'), findsOneWidget);
      expect(find.textContaining('١ سبتمبر ٢٠٢٦ - ٣١ أكتوبر ٢٠٢٦'), findsOneWidget);

      // 4 tabs
      expect(find.text('نظرة عامة'), findsOneWidget);
      expect(find.text('المهام'), findsOneWidget);
      expect(find.text('المراحل'), findsOneWidget);
      expect(find.text('النشاط'), findsOneWidget);
      expect(find.byType(Tab), findsNWidgets(4));
    });

    testWidgets('3. OverviewTabView renders full state and toggle to empty state', (tester) async {
      await tester.pumpWidget(_buildTestApp(Scaffold(
        body: OverviewTabView(
          onOpenTasksTab: () {},
          onOpenPhasesTab: () {},
        ),
      )));
      await tester.pumpAndSettle();

      // Full State elements
      expect(find.text('62%'), findsOneWidget);
      expect(find.text('ماشي كويس، لكن في 3 مهام محتاجة ترتيب'), findsOneWidget);
      expect(find.textContaining('18 من 29 مهمة مكتملة'), findsOneWidget);
      expect(find.text('أنت متقدم عن الأسبوع اللي فات بـ 8%'), findsOneWidget);
      expect(find.text('اقتراح ذكي'), findsOneWidget);
      expect(find.text('إنهاء شاشة تسجيل الدخول'), findsOneWidget);
      expect(find.text('ابدأ الآن'), findsOneWidget);
      expect(find.text('صحة المشروع ومسار الوقت'), findsOneWidget);
      expect(find.text('15س'), findsOneWidget);
      expect(find.text('في مهمتين مستنيين قرار منك'), findsOneWidget);

      // Toggle to empty state
      await tester.tap(find.text('فارغة'));
      await tester.pumpAndSettle();

      expect(find.text('نبدأ المشروع على مهلك؟'), findsOneWidget);
      expect(find.text('قسم المشروع بالذكاء الاصطناعي'), findsOneWidget);
    });

    testWidgets('4. TasksTabView renders search, filters, and 3 view modes', (tester) async {
      await tester.pumpWidget(_buildTestApp(const Scaffold(body: TasksTabView())));
      await tester.pumpAndSettle();

      expect(find.text('29 مهمة إجمالية'), findsOneWidget);
      expect(find.text('قائمة'), findsOneWidget);
      expect(find.text('لوحة'), findsOneWidget);
      expect(find.text('الخط الزمني'), findsOneWidget);

      // Switch to Kanban Board view
      await tester.tap(find.text('لوحة'));
      await tester.pumpAndSettle();
      expect(find.text('جاهزة'), findsWidgets);
      expect(find.text('مكتملة'), findsWidgets);

      // Switch to Timeline view
      await tester.tap(find.text('الخط الزمني'));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);
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

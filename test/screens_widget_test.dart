import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sekretairak/app/theme/app_theme.dart';
import 'package:sekretairak/features/authentication/presentation/login_screen.dart';
import 'package:sekretairak/features/authentication/presentation/signup_screen.dart';
import 'package:sekretairak/features/home/presentation/dashboard_screen.dart';
import 'package:sekretairak/features/tasks/presentation/tasks_screen.dart';
import 'package:sekretairak/features/assistant/presentation/chat_screen.dart';
import 'package:sekretairak/features/projects/presentation/projects_screen.dart';
import 'package:sekretairak/features/notifications/presentation/notifications_screen.dart';
import 'package:sekretairak/features/settings/presentation/settings_screen.dart';

Widget _buildTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('Authentication Screens Widget Tests (PDF Design)', () {
    testWidgets('LoginScreen renders fields, buttons and logo', (tester) async {
      await tester.pumpWidget(_buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2)); // Email + Password
      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);
    });

    testWidgets('SignUpScreen renders registration form', (tester) async {
      await tester.pumpWidget(_buildTestApp(const SignUpScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(3)); // Name, Email, Password
      expect(find.text('إنشاء حساب'), findsWidgets);
      expect(find.text('أوافق على شروط الاستخدام وسياسة الخصوصية.'), findsOneWidget);
    });
  });

  group('Home & Productivity Screens Widget Tests (PDF Design)', () {
    testWidgets('DashboardScreen renders greeting, focus card and priorities', (tester) async {
      await tester.pumpWidget(_buildTestApp(const DashboardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.text('خطوتك الجاية'), findsOneWidget);
      expect(find.text('مراجعة تدفق المهام وتجربة المستخدم'), findsOneWidget);
      expect(find.text('ابدأ التركيز • ٢٥ دقيقة'), findsOneWidget);
      expect(find.text('وبعدها'), findsOneWidget);
      expect(find.text('إطلاق نسخة هندلها'), findsOneWidget);
    });

    testWidgets('TasksScreen renders the three task filters and action bar', (tester) async {
      await tester.pumpWidget(_buildTestApp(const TasksScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.text('مهامك، على مهلك'), findsOneWidget);
      expect(find.text('اليوم ٨'), findsOneWidget);
      expect(find.text('الوارد'), findsOneWidget);
      expect(find.text('المكتملة ٣'), findsOneWidget);
      expect(find.text('مراجعة تدفق المهام وتجربة المستخدم'), findsOneWidget);
    });

    testWidgets('ChatScreen renders assistant greeting and proposals', (tester) async {
      await tester.pumpWidget(_buildTestApp(const ChatScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('مساعد هندلها'), findsOneWidget);
      expect(find.text('معاك، خطوة بخطوة'), findsOneWidget);
      expect(find.text('مراجعة تدفق المهام وتجربة المستخدم'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('ProjectsScreen renders filter chips and project cards', (tester) async {
      await tester.pumpWidget(_buildTestApp(const ProjectsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('من فكرة لخطوة'), findsOneWidget);
      expect(find.text('نشطة ٢'), findsOneWidget);
      expect(find.text('إطلاق نسخة هندلها'), findsOneWidget);
      expect(find.text('تنظيم مساحة العمل'), findsOneWidget);
    });

    testWidgets('NotificationsScreen renders notifications and quiet hours', (tester) async {
      await tester.pumpWidget(_buildTestApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('الإشعارات'), findsOneWidget);
      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('غير المقروءة ٢'), findsOneWidget);
      expect(find.text('خطوتك الأولى جاهزة'), findsOneWidget);
    });

    testWidgets('SettingsScreen renders account, tone and preferences', (tester) async {
      await tester.pumpWidget(_buildTestApp(const SettingsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('على طريقتك'), findsOneWidget);
      expect(find.text('نبرة المساعد'), findsOneWidget);
      expect(find.text('المظهر'), findsOneWidget);
      expect(find.text('الخصوصية والبيانات'), findsOneWidget);
    });
  });
}

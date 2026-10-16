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

  group('Authentication Screens Widget Tests', () {
    testWidgets('LoginScreen renders fields, buttons and calm logo', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2)); // Email + Password
      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Facebook'), findsOneWidget);
      expect(find.text('اعمل حساب جديد'), findsOneWidget);
    });

    testWidgets('SignUpScreen renders registration form', (tester) async {
      await tester.pumpWidget(_buildTestApp(const SignUpScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(3)); // Name, Email, Password
      expect(find.text('إنشاء حساب'), findsOneWidget);
      expect(find.text('سجّل دخولك'), findsOneWidget);
    });
  });

  group('Home & Productivity Screens Widget Tests', () {
    testWidgets('DashboardScreen renders greeting, focus card and priorities', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(const DashboardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.text('أولويات النهار'), findsOneWidget);
      expect(find.text('نخلّص خطوة واحدة دلوقتي.'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // Quick add
    });

    testWidgets('TasksScreen renders the three task filters', (tester) async {
      await tester.pumpWidget(_buildTestApp(const TasksScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.text('مهامك'), findsOneWidget);
      expect(find.text('اليوم'), findsWidgets);
      expect(find.text('الوارد'), findsOneWidget);
      expect(find.text('المكتملة'), findsOneWidget);
    });

    testWidgets('ChatScreen renders assistant greeting and proposals', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(const ChatScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('هندلها معاك'), findsOneWidget);
      expect(find.text('متصل الآن'), findsOneWidget);
      expect(find.text('تأكيد وإضافة'), findsOneWidget); // Proposal card CTA
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('ProjectsScreen renders filter chips and project cards', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(const ProjectsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('مشاريع'), findsOneWidget);
      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('شغّالة'), findsOneWidget);
      expect(find.text('إطلاق نسخة هندلها'), findsOneWidget);
    });

    testWidgets('NotificationsScreen renders quiet hours and category tabs', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('تنبيهاتك'), findsOneWidget);
      expect(find.text('ساعات الهدوء: مفعّلة'), findsOneWidget);
      expect(find.text('تذكير'), findsAtLeastNWidgets(1));
      expect(find.text('تشجيع'), findsAtLeastNWidgets(1));
      expect(find.text('تركيز'), findsAtLeastNWidgets(1));
    });

    testWidgets('SettingsScreen renders account, tone and preferences', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(const SettingsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('إعداداتك'), findsOneWidget);
      expect(find.text('نبرة المساعد'), findsOneWidget);
      expect(find.text('المظهر'), findsOneWidget);
      expect(find.text('الخصوصية والبيانات'), findsOneWidget);
    });
  });
}

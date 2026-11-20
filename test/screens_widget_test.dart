import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:handelha/app/theme/app_theme.dart';
import 'package:handelha/features/authentication/presentation/login_screen.dart';
import 'package:handelha/features/authentication/presentation/signup_screen.dart';
import 'package:handelha/features/home/presentation/dashboard_screen.dart';
import 'package:handelha/features/tasks/presentation/tasks_screen.dart';
import 'package:handelha/features/assistant/presentation/chat_screen.dart';
import 'package:handelha/features/projects/presentation/projects_screen.dart';
import 'package:handelha/features/notifications/presentation/notifications_screen.dart';
import 'package:handelha/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('Authentication Screens Widget Tests', () {
    testWidgets('LoginScreen renders fields, Google & Facebook buttons and logo without demo button', (tester) async {
      await tester.pumpWidget(_buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.text('جوجل'), findsOneWidget);
      expect(find.text('فيسبوك'), findsOneWidget);
      expect(find.text('نسيت كلمة السر؟'), findsOneWidget);
      expect(find.text('دخول سريع بالحساب التجريبي'), findsNothing);
    });

    testWidgets('SignUpScreen renders registration form', (tester) async {
      await tester.pumpWidget(_buildTestApp(const SignUpScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('إنشاء حساب'), findsWidgets);
      expect(
        find.text('بالمتابعة، إنت موافق على شروط الاستخدام والخصوصية.'),
        findsOneWidget,
      );
    });
  });

  group('Home & Productivity Screens Widget Tests', () {
    testWidgets('DashboardScreen renders greeting and honest empty state', (tester) async {
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
      expect(find.textContaining('يومك رايق!'), findsOneWidget);
      expect(find.text('عرض الكل'), findsOneWidget);
    });

    testWidgets('TasksScreen renders real-data filters and empty state', (tester) async {
      await tester.pumpWidget(_buildTestApp(const TasksScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('المهام'), findsOneWidget);
      expect(find.textContaining('المفتوحة'), findsOneWidget);
      expect(find.textContaining('المكتملة'), findsOneWidget);
      expect(find.text('لسه الصفحة فاضية؟'), findsOneWidget);
    });

    testWidgets('ChatScreen renders the real assistant state and composer without stale ad labels', (tester) async {
      await tester.pumpWidget(_buildTestApp(const ChatScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('مساعد هندلها'), findsOneWidget);
      expect(find.text('معاك، مش مستعجلك'), findsOneWidget);
      expect(find.text('مش لازم ترتّب كلامك، أنا معاك.'), findsOneWidget);
      expect(find.textContaining('بإعلان'), findsNothing);
      expect(find.textContaining('+15 Ad'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('ProjectsScreen does not render fabricated project cards', (tester) async {
      await tester.pumpWidget(_buildTestApp(const ProjectsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('المشروعات'), findsOneWidget);
      expect(find.text('نشطة ٠'), findsOneWidget);
      expect(find.text('مكتملة'), findsOneWidget);
      expect(find.textContaining('لسه مفيش مشروعات'), findsOneWidget);
      expect(find.text('إطلاق نسخة هندلها'), findsNothing);
    });

    testWidgets('NotificationsScreen renders honest empty state', (tester) async {
      await tester.pumpWidget(_buildTestApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('الإشعارات'), findsOneWidget);
      expect(find.text('كل إشعاراتك مقروءة'), findsOneWidget);
    });

    testWidgets('SettingsScreen renders account, tone and preferences', (tester) async {
      await tester.pumpWidget(_buildTestApp(const SettingsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('نبرة المساعد'), findsOneWidget);
      expect(find.text('المظهر'), findsOneWidget);
      expect(find.text('خصوصيتك تحت سيطرتك'), findsOneWidget);
    });
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:handelha/app/app.dart';
import 'package:handelha/features/authentication/presentation/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HandelhaApp()));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

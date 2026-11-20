import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/notifications/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await LocalNotificationService.instance.initialize();

  ErrorWidget.builder = (details) {
    return Material(
      color: const Color(0xFFF6F7F5),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: const Text(
              'حصل خطأ غير متوقع أثناء عرض الشاشة. جرّب تقفل الصفحة وتفتحها تاني.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF1E2D2B),
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  };

  runApp(const ProviderScope(child: HandelhaApp()));
}


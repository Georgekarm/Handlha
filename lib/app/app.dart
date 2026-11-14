import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/notifications/presentation/alarm_coordinator.dart';
import '../shared/utils/arabic_formatters.dart';
import 'locale/language_controller.dart';
import 'mode/student_mode_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class HandelhaApp extends ConsumerWidget {
  const HandelhaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final appLang = ref.watch(appLanguageProvider);
    ref.watch(isStudentModeActiveProvider);
    ArabicFormatters.useEnglish = appLang.isEnglish;

    return MaterialApp.router(
      title: appLang.tr('هندلها', 'Handelha'),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,

      locale: appLang.locale,
      supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: appLang.textDirection,
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.8,
            maxScaleFactor: 1.4,
            child: HandelhaAlarmCoordinator(
              child: child ??
                  const ColoredBox(
                    color: Color(0xFFF6F7F5),
                    child: SizedBox.expand(),
                  ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/theme_controller.dart';

/// زر تبديل الثيم السريع (Light / Dark) مع حركة تفاعلية ناعمة
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isSystemDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system && isSystemDark);

    return Semantics(
      button: true,
      label: isDark ? 'التحويل للوضع النهاري' : 'التحويل للوضع الليلي',
      child: IconButton(
        tooltip: isDark ? 'الوضع النهاري' : 'الوضع الليلي',
        onPressed: () {
          HapticFeedback.selectionClick();
          ref.read(themeModeProvider.notifier).toggle();
        },
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) {
            return RotationTransition(
              turns: anim,
              child: FadeTransition(opacity: anim, child: child),
            );
          },
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
            key: ValueKey<bool>(isDark),
            color: isDark ? AppColors.darkWarning : AppColors.secondary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'handelha_brand.dart';

enum HandelhaIllustrationType { welcome, calendar, reset, sent, task, focus }

/// رسوم واجهة خفيفة قابلة للتحجيم، مرسومة بعناصر Flutter بدل صور مشوشة.
class HandelhaIllustration extends StatelessWidget {
  const HandelhaIllustration({
    super.key,
    required this.type,
    this.height = 190,
  });

  final HandelhaIllustrationType type;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = height * 1.55;
    final art = switch (type) {
      HandelhaIllustrationType.welcome => _welcome(isDark),
      HandelhaIllustrationType.calendar => _calendar(isDark),
      HandelhaIllustrationType.reset => _envelope(success: false, isDark: isDark),
      HandelhaIllustrationType.sent => _envelope(success: true, isDark: isDark),
      HandelhaIllustrationType.task => _task(isDark),
      HandelhaIllustrationType.focus => _focus(isDark),
    };
    return SizedBox(width: width, height: height, child: art);
  }

  Widget _welcome(bool isDark) => Stack(
        alignment: Alignment.center,
        children: [
          _halo(isDark ? AppColors.darkPrimarySoft : AppColors.primarySoft, 142),
          Positioned(
            left: 12,
            bottom: 16,
            child: _tile(Icons.menu_book_rounded, isDark ? AppColors.darkSurface2 : AppColors.secondarySoft,
                isDark ? AppColors.darkSecondary : AppColors.secondary, 64),
          ),
          Positioned(
            right: 14,
            bottom: 18,
            child: _tile(Icons.check_box_rounded, isDark ? AppColors.darkSurface3 : AppColors.accentSoft,
                isDark ? AppColors.darkAccent : AppColors.accent, 50),
          ),
          Positioned(top: 4, child: HandelhaMark(size: 94, dark: isDark)),
          Positioned(
            bottom: 0,
            child: Container(
              width: 144,
              height: 18,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkPrimary : AppColors.primary).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      );

  Widget _calendar(bool isDark) => Stack(
        alignment: Alignment.center,
        children: [
          _halo(isDark ? AppColors.darkPrimarySoft : AppColors.primarySoft, 150),
          Positioned(
            left: 8,
            bottom: 22,
            child: _tile(Icons.spa_rounded, isDark ? AppColors.darkSurface3 : AppColors.successSoft,
                isDark ? AppColors.darkPrimary : AppColors.primary, 58),
          ),
          Positioned(
            right: 10,
            bottom: 22,
            child: _tile(Icons.local_cafe_rounded, isDark ? AppColors.darkSurface2 : AppColors.secondarySoft,
                isDark ? AppColors.darkSecondary : AppColors.secondary, 54),
          ),
          Container(
            width: 128,
            height: 112,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 5)),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkPrimary : AppColors.primary,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Icon(Icons.event_available_rounded,
                        size: 54, color: isDark ? AppColors.darkPrimaryStrong : AppColors.primaryStrong),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 18,
            right: 28,
            child: _spark(isDark ? AppColors.darkAccent : AppColors.accent),
          ),
        ],
      );

  Widget _envelope({required bool success, required bool isDark}) => Stack(
        alignment: Alignment.center,
        children: [
          _halo(success ? (isDark ? AppColors.darkPrimarySoft : AppColors.primarySoft) : (isDark ? AppColors.darkSurface3 : AppColors.secondarySoft), 145),
          Container(
            width: 138,
            height: 92,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? AppColors.darkPrimary : AppColors.primary, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x10000000), blurRadius: 14, offset: Offset(0, 5)),
              ],
            ),
            child: Icon(
              Icons.mail_outline_rounded,
              size: 72,
              color: isDark ? AppColors.darkPrimaryStrong : AppColors.primaryStrong,
            ),
          ),
          Positioned(
            right: 24,
            bottom: 27,
            child: _tile(
              success ? Icons.check_rounded : Icons.key_rounded,
              success ? (isDark ? AppColors.darkPrimary : AppColors.primary) : (isDark ? AppColors.darkSurface3 : AppColors.accentSoft),
              success ? (isDark ? AppColors.darkBackground : Colors.white) : (isDark ? AppColors.darkAccent : AppColors.accent),
              48,
            ),
          ),
          if (!success) Positioned(top: 20, right: 38, child: _spark(isDark ? AppColors.darkSecondary : AppColors.secondary)),
        ],
      );

  Widget _task(bool isDark) => Stack(
        alignment: Alignment.center,
        children: [
          _halo(isDark ? AppColors.darkPrimarySoft : AppColors.primarySoft, 128),
          _tile(Icons.checklist_rounded, isDark ? AppColors.darkSurface : Colors.white, isDark ? AppColors.darkPrimary : AppColors.primary, 92),
          Positioned(
            right: 30,
            bottom: 28,
            child: _tile(Icons.add_rounded, isDark ? AppColors.darkPrimary : AppColors.primary, isDark ? AppColors.darkBackground : Colors.white, 42),
          ),
          Positioned(top: 24, left: 34, child: _spark(isDark ? AppColors.darkAccent : AppColors.accent)),
        ],
      );

  Widget _focus(bool isDark) => Stack(
        alignment: Alignment.center,
        children: [
          _halo(isDark ? AppColors.darkPrimarySoft : AppColors.primarySoft, 144),
          Container(
            width: 126,
            height: 126,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border, width: 7),
            ),
            child: Icon(Icons.spa_rounded, size: 62, color: isDark ? AppColors.darkPrimary : AppColors.primary),
          ),
          Positioned(top: 15, right: 33, child: _spark(isDark ? AppColors.darkAccent : AppColors.accent)),
        ],
      );

  Widget _halo(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.65)),
      );

  Widget _tile(IconData icon, Color background, Color foreground, double size) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Icon(icon, color: foreground, size: size * 0.58),
      );

  Widget _spark(Color color) => Icon(Icons.auto_awesome_rounded, color: color, size: 23);
}

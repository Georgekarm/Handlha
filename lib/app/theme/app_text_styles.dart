import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// نظام الخطوط لتطبيق «هندلها» بهوية Calm Intelligent Productivity.
/// الخط الأساسي: IBM Plex Sans Arabic — وضوح عالي، مظهر حديث ومهني.
///
/// Scale:
///   Display  32 / 700
///   Headline 26 / 700
///   Title    20 / 700
///   Subtitle 16 / 600
///   Body     14–16 / 400
///   Label    13 / 600
///   Caption  12 / 400
class AppTextStyles {
  AppTextStyles._();

  /// Helper to create IBM Plex Sans Arabic style
  static TextStyle _font({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color color = AppColors.textPrimary,
    double height = 1.45,
  }) {
    try {
      return GoogleFonts.ibmPlexSansArabic(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    } catch (_) {
      return TextStyle(
        fontFamily: 'Tahoma',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    }
  }

  // ===========================================================================
  // Light Text Theme
  // ===========================================================================
  static TextTheme get textTheme {
    return TextTheme(
      // Display: 32 / 700
      displayLarge: _font(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      // Headline Large: 26 / 700
      headlineLarge: _font(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      // Headline Medium (Title): 20 / 700
      headlineMedium: _font(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
      // Title Large: 20 / 700
      titleLarge: _font(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
      // Title Medium (Subtitle): 16 / 600
      titleMedium: _font(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.45,
      ),
      // Title Small: 14 / 600
      titleSmall: _font(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.45,
      ),
      // Body Large: 16 / 400
      bodyLarge: _font(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
        height: 1.55,
      ),
      // Body Medium: 14 / 400
      bodyMedium: _font(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondary,
        height: 1.55,
      ),
      // Body Small (Caption): 12 / 400
      bodySmall: _font(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppColors.textMuted,
        height: 1.5,
      ),
      // Label Large: 14 / 600
      labelLarge: _font(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textOnPrimary,
        height: 1.3,
      ),
      // Label Medium: 13 / 600
      labelMedium: _font(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        height: 1.3,
      ),
      // Label Small: 12 / 500
      labelSmall: _font(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
        height: 1.25,
      ),
    );
  }

  // ===========================================================================
  // Dark Text Theme — مستقل مع ألوان Dark المناسبة
  // ===========================================================================
  static TextTheme get darkTextTheme {
    return TextTheme(
      displayLarge: _font(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.darkTextPrimary,
        height: 1.3,
      ),
      headlineLarge: _font(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.darkTextPrimary,
        height: 1.3,
      ),
      headlineMedium: _font(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.darkTextPrimary,
        height: 1.4,
      ),
      titleLarge: _font(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.darkTextPrimary,
        height: 1.4,
      ),
      titleMedium: _font(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
        height: 1.45,
      ),
      titleSmall: _font(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
        height: 1.45,
      ),
      bodyLarge: _font(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.darkTextPrimary,
        height: 1.55,
      ),
      bodyMedium: _font(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.darkTextSecondary,
        height: 1.55,
      ),
      bodySmall: _font(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppColors.darkTextMuted,
        height: 1.5,
      ),
      labelLarge: _font(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.darkBackground,
        height: 1.3,
      ),
      labelMedium: _font(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextSecondary,
        height: 1.3,
      ),
      labelSmall: _font(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.darkTextMuted,
        height: 1.25,
      ),
    );
  }
}

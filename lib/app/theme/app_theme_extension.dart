import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ThemeExtension لتوفير الألوان الدلالية (Semantic Colors) المخصصة
/// في تطبيقي Light و Dark من خلال `context.appColors`.
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  // --- Backgrounds & Surfaces ---
  final Color background;
  final Color surface;
  final Color surfaceSoft;
  final Color surfaceMuted;

  // --- Primary ---
  final Color primary;
  final Color primaryStrong;
  final Color primarySoft;
  final Color heroTeal;
  final Color textOnPrimary;

  // --- Secondary / Lavender ---
  final Color secondary;
  final Color secondarySoft;
  final Color lavenderSoft;
  final Color lavenderAccent;

  // --- Accent ---
  final Color accent;
  final Color accentSoft;

  // --- Ambient Glows ---
  final Color glowTopRight;
  final Color glowBottomLeft;

  // --- Text ---
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // --- Semantic Status ---
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  // --- Borders & Dividers ---
  final Color border;
  final Color divider;

  const AppThemeExtension({
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.surfaceMuted,
    required this.primary,
    required this.primaryStrong,
    required this.primarySoft,
    required this.secondary,
    required this.secondarySoft,
    required this.accent,
    required this.accentSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.border,
    required this.divider,
    this.heroTeal = AppColors.heroTeal,
    this.textOnPrimary = AppColors.textOnPrimary,
    this.lavenderSoft = AppColors.lavenderSoft,
    this.lavenderAccent = AppColors.lavenderAccent,
    this.glowTopRight = AppColors.glowTopRightLight,
    this.glowBottomLeft = AppColors.glowBottomLeftLight,
  });

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSoft,
    Color? surfaceMuted,
    Color? primary,
    Color? primaryStrong,
    Color? primarySoft,
    Color? heroTeal,
    Color? textOnPrimary,
    Color? secondary,
    Color? secondarySoft,
    Color? lavenderSoft,
    Color? lavenderAccent,
    Color? accent,
    Color? accentSoft,
    Color? glowTopRight,
    Color? glowBottomLeft,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? border,
    Color? divider,
  }) {
    return AppThemeExtension(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      primary: primary ?? this.primary,
      primaryStrong: primaryStrong ?? this.primaryStrong,
      primarySoft: primarySoft ?? this.primarySoft,
      heroTeal: heroTeal ?? this.heroTeal,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      secondary: secondary ?? this.secondary,
      secondarySoft: secondarySoft ?? this.secondarySoft,
      lavenderSoft: lavenderSoft ?? this.lavenderSoft,
      lavenderAccent: lavenderAccent ?? this.lavenderAccent,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      glowTopRight: glowTopRight ?? this.glowTopRight,
      glowBottomLeft: glowBottomLeft ?? this.glowBottomLeft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      border: border ?? this.border,
      divider: divider ?? this.divider,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
      covariant ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) {
      return this;
    }
    return AppThemeExtension(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryStrong: Color.lerp(primaryStrong, other.primaryStrong, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      heroTeal: Color.lerp(heroTeal, other.heroTeal, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondarySoft: Color.lerp(secondarySoft, other.secondarySoft, t)!,
      lavenderSoft: Color.lerp(lavenderSoft, other.lavenderSoft, t)!,
      lavenderAccent: Color.lerp(lavenderAccent, other.lavenderAccent, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      glowTopRight: Color.lerp(glowTopRight, other.glowTopRight, t)!,
      glowBottomLeft: Color.lerp(glowBottomLeft, other.glowBottomLeft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

extension AppThemeExtensionX on BuildContext {
  AppThemeExtension get appColors =>
      Theme.of(this).extension<AppThemeExtension>() ??
      const AppThemeExtension(
        background: AppColors.background,
        surface: AppColors.surface,
        surfaceSoft: AppColors.surfaceSoft,
        surfaceMuted: AppColors.surfaceMuted,
        primary: AppColors.primary,
        primaryStrong: AppColors.primaryStrong,
        primarySoft: AppColors.primarySoft,
        secondary: AppColors.secondary,
        secondarySoft: AppColors.secondarySoft,
        accent: AppColors.accent,
        accentSoft: AppColors.accentSoft,
        textPrimary: AppColors.textPrimary,
        textSecondary: AppColors.textSecondary,
        textMuted: AppColors.textMuted,
        success: AppColors.success,
        warning: AppColors.warning,
        danger: AppColors.danger,
        info: AppColors.info,
        border: AppColors.border,
        divider: AppColors.divider,
      );

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get heroBannerBackground =>
      isDark ? const Color(0xFF13382F) : const Color(0xFF143F35);

  Color get heroBannerBorder =>
      isDark ? const Color(0xFF204F43) : Colors.transparent;

  Color get heroPillBackground => const Color(0xFF1E5447);

  Color get limeAccent => const Color(0xFFC8F383);

  Color get limeAccentInk => const Color(0xFF0C211C);

  Color get ctaBackground =>
      isDark ? const Color(0xFFC8F383) : const Color(0xFF185447);

  Color get ctaForeground =>
      isDark ? const Color(0xFF0C211C) : Colors.white;

  Color get activeFieldBorder =>
      isDark ? const Color(0xFF8CD557) : appColors.primary;

  Color get softControlSurface =>
      isDark ? const Color(0xFF1A342D) : const Color(0xFFE7EFEC);

  Color get segmentedTrackBackground =>
      isDark ? const Color(0xFF112923) : const Color(0xFFE4ECE8);

  Color get segmentedActiveBackground =>
      isDark ? const Color(0xFF183830) : appColors.surface;
}

import 'package:flutter/material.dart';

/// نظام الألوان الرسمي لتطبيق «هندلها» — مطابق لمرجع التصميم (Light + Dark).
class AppColors {
  AppColors._();

  // ===========================================================================
  // Light Theme
  // ===========================================================================

  static const Color background = Color(0xFFEFF4F1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFEBF2EE);
  static const Color surfaceMuted = Color(0xFFE0EAE5);

  static const Color primary = Color(0xFF007067);
  static const Color primaryStrong = Color(0xFF00645C);
  static const Color primarySoft = Color(0xFFD3ECE8);

  static const Color secondary = Color(0xFF6F6B94);
  static const Color secondarySoft = Color(0xFFEBEBF3);

  static const Color accent = Color(0xFFC9735B);
  static const Color accentSoft = Color(0xFFF6E6E0);

  static const Color textPrimary = Color(0xFF172724);
  static const Color textSecondary = Color(0xFF5D6E6A);
  static const Color textMuted = Color(0xFF8C9B97);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF288E7E);
  static const Color warning = Color(0xFFC89B54);
  static const Color danger = Color(0xFFC9735B);
  static const Color info = Color(0xFF5683A5);

  static const Color successSoft = Color(0xFFD6EFE9);
  static const Color warningSoft = Color(0xFFF5EBCF);
  static const Color dangerSoft = Color(0xFFF6E3DE);
  static const Color infoSoft = Color(0xFFE2EDF4);

  static const Color border = Color(0xFFE2EBE6);
  static const Color divider = Color(0xFFEAF0ED);

  // Ambient Light Glows & Hero
  static const Color glowTopRightLight = Color(0xFFC2E8DF);
  static const Color glowBottomLeftLight = Color(0xFFE8E6F0);
  static const Color heroTeal = Color(0xFF007067);
  static const Color lavenderSoft = secondarySoft;
  static const Color lavenderAccent = secondary;

  // ===========================================================================
  // Dark Theme
  // ===========================================================================

  static const Color darkBackground = Color(0xFF0C211C);
  static const Color darkSurface = Color(0xFF12231F);
  static const Color darkSurface2 = Color(0xFF172D28);
  static const Color darkSurface3 = Color(0xFF1E3932);

  static const Color darkPrimary = Color(0xFF51C7B5);
  static const Color darkPrimaryStrong = Color(0xFF6CD6C6);
  static const Color darkPrimarySoft = Color(0xFF193A34);

  static const Color darkSecondary = Color(0xFF9E9BC9);
  static const Color darkSecondarySoft = Color(0xFF26263D);

  static const Color darkAccent = Color(0xFFE2856E);
  static const Color darkAccentSoft = Color(0xFF3E2622);

  static const Color darkTextPrimary = Color(0xFFF2F7F5);
  static const Color darkTextSecondary = Color(0xFF93A6A0);
  static const Color darkTextMuted = Color(0xFF60756F);
  static const Color darkTextOnPrimary = Color(0xFF082420);

  static const Color darkSuccess = Color(0xFF51C7B5);
  static const Color darkWarning = Color(0xFFE5B869);
  static const Color darkDanger = Color(0xFFE2856E);
  static const Color darkInfo = Color(0xFF8CB4D1);

  static const Color darkBorder = Color(0xFF1F3530);
  static const Color darkDivider = Color(0xFF1A2F2A);

  // Ambient Dark Glows & Hero
  static const Color glowTopRightDark = Color(0xFF04463C);
  static const Color glowBottomLeftDark = Color(0xFF212137);
  static const Color heroDarkTeal = Color(0xFF005750);
  static const Color darkLavenderSoft = darkSecondarySoft;
  static const Color darkLavenderAccent = darkSecondary;

  static const Color assistantPurple = Color(0xFF433E60);
  static const Color assistantPurpleSoft = Color(0xFF2D2A40);
  static const Color salmonBadge = accent;

  // ===========================================================================
  // Project Palette (matching New Project screen swatches)
  // ===========================================================================
  static const Color projectTeal = primary;
  static const Color projectIris = secondary;
  static const Color projectTerracotta = accent;
  static const Color projectSky = info;

  // ===========================================================================
  // Aliases (for backward compatibility)
  // ===========================================================================
  static const Color primaryDark = primaryStrong;
  static const Color surfaceSecondary = surfaceSoft;
  static const Color surfaceTertiary = surfaceMuted;
  static const Color navy = primaryStrong;
  static const Color coral = accent;
  static const Color mint = successSoft;
  static const Color yellow = warningSoft;
  static const Color blueSoft = infoSoft;
  static const Color peach = accentSoft;
  static const Color error = danger;
  static const Color accentWarm = accent;
  static const Color accentWarmSoft = accentSoft;
  static const Color focus = secondary;
  static const Color focusSoft = secondarySoft;
  static const Color projectSage = primary;
  static const Color projectDustyBlue = info;
  static const Color projectSoftSand = warning;
  static const Color projectLavender = secondary;
  static const Color darkSurfaceAlt = darkSurface2;
}

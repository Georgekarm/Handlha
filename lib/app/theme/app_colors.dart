import 'package:flutter/material.dart';

/// نظام الألوان الجديد لتطبيق «هندلها»
/// هوية: Calm Intelligent Productivity
class AppColors {
  AppColors._();

  // ===========================================================================
  // Light Theme
  // ===========================================================================

  static const Color background = Color(0xFFF7F8F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFEEF3F0);
  static const Color surfaceMuted = Color(0xFFE4ECE8);

  static const Color primary = Color(0xFF2F6F68);
  static const Color primaryStrong = Color(0xFF245650);
  static const Color primarySoft = Color(0xFFD9ECE8);

  static const Color secondary = Color(0xFF7773A1);
  static const Color secondarySoft = Color(0xFFE9E8F2);

  static const Color accent = Color(0xFFC9826C);
  static const Color accentSoft = Color(0xFFF3E1DB);

  static const Color textPrimary = Color(0xFF1E2D2B);
  static const Color textSecondary = Color(0xFF647370);
  static const Color textMuted = Color(0xFF99A6A2);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF4E9B77);
  static const Color warning = Color(0xFFB7863C);
  static const Color danger = Color(0xFFB96368);
  static const Color info = Color(0xFF5683A5);

  // Added missing soft variants for semantic colors used in theme
  static const Color successSoft = Color(0xFFDDF0E5);
  static const Color warningSoft = Color(0xFFF5EBCF);
  static const Color dangerSoft = Color(0xFFF4DFE0);
  static const Color infoSoft = Color(0xFFE2EDF4);

  static const Color border = Color(0xFFDDE7E2);
  static const Color divider = Color(0xFFEAF0ED);

  // ===========================================================================
  // Dark Theme
  // ===========================================================================

  static const Color darkBackground = Color(0xFF0E1715);
  static const Color darkSurface = Color(0xFF162320);
  static const Color darkSurface2 = Color(0xFF1C2C28);
  static const Color darkSurface3 = Color(0xFF243833);

  static const Color darkPrimary = Color(0xFF72C5B5);
  static const Color darkPrimaryStrong = Color(0xFF90D6C8);
  static const Color darkPrimarySoft = Color(0xFF20423C);

  static const Color darkSecondary = Color(0xFFA9A7CD);
  static const Color darkSecondarySoft = Color(0xFF3D3B5C);

  static const Color darkAccent = Color(0xFFE17B71);
  static const Color darkAccentSoft = Color(0xFF4A2B28);

  static const Color darkTextPrimary = Color(0xFFEFF6F2);
  static const Color darkTextSecondary = Color(0xFF8D9E98);
  static const Color darkTextMuted = Color(0xFF5E736C);

  static const Color darkSuccess = Color(0xFF7CCAA2);
  static const Color darkWarning = Color(0xFFE5B869);
  static const Color darkDanger = Color(0xFFE17B71);
  static const Color darkInfo = Color(0xFF8CB4D1);

  static const Color darkBorder = Color(0xFF233631);
  static const Color darkDivider = Color(0xFF1D2E2A);

  static const Color assistantPurple = Color(0xFF433E60);
  static const Color assistantPurpleSoft = Color(0xFF2D2A40);
  static const Color salmonBadge = Color(0xFFE17B71);

  // ===========================================================================
  // Project Palette
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

package com.handelha.app.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

object AppColors {
    // Light Theme
    val Background = Color(0xFFEFF4F1)
    val Surface = Color(0xFFFFFFFF)
    val SurfaceSoft = Color(0xFFEBF2EE)
    val SurfaceMuted = Color(0xFFE0EAE5)

    val Primary = Color(0xFF007067)
    val PrimaryStrong = Color(0xFF00645C)
    val PrimarySoft = Color(0xFFD3ECE8)

    val Secondary = Color(0xFF6F6B94)
    val SecondarySoft = Color(0xFFEBEBF3)

    val Accent = Color(0xFFC9735B)
    val AccentSoft = Color(0xFFF6E6E0)

    val TextPrimary = Color(0xFF172724)
    val TextSecondary = Color(0xFF5D6E6A)
    val TextMuted = Color(0xFF8C9B97)
    val TextOnPrimary = Color(0xFFFFFFFF)

    val Success = Color(0xFF288E7E)
    val Warning = Color(0xFFC89B54)
    val Danger = Color(0xFFC9735B)
    val Info = Color(0xFF5683A5)

    val SuccessSoft = Color(0xFFD6EFE9)
    val WarningSoft = Color(0xFFF5EBCF)
    val DangerSoft = Color(0xFFF6E3DE)
    val InfoSoft = Color(0xFFE2EDF4)

    val Border = Color(0xFFE2EBE6)
    val Divider = Color(0xFFEAF0ED)

    val GlowTopRightLight = Color(0xFFC2E8DF)
    val GlowBottomLeftLight = Color(0xFFE8E6F0)
    val HeroTeal = Color(0xFF007067)
    val HeroBannerLight = Color(0xFF143F35)
    val HeroTealBright = Color(0xFF007067)
    val LimeAccent = Color(0xFFC8F383)
    val LimeAccentInk = Color(0xFF0C211C)

    // Dark Theme
    val DarkBackground = Color(0xFF0C211C)
    val DarkSurface = Color(0xFF12231F)
    val DarkSurface2 = Color(0xFF172D28)
    val DarkSurface3 = Color(0xFF1E3932)

    val DarkPrimary = Color(0xFF51C7B5)
    val DarkPrimaryStrong = Color(0xFF6CD6C6)
    val DarkPrimarySoft = Color(0xFF193A34)

    val DarkSecondary = Color(0xFF9E9BC9)
    val DarkSecondarySoft = Color(0xFF26263D)

    val DarkAccent = Color(0xFFE2856E)
    val DarkAccentSoft = Color(0xFF3E2622)

    val DarkTextPrimary = Color(0xFFF2F7F5)
    val DarkTextSecondary = Color(0xFF93A6A0)
    val DarkTextMuted = Color(0xFF60756F)
    val DarkTextOnPrimary = Color(0xFF082420)

    val DarkSuccess = Color(0xFF51C7B5)
    val DarkWarning = Color(0xFFE5B869)
    val DarkDanger = Color(0xFFE2856E)
    val DarkInfo = Color(0xFF8CB4D1)

    val DarkSuccessSoft = Color(0xFF17362F)
    val DarkWarningSoft = Color(0xFF352C1B)
    val DarkDangerSoft = Color(0xFF3E2622)
    val DarkInfoSoft = Color(0xFF1B2E3B)

    val DarkBorder = Color(0xFF1F3530)
    val DarkDivider = Color(0xFF1A2F2A)

    val GlowTopRightDark = Color(0xFF04463C)
    val GlowBottomLeftDark = Color(0xFF212137)
    val HeroDarkTeal = Color(0xFF005750)
    val HeroBannerDark = Color(0xFF13382F)

    // Student Mode Accents
    val StudentIndigo = Color(0xFF4F46E5)
    val StudentTeal = Color(0xFF0D9488)
    val StudentIndigoSoft = Color(0xFFEDE9FE)
    val DarkStudentIndigoSoft = Color(0xFF26234D)

    // Project Palette
    val ProjectTeal = Primary
    val ProjectIris = Secondary
    val ProjectTerracotta = Accent
    val ProjectSky = Info
}

@Immutable
data class HandelhaExtendedColors(
    val isDark: Boolean,
    val background: Color,
    val surface: Color,
    val surfaceSoft: Color,
    val surfaceMuted: Color,
    val primary: Color,
    val primaryStrong: Color,
    val primarySoft: Color,
    val secondary: Color,
    val secondarySoft: Color,
    val lavenderSoft: Color,
    val lavenderAccent: Color,
    val accent: Color,
    val accentSoft: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textMuted: Color,
    val textOnPrimary: Color,
    val success: Color,
    val warning: Color,
    val danger: Color,
    val info: Color,
    val successSoft: Color,
    val warningSoft: Color,
    val dangerSoft: Color,
    val infoSoft: Color,
    val border: Color,
    val divider: Color,
    val glowTopRight: Color,
    val glowBottomLeft: Color,
    val heroTeal: Color,
    val heroCardBg: Color,
    val heroBannerBorder: Color,
    val heroPillBackground: Color,
    val limeAccent: Color,
    val limeAccentInk: Color,
    val ctaBackground: Color,
    val ctaForeground: Color,
    val activeFieldBorder: Color,
    val softControlSurface: Color,
    val segmentedTrackBackground: Color,
    val segmentedActiveBackground: Color,
    val studentIndigo: Color,
    val studentTeal: Color,
    val studentIndigoSoft: Color,
)

val LightExtendedColors = HandelhaExtendedColors(
    isDark = false,
    background = AppColors.Background,
    surface = AppColors.Surface,
    surfaceSoft = AppColors.SurfaceSoft,
    surfaceMuted = AppColors.SurfaceMuted,
    primary = AppColors.Primary,
    primaryStrong = AppColors.PrimaryStrong,
    primarySoft = AppColors.PrimarySoft,
    secondary = AppColors.Secondary,
    secondarySoft = AppColors.SecondarySoft,
    lavenderSoft = AppColors.SecondarySoft,
    lavenderAccent = AppColors.Secondary,
    accent = AppColors.Accent,
    accentSoft = AppColors.AccentSoft,
    textPrimary = AppColors.TextPrimary,
    textSecondary = AppColors.TextSecondary,
    textMuted = AppColors.TextMuted,
    textOnPrimary = AppColors.TextOnPrimary,
    success = AppColors.Success,
    warning = AppColors.Warning,
    danger = AppColors.Danger,
    info = AppColors.Info,
    successSoft = AppColors.SuccessSoft,
    warningSoft = AppColors.WarningSoft,
    dangerSoft = AppColors.DangerSoft,
    infoSoft = AppColors.InfoSoft,
    border = AppColors.Border,
    divider = AppColors.Divider,
    glowTopRight = AppColors.GlowTopRightLight,
    glowBottomLeft = AppColors.GlowBottomLeftLight,
    heroTeal = AppColors.HeroTeal,
    heroCardBg = AppColors.HeroBannerLight,
    heroBannerBorder = Color.Transparent,
    heroPillBackground = Color(0xFF1E5447),
    limeAccent = AppColors.LimeAccent,
    limeAccentInk = AppColors.LimeAccentInk,
    ctaBackground = Color(0xFF185447),
    ctaForeground = Color.White,
    activeFieldBorder = AppColors.Primary,
    softControlSurface = Color(0xFFE7EFEC),
    segmentedTrackBackground = Color(0xFFE4ECE8),
    segmentedActiveBackground = AppColors.Surface,
    studentIndigo = AppColors.StudentIndigo,
    studentTeal = AppColors.StudentTeal,
    studentIndigoSoft = AppColors.StudentIndigoSoft,
)

val DarkExtendedColors = HandelhaExtendedColors(
    isDark = true,
    background = AppColors.DarkBackground,
    surface = AppColors.DarkSurface,
    surfaceSoft = AppColors.DarkSurface2,
    surfaceMuted = AppColors.DarkSurface3,
    primary = AppColors.DarkPrimary,
    primaryStrong = AppColors.DarkPrimaryStrong,
    primarySoft = AppColors.DarkPrimarySoft,
    secondary = AppColors.DarkSecondary,
    secondarySoft = AppColors.DarkSecondarySoft,
    lavenderSoft = AppColors.DarkSecondarySoft,
    lavenderAccent = AppColors.DarkSecondary,
    accent = AppColors.DarkAccent,
    accentSoft = AppColors.DarkAccentSoft,
    textPrimary = AppColors.DarkTextPrimary,
    textSecondary = AppColors.DarkTextSecondary,
    textMuted = AppColors.DarkTextMuted,
    textOnPrimary = AppColors.DarkTextOnPrimary,
    success = AppColors.DarkSuccess,
    warning = AppColors.DarkWarning,
    danger = AppColors.DarkDanger,
    info = AppColors.DarkInfo,
    successSoft = AppColors.DarkSuccessSoft,
    warningSoft = AppColors.DarkWarningSoft,
    dangerSoft = AppColors.DarkDangerSoft,
    infoSoft = AppColors.DarkInfoSoft,
    border = AppColors.DarkBorder,
    divider = AppColors.DarkDivider,
    glowTopRight = AppColors.GlowTopRightDark,
    glowBottomLeft = AppColors.GlowBottomLeftDark,
    heroTeal = AppColors.HeroDarkTeal,
    heroCardBg = AppColors.HeroBannerDark,
    heroBannerBorder = Color(0xFF204F43),
    heroPillBackground = Color(0xFF1E5447),
    limeAccent = AppColors.LimeAccent,
    limeAccentInk = AppColors.LimeAccentInk,
    ctaBackground = AppColors.LimeAccent,
    ctaForeground = AppColors.LimeAccentInk,
    activeFieldBorder = Color(0xFF8CD557),
    softControlSurface = Color(0xFF1A342D),
    segmentedTrackBackground = Color(0xFF112923),
    segmentedActiveBackground = Color(0xFF183830),
    studentIndigo = AppColors.StudentIndigo,
    studentTeal = AppColors.StudentTeal,
    studentIndigoSoft = AppColors.DarkStudentIndigoSoft,
)

val LocalHandelhaColors = staticCompositionLocalOf { LightExtendedColors }

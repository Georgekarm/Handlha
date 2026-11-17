package com.handelha.app.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.handelha.app.R

val IbmPlexSansArabic = FontFamily(
    Font(R.font.ibm_plex_sans_arabic_light, FontWeight.Thin),
    Font(R.font.ibm_plex_sans_arabic_light, FontWeight.ExtraLight),
    Font(R.font.ibm_plex_sans_arabic_light, FontWeight.Light),
    Font(R.font.ibm_plex_sans_arabic_regular, FontWeight.Normal),
    Font(R.font.ibm_plex_sans_arabic_medium, FontWeight.Medium),
    Font(R.font.ibm_plex_sans_arabic_semibold, FontWeight.SemiBold),
    Font(R.font.ibm_plex_sans_arabic_bold, FontWeight.Bold),
    Font(R.font.ibm_plex_sans_arabic_bold, FontWeight.ExtraBold),
    Font(R.font.ibm_plex_sans_arabic_bold, FontWeight.Black),
)

private val NoPaddingPlatformStyle = PlatformTextStyle(includeFontPadding = false)

val HandelhaDefaultTextStyle = TextStyle(
    fontFamily = IbmPlexSansArabic,
    fontWeight = FontWeight.Normal,
    fontSize = 14.sp,
    lineHeight = 22.sp,
    platformStyle = NoPaddingPlatformStyle,
)

private fun handelhaStyle(
    fontSize: Int,
    lineHeight: Int,
    fontWeight: FontWeight,
) = TextStyle(
    fontFamily = IbmPlexSansArabic,
    fontWeight = fontWeight,
    fontSize = fontSize.sp,
    lineHeight = lineHeight.sp,
    platformStyle = NoPaddingPlatformStyle,
)

val HandelhaTypography = Typography(
    displayLarge = handelhaStyle(fontSize = 32, lineHeight = 42, fontWeight = FontWeight.Bold),
    displayMedium = handelhaStyle(fontSize = 28, lineHeight = 36, fontWeight = FontWeight.Bold),
    displaySmall = handelhaStyle(fontSize = 24, lineHeight = 32, fontWeight = FontWeight.Bold),
    headlineLarge = handelhaStyle(fontSize = 26, lineHeight = 34, fontWeight = FontWeight.Bold),
    headlineMedium = handelhaStyle(fontSize = 20, lineHeight = 28, fontWeight = FontWeight.Bold),
    headlineSmall = handelhaStyle(fontSize = 18, lineHeight = 26, fontWeight = FontWeight.Bold),
    titleLarge = handelhaStyle(fontSize = 20, lineHeight = 28, fontWeight = FontWeight.Bold),
    titleMedium = handelhaStyle(fontSize = 16, lineHeight = 23, fontWeight = FontWeight.SemiBold),
    titleSmall = handelhaStyle(fontSize = 14, lineHeight = 20, fontWeight = FontWeight.SemiBold),
    bodyLarge = handelhaStyle(fontSize = 16, lineHeight = 25, fontWeight = FontWeight.Normal),
    bodyMedium = handelhaStyle(fontSize = 14, lineHeight = 22, fontWeight = FontWeight.Normal),
    bodySmall = handelhaStyle(fontSize = 12, lineHeight = 18, fontWeight = FontWeight.Normal),
    labelLarge = handelhaStyle(fontSize = 14, lineHeight = 18, fontWeight = FontWeight.SemiBold),
    labelMedium = handelhaStyle(fontSize = 13, lineHeight = 17, fontWeight = FontWeight.SemiBold),
    labelSmall = handelhaStyle(fontSize = 12, lineHeight = 15, fontWeight = FontWeight.Medium),
)

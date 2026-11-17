package com.handelha.app.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ProvideTextStyle
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat

private val LightColorScheme = lightColorScheme(
    primary = AppColors.Primary,
    onPrimary = AppColors.TextOnPrimary,
    primaryContainer = AppColors.PrimarySoft,
    onPrimaryContainer = AppColors.PrimaryStrong,
    secondary = AppColors.Secondary,
    onSecondary = AppColors.TextOnPrimary,
    secondaryContainer = AppColors.SecondarySoft,
    onSecondaryContainer = AppColors.Secondary,
    tertiary = AppColors.Accent,
    onTertiary = AppColors.TextOnPrimary,
    tertiaryContainer = AppColors.AccentSoft,
    onTertiaryContainer = AppColors.Accent,
    background = AppColors.Background,
    onBackground = AppColors.TextPrimary,
    surface = AppColors.Surface,
    onSurface = AppColors.TextPrimary,
    surfaceVariant = AppColors.SurfaceSoft,
    onSurfaceVariant = AppColors.TextSecondary,
    outline = AppColors.Border,
    outlineVariant = AppColors.Divider,
    error = AppColors.Danger,
    onError = AppColors.TextOnPrimary,
    errorContainer = AppColors.DangerSoft,
    onErrorContainer = AppColors.Danger,
)

private val DarkColorScheme = darkColorScheme(
    primary = AppColors.DarkPrimary,
    onPrimary = AppColors.DarkTextOnPrimary,
    primaryContainer = AppColors.DarkPrimarySoft,
    onPrimaryContainer = AppColors.DarkPrimaryStrong,
    secondary = AppColors.DarkSecondary,
    onSecondary = AppColors.DarkTextOnPrimary,
    secondaryContainer = AppColors.DarkSecondarySoft,
    onSecondaryContainer = AppColors.DarkSecondary,
    tertiary = AppColors.DarkAccent,
    onTertiary = AppColors.DarkTextOnPrimary,
    tertiaryContainer = AppColors.DarkAccentSoft,
    onTertiaryContainer = AppColors.DarkAccent,
    background = AppColors.DarkBackground,
    onBackground = AppColors.DarkTextPrimary,
    surface = AppColors.DarkSurface,
    onSurface = AppColors.DarkTextPrimary,
    surfaceVariant = AppColors.DarkSurface2,
    onSurfaceVariant = AppColors.DarkTextSecondary,
    outline = AppColors.DarkBorder,
    outlineVariant = AppColors.DarkDivider,
    error = AppColors.DarkDanger,
    onError = AppColors.DarkTextOnPrimary,
    errorContainer = AppColors.DarkAccentSoft,
    onErrorContainer = AppColors.DarkDanger,
)

val HandelhaShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(18.dp),
    large = RoundedCornerShape(24.dp),
    extraLarge = RoundedCornerShape(28.dp),
)

enum class AppThemeMode(val storedValue: String) {
    SYSTEM("system"),
    LIGHT("light"),
    DARK("dark");

    companion object {
        fun fromString(raw: String?): AppThemeMode =
            entries.firstOrNull { it.storedValue == raw } ?: SYSTEM
    }
}

object HandelhaTheme {
    val colors: HandelhaExtendedColors
        @Composable
        @ReadOnlyComposable
        get() = LocalHandelhaColors.current
}

@Composable
fun HandelhaTheme(
    themeMode: AppThemeMode = AppThemeMode.SYSTEM,
    content: @Composable () -> Unit,
) {
    val useDark = when (themeMode) {
        AppThemeMode.SYSTEM -> isSystemInDarkTheme()
        AppThemeMode.LIGHT -> false
        AppThemeMode.DARK -> true
    }
    val extendedColors = if (useDark) DarkExtendedColors else LightExtendedColors
    val m3Scheme = if (useDark) DarkColorScheme else LightColorScheme

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as? Activity)?.window ?: return@SideEffect
            val insetsController = WindowCompat.getInsetsController(window, view)
            insetsController.isAppearanceLightStatusBars = !useDark
            insetsController.isAppearanceLightNavigationBars = !useDark
        }
    }

    CompositionLocalProvider(LocalHandelhaColors provides extendedColors) {
        MaterialTheme(
            colorScheme = m3Scheme,
            typography = HandelhaTypography,
            shapes = HandelhaShapes,
        ) {
            ProvideTextStyle(value = HandelhaDefaultTextStyle, content = content)
        }
    }
}


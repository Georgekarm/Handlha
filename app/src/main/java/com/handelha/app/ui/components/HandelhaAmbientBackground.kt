package com.handelha.app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.handelha.app.ui.theme.HandelhaTheme

@Composable
fun HandelhaAmbientBackground(
    modifier: Modifier = Modifier,
    showDecorations: Boolean = true,
    content: @Composable BoxScope.() -> Unit,
) {
    val c = HandelhaTheme.colors
    val isDark = c.isDark

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(c.background),
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            // Top-right soft teal radial glow (420dp circle centered at right+100, top+100)
            val topGlowRadius = 210.dp.toPx()
            val topCenter = Offset(size.width - 100.dp.toPx(), 100.dp.toPx())
            drawCircle(
                brush = Brush.radialGradient(
                    colorStops = arrayOf(
                        0.0f to c.glowTopRight.copy(alpha = if (isDark) 0.85f else 0.90f),
                        0.72f to c.glowTopRight.copy(alpha = 0f),
                        1.0f to Color.Transparent,
                    ),
                    center = topCenter,
                    radius = topGlowRadius,
                ),
                center = topCenter,
                radius = topGlowRadius,
            )

            // Bottom-left soft lavender radial glow (440dp circle)
            val bottomGlowRadius = 220.dp.toPx()
            val bottomCenter = Offset(100.dp.toPx(), size.height - 90.dp.toPx())
            drawCircle(
                brush = Brush.radialGradient(
                    colorStops = arrayOf(
                        0.0f to c.glowBottomLeft.copy(alpha = if (isDark) 0.88f else 0.85f),
                        0.74f to c.glowBottomLeft.copy(alpha = 0f),
                        1.0f to Color.Transparent,
                    ),
                    center = bottomCenter,
                    radius = bottomGlowRadius,
                ),
                center = bottomCenter,
                radius = bottomGlowRadius,
            )

            if (showDecorations) {
                val baseInk = if (isDark) Color.White else c.primary
                val arcColor = baseInk.copy(alpha = if (isDark) 0.045f else 0.055f)
                val dotColor = baseInk.copy(alpha = if (isDark) 0.065f else 0.085f)

                val circleCenter = Offset((-18).dp.toPx(), 180.dp.toPx())
                val radii = listOf(96f, 148f, 200f, 252f)
                radii.forEach { r ->
                    drawCircle(
                        color = arcColor,
                        radius = r.dp.toPx(),
                        center = circleCenter,
                        style = Stroke(width = 1.2.dp.toPx()),
                    )
                }

                val startX = 24.dp.toPx()
                val startY = 72.dp.toPx()
                val step = 12.dp.toPx()
                val dotR = 1.25.dp.toPx()
                for (row in 0 until 5) {
                    for (col in 0 until 5) {
                        drawCircle(
                            color = dotColor,
                            radius = dotR,
                            center = Offset(startX + col * step, startY + row * step),
                        )
                    }
                }
            }
        }
        content()
    }
}

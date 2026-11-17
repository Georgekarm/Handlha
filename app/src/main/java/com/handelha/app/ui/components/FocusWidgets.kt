package com.handelha.app.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.VolumeOff
import androidx.compose.material.icons.rounded.Forest
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.NightsStay
import androidx.compose.material.icons.rounded.Park
import androidx.compose.material.icons.rounded.Water
import androidx.compose.material.icons.rounded.WaterDrop
import androidx.compose.material.icons.rounded.Waves
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handelha.app.core.audio.AmbientSoundscape
import com.handelha.app.domain.FocusSessionItem
import com.handelha.app.ui.theme.HandelhaTheme
import com.handelha.app.util.ArabicFormatters
import java.util.Calendar
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

data class FocusTreeProgress(
    val totalMinutes: Int,
    val todayMinutes: Int,
    val completedSessions: Int,
    val completedTrees: Int,
    val stageIndex: Int,
    val stageFraction: Float,
    val minutesToNextStage: Int,
) {
    fun stageTitle(isEn: Boolean): String = when (stageIndex) {
        0 -> if (isEn) "Quiet Seed" else "بذرة هادئة"
        1 -> if (isEn) "Tender Sprout" else "برعم أخضر"
        2 -> if (isEn) "Young Sapling" else "شجيرة نابتة"
        3 -> if (isEn) "Leafy Tree" else "شجرة مورقة"
        else -> if (isEn) "Blooming Tree" else "شجرة مزهرة"
    }

    fun stageMotivation(isEn: Boolean): String = when (stageIndex) {
        0 -> if (isEn) "Start your first minutes to awaken the soil." else "ابدأ أول دقائق تركيز عشان التربة تصحى وتنبت."
        1 -> if (isEn) "First green leaves appeared — keep the calm pace." else "أول ورقتين ظهروا — حافظ على الوتيرة الهادئة."
        2 -> if (isEn) "Your trunk is growing stronger session by session." else "جذع شجرتك بيقوى جلسة ورا جلسة."
        3 -> if (isEn) "Rich branches & shade — a calm mind at work." else "فروع وأوراق مليانة — دماغ رايقة بتنتج."
        else -> if (isEn) "Full bloom! Every 90m grows a new tree in your garden." else "إزهار كامل! كل ٩٠ دقيقة بتزرع شجرة جديدة في حديقتك."
    }

    companion object {
        fun compute(sessions: List<FocusSessionItem>): FocusTreeProgress {
            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val todayStart = cal.timeInMillis
            val totalMins = sessions.sumOf { it.elapsedMinutes.coerceAtLeast(0) }
            val todayMins = sessions.filter { it.endedAtMs >= todayStart }.sumOf { it.elapsedMinutes.coerceAtLeast(0) }
            val completedCount = sessions.count { it.completed }
            val trees = totalMins / 90
            val inCycle = if (totalMins == 0) 0 else (totalMins % 90).let { if (it == 0) 90 else it }
            val stageIdx = when {
                inCycle == 0 -> 0
                inCycle < 20 -> 1
                inCycle < 45 -> 2
                inCycle < 75 -> 3
                else -> 4
            }
            val nextThreshold = when (stageIdx) {
                0 -> 1
                1 -> 20
                2 -> 45
                3 -> 75
                else -> 90
            }
            return FocusTreeProgress(
                totalMinutes = totalMins,
                todayMinutes = todayMins,
                completedSessions = completedCount,
                completedTrees = trees,
                stageIndex = stageIdx,
                stageFraction = (inCycle / 90f).coerceIn(0f, 1f),
                minutesToNextStage = (nextThreshold - inCycle).coerceAtLeast(0),
            )
        }
    }
}

@Composable
fun MiniFocusTreeEmblem(
    stageIndex: Int,
    trunkColor: Color,
    foliageColor: Color,
    blossomColor: Color,
    modifier: Modifier = Modifier,
) {
    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height
        val cx = w / 2f

        drawLine(
            color = trunkColor.copy(alpha = 0.35f),
            start = Offset(w * 0.25f, h * 0.80f),
            end = Offset(w * 0.75f, h * 0.80f),
            strokeWidth = 2.dp.toPx(),
            cap = StrokeCap.Round,
        )

        val stemHeight = (0.18f + stageIndex * 0.08f).coerceIn(0.18f, 0.45f)
        val basePt = Offset(cx, h * 0.79f)
        val topPt = Offset(cx, h * (0.79f - stemHeight))
        drawLine(
            color = trunkColor,
            start = basePt,
            end = topPt,
            strokeWidth = if (stageIndex >= 2) 3.2.dp.toPx() else 2.2.dp.toPx(),
            cap = StrokeCap.Round,
        )

        if (stageIndex <= 1) {
            drawOval(
                color = foliageColor,
                topLeft = Offset(cx - 9.dp.toPx(), topPt.y - 2.dp.toPx()),
                size = Size(9.dp.toPx(), 5.5.dp.toPx()),
            )
            drawOval(
                color = foliageColor,
                topLeft = Offset(cx, topPt.y - 4.dp.toPx()),
                size = Size(9.dp.toPx(), 5.5.dp.toPx()),
            )
            return@Canvas
        }

        val sideLeafColor = foliageColor.copy(alpha = 0.86f)
        drawCircle(
            color = foliageColor,
            radius = if (stageIndex >= 3) 9.5.dp.toPx() else 7.5.dp.toPx(),
            center = Offset(cx, topPt.y - 4.dp.toPx()),
        )
        drawCircle(
            color = sideLeafColor,
            radius = 6.dp.toPx(),
            center = Offset(cx - 6.5.dp.toPx(), topPt.y + 2.dp.toPx()),
        )
        drawCircle(
            color = sideLeafColor,
            radius = 6.dp.toPx(),
            center = Offset(cx + 6.5.dp.toPx(), topPt.y + 2.dp.toPx()),
        )
        if (stageIndex >= 4) {
            drawCircle(blossomColor, 2.1.dp.toPx(), Offset(cx - 3.5.dp.toPx(), topPt.y - 6.dp.toPx()))
            drawCircle(blossomColor, 2.1.dp.toPx(), Offset(cx + 4.5.dp.toPx(), topPt.y - 3.dp.toPx()))
            drawCircle(blossomColor, 1.9.dp.toPx(), Offset(cx, topPt.y + 1.dp.toPx()))
        }
    }
}

@Composable
fun AnimatedFocusTreeCanvas(
    progress: FocusTreeProgress,
    isRunning: Boolean,
    modifier: Modifier = Modifier,
) {
    val c = HandelhaTheme.colors
    val infinite = rememberInfiniteTransition(label = "focus_tree_anim")
    val swayPhase by infinite.animateFloat(
        initialValue = 0f,
        targetValue = (2f * PI).toFloat(),
        animationSpec = infiniteRepeatable(tween(4200, easing = LinearEasing), RepeatMode.Restart),
        label = "sway",
    )
    val pulse by infinite.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(2400, easing = LinearEasing), RepeatMode.Reverse),
        label = "pulse",
    )

    val stage = progress.stageIndex
    val isDark = c.isDark

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(210.dp)
            .clip(RoundedCornerShape(24.dp)),
    ) {
        val w = size.width
        val h = size.height

        // Sky gradient
        drawRect(
            brush = Brush.verticalGradient(
                colors = if (isDark) {
                    listOf(Color(0xFF0E2923), Color(0xFF153B31), Color(0xFF1C473B))
                } else {
                    listOf(Color(0xFFE1F3EE), Color(0xFFCDEBE3), Color(0xFFBDE2D7))
                },
            ),
        )

        // Glowing sun / moon halo
        val orbCenter = Offset(w * 0.80f, h * 0.24f)
        val orbColor = if (isDark) c.limeAccent else Color(0xFFFFD166)
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(orbColor.copy(alpha = 0.24f + pulse * 0.14f), Color.Transparent),
                center = orbCenter,
                radius = 48.dp.toPx(),
            ),
            center = orbCenter,
            radius = 48.dp.toPx(),
        )
        drawCircle(color = orbColor.copy(alpha = 0.90f), radius = 14.dp.toPx(), center = orbCenter)

        // Rolling distant hill
        val hillPath = Path().apply {
            moveTo(0f, h * 0.80f)
            quadraticTo(w * 0.35f, h * 0.68f, w * 0.68f, h * 0.77f)
            quadraticTo(w * 0.85f, h * 0.82f, w, h * 0.73f)
            lineTo(w, h)
            lineTo(0f, h)
            close()
        }
        drawPath(
            path = hillPath,
            color = if (isDark) Color(0xFF184539) else Color(0xFF9AD2C1),
        )

        // Foreground soil mound
        val soilPath = Path().apply {
            moveTo(0f, h * 0.84f)
            quadraticTo(w * 0.5f, h * 0.75f, w, h * 0.84f)
            lineTo(w, h)
            lineTo(0f, h)
            close()
        }
        drawPath(
            path = soilPath,
            color = if (isDark) Color(0xFF2B241E) else Color(0xFF6B5344),
        )

        // Gentle fireflies when running or higher stage
        if (isRunning || stage >= 2) {
            val fireflyCount = if (isRunning) 7 else 4
            for (idx in 0 until fireflyCount) {
                val fx = w * (0.20f + idx * 0.11f) + sin(swayPhase + idx * 1.4f) * 10.dp.toPx()
                val fy = h * (0.30f + (idx % 3) * 0.14f) + cos(swayPhase + idx * 0.9f) * 8.dp.toPx()
                drawCircle(
                    color = c.limeAccent.copy(alpha = 0.45f + 0.45f * sin(swayPhase + idx)),
                    radius = 2.6.dp.toPx(),
                    center = Offset(fx, fy),
                )
            }
        }

        val cx = w * 0.5f
        val groundY = h * 0.79f
        val swayOffset = if (isRunning) sin(swayPhase) * 4.5.dp.toPx() else sin(swayPhase) * 1.5.dp.toPx()
        val trunkColor = if (isDark) Color(0xFF8C6B53) else Color(0xFF6B4F3B)
        val leafMain = if (isDark) c.primary else Color(0xFF146B5C)
        val leafLight = if (isDark) c.limeAccent else Color(0xFF288E7E)

        if (stage == 0) {
            // Seed tucked in soil with soft glow
            drawOval(
                color = Color(0xFF9E7B56),
                topLeft = Offset(cx - 8.dp.toPx(), groundY - 5.dp.toPx()),
                size = Size(16.dp.toPx(), 10.dp.toPx()),
            )
            return@Canvas
        }

        val trunkTopY = when (stage) {
            1 -> groundY - 38.dp.toPx()
            2 -> groundY - 68.dp.toPx()
            3 -> groundY - 92.dp.toPx()
            else -> groundY - 102.dp.toPx()
        }
        val strokeW = when (stage) {
            1 -> 3.5.dp.toPx()
            2 -> 6.5.dp.toPx()
            else -> 10.dp.toPx()
        }
        val topCenter = Offset(cx + swayOffset * 0.4f, trunkTopY)

        // Main trunk
        drawLine(
            color = trunkColor,
            start = Offset(cx, groundY),
            end = topCenter,
            strokeWidth = strokeW,
            cap = StrokeCap.Round,
        )

        if (stage >= 2) {
            // Side branches
            drawLine(
                color = trunkColor,
                start = Offset(cx, groundY - 38.dp.toPx()),
                end = Offset(cx - 26.dp.toPx() + swayOffset * 0.5f, trunkTopY + 18.dp.toPx()),
                strokeWidth = strokeW * 0.55f,
                cap = StrokeCap.Round,
            )
            drawLine(
                color = trunkColor,
                start = Offset(cx, groundY - 46.dp.toPx()),
                end = Offset(cx + 28.dp.toPx() + swayOffset * 0.5f, trunkTopY + 14.dp.toPx()),
                strokeWidth = strokeW * 0.55f,
                cap = StrokeCap.Round,
            )
        }

        if (stage == 1) {
            // Tender double sprout
            drawOval(
                color = leafLight,
                topLeft = Offset(topCenter.x - 19.dp.toPx(), topCenter.y - 6.dp.toPx()),
                size = Size(18.dp.toPx(), 10.dp.toPx()),
            )
            drawOval(
                color = leafMain,
                topLeft = Offset(topCenter.x + 1.dp.toPx(), topCenter.y - 9.dp.toPx()),
                size = Size(18.dp.toPx(), 10.dp.toPx()),
            )
            return@Canvas
        }

        // Lush canopy clusters
        val canopyShift = swayOffset
        drawCircle(leafMain, 26.dp.toPx(), Offset(topCenter.x - 24.dp.toPx() + canopyShift, topCenter.y + 10.dp.toPx()))
        drawCircle(leafMain, 26.dp.toPx(), Offset(topCenter.x + 24.dp.toPx() + canopyShift, topCenter.y + 10.dp.toPx()))
        drawCircle(leafLight.copy(alpha = 0.90f), 32.dp.toPx(), Offset(topCenter.x + canopyShift, topCenter.y - 12.dp.toPx()))

        if (stage >= 3) {
            drawCircle(leafMain.copy(alpha = 0.85f), 22.dp.toPx(), Offset(topCenter.x - 36.dp.toPx() + canopyShift, topCenter.y - 4.dp.toPx()))
            drawCircle(leafLight.copy(alpha = 0.85f), 22.dp.toPx(), Offset(topCenter.x + 36.dp.toPx() + canopyShift, topCenter.y - 4.dp.toPx()))
        }

        if (stage >= 4) {
            val blossoms = listOf(
                Offset(-18f, -18f),
                Offset(16f, -22f),
                Offset(-28f, 6f),
                Offset(28f, 8f),
                Offset(0f, -4f),
                Offset(8f, -34f),
            )
            blossoms.forEach { (dx, dy) ->
                drawCircle(
                    color = c.limeAccent,
                    radius = 4.dp.toPx(),
                    center = Offset(topCenter.x + dx.dp.toPx() + canopyShift, topCenter.y + dy.dp.toPx()),
                )
            }
        }
    }
}

@Composable
fun ModernFocusDial(
    progress: Float,
    timeLabel: String,
    subtitleLabel: String,
    isRunning: Boolean,
    isBreakMode: Boolean,
    modifier: Modifier = Modifier,
) {
    val c = HandelhaTheme.colors
    val infinite = rememberInfiniteTransition(label = "dial_pulse")
    val pulse by infinite.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(2200, easing = LinearEasing), RepeatMode.Reverse),
        label = "aura",
    )

    val ringColor = if (isBreakMode) c.lavenderAccent else c.primary
    val tipColor = if (c.isDark) c.limeAccent else ringColor

    Box(
        modifier = modifier.size(258.dp),
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height
            val center = Offset(w / 2f, h / 2f)
            val radius = (minOf(w, h) / 2f) - 22.dp.toPx()

            if (isRunning) {
                drawCircle(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            ringColor.copy(alpha = 0.16f + 0.08f * pulse),
                            Color.Transparent,
                        ),
                        center = center,
                        radius = radius + 24.dp.toPx(),
                    ),
                    center = center,
                    radius = radius + 24.dp.toPx(),
                )
            }

            // 60 radial ticks
            val outerR = radius + 12.dp.toPx()
            for (i in 0 until 60) {
                val angle = (i * 6.0 - 90.0) * PI / 180.0
                val isMajor = i % 5 == 0
                val innerR = outerR - (if (isMajor) 7.dp.toPx() else 3.5.dp.toPx())
                drawLine(
                    color = (if (isMajor) ringColor else c.border).copy(alpha = if (isMajor) 0.45f else 0.7f),
                    start = Offset(
                        center.x + (innerR * cos(angle)).toFloat(),
                        center.y + (innerR * sin(angle)).toFloat(),
                    ),
                    end = Offset(
                        center.x + (outerR * cos(angle)).toFloat(),
                        center.y + (outerR * sin(angle)).toFloat(),
                    ),
                    strokeWidth = if (isMajor) 2.dp.toPx() else 1.2.dp.toPx(),
                    cap = StrokeCap.Round,
                )
            }

            // Track ring
            drawCircle(
                color = c.surfaceSoft,
                radius = radius,
                center = center,
                style = Stroke(width = 13.dp.toPx()),
            )

            // Progress arc
            val sweep = 360f * progress.coerceIn(0f, 1f)
            if (sweep > 0.5f) {
                drawArc(
                    brush = Brush.sweepGradient(listOf(ringColor, tipColor, ringColor)),
                    startAngle = -90f,
                    sweepAngle = sweep,
                    useCenter = false,
                    topLeft = Offset(center.x - radius, center.y - radius),
                    size = Size(radius * 2f, radius * 2f),
                    style = Stroke(width = 13.dp.toPx(), cap = StrokeCap.Round),
                )
                val tipAngle = (-90.0 + sweep) * PI / 180.0
                val tipPos = Offset(
                    center.x + (radius * cos(tipAngle)).toFloat(),
                    center.y + (radius * sin(tipAngle)).toFloat(),
                )
                drawCircle(color = tipColor, radius = 8.dp.toPx(), center = tipPos)
                drawCircle(color = Color.White, radius = 3.5.dp.toPx(), center = tipPos)
            }
        }

        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = timeLabel,
                fontSize = 46.sp,
                fontWeight = FontWeight.Black,
                color = c.textPrimary,
                letterSpacing = (-1).sp,
            )
            Spacer(Modifier.height(4.dp))
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(if (isBreakMode) c.lavenderSoft else c.primarySoft)
                    .padding(horizontal = 12.dp, vertical = 4.dp),
            ) {
                Text(
                    text = subtitleLabel,
                    fontSize = 11.5.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (isBreakMode) c.lavenderAccent else c.primary,
                )
            }
        }
    }
}

@Composable
fun FocusDurationRulerBar(
    selectedMinutes: Int,
    onMinutesSelected: (Int) -> Unit,
    isBreakMode: Boolean,
    isRunning: Boolean,
    isEnglish: Boolean,
    modifier: Modifier = Modifier,
) {
    val c = HandelhaTheme.colors
    val minMins = if (isBreakMode) 5 else 5
    val maxMins = if (isBreakMode) 30 else 120
    val presets = if (isBreakMode) listOf(5, 10, 15, 20) else listOf(15, 25, 45, 60, 90)
    val cardShape = RoundedCornerShape(22.dp)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(cardShape)
            .background(c.surface, cardShape)
            .border(1.dp, c.border, cardShape)
            .padding(16.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = if (isBreakMode) {
                    if (isEnglish) "Break Duration" else "مدة الاستراحة"
                } else {
                    if (isEnglish) "Session Duration" else "مدة الجلسة"
                },
                fontSize = 13.5.sp,
                fontWeight = FontWeight.Bold,
                color = c.textPrimary,
            )
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .background(c.primarySoft)
                    .padding(horizontal = 10.dp, vertical = 4.dp),
            ) {
                Text(
                    text = ArabicFormatters.durationMinutesFull(selectedMinutes),
                    fontSize = 12.5.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = c.primary,
                )
            }
        }

        Spacer(Modifier.height(10.dp))

        // Interactive scrubbable ruler ticks
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(38.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(c.surfaceSoft)
                .then(
                    if (!isRunning) {
                        Modifier.pointerInput(isBreakMode) {
                            detectTapGestures { offset ->
                                val ratio = (offset.x / size.width.coerceAtLeast(1)).coerceIn(0f, 1f)
                                val raw = minMins + ratio * (maxMins - minMins)
                                val snapped = ((raw / 5f).roundToInt() * 5).coerceIn(minMins, maxMins)
                                onMinutesSelected(snapped)
                            }
                        }.pointerInput(isBreakMode) {
                            detectHorizontalDragGestures { change, _ ->
                                change.consume()
                                val ratio = (change.position.x / size.width.coerceAtLeast(1)).coerceIn(0f, 1f)
                                val raw = minMins + ratio * (maxMins - minMins)
                                val snapped = ((raw / 5f).roundToInt() * 5).coerceIn(minMins, maxMins)
                                onMinutesSelected(snapped)
                            }
                        }
                    } else {
                        Modifier
                    },
                ),
            contentAlignment = Alignment.Center,
        ) {
            Canvas(modifier = Modifier.fillMaxSize().padding(horizontal = 12.dp)) {
                val steps = (maxMins - minMins) / 5
                val activeIndex = ((selectedMinutes - minMins) / 5).coerceIn(0, steps)
                val w = size.width
                val h = size.height
                for (i in 0..steps) {
                    val x = w * (i.toFloat() / steps.coerceAtLeast(1))
                    val isMajor = i % 3 == 0
                    val isActive = i == activeIndex
                    val tickH = when {
                        isActive -> h * 0.72f
                        isMajor -> h * 0.48f
                        else -> h * 0.28f
                    }
                    drawLine(
                        color = when {
                            isActive -> c.primary
                            i < activeIndex -> c.primary.copy(alpha = 0.50f)
                            else -> c.textMuted.copy(alpha = 0.45f)
                        },
                        start = Offset(x, (h - tickH) / 2f),
                        end = Offset(x, (h + tickH) / 2f),
                        strokeWidth = if (isActive) 3.dp.toPx() else 1.6.dp.toPx(),
                        cap = StrokeCap.Round,
                    )
                }
            }
        }

        Spacer(Modifier.height(10.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            presets.forEach { mins ->
                val sel = mins == selectedMinutes
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(36.dp)
                        .clip(RoundedCornerShape(11.dp))
                        .background(if (sel) c.ctaBackground else c.surfaceSoft)
                        .border(1.dp, if (sel) c.ctaBackground else c.border, RoundedCornerShape(11.dp))
                        .clickable(enabled = !isRunning) { onMinutesSelected(mins) }
                        .testTag("focus_preset_$mins"),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = ArabicFormatters.durationMinutes(mins),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (sel) c.ctaForeground else c.textPrimary,
                    )
                }
            }
        }
    }
}

@Composable
fun FocusSoundscapeSection(
    selectedSound: AmbientSoundscape,
    volume: Float,
    isEnglish: Boolean,
    onSelectSound: (AmbientSoundscape) -> Unit,
    onVolumeChange: (Float) -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = HandelhaTheme.colors
    val cardShape = RoundedCornerShape(22.dp)
    val infinite = rememberInfiniteTransition(label = "eq")
    val eqPhase by infinite.animateFloat(
        initialValue = 0f,
        targetValue = (2 * PI).toFloat(),
        animationSpec = infiniteRepeatable(tween(900, easing = LinearEasing), RepeatMode.Restart),
        label = "eq_phase",
    )

    fun soundIcon(s: AmbientSoundscape): ImageVector = when (s) {
        AmbientSoundscape.SILENT -> Icons.AutoMirrored.Rounded.VolumeOff
        AmbientSoundscape.OCEAN -> Icons.Rounded.Waves
        AmbientSoundscape.NIGHT -> Icons.Rounded.NightsStay
        AmbientSoundscape.RAIN -> Icons.Rounded.WaterDrop
        AmbientSoundscape.FOREST -> Icons.Rounded.Park
        AmbientSoundscape.WARM_NOISE -> Icons.Rounded.GraphicEq
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(cardShape)
            .background(c.surface, cardShape)
            .border(1.dp, c.border, cardShape)
            .padding(16.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = if (isEnglish) "Ambient Soundscape" else "الأصوات المحيطة",
                fontSize = 14.5.sp,
                fontWeight = FontWeight.ExtraBold,
                color = c.textPrimary,
            )
            if (selectedSound != AmbientSoundscape.SILENT) {
                Row(
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(2.dp),
                    modifier = Modifier.height(14.dp),
                ) {
                    for (b in 0..2) {
                        val barRatio = 0.35f + 0.65f * ((sin(eqPhase + b * 1.3f) + 1f) / 2f)
                        Box(
                            modifier = Modifier
                                .width(3.dp)
                                .height((14 * barRatio).dp)
                                .clip(RoundedCornerShape(99.dp))
                                .background(c.primary),
                        )
                    }
                }
            }
        }
        Spacer(Modifier.height(4.dp))
        Text(
            text = selectedSound.subtitle(isEnglish),
            fontSize = 12.sp,
            color = c.textSecondary,
        )
        Spacer(Modifier.height(12.dp))

        // 2-column grid matching Flutter FocusSoundscapeSection
        val rows = AmbientSoundscape.entries.chunked(2)
        rows.forEachIndexed { rIdx, pair ->
            if (rIdx > 0) Spacer(Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                pair.forEach { sound ->
                    val sel = sound == selectedSound
                    val pillShape = RoundedCornerShape(14.dp)
                    Row(
                        modifier = Modifier
                            .weight(1f)
                            .height(46.dp)
                            .clip(pillShape)
                            .background(if (sel) c.primarySoft else c.surfaceSoft, pillShape)
                            .border(1.dp, if (sel) c.primary else c.border, pillShape)
                            .clickable { onSelectSound(sound) }
                            .padding(horizontal = 12.dp)
                            .testTag("sound_${sound.storedKey}"),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = soundIcon(sound),
                            contentDescription = null,
                            tint = if (sel) c.primary else c.textSecondary,
                            modifier = Modifier.size(18.dp),
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = sound.label(isEnglish),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            fontSize = 12.5.sp,
                            fontWeight = if (sel) FontWeight.Bold else FontWeight.Medium,
                            color = if (sel) c.primary else c.textPrimary,
                        )
                    }
                }
            }
        }

        if (selectedSound != AmbientSoundscape.SILENT) {
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = if (isEnglish) "Volume" else "الصوت",
                    fontSize = 12.sp,
                    color = c.textSecondary,
                )
                Spacer(Modifier.width(8.dp))
                Slider(
                    value = volume,
                    onValueChange = onVolumeChange,
                    valueRange = 0.05f..1f,
                    colors = SliderDefaults.colors(
                        thumbColor = c.primary,
                        activeTrackColor = c.primary,
                        inactiveTrackColor = c.surfaceSoft,
                    ),
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

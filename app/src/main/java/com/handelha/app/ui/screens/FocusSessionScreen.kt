package com.handelha.app.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Celebration
import androidx.compose.material.icons.rounded.Coffee
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Stop
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handelha.app.core.audio.AmbientSoundscape
import com.handelha.app.domain.FocusSessionItem
import com.handelha.app.ui.FocusTimerUiState
import com.handelha.app.ui.components.AnimatedFocusTreeCanvas
import com.handelha.app.ui.components.FocusDurationRulerBar
import com.handelha.app.ui.components.FocusSoundscapeSection
import com.handelha.app.ui.components.FocusTreeProgress
import com.handelha.app.ui.components.HandelhaHeader
import com.handelha.app.ui.components.HandelhaSegmentOption
import com.handelha.app.ui.components.HandelhaSegmentedSwitch
import com.handelha.app.ui.components.ModernFocusDial
import com.handelha.app.ui.theme.HandelhaTheme
import com.handelha.app.util.ArabicFormatters

@Composable
fun FocusSessionScreen(
    focusState: FocusTimerUiState,
    sessions: List<FocusSessionItem>,
    initialTab: Int,
    isEnglish: Boolean,
    onBack: () -> Unit,
    onToggleRunPause: () -> Unit,
    onEndSession: () -> Unit,
    onSelectDuration: (Int) -> Unit,
    onToggleBreakMode: (Boolean) -> Unit,
    onSelectSound: (AmbientSoundscape) -> Unit,
    onVolumeChange: (Float) -> Unit,
    onDismissCelebration: () -> Unit,
) {
    BackHandler(onBack = onBack)

    val c = HandelhaTheme.colors
    var selectedTab by remember(initialTab) { mutableIntStateOf(initialTab) }
    val treeProgress = remember(sessions) { FocusTreeProgress.compute(sessions) }

    val progress = if (focusState.totalSeconds <= 0) 0f
    else ((focusState.totalSeconds - focusState.remainingSeconds).toFloat() / focusState.totalSeconds.toFloat()).coerceIn(0f, 1f)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(bottom = 36.dp),
    ) {
        HandelhaHeader(
            title = if (isEnglish) "Focus Session" else "جلسة التركيز",
            subtitle = ArabicFormatters.trData(focusState.linkedTaskTitle.ifBlank { if (isEnglish) "Calm Focus Session" else "جلسة تركيز هادئة" }),
            isEnglish = isEnglish,
            showBack = true,
            onBack = onBack,
        )

        Column(modifier = Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            HandelhaSegmentedSwitch(
                options = listOf(
                    HandelhaSegmentOption(0, if (isEnglish) "Timer & Sounds" else "المؤقت والأصوات", Icons.Rounded.Timer, "focus_tab_timer"),
                    HandelhaSegmentOption(1, if (isEnglish) "Your Tree" else "شجرتك", null, "focus_tab_tree"),
                ),
                selected = selectedTab,
                onChanged = { selectedTab = it },
            )

            if (focusState.showCompletionCelebration) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(24.dp))
                        .background(c.primarySoft, RoundedCornerShape(24.dp))
                        .border(1.2.dp, c.primary, RoundedCornerShape(24.dp))
                        .padding(18.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Icon(Icons.Rounded.Celebration, null, tint = c.primary, modifier = Modifier.size(34.dp))
                    Spacer(Modifier.height(8.dp))
                    Text(
                        text = if (isEnglish) "Well done! Session logged 🌿" else "عاش! الجلسة اتسجلت في شجرتك 🌿",
                        fontSize = 16.5.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = c.primary,
                        textAlign = TextAlign.Center,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = if (isEnglish) "+${focusState.lastCompletedMinutes} focus minutes added to your progress"
                        else "اتضاف +${ArabicFormatters.durationMinutesFull(focusState.lastCompletedMinutes)} لرصيد تركيزك",
                        fontSize = 13.sp,
                        color = c.textSecondary,
                    )
                    Spacer(Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = onDismissCelebration, shape = RoundedCornerShape(12.dp)) {
                            Text(if (isEnglish) "Close" else "إغلاق", fontWeight = FontWeight.Bold)
                        }
                        Button(
                            onClick = { onDismissCelebration(); onToggleBreakMode(true) },
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = c.primary, contentColor = c.textOnPrimary),
                        ) {
                            Icon(Icons.Rounded.Coffee, null, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(6.dp))
                            Text(if (isEnglish) "Take a Break" else "خد استراحة", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            if (selectedTab == 0) {
                // Mode switch: Focus / Break
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    val modes = listOf(
                        false to (if (isEnglish) "Deep Focus" else "تركيز عميق"),
                        true to (if (isEnglish) "Short Break" else "استراحة هادئة"),
                    )
                    modes.forEach { (isBrk, lbl) ->
                        val sel = focusState.isBreakMode == isBrk
                        val pillShape = RoundedCornerShape(14.dp)
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(42.dp)
                                .clip(pillShape)
                                .background(if (sel) (if (isBrk) c.lavenderSoft else c.primarySoft) else c.surface)
                                .border(1.dp, if (sel) (if (isBrk) c.lavenderAccent else c.primary) else c.border, pillShape)
                                .clickable(enabled = !focusState.isRunning) { onToggleBreakMode(isBrk) },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = lbl,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (sel) (if (isBrk) c.lavenderAccent else c.primary) else c.textSecondary,
                            )
                        }
                    }
                }

                // Dial card
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(26.dp))
                        .background(c.surface, RoundedCornerShape(26.dp))
                        .border(1.dp, c.border, RoundedCornerShape(26.dp))
                        .padding(vertical = 20.dp, horizontal = 16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    ModernFocusDial(
                        progress = progress,
                        timeLabel = ArabicFormatters.timerMmSs(focusState.remainingSeconds),
                        subtitleLabel = if (focusState.isBreakMode) {
                            if (isEnglish) "Rest & Breathe" else "استراحة وتنفس"
                        } else if (focusState.isRunning) {
                            if (isEnglish) "Staying Calmly Focused" else "تركيزك شغال دلوقتي"
                        } else {
                            if (isEnglish) "Ready to Start" else "جاهز للبدء"
                        },
                        isRunning = focusState.isRunning,
                        isBreakMode = focusState.isBreakMode,
                    )

                    Spacer(Modifier.height(18.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Button(
                            onClick = onToggleRunPause,
                            modifier = Modifier.weight(2f).height(52.dp).testTag("focus_play_pause_button"),
                            shape = RoundedCornerShape(16.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = if (focusState.isBreakMode) c.lavenderAccent else c.ctaBackground,
                                contentColor = if (focusState.isBreakMode) Color.White else c.ctaForeground,
                            ),
                        ) {
                            Icon(
                                imageVector = if (focusState.isRunning) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                                contentDescription = null,
                                modifier = Modifier.size(22.dp),
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(
                                text = if (focusState.isRunning) {
                                    if (isEnglish) "Pause" else "إيقاف مؤقت"
                                } else {
                                    if (isEnglish) "Start" else "ابدأ الآن"
                                },
                                fontSize = 15.5.sp,
                                fontWeight = FontWeight.ExtraBold,
                            )
                        }

                        if (focusState.isRunning || focusState.remainingSeconds < focusState.totalSeconds) {
                            OutlinedButton(
                                onClick = onEndSession,
                                modifier = Modifier.weight(1f).height(52.dp).testTag("focus_end_button"),
                                shape = RoundedCornerShape(16.dp),
                            ) {
                                Icon(Icons.Rounded.Stop, null, tint = c.danger, modifier = Modifier.size(20.dp))
                                Spacer(Modifier.width(4.dp))
                                Text(if (isEnglish) "Finish" else "إنهاء", fontWeight = FontWeight.Bold, color = c.danger)
                            }
                        }
                    }
                }

                FocusDurationRulerBar(
                    selectedMinutes = if (focusState.isBreakMode) focusState.selectedBreakMinutes else focusState.selectedFocusMinutes,
                    onMinutesSelected = onSelectDuration,
                    isBreakMode = focusState.isBreakMode,
                    isRunning = focusState.isRunning,
                    isEnglish = isEnglish,
                )

                FocusSoundscapeSection(
                    selectedSound = focusState.selectedSound,
                    volume = focusState.volume,
                    isEnglish = isEnglish,
                    onSelectSound = onSelectSound,
                    onVolumeChange = onVolumeChange,
                )
            } else {
                // YOUR TREE TAB
                AnimatedFocusTreeCanvas(progress = treeProgress, isRunning = focusState.isRunning)

                // Growth stage card
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(22.dp))
                        .background(c.surface, RoundedCornerShape(22.dp))
                        .border(1.dp, c.border, RoundedCornerShape(22.dp))
                        .padding(16.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                        Text(treeProgress.stageTitle(isEnglish), fontSize = 18.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
                        Box(
                            modifier = Modifier.clip(RoundedCornerShape(999.dp)).background(c.primarySoft).padding(horizontal = 10.dp, vertical = 4.dp),
                        ) {
                            Text(
                                text = if (isEnglish) "Trees: ${treeProgress.completedTrees}" else "الأشجار المكتملة: ${ArabicFormatters.toArabicDigits(treeProgress.completedTrees)}",
                                fontSize = 11.5.sp,
                                fontWeight = FontWeight.Bold,
                                color = c.primary,
                            )
                        }
                    }
                    Spacer(Modifier.height(6.dp))
                    Text(treeProgress.stageMotivation(isEnglish), fontSize = 13.sp, color = c.textSecondary)
                    Spacer(Modifier.height(12.dp))
                    LinearProgressIndicator(
                        progress = { treeProgress.stageFraction },
                        modifier = Modifier.fillMaxWidth().height(7.dp).clip(RoundedCornerShape(999.dp)),
                        color = c.primary,
                        trackColor = c.surfaceSoft,
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        text = if (isEnglish) "${treeProgress.minutesToNextStage}m until next stage • 90m daily goal"
                        else "متبقي ${ArabicFormatters.durationMinutesFull(treeProgress.minutesToNextStage)} للمرحلة الجاية • هدف اليوم ٩٠ د",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = c.primary,
                    )
                }

                // 3 KPI tiles
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    TreeStatTile(ArabicFormatters.durationCompact(treeProgress.todayMinutes), if (isEnglish) "Today" else "اليوم", Modifier.weight(1f))
                    TreeStatTile(ArabicFormatters.durationCompact(treeProgress.totalMinutes), if (isEnglish) "Total Focus" else "الإجمالي", Modifier.weight(1f))
                    TreeStatTile(ArabicFormatters.toArabicDigits(treeProgress.completedSessions), if (isEnglish) "Sessions" else "جلسات", Modifier.weight(1f))
                }

                // Session history list
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(22.dp))
                        .background(c.surface, RoundedCornerShape(22.dp))
                        .border(1.dp, c.border, RoundedCornerShape(22.dp))
                        .padding(16.dp),
                ) {
                    Text(
                        text = if (isEnglish) "Recent Focus Sessions" else "سجل جلسات التركيز",
                        fontSize = 15.5.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = c.textPrimary,
                    )
                    Spacer(Modifier.height(10.dp))
                    if (sessions.isEmpty()) {
                        Text(
                            text = if (isEnglish) "Complete your first focus session and it will appear right here."
                            else "أول ما تخلص جلسة تركيز هتتسجل هنا تلقائيًا.",
                            fontSize = 13.sp,
                            color = c.textSecondary,
                        )
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            sessions.take(8).forEach { s ->
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(14.dp))
                                        .background(c.surfaceSoft)
                                        .padding(horizontal = 12.dp, vertical = 10.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Box(modifier = Modifier.size(8.dp).clip(CircleShape).background(c.primary))
                                    Spacer(Modifier.width(10.dp))
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(ArabicFormatters.trData(s.taskTitle), fontSize = 13.5.sp, fontWeight = FontWeight.Bold, color = c.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                        Text("${ArabicFormatters.dateShort(s.endedAtMs)} • ${ArabicFormatters.timeOfDayAr(s.endedAtMs)}", fontSize = 11.5.sp, color = c.textSecondary)
                                    }
                                    Text(ArabicFormatters.durationMinutes(s.elapsedMinutes), fontSize = 13.sp, fontWeight = FontWeight.ExtraBold, color = c.primary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TreeStatTile(value: String, label: String, modifier: Modifier = Modifier) {
    val c = HandelhaTheme.colors
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(18.dp))
            .background(c.surface, RoundedCornerShape(18.dp))
            .border(1.dp, c.border, RoundedCornerShape(18.dp))
            .padding(vertical = 12.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(value, fontSize = 17.5.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
        Spacer(Modifier.height(2.dp))
        Text(label, fontSize = 11.sp, color = c.textSecondary)
    }
}

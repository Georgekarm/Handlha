package com.handelha.app.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.material.icons.outlined.LightMode
import androidx.compose.material.icons.outlined.NotificationsNone
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.WbSunny
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.School
import com.handelha.app.domain.AppUser
import com.handelha.app.domain.FocusSessionItem
import com.handelha.app.domain.ProjectItem
import com.handelha.app.domain.StudentMotivationState
import com.handelha.app.domain.StudentStudyMood
import com.handelha.app.domain.TaskItem
import com.handelha.app.domain.TaskPriority
import com.handelha.app.ui.components.FocusTreeProgress
import com.handelha.app.ui.components.HandelhaHeaderIconButton
import com.handelha.app.ui.components.HandelhaTaskCard
import com.handelha.app.ui.components.MiniFocusTreeEmblem
import com.handelha.app.ui.components.StudentQuoteWidgetCard
import com.handelha.app.ui.theme.HandelhaTheme
import com.handelha.app.util.ArabicFormatters
import java.util.Calendar

@Composable
fun DashboardScreen(
    user: AppUser?,
    tasks: List<TaskItem>,
    projects: List<ProjectItem>,
    focusSessions: List<FocusSessionItem>,
    readNotifIds: Set<String>,
    isStudentMode: Boolean = true,
    studentMotivation: StudentMotivationState = StudentMotivationState(),
    isEnglish: Boolean,
    onToggleTheme: () -> Unit,
    onOpenNotifications: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenAddTask: (TaskItem?) -> Unit,
    onToggleTaskComplete: (String) -> Unit,
    onStartFocus: (taskId: String?, title: String, initialTab: Int) -> Unit,
    onOpenAssistant: () -> Unit,
    onOpenAllTasks: () -> Unit,
    onNextStudentQuote: () -> Unit = {},
    onToggleFavoriteQuote: (String) -> Unit = {},
    onPinQuoteToWidget: (String?) -> Unit = {},
    onSelectStudentMood: (StudentStudyMood) -> Unit = {},
    onOpenStudentQuotesHub: () -> Unit = {},
    onToggleStudentMode: (Boolean) -> Unit = {},
    onShowToast: (String, Boolean) -> Unit = { _, _ -> },
) {
    val c = HandelhaTheme.colors
    var selectedDayOffset by remember { mutableIntStateOf(0) }
    val projectMap = remember(projects) { projects.associateBy { it.id } }

    val todayCal = remember {
        Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
    }
    val selectedCal = (todayCal.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, selectedDayOffset) }
    val selectedStart = selectedCal.timeInMillis
    val selectedEnd = selectedStart + 86_400_000L

    val activeTasks = tasks.filter { !it.isCancelled && !it.isDeleted }
    val dayTasks = if (selectedDayOffset == 0) {
        activeTasks.filter {
            val dt = it.scheduledStartAtMs ?: it.dueAtMs
            dt == null || dt < selectedEnd
        }
    } else {
        activeTasks.filter {
            val dt = it.scheduledStartAtMs ?: it.dueAtMs
            dt != null && dt in selectedStart until selectedEnd
        }
    }

    val totalCount = dayTasks.size
    val completedCount = dayTasks.count { it.isCompleted }
    val progressRatio = if (totalCount == 0) 0f else (completedCount.toFloat() / totalCount.toFloat()).coerceIn(0f, 1f)
    val openTasks = dayTasks.filter { !it.isCompleted && !it.isCancelled }
    val heroTask = openTasks.firstOrNull()
    val remainingTasks = if (heroTask != null) openTasks.drop(1).take(4) else emptyList()

    val hasUnreadNotifs = activeTasks.any {
        !it.isCompleted && !it.isCancelled && it.dueAtMs != null && !readNotifIds.contains(it.id)
    }

    val greetingPrefix = remember(isEnglish) {
        val hr = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        if (isEnglish) {
            if (hr < 12) "Good morning," else "Good evening,"
        } else {
            if (hr < 12) "صباح الخير يا" else "مساء الخير يا"
        }
    }
    val cleanName = ArabicFormatters.trData(user?.firstName ?: if (isEnglish) "Friend" else "صديقي")

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, top = 12.dp, end = 20.dp, bottom = 114.dp),
    ) {
        // Top Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (isEnglish) {
                        "${ArabicFormatters.weekdayShort(selectedStart)}, ${ArabicFormatters.dateShort(selectedStart)}"
                    } else {
                        "${ArabicFormatters.weekdayShort(selectedStart)}، ${ArabicFormatters.dateShort(selectedStart)}"
                    },
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.primary,
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    text = "$greetingPrefix $cleanName",
                    fontSize = 27.sp,
                    fontWeight = FontWeight.Black,
                    color = c.textPrimary,
                    lineHeight = 33.sp,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = if (isEnglish) "You don't have to finish everything. Start with one thing."
                    else "مش لازم تخلّص كل حاجة. ابدأ بحاجة واحدة.",
                    fontSize = 13.sp,
                    color = c.textSecondary,
                )
            }
            Spacer(Modifier.width(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(2.dp), verticalAlignment = Alignment.CenterVertically) {
                HandelhaHeaderIconButton(
                    icon = if (c.isDark) Icons.Outlined.LightMode else Icons.Outlined.WbSunny,
                    tooltip = if (isEnglish) (if (c.isDark) "Light Mode" else "Dark Mode") else (if (c.isDark) "الوضع النهاري" else "الوضع الليلي"),
                    iconColor = c.primary,
                    backgroundColor = Color.Transparent,
                    onClick = onToggleTheme,
                    testTag = "home_theme_button",
                )
                HandelhaHeaderIconButton(
                    icon = Icons.Outlined.NotificationsNone,
                    tooltip = if (isEnglish) "Notifications" else "الإشعارات",
                    showBadge = hasUnreadNotifs,
                    onClick = onOpenNotifications,
                    testTag = "home_notifications_button",
                )
                HandelhaHeaderIconButton(
                    icon = Icons.Outlined.Settings,
                    tooltip = if (isEnglish) "Settings" else "الإعدادات",
                    onClick = onOpenSettings,
                    testTag = "home_settings_button",
                )
            }
        }

        Spacer(Modifier.height(18.dp))

        // 7-day strip
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            for (i in 0 until 7) {
                val cal = (todayCal.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, i) }
                val selected = i == selectedDayOffset
                val shape = RoundedCornerShape(16.dp)
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .height(62.dp)
                        .then(
                            if (!c.isDark && !selected) {
                                Modifier.shadow(4.dp, shape, ambientColor = Color.Black.copy(alpha = 0.04f))
                            } else if (selected && !c.isDark) {
                                Modifier.shadow(8.dp, shape, ambientColor = c.primary.copy(alpha = 0.25f))
                            } else {
                                Modifier
                            },
                        )
                        .clip(shape)
                        .background(if (selected) c.primary else c.surface, shape)
                        .then(if (selected) Modifier else Modifier.border(1.dp, c.border, shape))
                        .clickable { selectedDayOffset = i }
                        .padding(horizontal = 4.dp, vertical = 4.dp)
                        .testTag("home_day_pill_$i"),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Text(
                        text = singleDayInitial(cal.get(Calendar.DAY_OF_WEEK), isEnglish),
                        fontSize = 11.5.sp,
                        fontWeight = FontWeight.Medium,
                        color = if (selected) c.textOnPrimary.copy(alpha = 0.85f) else c.textSecondary,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = ArabicFormatters.toArabicDigits(cal.get(Calendar.DAY_OF_MONTH)),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = if (selected) c.textOnPrimary else c.textPrimary,
                    )
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        // Row 5:3 Progress Ring card + Lavender Quick "+ مهمة جديدة" Card
        val ringCardShape = RoundedCornerShape(22.dp)
        Row(
            modifier = Modifier.fillMaxWidth().height(IntrinsicSize.Max),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier
                    .weight(5f)
                    .fillMaxHeight()
                    .then(
                        if (!c.isDark) Modifier.shadow(6.dp, ringCardShape, ambientColor = Color.Black.copy(alpha = 0.05f), spotColor = Color.Black.copy(alpha = 0.05f))
                        else Modifier,
                    )
                    .clip(ringCardShape)
                    .background(c.surface, ringCardShape)
                    .border(1.dp, c.border, ringCardShape)
                    .padding(horizontal = 16.dp, vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.Center) {
                    Text(
                        text = if (isEnglish) "$completedCount of $totalCount"
                        else "${ArabicFormatters.toArabicDigits(completedCount)} من ${ArabicFormatters.toArabicDigits(totalCount)}",
                        fontSize = 22.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = c.textPrimary,
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = if (isEnglish) {
                            if (selectedDayOffset == 0) "Tasks done today" else "Tasks for this day"
                        } else {
                            if (selectedDayOffset == 0) "مهام خلصوا النهارده" else "مهام اليوم ده"
                        },
                        fontSize = 12.sp,
                        color = c.textSecondary,
                    )
                }
                Spacer(Modifier.width(8.dp))
                Box(modifier = Modifier.size(58.dp), contentAlignment = Alignment.Center) {
                    Canvas(modifier = Modifier.fillMaxSize()) {
                        val stroke = Stroke(width = 5.5.dp.toPx(), cap = StrokeCap.Round)
                        drawCircle(color = c.primarySoft, style = stroke)
                        drawArc(
                            color = c.primary,
                            startAngle = -90f,
                            sweepAngle = 360f * progressRatio,
                            useCenter = false,
                            style = stroke,
                        )
                    }
                    Text(
                        text = ArabicFormatters.percent(progressRatio * 100.0),
                        fontSize = 12.5.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = c.primary,
                    )
                }
            }

            Column(
                modifier = Modifier
                    .weight(3f)
                    .fillMaxHeight()
                    .then(
                        if (!c.isDark) Modifier.shadow(6.dp, ringCardShape, ambientColor = c.lavenderAccent.copy(alpha = 0.12f))
                        else Modifier,
                    )
                    .clip(ringCardShape)
                    .background(c.lavenderSoft, ringCardShape)
                    .clickable { onOpenAddTask(null) }
                    .padding(horizontal = 10.dp, vertical = 16.dp)
                    .testTag("home_quick_add_task"),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Icon(Icons.Rounded.Add, contentDescription = null, tint = c.lavenderAccent, modifier = Modifier.size(26.dp))
                Spacer(Modifier.height(6.dp))
                Text(
                    text = if (isEnglish) "New Task" else "مهمة جديدة",
                    textAlign = TextAlign.Center,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = c.lavenderAccent,
                )
            }
        }

        Spacer(Modifier.height(18.dp))

        // Hero Teal Card: خطوتك الجاية
        val minutes = heroTask?.estimatedDurationMinutes ?: 25
        val heroProj = heroTask?.projectId?.let { projectMap[it]?.title }
        val cleanProject = if (heroProj != null) ArabicFormatters.trData(heroProj) else if (isEnglish) "Core Task" else "مهمة أساسية"
        val isHigh = heroTask != null && (heroTask.priority == TaskPriority.high || heroTask.priority == TaskPriority.urgent)
        val subLabel = if (heroTask == null) {
            if (isEnglish) "Calm planning • Step by step" else "تنظيم هادئ • خطوة بخطوة"
        } else {
            "$cleanProject • ${if (isHigh) (if (isEnglish) "Work" else "شغل") else (if (isEnglish) "Focus" else "تركيز")}"
        }
        val focusTargetTitle = heroTask?.title?.let { ArabicFormatters.trData(it) }
            ?: if (isEnglish) "Calm Focus Session" else "جلسة تركيز هادئة"

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .shadow(16.dp, RoundedCornerShape(26.dp), ambientColor = c.heroTeal.copy(alpha = 0.25f))
                .clip(RoundedCornerShape(26.dp))
                .background(c.heroTeal, RoundedCornerShape(26.dp))
                .padding(20.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (isEnglish) "Your Next Step" else "خطوتك الجاية",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color.White.copy(alpha = 0.85f),
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        text = if (heroTask != null) ArabicFormatters.trData(heroTask.title)
                        else if (isEnglish) "Start a short focus session" else "ابدأ جلسة تركيز قصيرة",
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = Color.White,
                        lineHeight = 28.sp,
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        text = subLabel,
                        fontSize = 13.sp,
                        color = Color.White.copy(alpha = 0.82f),
                    )
                }
                Spacer(Modifier.width(14.dp))
                Box(
                    modifier = Modifier
                        .size(72.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.12f))
                        .border(2.dp, Color.White.copy(alpha = 0.34f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = ArabicFormatters.toArabicDigits(minutes),
                            fontSize = 22.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = Color.White,
                            lineHeight = 23.sp,
                        )
                        Text(
                            text = if (isEnglish) "min" else "دقيقة",
                            fontSize = 10.5.sp,
                            color = Color.White.copy(alpha = 0.85f),
                        )
                    }
                }
            }
            Spacer(Modifier.height(18.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Button(
                    onClick = { onStartFocus(heroTask?.id, focusTargetTitle, 0) },
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .testTag("home_start_focus_button"),
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White.copy(alpha = 0.92f),
                        contentColor = c.heroTeal,
                    ),
                    contentPadding = PaddingValues(horizontal = 12.dp),
                ) {
                    Icon(Icons.Rounded.PlayArrow, null, tint = c.heroTeal, modifier = Modifier.size(21.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(
                        text = if (isEnglish) "Start Focus Session" else "ابدأ جلسة تركيز",
                        fontSize = 14.5.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = c.heroTeal,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                Spacer(Modifier.width(10.dp))
                TextButton(
                    onClick = onOpenAssistant,
                    modifier = Modifier.testTag("home_plan_together_button"),
                ) {
                    Text(
                        text = if (isEnglish) "Plan together?" else "نرتّبها سوا؟",
                        fontSize = 13.5.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White.copy(alpha = 0.92f),
                    )
                }
            }
        }

        Spacer(Modifier.height(14.dp))

        // Focus Dashboard Strip Card
        val treeProgress = remember(focusSessions) { FocusTreeProgress.compute(focusSessions) }
        val dailyRatio = (treeProgress.todayMinutes / 90f).coerceIn(0f, 1f)
        val stageName = treeProgress.stageTitle(isEnglish)
        val treeCardShape = RoundedCornerShape(20.dp)

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .then(
                    if (!c.isDark) Modifier.shadow(6.dp, treeCardShape, ambientColor = Color.Black.copy(alpha = 0.05f), spotColor = Color.Black.copy(alpha = 0.05f))
                    else Modifier,
                )
                .clip(treeCardShape)
                .background(c.surface, treeCardShape)
                .border(1.dp, c.border, treeCardShape)
                .clickable { onStartFocus(heroTask?.id, focusTargetTitle, 1) }
                .padding(14.dp)
                .testTag("home_focus_tree_strip"),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(13.dp))
                        .background(c.primarySoft),
                    contentAlignment = Alignment.Center,
                ) {
                    MiniFocusTreeEmblem(
                        stageIndex = treeProgress.stageIndex,
                        trunkColor = Color(0xFF6B4F3B),
                        foliageColor = c.primary,
                        blossomColor = c.limeAccent,
                        modifier = Modifier.fillMaxSize(),
                    )
                }
                Spacer(Modifier.width(11.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (isEnglish) "Your Focus Tree" else "شجرتك ونمو تركيزك",
                        fontSize = 13.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.textPrimary,
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = "$stageName • ${ArabicFormatters.durationMinutes(treeProgress.todayMinutes)} / ${ArabicFormatters.durationMinutes(90)}",
                        fontSize = 12.sp,
                        color = c.textSecondary,
                    )
                }
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(c.primarySoft)
                        .clickable { onStartFocus(heroTask?.id, focusTargetTitle, 0) }
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                ) {
                    Text(
                        text = if (isEnglish) "Open Timer" else "فتح المؤقت",
                        fontSize = 11.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.primary,
                    )
                }
            }
            Spacer(Modifier.height(10.dp))
            LinearProgressIndicator(
                progress = { dailyRatio },
                modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(999.dp)),
                color = c.primary,
                trackColor = c.surfaceSoft,
            )
            Spacer(Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = treeProgress.stageMotivation(isEnglish),
                    fontSize = 11.5.sp,
                    color = c.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = if (isEnglish) "View Tree" else "عرض شجرتك",
                    fontSize = 11.5.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.primary,
                )
            }
        }

        Spacer(Modifier.height(20.dp))

        // Rest of Your Day
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = if (isEnglish) "Rest of Your Day" else "باقي يومك",
                fontSize = 20.sp,
                fontWeight = FontWeight.ExtraBold,
                color = c.textPrimary,
            )
            TextButton(onClick = onOpenAllTasks, modifier = Modifier.testTag("home_view_all_tasks")) {
                Text(
                    text = if (isEnglish) "View All" else "عرض الكل",
                    fontSize = 13.5.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.primary,
                )
            }
        }
        Spacer(Modifier.height(8.dp))

        if (remainingTasks.isEmpty()) {
            val emptyShape = RoundedCornerShape(20.dp)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .then(
                        if (!c.isDark) Modifier.shadow(5.dp, emptyShape, ambientColor = Color.Black.copy(alpha = 0.04f))
                        else Modifier,
                    )
                    .clip(emptyShape)
                    .background(c.surface, emptyShape)
                    .border(1.dp, c.border, emptyShape)
                    .padding(20.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = if (heroTask == null) {
                        if (isEnglish) "Your day is clear! Add your first task or plan your day with the assistant."
                        else "يومك رايق! تقدر تضيف أول مهمة أو ترتّب يومك مع المساعد."
                    } else {
                        if (isEnglish) "No other tasks left today besides your current focus step."
                        else "مفيش مهام تانية متبقية النهارده غير خطوتك الحالية."
                    },
                    textAlign = TextAlign.Center,
                    fontSize = 13.5.sp,
                    color = c.textSecondary,
                )
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                remainingTasks.forEach { t ->
                    val proj = t.projectId?.let { projectMap[it] }
                    HandelhaTaskCard(
                        task = t,
                        isEnglish = isEnglish,
                        projectName = proj?.title,
                        stripeColor = proj?.let { Color(it.colorValue) },
                        onToggleComplete = { onToggleTaskComplete(t.id) },
                        onTap = { onOpenAddTask(t) },
                    )
                }
            }
        }

        // Student Mode Wisdom & Quotes Card placed calmly at the bottom of the Home screen
        if (isStudentMode) {
            Spacer(Modifier.height(18.dp))
            StudentQuoteWidgetCard(
                studentName = user?.firstName ?: if (isEnglish) "Friend" else "صديقي",
                motivationState = studentMotivation,
                isEnglish = isEnglish,
                onNextQuote = onNextStudentQuote,
                onToggleFavorite = onToggleFavoriteQuote,
                onSelectMood = onSelectStudentMood,
                onOpenQuotesHub = onOpenStudentQuotesHub,
                onStartQuickFocus = { boostMins, boostTitle ->
                    onStartFocus(heroTask?.id, "$boostTitle (${ArabicFormatters.toArabicDigits(boostMins)} د)", 0)
                },
                onShowToast = onShowToast,
            )
        }
    }
}

private fun singleDayInitial(dayOfWeek: Int, isEn: Boolean): String = if (isEn) {
    when (dayOfWeek) {
        Calendar.MONDAY -> "M"
        Calendar.TUESDAY -> "T"
        Calendar.WEDNESDAY -> "W"
        Calendar.THURSDAY -> "T"
        Calendar.FRIDAY -> "F"
        Calendar.SATURDAY -> "S"
        Calendar.SUNDAY -> "S"
        else -> ""
    }
} else {
    when (dayOfWeek) {
        Calendar.MONDAY -> "ن"
        Calendar.TUESDAY -> "ث"
        Calendar.WEDNESDAY -> "ر"
        Calendar.THURSDAY -> "خ"
        Calendar.FRIDAY -> "ج"
        Calendar.SATURDAY -> "س"
        Calendar.SUNDAY -> "ح"
        else -> ""
    }
}

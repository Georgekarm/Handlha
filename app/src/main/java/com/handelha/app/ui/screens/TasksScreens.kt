package com.handelha.app.ui.screens

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Alarm
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.NotificationsActive
import androidx.compose.material.icons.outlined.NotificationsNone
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Timer
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AttachFile
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Celebration
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CheckCircleOutline
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.NotificationsActive
import androidx.compose.material.icons.rounded.NotificationsNone
import androidx.compose.material.icons.rounded.Repeat
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.core.content.ContextCompat
import com.handelha.app.domain.ProjectItem
import com.handelha.app.domain.TaskItem
import com.handelha.app.domain.TaskPriority
import com.handelha.app.domain.TaskRecurrence
import com.handelha.app.ui.components.FeatureEmptyState
import com.handelha.app.ui.components.HandelhaBottomSheetFrame
import com.handelha.app.ui.components.HandelhaConfirmDialog
import com.handelha.app.ui.components.HandelhaDateTimePickerSheet
import com.handelha.app.ui.components.HandelhaHeader
import com.handelha.app.ui.components.HandelhaHeaderIconButton
import com.handelha.app.ui.components.HandelhaPickerMode
import com.handelha.app.ui.components.HandelhaTaskCard
import com.handelha.app.ui.theme.HandelhaTheme
import com.handelha.app.ui.theme.IbmPlexSansArabic
import com.handelha.app.util.ArabicFormatters
import java.util.Calendar
import kotlin.math.roundToInt

@Composable
fun TasksScreen(
    tasks: List<TaskItem>,
    projects: List<ProjectItem>,
    isEnglish: Boolean,
    onOpenSettings: () -> Unit,
    onOpenAddTask: (TaskItem?) -> Unit,
    onOpenAssistant: () -> Unit,
    onStartFocus: (taskId: String, title: String) -> Unit,
    onToggleComplete: (String) -> Unit,
    onDeleteTask: (String) -> Unit,
) {
    val c = HandelhaTheme.colors
    var selectedTab by remember { mutableIntStateOf(0) } // 0 = open, 1 = completed
    var actionTask by remember { mutableStateOf<TaskItem?>(null) }
    var deleteConfirmTask by remember { mutableStateOf<TaskItem?>(null) }

    val projectMap = remember(projects) { projects.associateBy { it.id } }
    val active = tasks.filter { !it.isCancelled && !it.isDeleted }
    val openTasks = active.filter { !it.isCompleted }
    val completedTasks = active.filter { it.isCompleted }
    val shown = if (selectedTab == 0) openTasks else completedTasks

    val todayEndMs = remember {
        Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_YEAR, 1)
        }.timeInMillis
    }

    val todayOpen = openTasks.filter {
        val dt = it.scheduledStartAtMs ?: it.dueAtMs
        dt == null || dt < todayEndMs
    }
    val upcomingOpen = openTasks.filter {
        val dt = it.scheduledStartAtMs ?: it.dueAtMs
        dt != null && dt >= todayEndMs
    }

    val totalCount = openTasks.size + completedTasks.size
    val doneCount = completedTasks.size
    val ratio = if (totalCount == 0) 0f else (doneCount.toFloat() / totalCount.toFloat()).coerceIn(0f, 1f)
    val percent = (ratio * 100f).roundToInt()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, end = 20.dp, bottom = 114.dp),
    ) {
        HandelhaHeader(
            title = if (selectedTab == 0) (if (isEnglish) "Tasks" else "المهام") else (if (isEnglish) "Completed Tasks" else "المهام المكتملة"),
            isEnglish = isEnglish,
            showBack = false,
            padding = PaddingValues(top = 10.dp, bottom = 14.dp),
            actions = {
                HandelhaHeaderIconButton(
                    icon = Icons.Outlined.Settings,
                    tooltip = if (isEnglish) "Settings" else "الإعدادات",
                    onClick = onOpenSettings,
                    testTag = "tasks_settings_button",
                )
            },
        )

        // Hero Summary Banner Card matching Flutter tasks_screen.dart
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(22.dp))
                .background(c.heroCardBg, RoundedCornerShape(22.dp))
                .then(if (c.isDark) Modifier.border(1.dp, c.heroBannerBorder, RoundedCornerShape(22.dp)) else Modifier)
                .padding(horizontal = 18.dp, vertical = 16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (isEnglish) "Take it step by step" else "خدها خطوة خطوة",
                        fontSize = 11.5.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color.White.copy(alpha = 0.72f),
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = if (totalCount == 0) {
                            if (isEnglish) "Ready for your first task" else "جاهز لأول مهمة"
                        } else {
                            if (isEnglish) "$doneCount of $totalCount tasks done"
                            else "${ArabicFormatters.toArabicDigits(doneCount)} من ${ArabicFormatters.toArabicDigits(totalCount)} مهام خلصت"
                        },
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        fontSize = 19.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                    )
                }
                Spacer(Modifier.width(10.dp))
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(c.limeAccent)
                        .padding(horizontal = 12.dp, vertical = 5.dp),
                ) {
                    Text(
                        text = ArabicFormatters.percent(percent.toDouble()),
                        fontSize = 12.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.limeAccentInk,
                    )
                }
            }
            Spacer(Modifier.height(14.dp))
            LinearProgressIndicator(
                progress = { ratio },
                modifier = Modifier.fillMaxWidth().height(5.5.dp).clip(RoundedCornerShape(999.dp)),
                color = c.limeAccent,
                trackColor = Color.White.copy(alpha = 0.16f),
            )
        }

        Spacer(Modifier.height(14.dp))

        // Segmented Capsule Track (المفتوحة N / المكتملة M)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(c.segmentedTrackBackground)
                .padding(4.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            listOf(
                0 to (if (isEnglish) "Open ${openTasks.size}" else "المفتوحة ${ArabicFormatters.toArabicDigits(openTasks.size)}"),
                1 to (if (isEnglish) "Completed ${completedTasks.size}" else "المكتملة ${ArabicFormatters.toArabicDigits(completedTasks.size)}"),
            ).forEach { (idx, label) ->
                val sel = selectedTab == idx
                val pillShape = RoundedCornerShape(12.dp)
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(42.dp)
                        .then(
                            if (sel && !c.isDark) {
                                Modifier.shadow(
                                    elevation = 6.dp,
                                    shape = pillShape,
                                    ambientColor = Color.Black.copy(alpha = 0.06f),
                                    spotColor = Color.Black.copy(alpha = 0.06f),
                                )
                            } else {
                                Modifier
                            },
                        )
                        .clip(pillShape)
                        .background(if (sel) c.segmentedActiveBackground else Color.Transparent, pillShape)
                        .clickable { selectedTab = idx }
                        .testTag("tasks_tab_$idx"),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = label,
                        fontSize = 13.5.sp,
                        fontWeight = if (sel) FontWeight.Bold else FontWeight.Medium,
                        color = if (sel) (if (c.isDark) Color.White else c.primary) else c.textSecondary,
                    )
                }
            }
        }

        Spacer(Modifier.height(18.dp))

        if (shown.isEmpty()) {
            FeatureEmptyState(
                title = if (selectedTab == 0) {
                    if (isEnglish) "Page still empty?" else "لسه الصفحة فاضية؟"
                } else {
                    if (isEnglish) "No completed tasks yet" else "مفيش مهام مكتملة لسه"
                },
                subtitle = if (selectedTab == 0) {
                    if (isEnglish) "That's a great start. Pick one thing you want to finish, and take the rest step by step."
                    else "دي بداية حلوة. اختار حاجة واحدة نفسك تخلّصها، وسيب الباقي خطوة خطوة."
                } else {
                    if (isEnglish) "Once you finish a task, it will show up here so you can celebrate your progress."
                    else "أول ما تخلّص مهمة من مهامك هتظهر هنا عشان تفرح بإنجازك."
                },
                primaryCtaLabel = if (isEnglish) "+ Add First Task" else "+ أضف أول مهمة",
                onPrimaryCta = { onOpenAddTask(null) },
                secondaryCtaLabel = if (isEnglish) "Let the assistant help" else "خلّي المساعد يساعدك",
                onSecondaryCta = onOpenAssistant,
            )
        } else if (selectedTab == 0) {
            if (todayOpen.isNotEmpty()) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text(if (isEnglish) "Today" else "النهارده", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = c.textPrimary)
                    Text(
                        text = if (isEnglish) "${todayOpen.size} tasks" else "${ArabicFormatters.toArabicDigits(todayOpen.size)} مهام",
                        fontSize = 12.sp,
                        color = c.textSecondary,
                    )
                }
                Spacer(Modifier.height(10.dp))
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    todayOpen.forEach { t ->
                        val proj = t.projectId?.let { projectMap[it] }
                        HandelhaTaskCard(
                            task = t,
                            isEnglish = isEnglish,
                            projectName = proj?.title,
                            stripeColor = proj?.let { Color(it.colorValue) },
                            onToggleComplete = { onToggleComplete(t.id) },
                            onTap = { onOpenAddTask(t) },
                            onLongPress = { actionTask = t },
                            onMorePressed = { actionTask = t },
                        )
                    }
                }
            }
            if (upcomingOpen.isNotEmpty()) {
                Spacer(Modifier.height(18.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text(if (isEnglish) "Upcoming" else "القادمة", fontSize = 17.5.sp, fontWeight = FontWeight.Bold, color = c.textPrimary)
                    Text(
                        text = if (isEnglish) "${upcomingOpen.size} tasks" else "${ArabicFormatters.toArabicDigits(upcomingOpen.size)} مهام",
                        fontSize = 12.sp,
                        color = c.textSecondary,
                    )
                }
                Spacer(Modifier.height(10.dp))
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    upcomingOpen.forEach { t ->
                        val proj = t.projectId?.let { projectMap[it] }
                        HandelhaTaskCard(
                            task = t,
                            isEnglish = isEnglish,
                            projectName = proj?.title,
                            stripeColor = proj?.let { Color(it.colorValue) },
                            onToggleComplete = { onToggleComplete(t.id) },
                            onTap = { onOpenAddTask(t) },
                            onLongPress = { actionTask = t },
                            onMorePressed = { actionTask = t },
                        )
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
            Text(
                text = if (isEnglish) "Prioritize what matters most, not what is most." else "الأولوية للأهم، مش للأكثر.",
                textAlign = TextAlign.Center,
                fontSize = 12.sp,
                color = c.textSecondary,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(14.dp))
            Button(
                onClick = { onOpenAddTask(null) },
                modifier = Modifier.fillMaxWidth().height(52.dp).testTag("tasks_add_cta"),
                shape = RoundedCornerShape(18.dp),
                colors = ButtonDefaults.buttonColors(containerColor = c.ctaBackground, contentColor = c.ctaForeground),
            ) {
                Text(if (isEnglish) "+ Add Task" else "+ إضافة مهمة", fontSize = 15.5.sp, fontWeight = FontWeight.Bold)
            }
        } else {
            Text(
                text = if (isEnglish) "${completedTasks.size} steps worth celebrating."
                else "${ArabicFormatters.toArabicDigits(completedTasks.size)} خطوات تستاهل تفرح بيها.",
                fontSize = 21.sp,
                fontWeight = FontWeight.ExtraBold,
                color = c.textPrimary,
            )
            Spacer(Modifier.height(14.dp))
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                completedTasks.forEach { t ->
                    val proj = t.projectId?.let { projectMap[it] }
                    HandelhaTaskCard(
                        task = t,
                        isEnglish = isEnglish,
                        projectName = proj?.title,
                        stripeColor = proj?.let { Color(it.colorValue) },
                        onToggleComplete = { onToggleComplete(t.id) },
                        onTap = { onOpenAddTask(t) },
                        onLongPress = { actionTask = t },
                        onMorePressed = { actionTask = t },
                    )
                }
            }
            Spacer(Modifier.height(22.dp))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(22.dp))
                    .background(c.primarySoft, RoundedCornerShape(22.dp))
                    .border(1.dp, c.primary.copy(alpha = 0.25f), RoundedCornerShape(22.dp))
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier.size(46.dp).clip(RoundedCornerShape(14.dp)).background(c.primary),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Rounded.Celebration, null, tint = c.textOnPrimary, modifier = Modifier.size(24.dp))
                }
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (isEnglish) "Awesome steady effort!" else "عاش بجد على الاستمرار!",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = c.primary,
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = if (isEnglish) "Every small completed step builds calm confidence." else "كل خطوة بتخلّصها بتبني ثقة وهدوء في يومك.",
                        fontSize = 12.5.sp,
                        color = c.textSecondary,
                    )
                }
            }
        }
    }

    if (actionTask != null) {
        val t = actionTask!!
        HandelhaBottomSheetFrame(onDismiss = { actionTask = null }) {
            Text(
                text = ArabicFormatters.trData(t.title),
                fontSize = 17.sp,
                fontWeight = FontWeight.ExtraBold,
                color = c.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(8.dp))
            ListItem(
                headlineContent = { Text(if (isEnglish) "Edit task" else "تعديل المهمة", fontWeight = FontWeight.Bold) },
                leadingContent = { Icon(Icons.Outlined.Edit, null, tint = c.primary) },
                colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                modifier = Modifier.clip(RoundedCornerShape(14.dp)).clickable {
                    actionTask = null
                    onOpenAddTask(t)
                },
            )
            ListItem(
                headlineContent = { Text(if (isEnglish) "Start focus session" else "ابدأ جلسة تركيز", fontWeight = FontWeight.Bold) },
                leadingContent = { Icon(Icons.Outlined.Timer, null, tint = c.primary) },
                colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                modifier = Modifier.clip(RoundedCornerShape(14.dp)).clickable {
                    actionTask = null
                    onStartFocus(t.id, t.title)
                },
            )
            ListItem(
                headlineContent = { Text(if (isEnglish) "Delete task" else "حذف المهمة", fontWeight = FontWeight.Bold, color = c.danger) },
                leadingContent = { Icon(Icons.Outlined.DeleteOutline, null, tint = c.danger) },
                colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                modifier = Modifier.clip(RoundedCornerShape(14.dp)).clickable {
                    actionTask = null
                    deleteConfirmTask = t
                },
            )
        }
    }

    if (deleteConfirmTask != null) {
        val t = deleteConfirmTask!!
        HandelhaConfirmDialog(
            icon = Icons.Outlined.DeleteOutline,
            title = if (isEnglish) "Delete Task?" else "حذف المهمة؟",
            message = if (isEnglish) "Permanently delete \"${ArabicFormatters.trData(t.title)}\"?" else "هل تريد حذف «${t.title}» نهائيًا؟",
            confirmLabel = if (isEnglish) "Delete" else "حذف",
            cancelLabel = if (isEnglish) "Cancel" else "إلغاء",
            isDanger = true,
            onConfirm = {
                deleteConfirmTask = null
                onDeleteTask(t.id)
            },
            onDismiss = { deleteConfirmTask = null },
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AddTaskScreen(
    editingTask: TaskItem?,
    projects: List<ProjectItem>,
    initialAlertMode: String,
    isEnglish: Boolean,
    onBack: () -> Unit,
    onAskAssistant: (String) -> Unit,
    onSave: (
        title: String,
        description: String?,
        priority: TaskPriority,
        dueAtMs: Long?,
        estimatedMinutes: Int?,
        recurrence: TaskRecurrence,
        projectId: String?,
        alertMode: String,
    ) -> Unit,
    onShowToast: (String, Boolean) -> Unit,
) {
    BackHandler(onBack = onBack)

    val c = HandelhaTheme.colors
    val context = LocalContext.current
    val isEditing = editingTask != null

    var isAssistantMode by remember { mutableStateOf(false) }
    var title by remember(editingTask) { mutableStateOf(editingTask?.title.orEmpty()) }
    var note by remember(editingTask) { mutableStateOf(editingTask?.description.orEmpty()) }
    var aiPrompt by remember { mutableStateOf("") }
    var priority by remember(editingTask) { mutableStateOf(editingTask?.priority ?: TaskPriority.medium) }
    var dueAtMs by remember(editingTask) { mutableStateOf(editingTask?.scheduledStartAtMs ?: editingTask?.dueAtMs) }
    var estMinutes by remember(editingTask) { mutableStateOf(editingTask?.estimatedDurationMinutes ?: 25) }
    var recurrence by remember(editingTask) { mutableStateOf(editingTask?.recurrence ?: TaskRecurrence.none) }
    var projectId by remember(editingTask) { mutableStateOf(editingTask?.projectId) }
    var alertMode by remember(editingTask, initialAlertMode) { mutableStateOf(initialAlertMode) }

    val substeps = remember { mutableStateListOf<String>() }
    var showSubstepInput by remember { mutableStateOf(false) }
    var substepDraft by remember { mutableStateOf("") }

    val attachments = remember { mutableStateListOf<String>() }
    var showAttachmentDialog by remember { mutableStateOf(false) }
    var attachmentDraft by remember { mutableStateOf("") }

    var showCalendarDateTimePicker by remember { mutableStateOf(false) }
    var showScheduleOptionsSheet by remember { mutableStateOf(false) }
    var showPrioritySheet by remember { mutableStateOf(false) }
    var showProjectSheet by remember { mutableStateOf(false) }

    val notifLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (!granted) {
            onShowToast(
                if (isEnglish) "Notification permission is off — you can enable it in Settings."
                else "إذن الإشعارات مقفول — تقدر تفعّله من الإعدادات في أي وقت.",
                false,
            )
        }
    }

    fun requestNotifPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
            if (!granted) {
                notifLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }

    fun formatScheduleLabel(ms: Long?): String {
        if (ms == null) return if (isEnglish) "Set schedule" else "تحديد الموعد"
        val now = Calendar.getInstance()
        val todayStart = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val target = Calendar.getInstance().apply { timeInMillis = ms }
        val targetStart = (target.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val diffDays = ((targetStart.timeInMillis - todayStart.timeInMillis) / 86_400_000L).toInt()
        val timePart = ArabicFormatters.timeOfDayAr(ms)
        return when (diffDays) {
            0 -> if (isEnglish) "Today, $timePart" else "النهارده، $timePart"
            1 -> if (isEnglish) "Tomorrow, $timePart" else "بكرة، $timePart"
            else -> "${ArabicFormatters.dateShort(ms)}، $timePart"
        }
    }

    fun priorityLabel(p: TaskPriority): String = when (p) {
        TaskPriority.low -> if (isEnglish) "Calm Priority" else "أولوية هادئة"
        TaskPriority.medium -> if (isEnglish) "Medium" else "متوسطة"
        TaskPriority.high -> if (isEnglish) "High Priority" else "أولوية عالية"
        TaskPriority.urgent -> if (isEnglish) "Urgent Priority" else "أولوية عاجلة"
    }

    fun priorityDotColor(p: TaskPriority): Color = when (p) {
        TaskPriority.low -> c.primary
        TaskPriority.medium -> c.warning
        TaskPriority.high -> Color(0xFFD97736)
        TaskPriority.urgent -> c.danger
    }

    fun priorityCardBg(p: TaskPriority): Color = when (p) {
        TaskPriority.low -> c.primarySoft
        TaskPriority.medium -> if (c.isDark) Color(0xFF2E2A1E) else Color(0xFFF7F0DC)
        TaskPriority.high -> c.warningSoft
        TaskPriority.urgent -> c.dangerSoft
    }

    fun priorityCardBorder(p: TaskPriority): Color = when (p) {
        TaskPriority.low -> c.primary.copy(alpha = 0.30f)
        TaskPriority.medium -> if (c.isDark) Color(0xFF54492A) else Color(0xFFE5D5A6)
        TaskPriority.high -> c.warning.copy(alpha = 0.45f)
        TaskPriority.urgent -> c.danger.copy(alpha = 0.45f)
    }

    fun parseAssistantDraft() {
        val raw = aiPrompt.trim()
        if (raw.isEmpty()) {
            onShowToast(
                if (isEnglish) "Write a short description of the task first"
                else "اكتب وصف سريع للمهمة الأول وهندلها هترتبهالك",
                true,
            )
            return
        }
        val cal = Calendar.getInstance()
        var parsedCal: Calendar? = null
        if (raw.contains("بكرة") || raw.contains("بكره") || raw.contains("غد")) {
            parsedCal = (cal.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 10)
                set(Calendar.MINUTE, 0)
            }
        } else if (raw.contains("النهارده") || raw.contains("اليوم")) {
            parsedCal = (cal.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, (get(Calendar.HOUR_OF_DAY) + 2).coerceIn(9, 21))
                set(Calendar.MINUTE, 0)
            }
        } else if (raw.contains("الأسبوع الجاي") || raw.contains("الاسبوع الجاي")) {
            parsedCal = (cal.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, 7)
                set(Calendar.HOUR_OF_DAY, 10)
                set(Calendar.MINUTE, 0)
            }
        }

        val normalizedDigits = raw
            .replace('٠', '0').replace('١', '1').replace('٢', '2')
            .replace('٣', '3').replace('٤', '4').replace('٥', '5')
            .replace('٦', '6').replace('٧', '7').replace('٨', '8')
            .replace('٩', '9')

        Regex("""الساعة\s*(\d{1,2})""").find(normalizedDigits)?.groupValues?.getOrNull(1)?.toIntOrNull()?.let { h ->
            val adjusted = if (h in 1..7) h + 12 else h.coerceIn(0, 23)
            val base = parsedCal ?: (cal.clone() as Calendar)
            base.set(Calendar.HOUR_OF_DAY, adjusted)
            base.set(Calendar.MINUTE, 0)
            parsedCal = base
        }

        if (raw.contains("عاجل") || raw.contains("ضروري")) {
            priority = TaskPriority.urgent
        } else if (raw.contains("مهم") || raw.contains("عالي") || raw.contains("عالية")) {
            priority = TaskPriority.high
        } else if (raw.contains("بسيط") || raw.contains("هادئ")) {
            priority = TaskPriority.low
        }

        for (d in listOf(15, 25, 45, 60, 90)) {
            if (normalizedDigits.contains("$d")) {
                estMinutes = d
                break
            }
        }

        val cleanedTitle = raw
            .replace(Regex("""(بكرة|بكره|النهارده|اليوم|الأسبوع الجاي|الاسبوع الجاي|أولوية عالية|أولوية عاجلة|أولوية هادئة)"""), "")
            .trim()

        title = cleanedTitle.ifEmpty { raw }
        if (parsedCal != null) {
            dueAtMs = parsedCal!!.timeInMillis
        }
        isAssistantMode = false
        onShowToast(
            if (isEnglish) "Task details prepared — review and save!"
            else "تم تجهيز تفاصيل المهمة تلقائيًا — راجعها واحفظ",
            false,
        )
    }

    val selectedProject = projects.firstOrNull { it.id == projectId }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, end = 20.dp, bottom = 36.dp),
    ) {
        HandelhaHeader(
            title = if (isEditing) (if (isEnglish) "Edit Task" else "تعديل المهمة") else (if (isEnglish) "Add Task" else "إضافة مهمة"),
            subtitle = if (isEnglish) "Take it step by step" else "خدها خطوة خطوة",
            isEnglish = isEnglish,
            showBack = true,
            onBack = onBack,
            padding = PaddingValues(top = 12.dp, bottom = 14.dp),
        )

        // Mode Switcher (يدوي | بمساعدة هندلها) matching add_task_screen.dart
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(c.segmentedTrackBackground)
                .padding(4.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            listOf(
                false to (if (isEnglish) "Manual" else "يدوي"),
                true to (if (isEnglish) "With Handelha" else "بمساعدة هندلها"),
            ).forEach { (assistantTab, label) ->
                val active = isAssistantMode == assistantTab
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(42.dp)
                        .clip(RoundedCornerShape(13.dp))
                        .background(if (active) c.heroCardBg else Color.Transparent)
                        .clickable { isAssistantMode = assistantTab }
                        .testTag(if (assistantTab) "add_task_mode_ai" else "add_task_mode_manual"),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = label,
                        fontSize = 13.5.sp,
                        fontWeight = if (active) FontWeight.Bold else FontWeight.Medium,
                        color = if (active) Color.White else c.textSecondary,
                    )
                }
            }
        }

        if (isAssistantMode) {
            Spacer(Modifier.height(14.dp))
            // _AssistantTaskComposerCard from add_task_screen.dart
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(18.dp))
                    .background(c.primarySoft, RoundedCornerShape(18.dp))
                    .border(1.dp, c.primary.copy(alpha = 0.25f), RoundedCornerShape(18.dp))
                    .padding(14.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.AutoAwesome, null, tint = c.primary, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = if (isEnglish) "Tell Handelha about the task in one sentence"
                        else "احكي لهندلها عن المهمة بجملة واحدة",
                        fontSize = 13.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.primary,
                        modifier = Modifier.weight(1f),
                    )
                }
                Spacer(Modifier.height(10.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(78.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(c.surface, RoundedCornerShape(12.dp))
                        .border(1.dp, c.border, RoundedCornerShape(12.dp))
                        .padding(horizontal = 12.dp, vertical = 10.dp),
                ) {
                    if (aiPrompt.isEmpty()) {
                        Text(
                            text = if (isEnglish) "e.g. Review the report tomorrow at 5 for 45 mins high priority"
                            else "مثال: مراجعة التقرير بكرة الساعة ٥ لمدة ٤٥ دقيقة أولوية عالية",
                            fontSize = 12.5.sp,
                            color = c.textMuted,
                        )
                    }
                    BasicTextField(
                        value = aiPrompt,
                        onValueChange = { aiPrompt = it },
                        textStyle = TextStyle(fontFamily = IbmPlexSansArabic, fontSize = 13.5.sp, color = c.textPrimary),
                        cursorBrush = SolidColor(c.primary),
                        modifier = Modifier.fillMaxSize().testTag("add_task_ai_input"),
                    )
                }
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = ::parseAssistantDraft,
                        modifier = Modifier.weight(1f).height(42.dp).testTag("add_task_ai_parse"),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = c.primary, contentColor = c.textOnPrimary),
                        contentPadding = PaddingValues(horizontal = 10.dp),
                    ) {
                        Icon(Icons.Rounded.AutoAwesome, null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text(
                            text = if (isEnglish) "Prepare Task Details" else "تجهيز تفاصيل المهمة",
                            fontSize = 12.5.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                    OutlinedButton(
                        onClick = { onAskAssistant(aiPrompt.trim()) },
                        modifier = Modifier.height(42.dp).testTag("add_task_ai_open_chat"),
                        shape = RoundedCornerShape(12.dp),
                        contentPadding = PaddingValues(horizontal = 12.dp),
                    ) {
                        Text(
                            text = if (isEnglish) "Open Chat" else "افتح الشات",
                            fontSize = 12.5.sp,
                            fontWeight = FontWeight.Bold,
                            color = c.primary,
                        )
                    }
                }
            }
        }

        Spacer(Modifier.height(18.dp))

        // Field 1: اسم المهمة (label outside above the box)
        Text(
            text = if (isEnglish) "Task Name" else "اسم المهمة",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = c.textSecondary,
        )
        Spacer(Modifier.height(8.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(c.surface, RoundedCornerShape(16.dp))
                .border(1.4.dp, c.activeFieldBorder, RoundedCornerShape(16.dp))
                .padding(horizontal = 16.dp, vertical = 14.dp),
        ) {
            if (title.isEmpty()) {
                Text(
                    text = if (isEnglish) "Prepare campaign ideas" else "جهّز أفكار الحملة",
                    fontSize = 15.sp,
                    color = c.textMuted,
                )
            }
            BasicTextField(
                value = title,
                onValueChange = { title = it },
                singleLine = true,
                textStyle = TextStyle(
                    fontFamily = IbmPlexSansArabic,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = c.textPrimary,
                ),
                cursorBrush = SolidColor(c.primary),
                modifier = Modifier.fillMaxWidth().testTag("add_task_title_input"),
            )
        }

        Spacer(Modifier.height(16.dp))

        // Field 2: وصف بسيط (اختياري) (label outside above the box)
        Text(
            text = if (isEnglish) "Quick Note (optional)" else "وصف بسيط (اختياري)",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = c.textSecondary,
        )
        Spacer(Modifier.height(8.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(82.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(c.surface, RoundedCornerShape(16.dp))
                .border(1.dp, c.border, RoundedCornerShape(16.dp))
                .padding(horizontal = 16.dp, vertical = 14.dp),
        ) {
            if (note.isEmpty()) {
                Text(
                    text = if (isEnglish) "Write what helps you start..." else "اكتب اللي هيساعدك تبدأ...",
                    fontSize = 14.sp,
                    color = c.textMuted,
                )
            }
            BasicTextField(
                value = note,
                onValueChange = { note = it },
                textStyle = TextStyle(
                    fontFamily = IbmPlexSansArabic,
                    fontSize = 14.5.sp,
                    color = c.textPrimary,
                ),
                cursorBrush = SolidColor(c.primary),
                modifier = Modifier.fillMaxSize().testTag("add_task_note_input"),
            )
        }

        Spacer(Modifier.height(18.dp))

        // Section: الموعد والأولوية
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = if (isEnglish) "Schedule & Priority" else "الموعد والأولوية",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = c.textSecondary,
            )
            // Quick button to also adjust duration & recurrence
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(c.primarySoft)
                    .clickable { showScheduleOptionsSheet = true }
                    .padding(horizontal = 10.dp, vertical = 4.dp)
                    .testTag("add_task_duration_recurrence_chip"),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Rounded.Schedule, null, tint = c.primary, modifier = Modifier.size(13.dp))
                Spacer(Modifier.width(4.dp))
                Text(
                    text = "${ArabicFormatters.durationMinutesFull(estMinutes)} • ${recurrenceShortLabel(recurrence, isEnglish)}",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.primary,
                )
            }
        }
        Spacer(Modifier.height(8.dp))

        // 2 side-by-side _PickerCard cards matching add_task_screen.dart
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            // Card 1: الموعد — tapping opens the full interactive Calendar + Time Wheel picker directly!
            PickerSummaryCard(
                label = if (isEnglish) "Schedule" else "الموعد",
                value = formatScheduleLabel(dueAtMs),
                background = c.surface,
                borderColor = if (dueAtMs != null) c.primary.copy(alpha = 0.45f) else c.border,
                valueColor = if (dueAtMs != null) c.primary else c.textPrimary,
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Rounded.CalendarMonth,
                        contentDescription = null,
                        tint = c.primary,
                        modifier = Modifier.size(15.dp),
                    )
                },
                onClick = { showCalendarDateTimePicker = true },
                modifier = Modifier.weight(1f).testTag("add_task_schedule_card"),
            )

            // Card 2: الأولوية
            PickerSummaryCard(
                label = if (isEnglish) "Priority" else "الأولوية",
                value = priorityLabel(priority),
                background = priorityCardBg(priority),
                borderColor = priorityCardBorder(priority),
                valueColor = c.textPrimary,
                leadingDotColor = priorityDotColor(priority),
                onClick = { showPrioritySheet = true },
                modifier = Modifier.weight(1f).testTag("add_task_priority_card"),
            )
        }

        // Reminder Alert Type Card (shown when dueAtMs != null)
        if (dueAtMs != null) {
            Spacer(Modifier.height(12.dp))
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(c.surface, RoundedCornerShape(16.dp))
                    .border(1.dp, c.border, RoundedCornerShape(16.dp))
                    .padding(12.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = if (alertMode == "alarm") Icons.Outlined.Alarm else Icons.Outlined.NotificationsActive,
                        contentDescription = null,
                        tint = if (alertMode == "alarm") c.warning else c.primary,
                        modifier = Modifier.size(18.dp),
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = if (isEnglish) "Reminder Alert Style" else "طريقة التنبيه عند الموعد",
                        fontSize = 12.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.textPrimary,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        text = if (isEnglish) "Clear date" else "إلغاء الموعد",
                        fontSize = 11.5.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = c.danger,
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .clickable { dueAtMs = null }
                            .padding(horizontal = 6.dp, vertical = 2.dp),
                    )
                }
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AlertModeChoiceButton(
                        selected = alertMode == "quiet",
                        icon = Icons.Outlined.NotificationsNone,
                        label = if (isEnglish) "Notification" else "رسالة إشعار",
                        accentColor = c.primary,
                        softBg = c.primarySoft,
                        onClick = {
                            requestNotifPermissionIfNeeded()
                            alertMode = "quiet"
                        },
                        modifier = Modifier.weight(1f),
                    )
                    AlertModeChoiceButton(
                        selected = alertMode == "alarm",
                        icon = Icons.Outlined.Alarm,
                        label = if (isEnglish) "Ringing Alarm" else "منبه يرن",
                        accentColor = c.warning,
                        softBg = c.warningSoft,
                        onClick = {
                            requestNotifPermissionIfNeeded()
                            alertMode = "alarm"
                        },
                        modifier = Modifier.weight(1f),
                    )
                }
                Spacer(Modifier.height(10.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(c.primarySoft.copy(alpha = 0.65f))
                        .padding(horizontal = 10.dp, vertical = 7.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Rounded.CheckCircleOutline, null, tint = c.primary, modifier = Modifier.size(15.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(
                        text = if (alertMode == "alarm") {
                            if (isEnglish) "Schedule alarm active — rings with sound & vibration on time"
                            else "منبه المواعيد مفعّل — ينبّهك بصوت واهتزاز في ميعاده"
                        } else {
                            if (isEnglish) "Quiet notification will arrive at the scheduled time"
                            else "سيصلك إشعار هادئ في ميعاد المهمة"
                        },
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = c.primary,
                    )
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        // Project Selector
        Text(
            text = if (isEnglish) "Project" else "المشروع",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = c.textSecondary,
        )
        Spacer(Modifier.height(8.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(c.surface, RoundedCornerShape(16.dp))
                .border(1.dp, c.border, RoundedCornerShape(16.dp))
                .clickable { showProjectSheet = true }
                .padding(horizontal = 16.dp, vertical = 14.dp)
                .testTag("add_task_project_selector"),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .width(4.dp)
                    .height(22.dp)
                    .clip(RoundedCornerShape(999.dp))
                    .background(selectedProject?.let { Color(it.colorValue) } ?: c.primary),
            )
            Spacer(Modifier.width(12.dp))
            Text(
                text = selectedProject?.let { ArabicFormatters.trData(it.title) } ?: (if (isEnglish) "No project" else "بدون مشروع"),
                fontSize = 14.5.sp,
                fontWeight = FontWeight.SemiBold,
                color = c.textPrimary,
                modifier = Modifier.weight(1f),
            )
            Icon(Icons.Rounded.KeyboardArrowDown, null, tint = c.textSecondary, modifier = Modifier.size(20.dp))
        }

        Spacer(Modifier.height(16.dp))

        // Action Pills Row (+ خطوة فرعية | + مرفق)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(44.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(c.softControlSurface, RoundedCornerShape(14.dp))
                    .border(1.dp, c.border, RoundedCornerShape(14.dp))
                    .clickable { showSubstepInput = !showSubstepInput },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = if (isEnglish) "+ Substep" else "+ خطوة فرعية",
                    fontSize = 13.5.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = c.textPrimary,
                )
            }
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(44.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(c.softControlSurface, RoundedCornerShape(14.dp))
                    .border(1.dp, c.border, RoundedCornerShape(14.dp))
                    .clickable {
                        attachmentDraft = ""
                        showAttachmentDialog = true
                    },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = if (isEnglish) "+ Attachment" else "+ مرفق",
                    fontSize = 13.5.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = c.textPrimary,
                )
            }
        }

        if (showSubstepInput || substeps.isNotEmpty()) {
            Spacer(Modifier.height(12.dp))
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(c.surface, RoundedCornerShape(16.dp))
                    .border(1.dp, c.border, RoundedCornerShape(16.dp))
                    .padding(12.dp),
            ) {
                if (showSubstepInput) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(12.dp))
                                .background(c.surfaceSoft)
                                .padding(horizontal = 12.dp, vertical = 10.dp),
                        ) {
                            if (substepDraft.isEmpty()) {
                                Text(
                                    text = if (isEnglish) "Write a small substep..." else "اكتب خطوة فرعية صغيرة...",
                                    fontSize = 13.sp,
                                    color = c.textMuted,
                                )
                            }
                            BasicTextField(
                                value = substepDraft,
                                onValueChange = { substepDraft = it },
                                singleLine = true,
                                textStyle = TextStyle(fontFamily = IbmPlexSansArabic, fontSize = 13.5.sp, color = c.textPrimary),
                                cursorBrush = SolidColor(c.primary),
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                        Spacer(Modifier.width(6.dp))
                        IconButton(
                            onClick = {
                                val clean = substepDraft.trim()
                                if (clean.isNotEmpty()) {
                                    substeps.add(clean)
                                    substepDraft = ""
                                }
                            },
                        ) {
                            Icon(Icons.Rounded.Add, null, tint = c.primary)
                        }
                    }
                }
                substeps.forEachIndexed { idx, stepText ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Rounded.CheckCircleOutline, null, tint = c.primary, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(stepText, fontSize = 13.sp, color = c.textPrimary, modifier = Modifier.weight(1f))
                        Icon(
                            imageVector = Icons.Rounded.Close,
                            contentDescription = null,
                            tint = c.textSecondary,
                            modifier = Modifier.size(16.dp).clickable { substeps.removeAt(idx) },
                        )
                    }
                }
            }
        }

        if (attachments.isNotEmpty()) {
            Spacer(Modifier.height(10.dp))
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                attachments.forEachIndexed { idx, item ->
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(c.primarySoft)
                            .padding(horizontal = 10.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Rounded.AttachFile, null, tint = c.primary, modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(4.dp))
                        Text(item, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = c.primary)
                        Spacer(Modifier.width(6.dp))
                        Icon(
                            imageVector = Icons.Rounded.Close,
                            contentDescription = null,
                            tint = c.primary,
                            modifier = Modifier.size(14.dp).clickable { attachments.removeAt(idx) },
                        )
                    }
                }
            }
        }

        Spacer(Modifier.height(14.dp))

        // Reminder quick link (+ إضافة تذكير / تذكير: ...)
        Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .clickable { showCalendarDateTimePicker = true }
                    .padding(horizontal = 12.dp, vertical = 8.dp)
                    .testTag("add_task_reminder_link"),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    imageVector = if (dueAtMs != null) Icons.Rounded.NotificationsActive else Icons.Rounded.NotificationsNone,
                    contentDescription = null,
                    tint = c.primary,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    text = if (dueAtMs != null) {
                        if (isEnglish) "Reminder: ${formatScheduleLabel(dueAtMs)}"
                        else "تذكير: ${formatScheduleLabel(dueAtMs)}"
                    } else {
                        if (isEnglish) "+ Add Reminder" else "+ إضافة تذكير"
                    },
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = c.primary,
                )
            }
        }

        Spacer(Modifier.height(22.dp))

        // Primary Save Button (احفظ المهمة / حفظ التعديلات)
        Button(
            onClick = {
                val clean = title.trim()
                if (clean.isEmpty()) {
                    onShowToast(
                        if (isEnglish) "Please write a task name first" else "اكتب اسم المهمة الأول",
                        true,
                    )
                    return@Button
                }
                if (dueAtMs != null) {
                    requestNotifPermissionIfNeeded()
                }
                val combinedNotes = buildList {
                    if (note.trim().isNotEmpty()) add(note.trim())
                    if (substeps.isNotEmpty()) {
                        add("خطوات فرعية:\n" + substeps.joinToString("\n") { "• $it" })
                    }
                    if (attachments.isNotEmpty()) {
                        add("مرفقات:\n" + attachments.joinToString("\n") { "📎 $it" })
                    }
                }.joinToString("\n\n").ifBlank { null }

                onSave(clean, combinedNotes, priority, dueAtMs, estMinutes, recurrence, projectId, alertMode)
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .testTag("add_task_save_button"),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = c.ctaBackground,
                contentColor = c.ctaForeground,
            ),
        ) {
            Text(
                text = if (isEditing) (if (isEnglish) "Save Changes" else "حفظ التعديلات") else (if (isEnglish) "Save Task" else "احفظ المهمة"),
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
            )
        }
    }

    // 1. Full Interactive Monthly Calendar + Time Wheel Picker Sheet
    if (showCalendarDateTimePicker) {
        HandelhaDateTimePickerSheet(
            mode = HandelhaPickerMode.DATE_TIME,
            initialEpochMs = dueAtMs ?: (System.currentTimeMillis() + 3600_000L),
            isEnglish = isEnglish,
            title = if (isEnglish) "Pick Task Date & Time" else "اختار تاريخ ووقت المهمة",
            onDismiss = { showCalendarDateTimePicker = false },
            onConfirm = { pickedMs ->
                dueAtMs = pickedMs
                showCalendarDateTimePicker = false
            },
        )
    }

    // 2. Schedule, Duration & Recurrence Sheet (_SchedulePickerSheet from add_task_screen.dart)
    if (showScheduleOptionsSheet) {
        HandelhaBottomSheetFrame(onDismiss = { showScheduleOptionsSheet = false }) {
            Text(
                text = if (isEnglish) "Schedule & Duration" else "الموعد والمدة",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = c.textPrimary,
            )
            Spacer(Modifier.height(14.dp))
            Text(
                text = if (isEnglish) "When will you start?" else "إمتى هتبدأ؟",
                fontSize = 12.5.sp,
                fontWeight = FontWeight.SemiBold,
                color = c.textSecondary,
            )
            Spacer(Modifier.height(8.dp))
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                ScheduleOptionChip(
                    label = if (isEnglish) "Custom Calendar & Time" else "تاريخ ووقت مخصص من التقويم",
                    selected = dueAtMs != null,
                    onClick = {
                        showScheduleOptionsSheet = false
                        showCalendarDateTimePicker = true
                    },
                )
                ScheduleOptionChip(
                    label = if (isEnglish) "No schedule" else "بدون موعد",
                    selected = dueAtMs == null,
                    onClick = { dueAtMs = null },
                )
            }

            Spacer(Modifier.height(16.dp))
            Text(
                text = if (isEnglish) "Estimated Duration" else "المدة المتوقعة",
                fontSize = 12.5.sp,
                fontWeight = FontWeight.SemiBold,
                color = c.textSecondary,
            )
            Spacer(Modifier.height(8.dp))
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                listOf(15, 25, 45, 60, 90).forEach { mins ->
                    ScheduleOptionChip(
                        label = "${ArabicFormatters.toArabicDigits(mins)} ${if (isEnglish) "m" else "د"}",
                        selected = estMinutes == mins,
                        onClick = { estMinutes = mins },
                    )
                }
            }

            Spacer(Modifier.height(16.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.Repeat, null, tint = c.primary, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text(
                    text = if (isEnglish) "Repeat" else "التكرار",
                    fontSize = 12.5.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = c.textSecondary,
                )
            }
            Spacer(Modifier.height(8.dp))
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                listOf(
                    TaskRecurrence.none to (if (isEnglish) "Once" else "مرة واحدة"),
                    TaskRecurrence.daily to (if (isEnglish) "Daily" else "يوميًا"),
                    TaskRecurrence.weekdays to (if (isEnglish) "Workdays" else "أيام العمل"),
                    TaskRecurrence.weekly to (if (isEnglish) "Weekly" else "أسبوعيًا"),
                ).forEach { (rec, lbl) ->
                    ScheduleOptionChip(
                        label = lbl,
                        selected = recurrence == rec,
                        onClick = { recurrence = rec },
                    )
                }
            }

            Spacer(Modifier.height(20.dp))
            Button(
                onClick = { showScheduleOptionsSheet = false },
                modifier = Modifier.fillMaxWidth().height(48.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = c.primary, contentColor = c.textOnPrimary),
            ) {
                Text(if (isEnglish) "Confirm" else "تأكيد", fontWeight = FontWeight.Bold)
            }
        }
    }

    // 3. Priority Sheet (_PriorityPickerSheet from add_task_screen.dart)
    if (showPrioritySheet) {
        HandelhaBottomSheetFrame(onDismiss = { showPrioritySheet = false }) {
            Text(
                text = if (isEnglish) "Choose Task Priority" else "اختار أولوية المهمة",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = c.textPrimary,
            )
            Spacer(Modifier.height(12.dp))
            listOf(
                Triple(
                    TaskPriority.low,
                    if (isEnglish) "Calm Priority" else "أولوية هادئة",
                    if (isEnglish) "For light tasks with no rush" else "للمهام الخفيفة بدون استعجال",
                ),
                Triple(
                    TaskPriority.medium,
                    if (isEnglish) "Medium" else "متوسطة",
                    if (isEnglish) "Balanced for today's normal tasks" else "متوازنة ومناسبة لليوم العادي",
                ),
                Triple(
                    TaskPriority.high,
                    if (isEnglish) "High Priority" else "أولوية عالية",
                    if (isEnglish) "Important and deserves early focus" else "مهمة وتستحق تركيز بدري",
                ),
                Triple(
                    TaskPriority.urgent,
                    if (isEnglish) "Urgent Priority" else "أولوية عاجلة",
                    if (isEnglish) "Needs immediate attention today" else "لازم تخلص النهارده في أقرب وقت",
                ),
            ).forEach { (p, lbl, sub) ->
                val active = priority == p
                val dot = priorityDotColor(p)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 8.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (active) dot.copy(alpha = 0.12f) else c.surfaceSoft)
                        .border(if (active) 1.4.dp else 1.dp, if (active) dot else c.border, RoundedCornerShape(14.dp))
                        .clickable {
                            priority = p
                            showPrioritySheet = false
                        }
                        .padding(horizontal = 14.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(modifier = Modifier.size(10.dp).clip(CircleShape).background(dot))
                    Spacer(Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(lbl, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = c.textPrimary)
                        Text(sub, fontSize = 11.5.sp, color = c.textSecondary)
                    }
                    if (active) {
                        Icon(Icons.Rounded.Check, null, tint = dot, modifier = Modifier.size(18.dp))
                    }
                }
            }
        }
    }

    // 4. Project Picker Sheet (_ProjectPickerSheet from add_task_screen.dart)
    if (showProjectSheet) {
        HandelhaBottomSheetFrame(onDismiss = { showProjectSheet = false }) {
            Text(
                text = if (isEnglish) "Link Task to Project" else "ربط المهمة بمشروع",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = c.textPrimary,
            )
            Spacer(Modifier.height(12.dp))
            ProjectChoiceTile(
                title = if (isEnglish) "No project" else "بدون مشروع",
                color = c.textMuted,
                selected = projectId == null,
                onClick = {
                    projectId = null
                    showProjectSheet = false
                },
            )
            projects.forEach { proj ->
                ProjectChoiceTile(
                    title = ArabicFormatters.trData(proj.title),
                    color = Color(proj.colorValue),
                    selected = projectId == proj.id,
                    onClick = {
                        projectId = proj.id
                        showProjectSheet = false
                    },
                )
            }
        }
    }

    // 5. Attachment Dialog
    if (showAttachmentDialog) {
        Dialog(onDismissRequest = { showAttachmentDialog = false }) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(22.dp))
                    .background(c.surface, RoundedCornerShape(22.dp))
                    .border(1.dp, c.border, RoundedCornerShape(22.dp))
                    .padding(18.dp),
            ) {
                Text(
                    text = if (isEnglish) "Add Attachment or Link" else "إضافة مرفق أو رابط مرجعي",
                    fontSize = 16.5.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.textPrimary,
                )
                Spacer(Modifier.height(12.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(c.surfaceSoft)
                        .border(1.dp, c.border, RoundedCornerShape(14.dp))
                        .padding(horizontal = 14.dp, vertical = 12.dp),
                ) {
                    if (attachmentDraft.isEmpty()) {
                        Text(
                            text = if (isEnglish) "File name or URL (e.g. Drive / Figma)" else "اسم الملف أو الرابط (مثال: ملف Drive أو Figma)",
                            fontSize = 13.sp,
                            color = c.textMuted,
                        )
                    }
                    BasicTextField(
                        value = attachmentDraft,
                        onValueChange = { attachmentDraft = it },
                        singleLine = true,
                        textStyle = TextStyle(fontFamily = IbmPlexSansArabic, fontSize = 14.sp, color = c.textPrimary),
                        cursorBrush = SolidColor(c.primary),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                Spacer(Modifier.height(14.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = { showAttachmentDialog = false }) {
                        Text(if (isEnglish) "Cancel" else "إلغاء", color = c.textSecondary)
                    }
                    Spacer(Modifier.width(6.dp))
                    Button(
                        onClick = {
                            val clean = attachmentDraft.trim()
                            if (clean.isNotEmpty()) {
                                attachments.add(clean)
                            }
                            showAttachmentDialog = false
                        },
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = c.primary, contentColor = c.textOnPrimary),
                    ) {
                        Text(if (isEnglish) "Add" else "إضافة", fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

private fun recurrenceShortLabel(recurrence: TaskRecurrence, isEnglish: Boolean): String = when (recurrence) {
    TaskRecurrence.none -> if (isEnglish) "Once" else "مرة واحدة"
    TaskRecurrence.daily -> if (isEnglish) "Daily" else "يوميًا"
    TaskRecurrence.weekdays -> if (isEnglish) "Workdays" else "أيام العمل"
    TaskRecurrence.weekly -> if (isEnglish) "Weekly" else "أسبوعيًا"
}

@Composable
private fun PickerSummaryCard(
    label: String,
    value: String,
    background: Color,
    borderColor: Color,
    valueColor: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    leadingDotColor: Color? = null,
    leadingIcon: (@Composable () -> Unit)? = null,
) {
    val c = HandelhaTheme.colors
    val shape = RoundedCornerShape(16.dp)
    Column(
        modifier = modifier
            .clip(shape)
            .background(background, shape)
            .border(1.dp, borderColor, shape)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Text(
            text = label,
            fontSize = 11.5.sp,
            color = c.textSecondary,
        )
        Spacer(Modifier.height(4.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (leadingIcon != null) {
                leadingIcon()
                Spacer(Modifier.width(6.dp))
            } else if (leadingDotColor != null) {
                Box(
                    modifier = Modifier
                        .size(7.dp)
                        .clip(CircleShape)
                        .background(leadingDotColor),
                )
                Spacer(Modifier.width(6.dp))
            }
            Text(
                text = value,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                fontSize = 13.5.sp,
                fontWeight = FontWeight.SemiBold,
                color = valueColor,
                modifier = Modifier.weight(1f),
            )
            Icon(
                imageVector = Icons.Rounded.KeyboardArrowDown,
                contentDescription = null,
                tint = c.textSecondary,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

@Composable
private fun AlertModeChoiceButton(
    selected: Boolean,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    accentColor: Color,
    softBg: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = HandelhaTheme.colors
    val shape = RoundedCornerShape(12.dp)
    Row(
        modifier = modifier
            .clip(shape)
            .background(if (selected) softBg else c.surfaceSoft, shape)
            .border(if (selected) 1.4.dp else 1.dp, if (selected) accentColor else c.border, shape)
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp, horizontal = 10.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = if (selected) accentColor else c.textSecondary,
            modifier = Modifier.size(16.dp),
        )
        Spacer(Modifier.width(6.dp))
        Text(
            text = label,
            fontSize = 12.5.sp,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
            color = if (selected) accentColor else c.textSecondary,
        )
    }
}

@Composable
private fun ScheduleOptionChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val c = HandelhaTheme.colors
    val shape = RoundedCornerShape(12.dp)
    Box(
        modifier = Modifier
            .clip(shape)
            .background(if (selected) c.primarySoft else c.surfaceSoft, shape)
            .border(if (selected) 1.4.dp else 1.dp, if (selected) c.primary else c.border, shape)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 9.dp),
    ) {
        Text(
            text = label,
            fontSize = 13.sp,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
            color = if (selected) c.primary else c.textPrimary,
        )
    }
}

@Composable
private fun ProjectChoiceTile(
    title: String,
    color: Color,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val c = HandelhaTheme.colors
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp)
            .clip(shape)
            .background(if (selected) c.primarySoft else c.surfaceSoft, shape)
            .border(if (selected) 1.4.dp else 1.dp, if (selected) c.primary else c.border, shape)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .width(4.dp)
                .height(20.dp)
                .clip(RoundedCornerShape(999.dp))
                .background(color),
        )
        Spacer(Modifier.width(12.dp))
        Text(
            text = title,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            color = c.textPrimary,
            modifier = Modifier.weight(1f),
        )
        if (selected) {
            Icon(Icons.Rounded.Check, null, tint = c.primary, modifier = Modifier.size(18.dp))
        }
    }
}

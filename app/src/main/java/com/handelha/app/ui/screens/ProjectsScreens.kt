package com.handelha.app.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarToday
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.FolderOpen
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handelha.app.domain.ProjectItem
import com.handelha.app.domain.ProjectStatus
import com.handelha.app.domain.TaskItem
import com.handelha.app.domain.UserEnergyPreferences
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
import kotlin.math.max
import kotlin.math.roundToInt

private val projectSwatches = listOf(
    0xFF1D6659L,
    0xFF7873A6L,
    0xFFC9735BL,
    0xFF5683A5L,
    0xFFC89B54L,
)

@Composable
fun ProjectsScreen(
    projects: List<ProjectItem>,
    tasks: List<TaskItem>,
    isEnglish: Boolean,
    onOpenSettings: () -> Unit,
    onOpenNewProject: () -> Unit,
    onOpenWorkspace: (ProjectItem) -> Unit,
    onOpenAssistant: () -> Unit,
) {
    val c = HandelhaTheme.colors
    var filter by remember { mutableIntStateOf(0) } // 0 = active, 1 = completed

    val activeProjects = projects.filter { it.status == ProjectStatus.active || it.status == ProjectStatus.paused }
    val completedProjects = projects.filter { it.status == ProjectStatus.completed }
    val shown = if (filter == 0) activeProjects else completedProjects

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, end = 20.dp, bottom = 114.dp),
    ) {
        HandelhaHeader(
            title = if (isEnglish) "Projects" else "المشروعات",
            isEnglish = isEnglish,
            showBack = false,
            padding = PaddingValues(top = 12.dp, bottom = 14.dp),
            actions = {
                HandelhaHeaderIconButton(
                    icon = Icons.Outlined.Settings,
                    tooltip = if (isEnglish) "Settings" else "الإعدادات",
                    onClick = onOpenSettings,
                )
            },
        )

        Text(
            text = if (isEnglish) "Your big ideas, turned into clear steps." else "أفكارك الكبيرة، خطوات واضحة.",
            fontSize = 21.sp,
            fontWeight = FontWeight.ExtraBold,
            color = c.textPrimary,
        )
        Spacer(Modifier.height(16.dp))

        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            listOf(
                0 to (if (isEnglish) "Active ${activeProjects.size}" else "نشطة ${ArabicFormatters.toArabicDigits(activeProjects.size)}"),
                1 to (if (isEnglish) "Completed" else "مكتملة"),
            ).forEach { (idx, label) ->
                val sel = filter == idx
                val pillShape = RoundedCornerShape(14.dp)
                Box(
                    modifier = Modifier
                        .then(
                            if (!c.isDark && !sel) Modifier.shadow(4.dp, pillShape, ambientColor = Color.Black.copy(alpha = 0.04f))
                            else Modifier,
                        )
                        .clip(pillShape)
                        .background(if (sel) c.primarySoft else c.surface, pillShape)
                        .then(if (sel) Modifier else Modifier.border(1.dp, c.border, pillShape))
                        .clickable { filter = idx }
                        .padding(horizontal = 22.dp, vertical = 10.dp)
                        .testTag("projects_filter_$idx"),
                ) {
                    Text(
                        text = label,
                        fontSize = 13.5.sp,
                        fontWeight = if (sel) FontWeight.Bold else FontWeight.Medium,
                        color = if (sel) c.primary else c.textSecondary,
                    )
                }
            }
        }

        Spacer(Modifier.height(18.dp))

        if (shown.isEmpty()) {
            FeatureEmptyState(
                icon = Icons.Outlined.FolderOpen,
                title = if (filter == 0) {
                    if (isEnglish) "No active projects yet?" else "لسه مفيش مشروعات نشطة؟"
                } else {
                    if (isEnglish) "No completed projects yet" else "مفيش مشروعات مكتملة لسه"
                },
                subtitle = if (isEnglish) {
                    "Break your big idea into small steps, and each step will calmly bring you closer to your goal."
                } else {
                    "قسم فكرتك الكبيرة لخطوات صغيرة، وكل خطوة هتقربك من هدفك بهدوء."
                },
                primaryCtaLabel = if (isEnglish) "+ New Project" else "+ مشروع جديد",
                onPrimaryCta = onOpenNewProject,
                secondaryCtaLabel = if (isEnglish) "Let the assistant suggest a plan" else "خلّي المساعد يقترح خطة",
                onSecondaryCta = onOpenAssistant,
            )
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                shown.forEach { proj ->
                    val linked = tasks.filter { it.projectId == proj.id && !it.isCancelled && !it.isDeleted }
                    val total = if (linked.isNotEmpty()) linked.size else proj.taskIds.size
                    val done = if (linked.isNotEmpty()) linked.count { it.isCompleted } else ((proj.progressPercent / 100.0) * total).roundToInt()
                    val pct = if (linked.isNotEmpty()) (if (total == 0) 0.0 else (done.toDouble() / total) * 100.0) else proj.progressPercent
                    val projColor = Color(proj.colorValue)
                    val cardShape = RoundedCornerShape(22.dp)

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .then(
                                if (!c.isDark) Modifier.shadow(6.dp, cardShape, ambientColor = Color.Black.copy(alpha = 0.05f), spotColor = Color.Black.copy(alpha = 0.05f))
                                else Modifier,
                            )
                            .clip(cardShape)
                            .background(c.surface, cardShape)
                            .border(1.dp, c.border, cardShape)
                            .clickable { onOpenWorkspace(proj) }
                            .padding(start = 16.dp, top = 18.dp, end = 18.dp, bottom = 18.dp)
                            .testTag("project_card_${proj.id}"),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Outlined.FolderOpen, null, tint = projColor, modifier = Modifier.size(24.dp))
                                Spacer(Modifier.width(10.dp))
                                Text(
                                    text = ArabicFormatters.trData(proj.title),
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = c.textPrimary,
                                )
                            }
                            Spacer(Modifier.height(6.dp))
                            Text(
                                text = "${ArabicFormatters.countOf(done, total)} • ${ArabicFormatters.percent(pct)}",
                                fontSize = 13.sp,
                                color = c.textSecondary,
                            )
                            Spacer(Modifier.height(12.dp))
                            LinearProgressIndicator(
                                progress = { (pct / 100.0).toFloat().coerceIn(0f, 1f) },
                                modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(999.dp)),
                                color = projColor,
                                trackColor = c.surfaceMuted,
                            )
                        }
                        Spacer(Modifier.width(14.dp))
                        Box(
                            modifier = Modifier
                                .width(4.dp)
                                .height(44.dp)
                                .clip(RoundedCornerShape(999.dp))
                                .background(projColor),
                        )
                    }
                }
            }
            Spacer(Modifier.height(24.dp))
            Button(
                onClick = onOpenNewProject,
                modifier = Modifier.fillMaxWidth().height(54.dp).testTag("projects_new_button"),
                shape = RoundedCornerShape(18.dp),
                colors = ButtonDefaults.buttonColors(containerColor = c.primary, contentColor = c.textOnPrimary),
            ) {
                Text(if (isEnglish) "+ New Project" else "+ مشروع جديد", fontSize = 16.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
fun NewProjectScreen(
    isEnglish: Boolean,
    onBack: () -> Unit,
    onCreateProject: (title: String, goal: String?, targetDateMs: Long?, colorValue: Long, starterStep: String?) -> Unit,
    onShowToast: (String, Boolean) -> Unit,
) {
    BackHandler(onBack = onBack)

    val c = HandelhaTheme.colors
    var title by remember { mutableStateOf("") }
    var goal by remember { mutableStateOf("") }
    var starterStep by remember { mutableStateOf("") }
    var showFirstStepField by remember { mutableStateOf(false) }
    var selectedColorIdx by remember { mutableIntStateOf(0) }
    var targetDateMs by remember { mutableStateOf<Long?>(null) }
    var showTargetDatePresetsSheet by remember { mutableStateOf(false) }
    var showCustomCalendarPicker by remember { mutableStateOf(false) }

    val selectedColor = projectSwatches[selectedColorIdx]
    val previewTitle = title.trim().ifEmpty { if (isEnglish) "Give your project a clear name" else "سمّي مشروعك باسم واضح" }
    val targetLabel = targetDateMs?.let { ArabicFormatters.dateShort(it) } ?: if (isEnglish) "Not set" else "غير محدد"

    Column(
        modifier = Modifier
            .fillMaxSize()
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, end = 20.dp, bottom = 36.dp),
    ) {
        HandelhaHeader(
            title = if (isEnglish) "New Project" else "مشروع جديد",
            subtitle = if (isEnglish) "Break your big idea into clear steps" else "قسّم فكرتك الكبيرة لخطوات واضحة",
            isEnglish = isEnglish,
            showBack = true,
            onBack = onBack,
            padding = PaddingValues(top = 10.dp, bottom = 14.dp),
        )

        // Hero Preview Banner matching lib/features/projects/presentation/new_project_screen.dart
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(22.dp))
                .background(c.heroCardBg, RoundedCornerShape(22.dp))
                .then(if (c.isDark) Modifier.border(1.dp, c.heroBannerBorder, RoundedCornerShape(22.dp)) else Modifier)
                .padding(horizontal = 18.dp, vertical = 16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(Color(selectedColor).copy(alpha = 0.25f))
                        .border(1.2.dp, c.limeAccent.copy(alpha = 0.7f), RoundedCornerShape(14.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Outlined.FolderOpen, null, tint = c.limeAccent, modifier = Modifier.size(22.dp))
                }
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (isEnglish) "Every big project starts with an idea." else "كل مشروع كبير بيبدأ بفكرة.",
                        fontSize = 11.5.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color.White.copy(alpha = 0.72f),
                    )
                    Spacer(Modifier.height(3.dp))
                    Text(
                        text = previewTitle,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        fontSize = 16.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                    )
                }
                Spacer(Modifier.width(8.dp))
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(c.limeAccent)
                        .padding(horizontal = 10.dp, vertical = 5.dp),
                ) {
                    Text(
                        text = if (isEnglish) "Preview" else "معاينة",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.limeAccentInk,
                    )
                }
            }
        }

        Spacer(Modifier.height(18.dp))

        // Section Header: تفاصيل المشروع + toggle button for أول خطوة
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = if (isEnglish) "Project Details" else "تفاصيل المشروع",
                fontSize = 16.5.sp,
                fontWeight = FontWeight.Bold,
                color = c.textPrimary,
            )
            Box(
                modifier = Modifier
                    .size(34.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(c.primarySoft)
                    .clickable { showFirstStepField = !showFirstStepField },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = if (showFirstStepField) Icons.Rounded.Remove else Icons.Rounded.Add,
                    contentDescription = if (isEnglish) "Add First Step" else "إضافة أول خطوة",
                    tint = c.primary,
                    modifier = Modifier.size(18.dp),
                )
            }
        }

        Spacer(Modifier.height(10.dp))

        // اسم المشروع (Active field border matching new_project_screen.dart)
        val fieldShape = RoundedCornerShape(20.dp)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .then(
                    if (!c.isDark) Modifier.shadow(5.dp, fieldShape, ambientColor = Color.Black.copy(alpha = 0.04f))
                    else Modifier,
                )
                .clip(fieldShape)
                .background(c.surface, fieldShape)
                .border(1.4.dp, c.activeFieldBorder, fieldShape)
                .padding(horizontal = 18.dp, vertical = 14.dp),
        ) {
            Text(
                text = if (isEnglish) "Project Name" else "اسم المشروع",
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                color = if (c.isDark) c.limeAccent else c.primary,
            )
            Spacer(Modifier.height(4.dp))
            Box {
                if (title.isEmpty()) {
                    Text(
                        text = if (isEnglish) "e.g. Launch personal website" else "مثال: إطلاق الموقع الشخصي",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        color = c.textMuted,
                    )
                }
                BasicTextField(
                    value = title,
                    onValueChange = { title = it },
                    textStyle = TextStyle(fontFamily = IbmPlexSansArabic, fontSize = 16.5.sp, fontWeight = FontWeight.SemiBold, color = c.textPrimary),
                    cursorBrush = SolidColor(c.primary),
                    modifier = Modifier.fillMaxWidth().testTag("new_project_title_input"),
                )
            }
        }

        Spacer(Modifier.height(12.dp))

        // عايز توصل لإيه؟
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .then(
                    if (!c.isDark) Modifier.shadow(5.dp, fieldShape, ambientColor = Color.Black.copy(alpha = 0.04f))
                    else Modifier,
                )
                .clip(fieldShape)
                .background(c.surface, fieldShape)
                .border(1.dp, c.border, fieldShape)
                .padding(horizontal = 18.dp, vertical = 14.dp),
        ) {
            Text(
                text = if (isEnglish) "What do you want to achieve?" else "عايز توصل لإيه؟",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = c.textSecondary,
            )
            Spacer(Modifier.height(4.dp))
            Box {
                if (goal.isEmpty()) {
                    Text(
                        text = if (isEnglish) "Write the main goal in a short sentence..." else "اكتب الهدف الأساسي في جملة قصيرة...",
                        fontSize = 14.sp,
                        color = c.textMuted,
                    )
                }
                BasicTextField(
                    value = goal,
                    onValueChange = { goal = it },
                    textStyle = TextStyle(fontFamily = IbmPlexSansArabic, fontSize = 14.5.sp, color = c.textPrimary),
                    cursorBrush = SolidColor(c.primary),
                    modifier = Modifier.fillMaxWidth().height(54.dp).testTag("new_project_goal_input"),
                )
            }
        }

        if (showFirstStepField) {
            Spacer(Modifier.height(12.dp))
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .then(
                        if (!c.isDark) Modifier.shadow(5.dp, fieldShape, ambientColor = Color.Black.copy(alpha = 0.04f))
                        else Modifier,
                    )
                    .clip(fieldShape)
                    .background(c.surface, fieldShape)
                    .border(1.dp, c.border, fieldShape)
                    .padding(horizontal = 18.dp, vertical = 12.dp),
            ) {
                Text(
                    text = if (isEnglish) "First Step (optional)" else "أول خطوة (اختياري)",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = c.textSecondary,
                )
                Spacer(Modifier.height(4.dp))
                Box {
                    if (starterStep.isEmpty()) {
                        Text(
                            text = if (isEnglish) "e.g. Define core pages" else "مثال: تحديد الصفحات الأساسية",
                            fontSize = 14.sp,
                            color = c.textMuted,
                        )
                    }
                    BasicTextField(
                        value = starterStep,
                        onValueChange = { starterStep = it },
                        textStyle = TextStyle(fontFamily = IbmPlexSansArabic, fontSize = 14.5.sp, color = c.textPrimary),
                        cursorBrush = SolidColor(c.primary),
                        modifier = Modifier.fillMaxWidth().testTag("new_project_step_input"),
                    )
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        // لون يميّزه (Rounded-square 46.dp color swatches matching new_project_screen.dart)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .then(
                    if (!c.isDark) Modifier.shadow(5.dp, fieldShape, ambientColor = Color.Black.copy(alpha = 0.04f))
                    else Modifier,
                )
                .clip(fieldShape)
                .background(c.surface, fieldShape)
                .border(1.dp, c.border, fieldShape)
                .padding(16.dp),
        ) {
            Text(
                text = if (isEnglish) "Distinctive Color" else "لون يميّزه",
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = c.textPrimary,
            )
            Spacer(Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                projectSwatches.forEachIndexed { idx, col ->
                    val selected = idx == selectedColorIdx
                    Box(
                        modifier = Modifier
                            .size(46.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(Color(col), RoundedCornerShape(14.dp))
                            .then(
                                if (selected) {
                                    Modifier.border(
                                        width = 2.5.dp,
                                        color = if (c.isDark) c.limeAccent else c.textPrimary,
                                        shape = RoundedCornerShape(14.dp),
                                    )
                                } else {
                                    Modifier
                                },
                            )
                            .clickable { selectedColorIdx = idx },
                        contentAlignment = Alignment.Center,
                    ) {
                        if (selected) {
                            Icon(Icons.Rounded.Check, null, tint = Color.White, modifier = Modifier.size(20.dp))
                        }
                    }
                }
            }
        }

        Spacer(Modifier.height(12.dp))

        // موعد مستهدف (اختياري) matching new_project_screen.dart
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .then(
                    if (!c.isDark) Modifier.shadow(5.dp, fieldShape, ambientColor = Color.Black.copy(alpha = 0.04f))
                    else Modifier,
                )
                .clip(fieldShape)
                .background(c.surface, fieldShape)
                .border(1.dp, c.border, fieldShape)
                .clickable { showTargetDatePresetsSheet = true }
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(38.dp)
                    .clip(RoundedCornerShape(11.dp))
                    .background(c.primarySoft),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Outlined.CalendarToday,
                    contentDescription = null,
                    tint = if (c.isDark) c.limeAccent else c.primary,
                    modifier = Modifier.size(19.dp),
                )
            }
            Spacer(Modifier.width(12.dp))
            Text(
                text = if (isEnglish) "Target Date (optional)" else "موعد مستهدف (اختياري)",
                fontSize = 14.5.sp,
                fontWeight = FontWeight.SemiBold,
                color = c.textPrimary,
                modifier = Modifier.weight(1f),
            )
            Text(
                text = targetLabel,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (targetDateMs != null) (if (c.isDark) c.limeAccent else c.primary) else c.textSecondary,
            )
            Spacer(Modifier.width(4.dp))
            Icon(
                imageVector = if (isEnglish) Icons.Rounded.ChevronRight else Icons.Rounded.ChevronLeft,
                contentDescription = null,
                tint = c.textMuted,
                modifier = Modifier.size(18.dp),
            )
        }

        Spacer(Modifier.height(22.dp))

        Button(
            onClick = {
                val clean = title.trim()
                if (clean.isEmpty()) {
                    onShowToast(if (isEnglish) "Write a project name first" else "اكتب اسم المشروع الأول", true)
                } else {
                    onCreateProject(clean, goal.trim().ifBlank { null }, targetDateMs, selectedColor, starterStep.trim().ifBlank { null })
                }
            },
            modifier = Modifier.fillMaxWidth().height(54.dp).testTag("new_project_save_button"),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(containerColor = c.ctaBackground, contentColor = c.ctaForeground),
        ) {
            Text(if (isEnglish) "Create Project" else "إنشاء المشروع", fontSize = 16.5.sp, fontWeight = FontWeight.Bold)
        }
    }

    if (showTargetDatePresetsSheet) {
        val now = System.currentTimeMillis()
        val presets = listOf(
            (if (isEnglish) "In 1 week" else "بعد أسبوع") to (now + 7L * 86_400_000L),
            (if (isEnglish) "In 2 weeks" else "بعد أسبوعين") to (now + 14L * 86_400_000L),
            (if (isEnglish) "In 1 month" else "بعد شهر") to (now + 30L * 86_400_000L),
            (if (isEnglish) "In 3 months" else "بعد ٣ شهور") to (now + 90L * 86_400_000L),
        )
        HandelhaBottomSheetFrame(onDismiss = { showTargetDatePresetsSheet = false }) {
            Text(
                text = if (isEnglish) "Target Date" else "موعد مستهدف",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = c.textPrimary,
            )
            Spacer(Modifier.height(10.dp))
            presets.forEach { (label, ms) ->
                ListItem(
                    headlineContent = { Text(label, fontWeight = FontWeight.SemiBold, color = c.textPrimary) },
                    trailingContent = { Text(ArabicFormatters.dateShort(ms), fontSize = 12.sp, color = c.textSecondary) },
                    colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .clickable {
                            targetDateMs = ms
                            showTargetDatePresetsSheet = false
                        },
                )
            }
            ListItem(
                leadingContent = { Icon(Icons.Rounded.CalendarMonth, null, tint = c.primary) },
                headlineContent = {
                    Text(
                        text = if (isEnglish) "Pick from calendar" else "اختر من التقويم",
                        fontWeight = FontWeight.Bold,
                        color = c.primary,
                    )
                },
                colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .clickable {
                        showTargetDatePresetsSheet = false
                        showCustomCalendarPicker = true
                    },
            )
            if (targetDateMs != null) {
                ListItem(
                    leadingContent = { Icon(Icons.Rounded.Close, null, tint = c.danger) },
                    headlineContent = {
                        Text(
                            text = if (isEnglish) "Clear target date" else "بدون موعد محدد",
                            color = c.danger,
                            fontWeight = FontWeight.SemiBold,
                        )
                    },
                    colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .clickable {
                            targetDateMs = null
                            showTargetDatePresetsSheet = false
                        },
                )
            }
        }
    }

    if (showCustomCalendarPicker) {
        HandelhaDateTimePickerSheet(
            mode = HandelhaPickerMode.DATE_ONLY,
            initialEpochMs = targetDateMs ?: (System.currentTimeMillis() + 14L * 86_400_000L),
            isEnglish = isEnglish,
            title = if (isEnglish) "Pick Project Target Date" else "اختار التاريخ المستهدف للمشروع",
            showFuturePresets = true,
            onDismiss = { showCustomCalendarPicker = false },
            onConfirm = { pickedMs ->
                targetDateMs = pickedMs
                showCustomCalendarPicker = false
            },
        )
    }
}

@Composable
fun ProjectWorkspaceScreen(
    project: ProjectItem,
    allTasks: List<TaskItem>,
    energyPrefs: UserEnergyPreferences,
    isEnglish: Boolean,
    onBack: () -> Unit,
    onAddStep: (String) -> Unit,
    onSmartBreakdown: () -> Unit,
    onToggleTask: (String) -> Unit,
    onEditTask: (TaskItem) -> Unit,
    onDeleteProject: () -> Unit,
) {
    BackHandler(onBack = onBack)

    val c = HandelhaTheme.colors
    val projectColor = Color(project.colorValue)
    val linked = remember(allTasks, project.id) {
        allTasks.filter { it.projectId == project.id && !it.isCancelled && !it.isDeleted }
    }
    val open = linked.filter { !it.isCompleted }
    val done = linked.filter { it.isCompleted }
    val total = linked.size
    val pct = if (total == 0) project.progressPercent else (done.size.toDouble() / total.toDouble()) * 100.0
    val ratio = (pct / 100.0).toFloat().coerceIn(0f, 1f)

    val daysRemaining = project.targetDateMs?.let { target ->
        val diff = target - System.currentTimeMillis()
        max(0, (diff / 86_400_000L).toInt())
    }
    val statusLabel = when (project.status) {
        ProjectStatus.completed -> if (isEnglish) "Completed" else "مكتمل"
        ProjectStatus.paused -> if (isEnglish) "Paused" else "متوقف مؤقتًا"
        else -> if (isEnglish) "Active now" else "شغال دلوقتي"
    }
    val metaLine = buildList {
        if (!project.description.isNullOrBlank()) {
            add(ArabicFormatters.trData(project.description.trim()))
        } else {
            add(if (isEnglish) "Work" else "شغل")
        }
        if (project.targetDateMs != null) {
            add("${if (isEnglish) "Due" else "تسليم"} ${ArabicFormatters.dateShort(project.targetDateMs)}")
        } else if (daysRemaining != null) {
            add("${ArabicFormatters.toArabicDigits(daysRemaining)} ${if (isEnglish) "days left" else "يوم فاضل"}")
        } else {
            add(if (isEnglish) "Calm steps" else "خطوات هادية")
        }
    }.joinToString(" • ")

    var tab by remember { mutableIntStateOf(0) } // 0 = next steps, 1 = overview
    var showAddStepSheet by remember { mutableStateOf(false) }
    var newStepTitle by remember { mutableStateOf("") }
    var showDeleteConfirm by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, end = 20.dp, bottom = 36.dp),
    ) {
        HandelhaHeader(
            title = if (isEnglish) "Project Details" else "تفاصيل المشروع",
            subtitle = if (isEnglish) "Take it step by step" else "خدها خطوة خطوة",
            isEnglish = isEnglish,
            showBack = true,
            onBack = onBack,
            padding = PaddingValues(top = 10.dp, bottom = 14.dp),
            actions = {
                HandelhaHeaderIconButton(
                    icon = Icons.Outlined.DeleteOutline,
                    tooltip = if (isEnglish) "Delete Project" else "حذف المشروع",
                    iconColor = c.danger,
                    onClick = { showDeleteConfirm = true },
                    testTag = "project_delete_button",
                )
            },
        )

        // Hero Banner Card matching lib/features/projects/presentation/project_workspace_screen.dart
        val totalSegments = 8
        val activeSegments = (ratio * totalSegments).roundToInt().coerceIn(if (ratio > 0f) 1 else 0, totalSegments)

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(c.heroCardBg, RoundedCornerShape(24.dp))
                .then(if (c.isDark) Modifier.border(1.dp, c.heroBannerBorder, RoundedCornerShape(24.dp)) else Modifier)
                .padding(18.dp),
        ) {
            Row(verticalAlignment = Alignment.Top) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = ArabicFormatters.trData(project.title),
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        fontSize = 21.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = Color.White,
                        lineHeight = 27.sp,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = metaLine,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        fontSize = 12.sp,
                        color = Color.White.copy(alpha = 0.76f),
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
                        text = statusLabel,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.limeAccentInk,
                    )
                }
            }

            Spacer(Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = if (isEnglish) "Overall Progress" else "التقدم الكلي",
                    fontSize = 12.sp,
                    color = Color.White.copy(alpha = 0.78f),
                )
                Text(
                    text = ArabicFormatters.percent(pct),
                    fontSize = 13.5.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = c.limeAccent,
                )
            }
            Spacer(Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                for (i in 0 until totalSegments) {
                    val lit = i < activeSegments
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(6.dp)
                            .clip(RoundedCornerShape(999.dp))
                            .background(if (lit) c.limeAccent else Color.White.copy(alpha = 0.16f)),
                    )
                }
            }
        }

        Spacer(Modifier.height(14.dp))

        // 3 KPI Metric Cards matching project_workspace_screen.dart
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            MetricMiniCard(
                value = ArabicFormatters.toArabicDigits(done.size),
                label = if (isEnglish) "Done Tasks" else "مهام مكتملة",
                valueColor = if (c.isDark) c.limeAccent else c.primary,
                modifier = Modifier.weight(1f),
            )
            MetricMiniCard(
                value = ArabicFormatters.toArabicDigits(open.size),
                label = if (isEnglish) "Open Tasks" else "مهام مفتوحة",
                valueColor = c.secondary,
                modifier = Modifier.weight(1f),
            )
            MetricMiniCard(
                value = if (daysRemaining != null) ArabicFormatters.toArabicDigits(daysRemaining) else "—",
                label = if (isEnglish) "Days Left" else "يوم متبقي",
                valueColor = c.textPrimary,
                modifier = Modifier.weight(1f),
            )
        }

        Spacer(Modifier.height(16.dp))

        // Segmented Tab Bar ("الخطوات اللي جاية" | "نظرة عامة") matching _WorkspaceTabPill
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(c.segmentedTrackBackground)
                .padding(4.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            listOf(
                0 to (if (isEnglish) "Next Steps" else "الخطوات اللي جاية"),
                1 to (if (isEnglish) "Overview" else "نظرة عامة"),
            ).forEach { (idx, label) ->
                val sel = tab == idx
                val pillShape = RoundedCornerShape(12.dp)
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(40.dp)
                        .then(
                            if (sel && !c.isDark) {
                                Modifier.shadow(6.dp, pillShape, ambientColor = Color.Black.copy(alpha = 0.06f))
                            } else {
                                Modifier
                            },
                        )
                        .clip(pillShape)
                        .background(if (sel) c.segmentedActiveBackground else Color.Transparent, pillShape)
                        .clickable { tab = idx },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = label,
                        fontSize = 13.sp,
                        fontWeight = if (sel) FontWeight.Bold else FontWeight.Medium,
                        color = if (sel) (if (c.isDark) Color.White else c.primary) else c.textSecondary,
                    )
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        if (tab == 0) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = { showAddStepSheet = true },
                    modifier = Modifier.weight(1f).height(48.dp).testTag("workspace_add_step_btn"),
                    shape = RoundedCornerShape(15.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = c.ctaBackground, contentColor = c.ctaForeground),
                ) {
                    Icon(Icons.Rounded.Add, null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(if (isEnglish) "Add Step" else "أضف خطوة", fontWeight = FontWeight.Bold, fontSize = 13.5.sp)
                }
                OutlinedButton(
                    onClick = onSmartBreakdown,
                    modifier = Modifier.weight(1f).height(48.dp).testTag("workspace_smart_breakdown_btn"),
                    shape = RoundedCornerShape(15.dp),
                ) {
                    Icon(Icons.Rounded.AutoAwesome, null, tint = c.primary, modifier = Modifier.size(17.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(if (isEnglish) "Smart Split" else "تقسيم ذكي", fontWeight = FontWeight.Bold, fontSize = 13.5.sp, color = c.primary)
                }
            }

            Spacer(Modifier.height(14.dp))

            if (linked.isEmpty()) {
                FeatureEmptyState(
                    title = if (isEnglish) "No steps yet" else "لسه مفيش خطوات",
                    subtitle = if (isEnglish) "Add a quick step or tap Smart Split to break this project into ${energyPrefs.preferredSessionMinutes}m calm blocks."
                    else "ضيف أول خطوة أو اضغط تقسيم ذكي عشان نقسّمه على جلسات ${ArabicFormatters.toArabicDigits(energyPrefs.preferredSessionMinutes)} دقيقة.",
                    primaryCtaLabel = if (isEnglish) "Smart Split for My Energy" else "قسّمه على قد طاقتي ⚡",
                    onPrimaryCta = onSmartBreakdown,
                )
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    linked.forEach { task ->
                        HandelhaTaskCard(
                            task = task,
                            isEnglish = isEnglish,
                            projectName = project.title,
                            stripeColor = projectColor,
                            onToggleComplete = { onToggleTask(task.id) },
                            onTap = { onEditTask(task) },
                        )
                    }
                }
            }
        } else {
            val overviewShape = RoundedCornerShape(22.dp)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .then(
                        if (!c.isDark) Modifier.shadow(6.dp, overviewShape, ambientColor = Color.Black.copy(alpha = 0.05f))
                        else Modifier,
                    )
                    .clip(overviewShape)
                    .background(c.surface, overviewShape)
                    .border(1.dp, c.border, overviewShape)
                    .padding(18.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text(
                    text = if (isEnglish) "Project Goal" else "هدف المشروع",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = c.textPrimary,
                )
                Text(
                    text = project.description ?: if (isEnglish) "Steady progress one small step at a time." else "تقدّم هادي خطوة واحدة في المرة.",
                    fontSize = 13.5.sp,
                    color = c.textSecondary,
                    lineHeight = 20.sp,
                )
                if (project.targetDateMs != null) {
                    Text(
                        text = if (isEnglish) "Target: ${ArabicFormatters.dateFull(project.targetDateMs)}"
                        else "الميعاد المستهدف: ${ArabicFormatters.dateFull(project.targetDateMs)}",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.primary,
                    )
                }
                Text(
                    text = if (isEnglish) "Energy Fit: ${energyPrefs.peakLabel(true)} (${energyPrefs.preferredSessionMinutes}m blocks)"
                    else "توافق الطاقة: ${energyPrefs.peakLabel(false)} (جلسات ${ArabicFormatters.toArabicDigits(energyPrefs.preferredSessionMinutes)} د)",
                    fontSize = 12.5.sp,
                    color = c.textSecondary,
                )
            }
        }
    }

    if (showAddStepSheet) {
        HandelhaBottomSheetFrame(onDismiss = { showAddStepSheet = false }) {
            Text(if (isEnglish) "Add Step to Project" else "إضافة خطوة للمشروع", fontSize = 17.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
            Spacer(Modifier.height(12.dp))
            ProjectField(
                label = if (isEnglish) "Step Title" else "اسم الخطوة",
                hint = if (isEnglish) "e.g. Draft initial outline" else "مثال: مراجعة مسودة الفصل الأول",
                value = newStepTitle,
                onValueChange = { newStepTitle = it },
                testTag = "workspace_step_input",
            )
            Spacer(Modifier.height(14.dp))
            Button(
                onClick = {
                    val clean = newStepTitle.trim()
                    if (clean.isNotEmpty()) {
                        onAddStep(clean)
                        newStepTitle = ""
                        showAddStepSheet = false
                    }
                },
                modifier = Modifier.fillMaxWidth().height(48.dp).testTag("workspace_step_save"),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = c.ctaBackground, contentColor = c.ctaForeground),
            ) {
                Text(if (isEnglish) "Add Step" else "إضافة", fontWeight = FontWeight.Bold)
            }
        }
    }

    if (showDeleteConfirm) {
        HandelhaConfirmDialog(
            icon = Icons.Outlined.DeleteOutline,
            title = if (isEnglish) "Delete Project?" else "حذف المشروع؟",
            message = if (isEnglish) "Delete \"${ArabicFormatters.trData(project.title)}\"?" else "هل تريد حذف مشروع «${project.title}»؟",
            confirmLabel = if (isEnglish) "Delete" else "حذف",
            cancelLabel = if (isEnglish) "Cancel" else "إلغاء",
            isDanger = true,
            onConfirm = {
                showDeleteConfirm = false
                onDeleteProject()
            },
            onDismiss = { showDeleteConfirm = false },
        )
    }
}

@Composable
private fun MetricMiniCard(
    value: String,
    label: String,
    valueColor: Color,
    modifier: Modifier = Modifier,
) {
    val c = HandelhaTheme.colors
    val shape = RoundedCornerShape(18.dp)
    Column(
        modifier = modifier
            .then(
                if (!c.isDark) Modifier.shadow(5.dp, shape, ambientColor = Color.Black.copy(alpha = 0.04f))
                else Modifier,
            )
            .clip(shape)
            .background(c.surface, shape)
            .border(1.dp, c.border, shape)
            .padding(vertical = 12.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(value, fontSize = 19.sp, fontWeight = FontWeight.ExtraBold, color = valueColor)
        Spacer(Modifier.height(3.dp))
        Text(label, fontSize = 11.sp, color = c.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun ProjectField(
    label: String,
    hint: String,
    value: String,
    onValueChange: (String) -> Unit,
    testTag: String,
) {
    val c = HandelhaTheme.colors
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(c.surfaceSoft, RoundedCornerShape(16.dp))
            .border(1.dp, c.border, RoundedCornerShape(16.dp))
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Text(label, fontSize = 11.5.sp, fontWeight = FontWeight.Bold, color = c.textSecondary)
        Spacer(Modifier.height(4.dp))
        Box {
            if (value.isEmpty()) Text(hint, fontSize = 14.sp, color = c.textMuted)
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                textStyle = TextStyle(fontFamily = IbmPlexSansArabic, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = c.textPrimary),
                cursorBrush = SolidColor(c.primary),
                modifier = Modifier.fillMaxWidth().testTag(testTag),
            )
        }
    }
}

package com.handelha.app.ui.screens

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
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.School
import androidx.compose.material.icons.rounded.Spa
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.material.icons.rounded.FormatQuote
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.handelha.app.data.repo.ActivityBucket
import com.handelha.app.data.repo.AnalyticsGranularity
import com.handelha.app.data.repo.ProductivityReport
import com.handelha.app.domain.AppUser
import com.handelha.app.domain.ExamGradeEntry
import com.handelha.app.domain.ExamGradesHelper
import com.handelha.app.domain.FocusSessionItem
import com.handelha.app.domain.ProjectItem
import com.handelha.app.domain.TaskItem
import com.handelha.app.domain.TaskPriority
import com.handelha.app.ui.components.FeatureEmptyState
import com.handelha.app.ui.components.HandelhaBottomSheetFrame
import com.handelha.app.ui.components.HandelhaHeader
import com.handelha.app.ui.components.HandelhaHeaderIconButton
import com.handelha.app.ui.theme.HandelhaTheme
import com.handelha.app.ui.theme.IbmPlexSansArabic
import com.handelha.app.util.ArabicFormatters
import java.util.Locale

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TrackingScreen(
    user: AppUser?,
    tasks: List<TaskItem>,
    projects: List<ProjectItem>,
    focusSessions: List<FocusSessionItem>,
    examGrades: List<ExamGradeEntry>,
    isStudentMode: Boolean,
    isEnglish: Boolean,
    onOpenSettings: () -> Unit,
    onOpenAddTask: () -> Unit,
    onOpenSubscription: () -> Unit,
    onOpenStudentQuotes: () -> Unit = {},
    onAddExamGrade: (title: String, tier: String, score: String, onAdded: (ExamGradeEntry) -> Unit) -> Unit,
    onDeleteExamGrade: (String) -> Unit,
) {
    val c = HandelhaTheme.colors
    var granularity by remember { mutableStateOf(AnalyticsGranularity.week) }
    var logFilter by remember { mutableIntStateOf(0) } // 0=all, 1=tasks, 2=focus
    var showAllDetails by remember { mutableStateOf(false) }

    var showGradeSheet by remember { mutableStateOf(false) }
    var celebratedGrade by remember { mutableStateOf<ExamGradeEntry?>(null) }

    val report = remember(tasks, focusSessions, projects, granularity, user, isStudentMode, isEnglish) {
        ProductivityReport.build(
            tasks = tasks,
            sessions = focusSessions,
            projects = projects,
            granularity = granularity,
            firstName = user?.firstName ?: "صديقي",
            isStudentMode = isStudentMode,
            isEnglish = isEnglish,
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, end = 20.dp, bottom = 118.dp),
    ) {
        HandelhaHeader(
            title = if (isEnglish) "Your Progress" else "إنجازك",
            subtitle = if (isEnglish) "Track your days, weeks, and months clearly" else "تتابع أيامك وأسابيعك وشهورك بوضوح",
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

        if (isStudentMode) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .shadow(10.dp, RoundedCornerShape(20.dp), ambientColor = c.studentIndigo.copy(alpha = 0.22f))
                    .clip(RoundedCornerShape(20.dp))
                    .background(Brush.linearGradient(listOf(c.studentIndigo, c.studentTeal)))
                    .padding(14.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Rounded.School, null, tint = Color.White, modifier = Modifier.size(22.dp))
                    Spacer(Modifier.width(10.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = if (isEnglish) "Student Mode Active" else "وضع الطالب مفعّل",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = Color.White,
                        )
                        Text(
                            text = if (isEnglish) "Books, scientific studies, study quotes & exam records"
                            else "حِكم وكتب وأبحاث علمية، مود المذاكرة، وسجل تقديراتك",
                            fontSize = 11.5.sp,
                            color = Color.White.copy(alpha = 0.88f),
                        )
                    }
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(Color.White.copy(alpha = 0.2f))
                            .clickable(onClick = onOpenStudentQuotes)
                            .padding(horizontal = 10.dp, vertical = 7.dp)
                            .testTag("tracking_open_quotes_button"),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Rounded.FormatQuote, null, tint = Color.White, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text(
                            text = if (isEnglish) "Quotes Hub" else "مكتبة الحِكم",
                            fontSize = 11.5.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = Color.White,
                        )
                    }
                }
            }
            Spacer(Modifier.height(14.dp))
        }

        // Day | Week | Months Granularity Switcher
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(c.surface, RoundedCornerShape(18.dp))
                .border(1.dp, c.border, RoundedCornerShape(18.dp))
                .padding(4.dp),
        ) {
            listOf(
                AnalyticsGranularity.day to (if (isEnglish) "Day" else "اليوم"),
                AnalyticsGranularity.week to (if (isEnglish) "Week" else "الأسبوع"),
                AnalyticsGranularity.month to (if (isEnglish) "Months" else "الشهور"),
            ).forEach { (g, label) ->
                val sel = granularity == g
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(40.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (sel) c.primary else Color.Transparent)
                        .clickable { granularity = g; showAllDetails = false }
                        .testTag("tracking_gran_${g.name}"),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = label,
                        fontSize = 13.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (sel) Color.White else c.textSecondary,
                    )
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        // Gradient Hero Summary Card
        val scopeTitle = when (granularity) {
            AnalyticsGranularity.day -> if (isEnglish) "Today's Harvest" else "حصاد النهارده"
            AnalyticsGranularity.week -> if (isEnglish) "Weekly Performance" else "أداء الأسبوع"
            AnalyticsGranularity.month -> if (isEnglish) "Last 6 Months Progress" else "إنجاز آخر ٦ شهور"
        }
        val stats = report.periodStats

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .shadow(16.dp, RoundedCornerShape(24.dp), ambientColor = c.primary.copy(alpha = 0.24f))
                .clip(RoundedCornerShape(24.dp))
                .background(Brush.linearGradient(listOf(c.primary, c.primaryStrong)))
                .padding(20.dp),
        ) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text(scopeTitle, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.85f))
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(Color.White.copy(alpha = 0.16f))
                        .padding(horizontal = 10.dp, vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = if (report.currentStreakDays > 0) Icons.Rounded.LocalFireDepartment else Icons.Rounded.Spa,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(15.dp),
                    )
                    Spacer(Modifier.width(5.dp))
                    Text(
                        text = if (report.currentStreakDays > 0) {
                            if (isEnglish) "${report.currentStreakDays}-day streak" else "سلسلة ${ArabicFormatters.toArabicDigits(report.currentStreakDays)} أيام"
                        } else {
                            if (isEnglish) "Calm pace" else "إيقاع هادي"
                        },
                        fontSize = 11.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                    )
                }
            }

            Spacer(Modifier.height(10.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.Center) {
                Text(
                    text = if (isEnglish) "${stats.completedTasks} completed tasks"
                    else "${ArabicFormatters.toArabicDigits(stats.completedTasks)} مهام مكتملة",
                    fontSize = 24.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = Color.White,
                )
                Text(
                    text = if (isEnglish) "out of ${stats.totalTasks}" else "من أصل ${ArabicFormatters.toArabicDigits(stats.totalTasks)}",
                    fontSize = 13.sp,
                    color = Color.White.copy(alpha = 0.82f),
                    modifier = Modifier.padding(top = 8.dp),
                )
            }

            Spacer(Modifier.height(14.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                HeroStatChip(ArabicFormatters.durationCompact(stats.focusMinutes), if (isEnglish) "Focus" else "تركيز", Modifier.weight(1f))
                HeroStatChip(ArabicFormatters.toArabicDigits(stats.completedFocusSessions), if (isEnglish) "Sessions" else "جلسات", Modifier.weight(1f))
                HeroStatChip(ArabicFormatters.percent(stats.completionRate * 100.0), if (isEnglish) "Done Rate" else "نسبة الإنجاز", Modifier.weight(1f))
            }
        }

        Spacer(Modifier.height(16.dp))

        if (!report.overallStats.hasData) {
            FeatureEmptyState(
                icon = Icons.Rounded.BarChart,
                title = if (isEnglish) "Your progress is just getting started" else "إنجازاتك لسه في بدايتها",
                subtitle = if (isEnglish) "The first task you finish or focus session you start will build your progress charts and reports right here."
                else "أول مهمة تخلصها أو جلسة تركيز تبدأها هتبني رسومات وتقارير التتابع الخاصة بيك هنا.",
                primaryCtaLabel = if (isEnglish) "Add First Task" else "إضافة أول مهمة",
                onPrimaryCta = onOpenAddTask,
            )
            Spacer(Modifier.height(16.dp))
        } else {
            // Interactive Bar Charts per Granularity
            when (granularity) {
                AnalyticsGranularity.day -> InteractiveBucketChartCard(
                    title = if (isEnglish) "Daily Time Slots" else "تتابع فترات اليوم",
                    subtitle = if (isEnglish) "Your activity today across hours of the day" else "نشاطك النهارده متوزع على ساعات اليوم",
                    buckets = report.dayTimeSlots,
                    barColor = c.primary,
                    isEnglish = isEnglish,
                    highlightBadge = report.peakTimeSlotLabel?.let { if (isEnglish) "Peak: $it" else "ذروتك: $it" },
                )
                AnalyticsGranularity.week -> {
                    InteractiveBucketChartCard(
                        title = if (isEnglish) "Weekly Day Progress" else "تتابع أيام الأسبوع",
                        subtitle = if (isEnglish) "Last 7 days • Focus & completed tasks" else "آخر ٧ أيام • دقائق التركيز والمهام المكتملة",
                        buckets = report.weekDayBuckets,
                        barColor = c.primary,
                        isEnglish = isEnglish,
                        highlightBadge = report.peakDayLabel?.let { if (isEnglish) "Most active: $it" else "أنشط يوم: $it" },
                    )
                    Spacer(Modifier.height(14.dp))
                    InteractiveBucketChartCard(
                        title = if (isEnglish) "Last 4 Weeks Comparison" else "مقارنة آخر ٤ أسابيع",
                        subtitle = if (isEnglish) "Your week-to-week consistency" else "صورة أوسع لاستمراريتك من أسبوع للتاني",
                        buckets = report.rollingWeekBuckets,
                        barColor = c.lavenderAccent,
                        isEnglish = isEnglish,
                    )
                }
                AnalyticsGranularity.month -> {
                    InteractiveBucketChartCard(
                        title = if (isEnglish) "Monthly Progress (Last 6 Months)" else "تتابع الشهور (آخر ٦ شهور)",
                        subtitle = if (isEnglish) "vs last month: ${report.monthDeltaTasks} tasks • ${report.monthDeltaMinutes}m"
                        else "مقارنة بالشهر اللي فات: ${ArabicFormatters.toArabicDigits(report.monthDeltaTasks)} مهام • ${ArabicFormatters.toArabicDigits(report.monthDeltaMinutes)} د",
                        buckets = report.monthBuckets,
                        barColor = c.primary,
                        isEnglish = isEnglish,
                    )
                }
            }

            Spacer(Modifier.height(16.dp))

            // Real Insights Card (2x2 KPIs + Project breakdowns + Priority breakdown)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(22.dp))
                    .background(c.surface, RoundedCornerShape(22.dp))
                    .border(1.dp, c.border, RoundedCornerShape(22.dp))
                    .padding(16.dp),
            ) {
                Text(if (isEnglish) "Real Progress Insights" else "مؤشرات حقيقية لإنجازك", fontSize = 16.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    InsightKpiTile(
                        value = ArabicFormatters.toArabicDigits(report.bestStreakDays),
                        label = if (isEnglish) "Best Streak (d)" else "أطول سلسلة (أيام)",
                        modifier = Modifier.weight(1f),
                    )
                    InsightKpiTile(
                        value = ArabicFormatters.durationMinutes(report.avgFocusSessionMinutes),
                        label = if (isEnglish) "Avg Focus Block" else "متوسط جلسة التركيز",
                        modifier = Modifier.weight(1f),
                    )
                }
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    InsightKpiTile(
                        value = String.format(Locale.US, "%.1f", report.avgTasksPerActiveDay),
                        label = if (isEnglish) "Tasks / Active Day" else "متوسط مهام اليوم",
                        modifier = Modifier.weight(1f),
                    )
                    InsightKpiTile(
                        value = ArabicFormatters.toArabicDigits(report.overallStats.completedTasks),
                        label = if (isEnglish) "All-Time Done" else "إجمالي المهام",
                        modifier = Modifier.weight(1f),
                    )
                }

                if (report.projectBreakdowns.isNotEmpty()) {
                    Spacer(Modifier.height(14.dp))
                    Text(if (isEnglish) "By Project" else "حسب المشروعات", fontSize = 13.5.sp, fontWeight = FontWeight.Bold, color = c.textPrimary)
                    Spacer(Modifier.height(8.dp))
                    report.projectBreakdowns.take(4).forEach { pb ->
                        Column(modifier = Modifier.padding(vertical = 4.dp)) {
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Text(pb.title, fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, color = c.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                                Text("${ArabicFormatters.toArabicDigits(pb.completedTasks)}/${ArabicFormatters.toArabicDigits(pb.totalTasks)}", fontSize = 12.sp, color = c.textSecondary)
                            }
                            Spacer(Modifier.height(4.dp))
                            LinearProgressIndicator(
                                progress = { pb.completionRate.toFloat() },
                                modifier = Modifier.fillMaxWidth().height(5.dp).clip(RoundedCornerShape(999.dp)),
                                color = Color(pb.colorValue),
                                trackColor = c.surfaceSoft,
                            )
                        }
                    }
                }
            }
        }

        Spacer(Modifier.height(14.dp))

        // Encouragement Banner
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(22.dp))
                .background(c.primarySoft, RoundedCornerShape(22.dp))
                .border(1.dp, c.primary.copy(alpha = 0.25f), RoundedCornerShape(22.dp))
                .padding(16.dp),
        ) {
            Text(report.encouragementTitle, fontSize = 16.sp, fontWeight = FontWeight.ExtraBold, color = c.primary)
            Spacer(Modifier.height(4.dp))
            Text(report.encouragementSubtitle, fontSize = 13.sp, color = c.textSecondary, lineHeight = 20.sp)
        }

        Spacer(Modifier.height(14.dp))

        // Milestones Grid Card
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(22.dp))
                .background(c.surface, RoundedCornerShape(22.dp))
                .border(1.dp, c.border, RoundedCornerShape(22.dp))
                .padding(16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.EmojiEvents, null, tint = c.primary, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Text(if (isEnglish) "Achievement Milestones" else "أوسمة الإنجاز", fontSize = 16.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
            }
            Spacer(Modifier.height(12.dp))
            report.milestones.chunked(2).forEach { pair ->
                Row(modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    pair.forEach { m ->
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(16.dp))
                                .background(if (m.unlocked) c.primarySoft else c.surfaceSoft)
                                .border(1.dp, if (m.unlocked) c.primary.copy(alpha = 0.35f) else c.border, RoundedCornerShape(16.dp))
                                .padding(12.dp),
                        ) {
                            Text(m.title, fontSize = 13.sp, fontWeight = FontWeight.ExtraBold, color = if (m.unlocked) c.primary else c.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Spacer(Modifier.height(2.dp))
                            Text(m.subtitle, fontSize = 11.sp, color = c.textSecondary, maxLines = 2, minLines = 2)
                            Spacer(Modifier.height(6.dp))
                            LinearProgressIndicator(
                                progress = { m.progressRatio },
                                modifier = Modifier.fillMaxWidth().height(4.dp).clip(RoundedCornerShape(999.dp)),
                                color = if (m.unlocked) c.primary else c.textMuted,
                                trackColor = c.surface,
                            )
                            Spacer(Modifier.height(4.dp))
                            Text(m.progressLabel, fontSize = 10.5.sp, fontWeight = FontWeight.Bold, color = if (m.unlocked) c.primary else c.textSecondary)
                        }
                    }
                    if (pair.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        }

        // Student Mode Exam Grades Card
        if (isStudentMode) {
            Spacer(Modifier.height(16.dp))
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(22.dp))
                    .background(c.surface, RoundedCornerShape(22.dp))
                    .border(1.dp, c.studentIndigo.copy(alpha = 0.25f), RoundedCornerShape(22.dp))
                    .padding(16.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                        Icon(Icons.Rounded.School, null, tint = c.studentIndigo, modifier = Modifier.size(22.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = if (isEnglish) "Exam Grades & Record" else "تقديرات الامتحانات",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = c.textPrimary,
                        )
                    }
                    Button(
                        onClick = { showGradeSheet = true },
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = c.studentIndigo, contentColor = Color.White),
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                        modifier = Modifier.testTag("add_exam_grade_button"),
                    ) {
                        Icon(Icons.Rounded.Add, null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text(if (isEnglish) "Add Grade" else "سجّل تقدير", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }
                Spacer(Modifier.height(10.dp))
                if (examGrades.isEmpty()) {
                    Text(
                        text = if (isEnglish) "Record quizzes, midterms, or finals to celebrate every academic milestone."
                        else "سجّل نتائج الكويزات والميدتيرم أو الفاينل واحتفل بتعبك هنا.",
                        fontSize = 13.sp,
                        color = c.textSecondary,
                    )
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        examGrades.forEach { g ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(14.dp))
                                    .background(c.studentIndigoSoft)
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text("${g.examTitle} • ${g.scoreLabel}", fontSize = 13.5.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
                                    Spacer(Modifier.height(2.dp))
                                    Text(if (isEnglish) g.encouragementEn else g.encouragementAr, fontSize = 12.sp, color = c.textSecondary)
                                }
                                IconButton(onClick = { onDeleteExamGrade(g.id) }) {
                                    Icon(Icons.Outlined.DeleteOutline, null, tint = c.danger, modifier = Modifier.size(19.dp))
                                }
                            }
                        }
                    }
                }
            }
        }

        // Activity Details Log
        if (report.overallStats.hasData) {
            Spacer(Modifier.height(16.dp))
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(22.dp))
                    .background(c.surface, RoundedCornerShape(22.dp))
                    .border(1.dp, c.border, RoundedCornerShape(22.dp))
                    .padding(16.dp),
            ) {
                Text(if (isEnglish) "Activity Log" else "سجل الإنجازات", fontSize = 16.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(
                        0 to (if (isEnglish) "All" else "الكل"),
                        1 to (if (isEnglish) "Tasks" else "مهام"),
                        2 to (if (isEnglish) "Focus" else "تركيز"),
                    ).forEach { (idx, lbl) ->
                        val sel = logFilter == idx
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(12.dp))
                                .background(if (sel) c.primarySoft else c.surfaceSoft)
                                .clickable { logFilter = idx }
                                .padding(horizontal = 14.dp, vertical = 7.dp),
                        ) {
                            Text(lbl, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = if (sel) c.primary else c.textSecondary)
                        }
                    }
                }
                Spacer(Modifier.height(10.dp))
                val combined = buildList {
                    if (logFilter == 0 || logFilter == 1) {
                        report.periodCompletedTasks.forEach { t ->
                            add(Triple(t.updatedAtMs, true, ArabicFormatters.trData(t.title)))
                        }
                    }
                    if (logFilter == 0 || logFilter == 2) {
                        report.periodSessions.forEach { s ->
                            add(Triple(s.endedAtMs, false, "${ArabicFormatters.trData(s.taskTitle)} (${ArabicFormatters.durationMinutes(s.elapsedMinutes)})"))
                        }
                    }
                }.sortedByDescending { it.first }
                val shownLogs = if (showAllDetails) combined else combined.take(5)
                shownLogs.forEach { (stamp, isTask, title) ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = if (isTask) Icons.Rounded.CheckCircle else Icons.Rounded.Timer,
                            contentDescription = null,
                            tint = if (isTask) c.primary else c.lavenderAccent,
                            modifier = Modifier.size(18.dp),
                        )
                        Spacer(Modifier.width(10.dp))
                        Text(title, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = c.textPrimary, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(ArabicFormatters.dateShort(stamp), fontSize = 11.5.sp, color = c.textSecondary)
                    }
                }
                if (combined.size > 5) {
                    TextButton(onClick = { showAllDetails = !showAllDetails }) {
                        Text(if (showAllDetails) (if (isEnglish) "Show less" else "عرض أقل") else (if (isEnglish) "Show all" else "عرض الكل"))
                    }
                }
            }
        }
    }

    if (showGradeSheet) {
        var examTitle by remember { mutableStateOf("") }
        var scoreLabel by remember { mutableStateOf("") }
        var gradeTier by remember { mutableStateOf("excellent") }

        HandelhaBottomSheetFrame(onDismiss = { showGradeSheet = false }) {
            Text(if (isEnglish) "Record Exam Grade" else "تسجيل تقدير امتحان", fontSize = 17.5.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
            Spacer(Modifier.height(12.dp))
            GradeSheetInput(
                label = if (isEnglish) "Subject / Exam" else "المادة / الامتحان",
                hint = if (isEnglish) "e.g. Organic Chemistry Midterm" else "مثال: ميدتيرم كيمياء",
                value = examTitle,
                onValueChange = { examTitle = it },
                testTag = "exam_title_input",
            )
            Spacer(Modifier.height(10.dp))
            GradeSheetInput(
                label = if (isEnglish) "Score / Grade" else "الدرجة أو التقدير",
                hint = if (isEnglish) "e.g. 95% / A+" else "مثال: ٩٥٪ أو امتياز",
                value = scoreLabel,
                onValueChange = { scoreLabel = it },
                testTag = "exam_score_input",
            )
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf(
                    "excellent" to (if (isEnglish) "Excellent" else "امتياز"),
                    "very_good" to (if (isEnglish) "Very Good" else "جيد جدًا"),
                    "good" to (if (isEnglish) "Good" else "جيد"),
                    "pass" to (if (isEnglish) "Pass" else "مقبول"),
                ).forEach { (tier, lbl) ->
                    val sel = gradeTier == tier
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (sel) c.studentIndigo else c.surfaceSoft)
                            .clickable { gradeTier = tier }
                            .padding(vertical = 9.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(lbl, fontSize = 11.5.sp, fontWeight = FontWeight.Bold, color = if (sel) Color.White else c.textPrimary)
                    }
                }
            }
            Spacer(Modifier.height(14.dp))
            Button(
                onClick = {
                    val t = examTitle.trim().ifEmpty { if (isEnglish) "Exam" else "امتحان" }
                    val s = scoreLabel.trim().ifEmpty {
                        when (gradeTier) {
                            "excellent" -> if (isEnglish) "A+" else "امتياز"
                            "very_good" -> if (isEnglish) "B+" else "جيد جدًا"
                            "good" -> if (isEnglish) "B" else "جيد"
                            else -> if (isEnglish) "Pass" else "مقبول"
                        }
                    }
                    onAddExamGrade(t, gradeTier, s) { created ->
                        showGradeSheet = false
                        celebratedGrade = created
                    }
                },
                modifier = Modifier.fillMaxWidth().height(48.dp).testTag("exam_save_button"),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = c.studentIndigo, contentColor = Color.White),
            ) {
                Text(if (isEnglish) "Save & Celebrate" else "حفظ واحتفال", fontWeight = FontWeight.ExtraBold)
            }
        }
    }

    if (celebratedGrade != null) {
        val g = celebratedGrade!!
        val badge = ExamGradesHelper.buildEncouragement(g.examTitle, g.gradeTier, g.scoreLabel)
        Dialog(onDismissRequest = { celebratedGrade = null }) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(26.dp))
                    .background(c.surface, RoundedCornerShape(26.dp))
                    .padding(22.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Box(
                    modifier = Modifier.size(56.dp).clip(CircleShape).background(c.studentIndigoSoft),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Rounded.EmojiEvents, null, tint = c.studentIndigo, modifier = Modifier.size(30.dp))
                }
                Spacer(Modifier.height(12.dp))
                Text(if (isEnglish) badge.badgeEn else badge.badgeAr, fontSize = 17.sp, fontWeight = FontWeight.ExtraBold, color = c.studentIndigo, textAlign = TextAlign.Center)
                Spacer(Modifier.height(8.dp))
                Text(if (isEnglish) g.encouragementEn else g.encouragementAr, fontSize = 13.5.sp, color = c.textSecondary, textAlign = TextAlign.Center, lineHeight = 20.sp)
                Spacer(Modifier.height(16.dp))
                Button(
                    onClick = { celebratedGrade = null },
                    modifier = Modifier.fillMaxWidth().height(46.dp),
                    shape = RoundedCornerShape(14.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = c.studentIndigo, contentColor = Color.White),
                ) {
                    Text(if (isEnglish) "Thank you!" else "شكرًا!", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun HeroStatChip(value: String, label: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.14f))
            .padding(vertical = 10.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(value, fontSize = 16.sp, fontWeight = FontWeight.ExtraBold, color = Color.White)
        Text(label, fontSize = 11.sp, color = Color.White.copy(alpha = 0.85f), maxLines = 1)
    }
}

@Composable
private fun InsightKpiTile(value: String, label: String, modifier: Modifier = Modifier) {
    val c = HandelhaTheme.colors
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(c.surfaceSoft)
            .padding(12.dp),
    ) {
        Text(value, fontSize = 19.sp, fontWeight = FontWeight.ExtraBold, color = c.primary)
        Spacer(Modifier.height(2.dp))
        Text(label, fontSize = 11.5.sp, color = c.textSecondary)
    }
}

@Composable
private fun InteractiveBucketChartCard(
    title: String,
    subtitle: String,
    buckets: List<ActivityBucket>,
    barColor: Color,
    isEnglish: Boolean,
    highlightBadge: String? = null,
) {
    val c = HandelhaTheme.colors
    var selectedIdx by remember(buckets) {
        mutableIntStateOf(buckets.indexOfLast { it.isCurrent }.takeIf { it >= 0 } ?: 0)
    }
    val maxScore = remember(buckets) { (buckets.maxOfOrNull { it.combinedScore } ?: 1).coerceAtLeast(1) }
    val picked = buckets.getOrNull(selectedIdx)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(c.surface, RoundedCornerShape(22.dp))
            .border(1.dp, c.border, RoundedCornerShape(22.dp))
            .padding(16.dp),
    ) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(title, fontSize = 15.5.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
                Text(subtitle, fontSize = 11.5.sp, color = c.textSecondary)
            }
            if (highlightBadge != null) {
                Box(modifier = Modifier.clip(RoundedCornerShape(999.dp)).background(c.primarySoft).padding(horizontal = 10.dp, vertical = 4.dp)) {
                    Text(highlightBadge, fontSize = 11.sp, fontWeight = FontWeight.Bold, color = c.primary)
                }
            }
        }
        Spacer(Modifier.height(14.dp))

        Row(
            modifier = Modifier.fillMaxWidth().height(120.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            buckets.forEachIndexed { idx, bucket ->
                val ratio = (bucket.combinedScore.toFloat() / maxScore.toFloat()).coerceIn(0.08f, 1f)
                val sel = idx == selectedIdx
                Column(
                    modifier = Modifier.weight(1f).fillMaxHeight().clickable { selectedIdx = idx },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Bottom,
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(0.65f)
                            .fillMaxHeight(ratio * 0.78f)
                            .clip(RoundedCornerShape(topStart = 8.dp, topEnd = 8.dp))
                            .background(if (sel) barColor else barColor.copy(alpha = 0.35f)),
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        text = bucket.label,
                        fontSize = 10.sp,
                        fontWeight = if (sel) FontWeight.ExtraBold else FontWeight.Medium,
                        color = if (sel) barColor else c.textSecondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }

        if (picked != null) {
            Spacer(Modifier.height(10.dp))
            Row(
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(c.surfaceSoft).padding(horizontal = 12.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(picked.rangeLabel, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = c.textPrimary)
                Text(
                    text = if (isEnglish) "${picked.completedTasks} tasks • ${picked.focusMinutes}m focus"
                    else "${ArabicFormatters.toArabicDigits(picked.completedTasks)} مهام • ${ArabicFormatters.durationMinutes(picked.focusMinutes)}",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.primary,
                )
            }
        }
    }
}

@Composable
private fun GradeSheetInput(label: String, hint: String, value: String, onValueChange: (String) -> Unit, testTag: String) {
    val c = HandelhaTheme.colors
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(c.surfaceSoft, RoundedCornerShape(14.dp))
            .border(1.dp, c.border, RoundedCornerShape(14.dp))
            .padding(12.dp),
    ) {
        Text(label, fontSize = 11.5.sp, fontWeight = FontWeight.Bold, color = c.textSecondary)
        Spacer(Modifier.height(4.dp))
        Box {
            if (value.isEmpty()) Text(hint, fontSize = 13.5.sp, color = c.textMuted)
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                textStyle = TextStyle(fontFamily = IbmPlexSansArabic, fontSize = 14.5.sp, color = c.textPrimary),
                cursorBrush = SolidColor(c.primary),
                modifier = Modifier.fillMaxWidth().testTag(testTag),
            )
        }
    }
}

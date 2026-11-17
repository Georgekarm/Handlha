package com.handelha.app.data.repo

import com.handelha.app.domain.FocusSessionItem
import com.handelha.app.domain.ProjectItem
import com.handelha.app.domain.ProjectStatus
import com.handelha.app.domain.TaskItem
import com.handelha.app.domain.TaskPriority
import com.handelha.app.util.ArabicFormatters
import java.util.Calendar
import kotlin.math.roundToInt

enum class AnalyticsGranularity { day, week, month }

data class ProductivityAnalyticsSummary(
    val totalTasks: Int,
    val completedTasks: Int,
    val overdueTasks: Int,
    val focusMinutes: Int,
    val completedFocusSessions: Int,
) {
    val completionRate: Double
        get() = if (totalTasks == 0) 0.0 else completedTasks.toDouble() / totalTasks.toDouble()

    val hasData: Boolean
        get() = totalTasks > 0 || focusMinutes > 0

    companion object {
        fun from(
            tasks: List<TaskItem>,
            sessions: List<FocusSessionItem>,
            nowMs: Long = System.currentTimeMillis(),
        ): ProductivityAnalyticsSummary = ProductivityAnalyticsSummary(
            totalTasks = tasks.count { !it.isCancelled },
            completedTasks = tasks.count { it.isCompleted },
            overdueTasks = tasks.count {
                !it.isCompleted && !it.isCancelled && it.dueAtMs != null && it.dueAtMs < nowMs
            },
            focusMinutes = sessions.sumOf { it.elapsedMinutes },
            completedFocusSessions = sessions.count { it.completed },
        )
    }
}

data class ActivityBucket(
    val label: String,
    val rangeLabel: String,
    val completedTasks: Int,
    val focusMinutes: Int,
    val sessionsCount: Int,
    val isCurrent: Boolean = false,
) {
    val combinedScore: Int get() = focusMinutes + (completedTasks * 20)
}

data class ProjectBreakdown(
    val projectId: String,
    val title: String,
    val colorValue: Long,
    val completedTasks: Int,
    val totalTasks: Int,
) {
    val completionRate: Double
        get() = if (totalTasks == 0) 0.0 else (completedTasks.toDouble() / totalTasks).coerceIn(0.0, 1.0)
}

enum class MilestoneIconKind {
    firstStep,
    deepFocus,
    marathon,
    streak,
    tenTasks,
    finisher,
    hardTaskCrusher,
    examHero,
}

data class AchievementMilestone(
    val id: String,
    val title: String,
    val subtitle: String,
    val progressLabel: String,
    val progressRatio: Float,
    val unlocked: Boolean,
    val iconKind: MilestoneIconKind,
)

data class ProductivityReport(
    val granularity: AnalyticsGranularity,
    val periodStats: ProductivityAnalyticsSummary,
    val overallStats: ProductivityAnalyticsSummary,
    val dayTimeSlots: List<ActivityBucket>,
    val weekDayBuckets: List<ActivityBucket>,
    val rollingWeekBuckets: List<ActivityBucket>,
    val monthBuckets: List<ActivityBucket>,
    val currentStreakDays: Int,
    val bestStreakDays: Int,
    val avgFocusSessionMinutes: Int,
    val avgTasksPerActiveDay: Double,
    val peakDayLabel: String?,
    val peakTimeSlotLabel: String?,
    val monthDeltaTasks: Int,
    val monthDeltaMinutes: Int,
    val projectBreakdowns: List<ProjectBreakdown>,
    val priorityCompletedCounts: Map<TaskPriority, Int>,
    val milestones: List<AchievementMilestone>,
    val periodCompletedTasks: List<TaskItem>,
    val periodSessions: List<FocusSessionItem>,
    val encouragementTitle: String,
    val encouragementSubtitle: String,
) {
    companion object {
        fun build(
            tasks: List<TaskItem>,
            sessions: List<FocusSessionItem>,
            projects: List<ProjectItem>,
            granularity: AnalyticsGranularity,
            firstName: String = "صديقي",
            isStudentMode: Boolean = false,
            isEnglish: Boolean = false,
            nowMs: Long = System.currentTimeMillis(),
        ): ProductivityReport {
            ArabicFormatters.useEnglish = isEnglish
            val calToday = Calendar.getInstance().apply {
                timeInMillis = nowMs
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val todayStartMs = calToday.timeInMillis
            val tomorrowStartMs = todayStartMs + 86_400_000L
            val activeTasks = tasks.filter { !it.isCancelled && !it.isDeleted }

            val periodStartMs = when (granularity) {
                AnalyticsGranularity.day -> todayStartMs
                AnalyticsGranularity.week -> todayStartMs - 6L * 86_400_000L
                AnalyticsGranularity.month -> {
                    Calendar.getInstance().apply {
                        timeInMillis = todayStartMs
                        add(Calendar.MONTH, -5)
                        set(Calendar.DAY_OF_MONTH, 1)
                    }.timeInMillis
                }
            }

            val periodTasks = activeTasks.filter { t ->
                val stamp = if (t.isCompleted) t.updatedAtMs else (t.scheduledStartAtMs ?: t.dueAtMs ?: t.updatedAtMs)
                if (granularity == AnalyticsGranularity.day) {
                    if (t.isCompleted) {
                        t.updatedAtMs in todayStartMs until tomorrowStartMs
                    } else {
                        val planned = t.scheduledStartAtMs ?: t.dueAtMs
                        planned == null || planned < tomorrowStartMs
                    }
                } else {
                    stamp in periodStartMs until tomorrowStartMs
                }
            }

            val periodSessions = sessions
                .filter { it.endedAtMs in periodStartMs until tomorrowStartMs }
                .sortedByDescending { it.endedAtMs }

            val periodCompletedTasks = periodTasks
                .filter { it.isCompleted }
                .sortedByDescending { it.updatedAtMs }

            val overallStats = ProductivityAnalyticsSummary.from(activeTasks, sessions, nowMs)
            val periodStats = ProductivityAnalyticsSummary.from(periodTasks, periodSessions, nowMs)

            val completedAll = activeTasks.filter { it.isCompleted }
            val dayTimeSlots = buildDayTimeSlots(completedAll, sessions, todayStartMs, tomorrowStartMs, isEnglish)
            val weekDayBuckets = buildWeekDayBuckets(completedAll, sessions, todayStartMs)
            val rollingWeekBuckets = buildRollingWeekBuckets(completedAll, sessions, todayStartMs, isEnglish)
            val monthBuckets = buildMonthBuckets(completedAll, sessions, nowMs)

            val (curStreak, bestStreak) = computeStreaks(completedAll, sessions, todayStartMs)

            val avgFocus = if (periodSessions.isEmpty()) 0
            else (periodStats.focusMinutes.toDouble() / periodSessions.size).roundToInt()

            val activeDays = HashSet<String>().apply {
                periodCompletedTasks.forEach { add(dayKey(it.updatedAtMs)) }
                periodSessions.forEach { add(dayKey(it.endedAtMs)) }
            }
            val avgPerDay = if (activeDays.isEmpty()) 0.0
            else periodCompletedTasks.size.toDouble() / activeDays.size.toDouble()

            val peakDay = weekDayBuckets.filter { it.combinedScore > 0 }.maxByOrNull { it.combinedScore }?.label
            val peakSlot = dayTimeSlots.filter { it.combinedScore > 0 }.maxByOrNull { it.combinedScore }?.label

            val curMonth = monthBuckets.last()
            val prevMonth = monthBuckets[monthBuckets.size - 2]

            val projectBreakdowns = buildProjectBreakdowns(activeTasks, projects, isEnglish)
            val priorityCounts = TaskPriority.entries.associateWith { p ->
                periodCompletedTasks.count { it.priority == p }
            }

            val completedProjectsCount = projects.count {
                it.status == ProjectStatus.completed || it.progressPercent >= 100.0
            }
            val hardCompletedCount = activeTasks.count {
                it.isCompleted && (it.priority == TaskPriority.high || it.priority == TaskPriority.urgent)
            }
            val examRegex = Regex("(امتحان|اختبار|كويز|exam|quiz)", RegexOption.IGNORE_CASE)
            val examsCompletedCount = activeTasks.count { it.isCompleted && examRegex.containsMatchIn(it.title) }

            val milestones = buildMilestones(
                overallStats = overallStats,
                bestStreak = bestStreak,
                completedProjectsCount = completedProjectsCount,
                completedHardTasksCount = hardCompletedCount,
                completedExamsCount = examsCompletedCount,
                isStudentMode = isStudentMode,
                isEnglish = isEnglish,
            )

            val (encTitle, encSub) = buildEncouragement(
                firstName = firstName,
                granularity = granularity,
                periodStats = periodStats,
                overallStats = overallStats,
                streak = curStreak,
                peakDayLabel = peakDay,
                isEnglish = isEnglish,
            )

            return ProductivityReport(
                granularity = granularity,
                periodStats = periodStats,
                overallStats = overallStats,
                dayTimeSlots = dayTimeSlots,
                weekDayBuckets = weekDayBuckets,
                rollingWeekBuckets = rollingWeekBuckets,
                monthBuckets = monthBuckets,
                currentStreakDays = curStreak,
                bestStreakDays = bestStreak,
                avgFocusSessionMinutes = avgFocus,
                avgTasksPerActiveDay = avgPerDay,
                peakDayLabel = peakDay,
                peakTimeSlotLabel = peakSlot,
                monthDeltaTasks = curMonth.completedTasks - prevMonth.completedTasks,
                monthDeltaMinutes = curMonth.focusMinutes - prevMonth.focusMinutes,
                projectBreakdowns = projectBreakdowns,
                priorityCompletedCounts = priorityCounts,
                milestones = milestones,
                periodCompletedTasks = periodCompletedTasks,
                periodSessions = periodSessions,
                encouragementTitle = encTitle,
                encouragementSubtitle = encSub,
            )
        }

        private fun hourOf(ms: Long): Int =
            Calendar.getInstance().apply { timeInMillis = ms }.get(Calendar.HOUR_OF_DAY)

        private fun inSlot(hour: Int, idx: Int): Boolean = when (idx) {
            0 -> hour in 5 until 12
            1 -> hour in 12 until 16
            2 -> hour in 16 until 20
            else -> hour >= 20 || hour < 5
        }

        private fun buildDayTimeSlots(
            completedTasks: List<TaskItem>,
            sessions: List<FocusSessionItem>,
            todayStartMs: Long,
            tomorrowStartMs: Long,
            isEn: Boolean,
        ): List<ActivityBucket> {
            val todayTasks = completedTasks.filter { it.updatedAtMs in todayStartMs until tomorrowStartMs }
            val todaySessions = sessions.filter { it.endedAtMs in todayStartMs until tomorrowStartMs }
            val defs = if (isEn) {
                listOf(
                    "Morning" to "5 AM – 12 PM",
                    "Noon" to "12 PM – 4 PM",
                    "Afternoon" to "4 PM – 8 PM",
                    "Night" to "8 PM – 5 AM",
                )
            } else {
                listOf(
                    "الصبح" to "٥ ص – ١٢ م",
                    "الضهر" to "١٢ م – ٤ م",
                    "العصر" to "٤ م – ٨ م",
                    "بالليل" to "٨ م – ٥ ص",
                )
            }
            val nowHour = hourOf(System.currentTimeMillis())
            return defs.mapIndexed { idx, (label, range) ->
                val slotSessions = todaySessions.filter { inSlot(hourOf(it.endedAtMs), idx) }
                ActivityBucket(
                    label = label,
                    rangeLabel = range,
                    completedTasks = todayTasks.count { inSlot(hourOf(it.updatedAtMs), idx) },
                    focusMinutes = slotSessions.sumOf { it.elapsedMinutes },
                    sessionsCount = slotSessions.size,
                    isCurrent = inSlot(nowHour, idx),
                )
            }
        }

        private fun buildWeekDayBuckets(
            completedTasks: List<TaskItem>,
            sessions: List<FocusSessionItem>,
            todayStartMs: Long,
        ): List<ActivityBucket> = (0 until 7).map { idx ->
            val day = todayStartMs - (6 - idx) * 86_400_000L
            val nextDay = day + 86_400_000L
            val daySessions = sessions.filter { it.endedAtMs in day until nextDay }
            val dayTasks = completedTasks.filter { it.updatedAtMs in day until nextDay }
            ActivityBucket(
                label = ArabicFormatters.weekdayShort(day),
                rangeLabel = ArabicFormatters.dateShort(day),
                completedTasks = dayTasks.size,
                focusMinutes = daySessions.sumOf { it.elapsedMinutes },
                sessionsCount = daySessions.size,
                isCurrent = idx == 6,
            )
        }

        private fun buildRollingWeekBuckets(
            completedTasks: List<TaskItem>,
            sessions: List<FocusSessionItem>,
            todayStartMs: Long,
            isEn: Boolean,
        ): List<ActivityBucket> = (0 until 4).map { idx ->
            val weeksBack = 3 - idx
            val end = todayStartMs + (1L - weeksBack * 7L) * 86_400_000L
            val start = end - 7L * 86_400_000L
            val inclusiveEnd = end - 86_400_000L
            val wSessions = sessions.filter { it.endedAtMs in start until end }
            val wTasks = completedTasks.filter { it.updatedAtMs in start until end }
            val label = if (isEn) {
                when (weeksBack) {
                    0 -> "This Week"
                    1 -> "Last Week"
                    2 -> "2w Ago"
                    else -> "3w Ago"
                }
            } else {
                when (weeksBack) {
                    0 -> "الأسبوع ده"
                    1 -> "الأسبوع اللي فات"
                    2 -> "قبل أسبوعين"
                    else -> "قبل ٣ أسابيع"
                }
            }
            ActivityBucket(
                label = label,
                rangeLabel = "${ArabicFormatters.dateShort(start)} - ${ArabicFormatters.dateShort(inclusiveEnd)}",
                completedTasks = wTasks.size,
                focusMinutes = wSessions.sumOf { it.elapsedMinutes },
                sessionsCount = wSessions.size,
                isCurrent = weeksBack == 0,
            )
        }

        private fun buildMonthBuckets(
            completedTasks: List<TaskItem>,
            sessions: List<FocusSessionItem>,
            nowMs: Long,
        ): List<ActivityBucket> {
            val baseCal = Calendar.getInstance().apply { timeInMillis = nowMs }
            return (0 until 6).map { idx ->
                val monthsBack = 5 - idx
                val startCal = (baseCal.clone() as Calendar).apply {
                    add(Calendar.MONTH, -monthsBack)
                    set(Calendar.DAY_OF_MONTH, 1)
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                val endCal = (startCal.clone() as Calendar).apply { add(Calendar.MONTH, 1) }
                val startMs = startCal.timeInMillis
                val endMs = endCal.timeInMillis
                val monthSessions = sessions.filter { it.endedAtMs in startMs until endMs }
                val monthTasks = completedTasks.filter { it.updatedAtMs in startMs until endMs }
                val month1Based = startCal.get(Calendar.MONTH) + 1
                val year = startCal.get(Calendar.YEAR)
                val monthName = ArabicFormatters.monthName(month1Based)
                ActivityBucket(
                    label = monthName,
                    rangeLabel = "$monthName ${ArabicFormatters.toArabicDigits(year)}",
                    completedTasks = monthTasks.size,
                    focusMinutes = monthSessions.sumOf { it.elapsedMinutes },
                    sessionsCount = monthSessions.size,
                    isCurrent = monthsBack == 0,
                )
            }
        }

        private fun computeStreaks(
            completedTasks: List<TaskItem>,
            sessions: List<FocusSessionItem>,
            todayStartMs: Long,
        ): Pair<Int, Int> {
            val activeDayStarts = HashSet<Long>()
            fun toDayStart(ms: Long): Long = Calendar.getInstance().apply {
                timeInMillis = ms
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis

            completedTasks.forEach { activeDayStarts.add(toDayStart(it.updatedAtMs)) }
            sessions.forEach { activeDayStarts.add(toDayStart(it.endedAtMs)) }
            if (activeDayStarts.isEmpty()) return 0 to 0

            var current = 0
            var cursor = if (activeDayStarts.contains(todayStartMs)) todayStartMs else todayStartMs - 86_400_000L
            while (activeDayStarts.contains(cursor)) {
                current++
                cursor = Calendar.getInstance().apply {
                    timeInMillis = cursor
                    add(Calendar.DAY_OF_YEAR, -1)
                }.timeInMillis
            }

            val sorted = activeDayStarts.sorted()
            var best = 1
            var run = 1
            for (i in 1 until sorted.size) {
                val diffDays = ((sorted[i] - sorted[i - 1]) / 86_400_000.0).roundToInt()
                if (diffDays == 1) {
                    run++
                    if (run > best) best = run
                } else {
                    run = 1
                }
            }
            return current to best
        }

        private fun buildProjectBreakdowns(
            tasks: List<TaskItem>,
            projects: List<ProjectItem>,
            isEn: Boolean,
        ): List<ProjectBreakdown> {
            val result = mutableListOf<ProjectBreakdown>()
            for (p in projects) {
                val pTasks = tasks.filter { it.projectId == p.id }
                if (pTasks.isEmpty() && p.taskIds.isEmpty()) continue
                result += ProjectBreakdown(
                    projectId = p.id,
                    title = ArabicFormatters.trData(p.title),
                    colorValue = p.colorValue,
                    completedTasks = pTasks.count { it.isCompleted },
                    totalTasks = pTasks.size,
                )
            }
            val generalTasks = tasks.filter { it.projectId == null }
            if (generalTasks.isNotEmpty()) {
                result += ProjectBreakdown(
                    projectId = "_general",
                    title = if (isEn) "General Daily Tasks" else "مهام يومية عامة",
                    colorValue = 0xFF007067L,
                    completedTasks = generalTasks.count { it.isCompleted },
                    totalTasks = generalTasks.size,
                )
            }
            return result.sortedByDescending { it.completedTasks }
        }

        private fun buildMilestones(
            overallStats: ProductivityAnalyticsSummary,
            bestStreak: Int,
            completedProjectsCount: Int,
            completedHardTasksCount: Int,
            completedExamsCount: Int,
            isStudentMode: Boolean,
            isEnglish: Boolean,
        ): List<AchievementMilestone> {
            val completed = overallStats.completedTasks
            val focusMin = overallStats.focusMinutes
            val sessionsCount = overallStats.completedFocusSessions

            val list = mutableListOf(
                AchievementMilestone(
                    id = "first_step",
                    title = if (isEnglish) "First Step" else "أول خطوة",
                    subtitle = if (isEnglish) "Complete your first task" else "خلّص أول مهمة ليك",
                    progressLabel = if (isEnglish) "${completed.coerceIn(0, 1)}/1" else "${ArabicFormatters.toArabicDigits(completed.coerceIn(0, 1))}/١",
                    progressRatio = if (completed >= 1) 1f else 0f,
                    unlocked = completed >= 1,
                    iconKind = MilestoneIconKind.firstStep,
                ),
                AchievementMilestone(
                    id = "focus_hour",
                    title = if (isEnglish) "Focus Hour" else "ساعة تركيز",
                    subtitle = if (isEnglish) "60 total focus minutes" else "٦٠ دقيقة تركيز متجمعة",
                    progressLabel = if (isEnglish) "${focusMin.coerceIn(0, 60)}/60m" else "${ArabicFormatters.toArabicDigits(focusMin.coerceIn(0, 60))}/٦٠ د",
                    progressRatio = (focusMin / 60f).coerceIn(0f, 1f),
                    unlocked = focusMin >= 60,
                    iconKind = MilestoneIconKind.deepFocus,
                ),
                AchievementMilestone(
                    id = "steady_streak",
                    title = if (isEnglish) "Steady Rhythm" else "ماشي بثبات",
                    subtitle = if (isEnglish) "3-day active streak" else "٣ أيام ورا بعض بتنجز",
                    progressLabel = if (isEnglish) "${bestStreak.coerceIn(0, 3)}/3 days" else "${ArabicFormatters.toArabicDigits(bestStreak.coerceIn(0, 3))}/٣ أيام",
                    progressRatio = (bestStreak / 3f).coerceIn(0f, 1f),
                    unlocked = bestStreak >= 3,
                    iconKind = MilestoneIconKind.streak,
                ),
                AchievementMilestone(
                    id = "hard_task_crusher",
                    title = if (isEnglish) "Hard Task Crusher" else "قد الصعب",
                    subtitle = if (isEnglish) "Finish 3 high/urgent priority tasks" else "خلّص ٣ مهام صعبة أو عاجلة",
                    progressLabel = if (isEnglish) "${completedHardTasksCount.coerceIn(0, 3)}/3 hard" else "${ArabicFormatters.toArabicDigits(completedHardTasksCount.coerceIn(0, 3))}/٣ صعبة",
                    progressRatio = (completedHardTasksCount / 3f).coerceIn(0f, 1f),
                    unlocked = completedHardTasksCount >= 3,
                    iconKind = MilestoneIconKind.hardTaskCrusher,
                ),
                AchievementMilestone(
                    id = "focus_marathon",
                    title = if (isEnglish) "Deep Focus" else "تركيز عميق",
                    subtitle = if (isEnglish) "5 sessions or 150 minutes" else "٥ جلسات أو ١٥٠ دقيقة",
                    progressLabel = if (isEnglish) "${sessionsCount.coerceIn(0, 5)}/5 sessions" else "${ArabicFormatters.toArabicDigits(sessionsCount.coerceIn(0, 5))}/٥ جلسات",
                    progressRatio = maxOf((sessionsCount / 5f).coerceIn(0f, 1f), (focusMin / 150f).coerceIn(0f, 1f)),
                    unlocked = sessionsCount >= 5 || focusMin >= 150,
                    iconKind = MilestoneIconKind.marathon,
                ),
                AchievementMilestone(
                    id = "ten_tasks",
                    title = if (isEnglish) "Ten Done" else "خلّصت ١٠ مهام",
                    subtitle = if (isEnglish) "Finish 10 tasks successfully" else "كمّل ١٠ مهام بنجاح",
                    progressLabel = if (isEnglish) "${completed.coerceIn(0, 10)}/10" else "${ArabicFormatters.toArabicDigits(completed.coerceIn(0, 10))}/١٠",
                    progressRatio = (completed / 10f).coerceIn(0f, 1f),
                    unlocked = completed >= 10,
                    iconKind = MilestoneIconKind.tenTasks,
                ),
                AchievementMilestone(
                    id = "project_finisher",
                    title = if (isEnglish) "Project Champion" else "بطل المشروعات",
                    subtitle = if (isEnglish) "Complete a full project or 5 focus hours" else "خلّص مشروع كامل أو ٥ ساعات تركيز",
                    progressLabel = if (completedProjectsCount >= 1) (if (isEnglish) "Done" else "مكتمل") else if (isEnglish) "${focusMin.coerceIn(0, 300)}/300m" else "${ArabicFormatters.toArabicDigits(focusMin.coerceIn(0, 300))}/٣٠٠ د",
                    progressRatio = if (completedProjectsCount >= 1) 1f else (focusMin / 300f).coerceIn(0f, 1f),
                    unlocked = completedProjectsCount >= 1 || focusMin >= 300,
                    iconKind = MilestoneIconKind.finisher,
                ),
            )
            if (isStudentMode) {
                list += AchievementMilestone(
                    id = "exam_hero",
                    title = if (isEnglish) "Exam & Grade Hero" else "بطل الامتحانات والتقدير",
                    subtitle = if (isEnglish) "Complete an exam or record your grade" else "خلّص امتحان أو سجّل تقديرك الدراسي",
                    progressLabel = if (completedExamsCount >= 1) (if (isEnglish) "Unlocked" else "مفتوح") else if (isEnglish) "0/1 exam" else "٠/١ امتحان",
                    progressRatio = if (completedExamsCount >= 1) 1f else 0.25f,
                    unlocked = completedExamsCount >= 1,
                    iconKind = MilestoneIconKind.examHero,
                )
            }
            return list
        }

        private fun buildEncouragement(
            firstName: String,
            granularity: AnalyticsGranularity,
            periodStats: ProductivityAnalyticsSummary,
            overallStats: ProductivityAnalyticsSummary,
            streak: Int,
            peakDayLabel: String?,
            isEnglish: Boolean,
        ): Pair<String, String> {
            val cleanName = ArabicFormatters.trData(firstName)
            if (!overallStats.hasData) {
                return if (isEnglish) {
                    "Your space is ready, $cleanName" to
                        "Any small task you finish or focus session you start will show up here and build real momentum."
                } else {
                    "مساحتك جاهزة يا $firstName" to
                        "أي مهمة صغيرة تخلصها أو جلسة تركيز تبدأها هتظهر هنا وتبنيلك تتابع حقيقي ليومك وأسبوعك."
                }
            }
            if (streak >= 3) {
                return if (isEnglish) {
                    "Amazing consistency, $cleanName!" to
                        "You have kept a steady rhythm for $streak days in a row. Take it one step at a time and stay calm."
                } else {
                    "استمرارية هايلة يا $firstName!" to
                        "ماشي على وتيرة حلوة بقى لك ${ArabicFormatters.toArabicDigits(streak)} أيام ورا بعض. خد خطوة واحدة في المرة وحافظ على هدوءك."
                }
            }
            if (periodStats.completedTasks >= 3 || periodStats.focusMinutes >= 60) {
                return if (isEnglish) {
                    val hint = if (peakDayLabel == null) "" else " Your most active day was $peakDayLabel."
                    "Real progress, $cleanName" to
                        "You completed ${periodStats.completedTasks} tasks and logged ${ArabicFormatters.durationCompact(periodStats.focusMinutes)} of focus.$hint"
                } else {
                    val hint = if (peakDayLabel == null) "" else " وأكتر يوم نشيط عندك كان $peakDayLabel."
                    "إنجاز ملموس يا $firstName" to
                        "خلصت ${ArabicFormatters.toArabicDigits(periodStats.completedTasks)} مهام وسجلت ${ArabicFormatters.durationCompact(periodStats.focusMinutes)} تركيز$hint كل خطوة بتفرق."
                }
            }
            if (periodStats.totalTasks > 0 && periodStats.completedTasks == 0) {
                val open = periodStats.totalTasks
                return if (isEnglish) {
                    "One step breaks the ice, $cleanName" to
                        "You have $open open tasks. Pick the smallest one and start with 15 minutes of focus."
                } else {
                    "خطوة واحدة تكسر الحاجز يا $firstName" to
                        "عندك ${ArabicFormatters.toArabicDigits(open)} مهام مفتوحة، اختار أصغر واحدة بس وابدأ بتركيز ١٥ دقيقة."
                }
            }
            return if (isEnglish) {
                when (granularity) {
                    AnalyticsGranularity.day -> "Calm start, $cleanName" to "You still have room to win the day. Focus on just one task now."
                    AnalyticsGranularity.week -> "Balanced week, $cleanName" to "Your total focus this week is ${ArabicFormatters.durationCompact(periodStats.focusMinutes)}."
                    AnalyticsGranularity.month -> "Broader view, $cleanName" to "Your total progress reached ${overallStats.completedTasks} tasks and ${ArabicFormatters.durationCompact(overallStats.focusMinutes)} of focus."
                }
            } else {
                when (granularity) {
                    AnalyticsGranularity.day -> "بداية هادية يا $firstName" to "عندك لسه مساحة تكسب اليوم. ركّز على مهمة واحدة بس دلوقتي والباقي ييجي بعدها."
                    AnalyticsGranularity.week -> "أسبوع متوازن يا $firstName" to "إجمالي تركيزك الأسبوع ده ${ArabicFormatters.durationCompact(periodStats.focusMinutes)}، وكل جلسة بتضيف لرصيدك."
                    AnalyticsGranularity.month -> "صورة أوسع لتقدّمك يا $firstName" to "إجمالي إنجازك وصل لـ ${ArabicFormatters.toArabicDigits(overallStats.completedTasks)} مهام و${ArabicFormatters.durationCompact(overallStats.focusMinutes)} تركيز."
                }
            }
        }

        private fun dayKey(ms: Long): String {
            val c = Calendar.getInstance().apply { timeInMillis = ms }
            return "${c.get(Calendar.YEAR)}-${c.get(Calendar.MONTH)}-${c.get(Calendar.DAY_OF_MONTH)}"
        }
    }
}

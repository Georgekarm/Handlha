package com.handelha.app.ui

import com.handelha.app.domain.AssistantActionProposal
import com.handelha.app.domain.AssistantTone
import com.handelha.app.domain.ExamGradesHelper
import com.handelha.app.domain.ProjectItem
import com.handelha.app.domain.ProposedScheduleSlot
import com.handelha.app.domain.TaskItem
import com.handelha.app.domain.TaskPriority
import com.handelha.app.domain.UserEnergyPreferences
import com.handelha.app.util.ArabicFormatters
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.UUID

data class AssistantTurnOutput(
    val replyText: String,
    val quickReplies: List<String>,
    val proposal: AssistantActionProposal? = null,
    val confirmedTasksToCreate: List<TaskItem> = emptyList(),
    val markTaskCompletedId: String? = null,
    val scheduleAlarmRequest: Triple<String, Long, String>? = null, // title, whenMs, alertMode
    val recordExamGrade: Triple<String, String, String>? = null, // title, tier, scoreLabel
)

object LocalAssistantEngine {
    private val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)

    fun processMessage(
        userId: String,
        userMessage: String,
        isEnglish: Boolean,
        isStudentMode: Boolean,
        tone: AssistantTone,
        energyPrefs: UserEnergyPreferences,
        tasks: List<TaskItem>,
        projects: List<ProjectItem>,
        previousPendingProposal: AssistantActionProposal?,
    ): AssistantTurnOutput {
        val raw = userMessage.trim()
        val norm = raw.lowercase()
            .replace('أ', 'ا')
            .replace('إ', 'ا')
            .replace('آ', 'ا')
            .replace('ة', 'ه')
            .replace('ى', 'ي')

        // 1. Confirm pending draft
        if (previousPendingProposal != null && previousPendingProposal.draftStatus == "pending" &&
            (norm.contains("اعتمد") || norm.contains("اكد") || norm.contains("تم") ||
                norm.contains("موافق") || norm.contains("confirm") || norm.contains("approve") || norm.contains("save schedule"))
        ) {
            val confirmedTasks = previousPendingProposal.slots.map { slot ->
                val startMs = runCatching { isoFormat.parse(slot.startAtIso)?.time }.getOrNull()
                    ?: (System.currentTimeMillis() + 3_600_000L)
                val endMs = runCatching { isoFormat.parse(slot.endAtIso)?.time }.getOrNull()
                    ?: (startMs + energyPrefs.preferredSessionMinutes * 60_000L)
                val mins = ((endMs - startMs) / 60_000L).toInt().coerceIn(15, 180)
                val prio = when (slot.priority) {
                    "urgent" -> TaskPriority.urgent
                    "high" -> TaskPriority.high
                    "low" -> TaskPriority.low
                    else -> TaskPriority.medium
                }
                TaskItem(
                    id = slot.taskId,
                    userId = userId,
                    title = slot.title,
                    priority = prio,
                    dueAtMs = startMs,
                    scheduledStartAtMs = startMs,
                    estimatedDurationMinutes = mins,
                    status = com.handelha.app.domain.TaskStatus.planned,
                    source = com.handelha.app.domain.TaskSource.ai,
                )
            }
            val lines = if (isEnglish) {
                buildString {
                    appendLine("Added ${confirmedTasks.size} tasks to your schedule:")
                    confirmedTasks.forEachIndexed { i, t ->
                        appendLine("${i + 1}) ${t.title} • ${ArabicFormatters.timeOfDayAr(t.scheduledStartAtMs ?: System.currentTimeMillis())}")
                    }
                    append("Your reminders are ready and active.")
                }
            } else {
                buildString {
                    appendLine("تمام، ضفتلك ${ArabicFormatters.toArabicDigits(confirmedTasks.size)} مهام لجدولك:")
                    confirmedTasks.forEachIndexed { i, t ->
                        appendLine("${ArabicFormatters.toArabicDigits(i + 1)}) ${t.title} • ${ArabicFormatters.timeOfDayAr(t.scheduledStartAtMs ?: System.currentTimeMillis())}")
                    }
                    append("وتذكيراتهم جاهزة دلوقتي.")
                }
            }
            return AssistantTurnOutput(
                replyText = lines,
                quickReplies = if (isEnglish) listOf("Show my tasks today", "Start focus session") else listOf("عرض مهام النهارده", "ابدأ جلسة تركيز"),
                proposal = previousPendingProposal.copy(draftStatus = "confirmed"),
                confirmedTasksToCreate = confirmedTasks,
            )
        }

        // 2. Shift pending draft to evening (6-9 PM)
        if (previousPendingProposal != null && previousPendingProposal.slots.isNotEmpty() &&
            (norm.contains("6") && norm.contains("9") || norm.contains("مساء") || norm.contains("بليل") ||
                norm.contains("evening") || norm.contains("shift"))
        ) {
            var cursorHour = 18
            var cursorMin = 0
            val shiftedSlots = previousPendingProposal.slots.map { slot ->
                val cal = Calendar.getInstance().apply {
                    val parsed = runCatching { isoFormat.parse(slot.startAtIso) }.getOrNull()
                    if (parsed != null) time = parsed
                    set(Calendar.HOUR_OF_DAY, cursorHour)
                    set(Calendar.MINUTE, cursorMin)
                    set(Calendar.SECOND, 0)
                }
                val startStr = isoFormat.format(cal.time)
                val durMins = energyPrefs.preferredSessionMinutes.coerceIn(25, 60)
                cal.add(Calendar.MINUTE, durMins)
                val endStr = isoFormat.format(cal.time)
                cal.add(Calendar.MINUTE, 10)
                cursorHour = cal.get(Calendar.HOUR_OF_DAY)
                cursorMin = cal.get(Calendar.MINUTE)
                slot.copy(startAtIso = startStr, endAtIso = endStr)
            }
            val updatedProposal = previousPendingProposal.copy(
                draftStatus = "pending",
                slots = shiftedSlots,
            )
            return AssistantTurnOutput(
                replyText = formatDraftReply(shiftedSlots, isEnglish, updated = true, energyPrefs = energyPrefs),
                quickReplies = if (isEnglish) listOf("Confirm schedule", "View my tasks") else listOf("اعتمد الخطة", "عرض مهامي"),
                proposal = updatedProposal,
            )
        }

        // 3. Student Mode exam grade recording
        if (isStudentMode && (norm.contains("جبت") || norm.contains("تقدير") || norm.contains("درجتي") ||
                norm.contains("امتياز") || norm.contains("جيد جدا") || norm.contains("got ") || norm.contains("grade"))
        ) {
            val tier = ExamGradesHelper.inferTierFromText(norm)
            val scoreLabel = when (tier) {
                "excellent" -> if (isEnglish) "Excellent (A+)" else "امتياز"
                "very_good" -> if (isEnglish) "Very Good (B+)" else "جيد جدًا"
                "good" -> if (isEnglish) "Good (B)" else "جيد"
                else -> if (isEnglish) "Pass" else "مقبول"
            }
            val examTitle = extractSubject(raw, isEnglish)
            val enc = ExamGradesHelper.buildEncouragement(examTitle, tier, scoreLabel)
            val badge = if (isEnglish) enc.badgeEn else enc.badgeAr
            val msg = if (isEnglish) enc.en else enc.ar
            return AssistantTurnOutput(
                replyText = "$msg\n🏅 $badge",
                quickReplies = if (isEnglish) listOf("Plan next exam", "Start study focus") else listOf("رتّب مذاكرة المادة الجاية", "ابدأ جلسة مذاكرة"),
                recordExamGrade = Triple(examTitle, tier, scoreLabel),
            )
        }

        // 4. Task listing inquiry
        if (norm.contains("مهامي") || norm.contains("النهارده") && (norm.contains("ايه") || norm.contains("عرض") || norm.contains("شوف")) ||
            norm.contains("my tasks") || norm.contains("what tasks") || norm.contains("show tasks")
        ) {
            val open = tasks.filter { !it.isCompleted && !it.isCancelled && !it.isDeleted }
            if (open.isEmpty()) {
                return AssistantTurnOutput(
                    replyText = if (isEnglish) {
                        "Your list is completely clear right now. Tell me any task on your mind and I'll organize it for you."
                    } else {
                        "قائمتك فاضية ورايقة دلوقتي! قولّي أي مهمة في بالك وهنرتبها سوا في خطوات بسيطة."
                    },
                    quickReplies = if (isEnglish) listOf("Plan my day", "Study sprint 45m") else listOf("رتّبلي يومي النهارده", "مذاكرة ٤٥ دقيقة"),
                )
            }
            val listText = buildString {
                appendLine(if (isEnglish) "Here are the tasks I found:" else "دي المهام اللي لقيتها عندك:")
                open.take(6).forEachIndexed { idx, t ->
                    val timePart = (t.scheduledStartAtMs ?: t.dueAtMs)?.let { ArabicFormatters.timeOfDayAr(it) }
                        ?: if (isEnglish) "Flexible" else "وقت مرن"
                    val n = if (isEnglish) "${idx + 1})" else "${ArabicFormatters.toArabicDigits(idx + 1)})"
                    appendLine("$n ${t.title} — $timePart")
                }
            }.trim()
            return AssistantTurnOutput(
                replyText = listText,
                quickReplies = if (isEnglish) listOf("Organize them calmly", "Add another task") else listOf("رتّبهملي بهدوء", "ضيف مهمة جديدة"),
            )
        }

        // 5. Complete task command
        if (norm.startsWith("خلصت ") || norm.startsWith("اكملت ") || norm.startsWith("تم ") && norm.length > 6 ||
            norm.startsWith("finished ") || norm.startsWith("done with ")
        ) {
            val open = tasks.filter { !it.isCompleted && !it.isCancelled && !it.isDeleted }
            val query = raw.replace(Regex("^(خلصت|أكملت|اكملت|تم|finished|done with)\\s+", RegexOption.IGNORE_CASE), "").trim()
            val match = open.firstOrNull { it.title.contains(query, ignoreCase = true) } ?: open.firstOrNull()
            if (match != null) {
                return AssistantTurnOutput(
                    replyText = if (isEnglish) {
                        "Marked \"${match.title}\" as completed! Great steady momentum — take a breath before the next step."
                    } else {
                        "عاش عليك! علّمت على «${match.title}» كمكتملة 🎉 خد نفس بسيط قبل الخطوة اللي جاية."
                    },
                    quickReplies = if (isEnglish) listOf("What's next?", "Open Insights") else listOf("إيه الخطوة الجاية؟", "شوف إنجازك"),
                    markTaskCompletedId = match.id,
                )
            }
        }

        // 6. Alarm / reminder direct request
        if (norm.contains("منبه") || norm.contains("فكرني") || norm.contains("تنبيه") ||
            norm.contains("alarm") || norm.contains("remind me")
        ) {
            val whenCal = parseWhenCalendar(norm)
            val title = raw.replace(Regex("(اضبط|اعمل|فكرني بـ?|فكرني|منبه|تنبيه|alarm|remind me to|remind me)", RegexOption.IGNORE_CASE), "")
                .trim().ifEmpty { if (isEnglish) "Important Reminder" else "تذكير مهم" }
            val timeStr = ArabicFormatters.timeOfDayAr(whenCal.timeInMillis)
            val reply = if (isEnglish) {
                "Alarm & Reminder Setup\nTitle: $title\nTime: $timeStr\nType: Full Alarm Chime"
            } else {
                "إعداد المنبه والتذكير\nالعنوان: $title\nالميعاد: $timeStr\nالنوع: منبه صوتي كامل"
            }
            return AssistantTurnOutput(
                replyText = reply,
                quickReplies = if (isEnglish) listOf("Show my tasks", "Add another task") else listOf("عرض مهامي", "ضيف مهمة كمان"),
                scheduleAlarmRequest = Triple(title, whenCal.timeInMillis, "alarm"),
            )
        }

        // 7. Project breakdown request
        if (norm.contains("قسم") || norm.contains("مشروع") || norm.contains("خطوات") ||
            norm.contains("break down") || norm.contains("roadmap") || norm.contains("plan my")
        ) {
            val steps = buildBreakdownSteps(raw, isEnglish, energyPrefs)
            val header = if (isEnglish) {
                "Sure! Here is a calm roadmap with ${steps.size} actionable steps matched to your ${energyPrefs.preferredSessionMinutes}m focus blocks:"
            } else {
                "أكيد! دي ${ArabicFormatters.toArabicDigits(steps.size)} خطوات عملية متقسمة على مقاس جلساتك (${ArabicFormatters.toArabicDigits(energyPrefs.preferredSessionMinutes)} دقيقة):"
            }
            val body = buildString {
                appendLine(header)
                steps.forEachIndexed { idx, step ->
                    val prefix = if (isEnglish) "${idx + 1})" else "${ArabicFormatters.toArabicDigits(idx + 1)})"
                    appendLine("$prefix $step")
                }
            }.trim()

            // Also prepare schedule draft slots so user can approve directly
            val slots = buildSlotsFromTitles(steps, norm, energyPrefs)
            val proposal = AssistantActionProposal(
                id = UUID.randomUUID().toString(),
                type = "create_tasks",
                summary = if (isEnglish) "Approve roadmap" else "اعتماد الخطوات",
                slots = slots,
            )
            return AssistantTurnOutput(
                replyText = body,
                quickReplies = if (isEnglish) listOf("Confirm schedule", "Shift to evening 6-9 pm") else listOf("اعتمد الخطة", "خليه من 6 ل 9 بليل"),
                proposal = proposal,
            )
        }

        // 8. Multi-task / task scheduling parser (default smart organizer)
        val extracted = extractTaskTitles(raw, isEnglish)
        if (extracted.isNotEmpty()) {
            val slots = buildSlotsFromTitles(extracted, norm, energyPrefs)
            val proposal = AssistantActionProposal(
                id = UUID.randomUUID().toString(),
                type = "create_tasks",
                summary = if (isEnglish) "Prepared schedule draft" else "مسودة ترتيب المهام",
                slots = slots,
            )
            return AssistantTurnOutput(
                replyText = formatDraftReply(slots, isEnglish, updated = false, energyPrefs = energyPrefs),
                quickReplies = if (isEnglish) listOf("Confirm schedule", "Make it from 6 to 9 pm") else listOf("اعتمد الخطة", "خليه من 6 ل 9 بليل"),
                proposal = proposal,
            )
        }

        // 9. Supportive conversation fallback honoring tone
        val greeting = when {
            isEnglish && tone == AssistantTone.formal ->
                "I am ready to organize your schedule. Share the tasks, deadlines, or projects you want to structure today."
            isEnglish ->
                "I'm right here with you — no rush. Tell me what's on your mind today (tasks, study subjects, or a big goal) and I'll arrange it calmly into small steps."
            tone == AssistantTone.brief ->
                "جاهز. ابعتلي المهام أو المواعيد وهرتبهالك في جدول واضح حالًا."
            tone == AssistantTone.formal ->
                "مرحبًا بك. شاركني مهامك أو مواعيدك اليوم لأقوم بإعداد مسودة جدول دقيقة تتناسب مع طاقتك."
            else ->
                "معاك ومش مستعجلك خالص. احكيلي إيه اللي شاغل بالك النهارده — سواء شغل، مذاكرة، أو مشاوير — وهنقسّمهم سوا لخطوات هادية على قد طاقتك."
        }
        return AssistantTurnOutput(
            replyText = greeting,
            quickReplies = if (isEnglish) {
                listOf("Plan my tasks today", "Break down a project", "Show my tasks")
            } else {
                listOf("رتّبلي مهام النهارده", "قسّملي هدف لخطوات", "عرض مهامي")
            },
        )
    }

    private fun extractSubject(raw: String, isEnglish: Boolean): String {
        val cleaned = raw.replace(
            Regex("(جبت|تقدير|درجتي|امتياز|جيد جدا|جيد|مقبول|في|مادة|امتحان|اختبار|got|grade|score|in|exam)", RegexOption.IGNORE_CASE),
            " ",
        ).trim().replace(Regex("\\s+"), " ")
        return cleaned.ifBlank { if (isEnglish) "Midterm Exam" else "الامتحان" }
    }

    private fun extractTaskTitles(raw: String, isEnglish: Boolean): List<String> {
        val parts = raw.split(Regex("(?:\\s+و\\s+|\\n|،|,|\\band\\b)", RegexOption.IGNORE_CASE))
            .map { part ->
                part.replace(Regex("^(اضف|ضيف|عندي|ورايا|اعمل جدول لـ?|رتب|عاوز اخلص|add|schedule|plan|i have)\\s+", RegexOption.IGNORE_CASE), "")
                    .replace(Regex("\\s+(النهارده|بكره|بكرة|صباحا|مساء|بالليل|today|tomorrow|morning|evening)$", RegexOption.IGNORE_CASE), "")
                    .trim()
            }
            .filter { it.length >= 3 }
        if (parts.size >= 2) return parts.take(5)
        val triggers = listOf("عندي", "ورايا", "ضيف", "اضف", "مذاكره", "مذاكرة", "امتحان", "مشروع", "مهمه", "مهمة", "schedule", "add", "exam", "study", "task")
        val lower = raw.lowercase()
        return if (triggers.any { lower.contains(it) } && raw.length >= 4) {
            listOf(raw.trim().take(60))
        } else {
            emptyList()
        }
    }

    private fun buildBreakdownSteps(raw: String, isEnglish: Boolean, energyPrefs: UserEnergyPreferences): List<String> {
        val topic = raw.replace(Regex("(قسم|مشروع|خطوات|رتب|break down|plan|roadmap)", RegexOption.IGNORE_CASE), "")
            .trim().ifBlank { if (isEnglish) "Main Goal" else "الهدف الرئيسي" }
        val mins = energyPrefs.preferredSessionMinutes
        return if (isEnglish) {
            listOf(
                "Define key outcome & checklist for $topic (${mins}m)",
                "Gather references & prepare workspace (${mins}m)",
                "Execute core deep-work block #1 on $topic (${mins}m)",
                "Review progress & polish remaining details (${mins}m)",
            )
        } else {
            listOf(
                "تحديد النتيجة المطلوبة وأهم النقاط في $topic (${ArabicFormatters.toArabicDigits(mins)} د)",
                "تجهيز الأدوات والمصادر وفتح مساحتك (${ArabicFormatters.toArabicDigits(mins)} د)",
                "تنفيذ الجزء الأساسي الأول بتركيز عميق في $topic (${ArabicFormatters.toArabicDigits(mins)} د)",
                "مراجعة سريعة وإقفال التفاصيل الناقصة (${ArabicFormatters.toArabicDigits(mins)} د)",
            )
        }
    }

    private fun parseWhenCalendar(norm: String): Calendar {
        val cal = Calendar.getInstance()
        if (norm.contains("بكر") || norm.contains("tomorrow")) {
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        val hourMatch = Regex("""(\d{1,2})""").find(norm)
        var hour = hourMatch?.groupValues?.get(1)?.toIntOrNull()
        if (hour != null) {
            if ((norm.contains("م") || norm.contains("مسا") || norm.contains("بليل") || norm.contains("pm")) && hour < 12) {
                hour += 12
            }
            cal.set(Calendar.HOUR_OF_DAY, hour.coerceIn(0, 23))
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
        } else {
            cal.add(Calendar.HOUR_OF_DAY, 1)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
        }
        return cal
    }

    private fun buildSlotsFromTitles(
        titles: List<String>,
        norm: String,
        energyPrefs: UserEnergyPreferences,
    ): List<ProposedScheduleSlot> {
        val cal = Calendar.getInstance().apply {
            if (norm.contains("بكر") || norm.contains("tomorrow")) {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, energyPrefs.workStartMinute / 60)
                set(Calendar.MINUTE, 0)
            } else if (norm.contains("مسا") || norm.contains("بليل") || norm.contains("evening")) {
                set(Calendar.HOUR_OF_DAY, 18)
                set(Calendar.MINUTE, 0)
            } else {
                val prefStartH = energyPrefs.workStartMinute / 60
                val nextH = maxOf(get(Calendar.HOUR_OF_DAY) + 1, prefStartH).coerceAtMost(21)
                set(Calendar.HOUR_OF_DAY, nextH)
                set(Calendar.MINUTE, 0)
            }
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val dur = energyPrefs.preferredSessionMinutes.coerceIn(25, 60)
        return titles.mapIndexed { idx, t ->
            val startIso = isoFormat.format(cal.time)
            cal.add(Calendar.MINUTE, dur)
            val endIso = isoFormat.format(cal.time)
            cal.add(Calendar.MINUTE, 15)
            ProposedScheduleSlot(
                taskId = UUID.randomUUID().toString(),
                title = t,
                startAtIso = startIso,
                endAtIso = endIso,
                priority = if (idx == 0) "high" else "medium",
                alertMode = "alarm",
            )
        }
    }

    private fun formatDraftReply(
        slots: List<ProposedScheduleSlot>,
        isEnglish: Boolean,
        updated: Boolean,
        energyPrefs: UserEnergyPreferences,
    ): String {
        return buildString {
            if (isEnglish) {
                appendLine(if (updated) "Updated draft — shifted to your selected window:" else "Prepared your schedule draft based on your ${energyPrefs.peakShort(true)} energy:")
                slots.forEachIndexed { idx, s ->
                    val startMs = runCatching { isoFormat.parse(s.startAtIso)?.time }.getOrNull() ?: System.currentTimeMillis()
                    val endMs = runCatching { isoFormat.parse(s.endAtIso)?.time }.getOrNull() ?: (startMs + 45 * 60_000L)
                    val dateStr = ArabicFormatters.dateShort(startMs)
                    val range = "${ArabicFormatters.timeOfDayAr(startMs)} - ${ArabicFormatters.timeOfDayAr(endMs)}"
                    appendLine("${idx + 1}) ${s.title} | $dateStr | $range | ${energyPrefs.preferredSessionMinutes}m")
                }
                append("Tap 'Confirm & Save Schedule' to add these with active reminders.")
            } else {
                appendLine(if (updated) "حدّثت المسودة حسب الوقت اللي طلبته:" else "مسودة ترتيب المهام المقترحة حسب طاقتك (${energyPrefs.peakShort(false)}):")
                slots.forEachIndexed { idx, s ->
                    val startMs = runCatching { isoFormat.parse(s.startAtIso)?.time }.getOrNull() ?: System.currentTimeMillis()
                    val endMs = runCatching { isoFormat.parse(s.endAtIso)?.time }.getOrNull() ?: (startMs + 45 * 60_000L)
                    val dateStr = ArabicFormatters.dateShort(startMs)
                    val range = "${ArabicFormatters.timeOfDayAr(startMs)} - ${ArabicFormatters.timeOfDayAr(endMs)}"
                    appendLine("${ArabicFormatters.toArabicDigits(idx + 1)}) ${s.title} | $dateStr | $range | ${ArabicFormatters.durationMinutesFull(energyPrefs.preferredSessionMinutes)}")
                }
                append("اضغط «اعتمد الجدول الآن» عشان أضيفهم في مهامك وأفعل التنبيهات.")
            }
        }
    }
}

package com.handelha.app.domain

import java.util.Calendar
import kotlinx.serialization.Serializable

@Serializable
enum class TaskStatus { inbox, planned, inProgress, completed, cancelled }

@Serializable
enum class TaskPriority { low, medium, high, urgent }

@Serializable
enum class EnergyLevel { low, medium, high }

@Serializable
enum class TaskSource { manual, chat, voice, ai, import }

@Serializable
enum class SyncStatus { synced, pending, failed }

@Serializable
enum class TaskRecurrence { none, daily, weekdays, weekly }

@Serializable
data class TaskSubtaskItem(
    val id: String,
    val title: String,
    val isDone: Boolean = false,
)

object TaskSubtasksCodec {
    private const val PREFIX = "subtasks_v1::"

    fun decode(raw: String?): List<TaskSubtaskItem> {
        if (raw.isNullOrBlank() || !raw.startsWith(PREFIX)) return emptyList()
        val payload = raw.removePrefix(PREFIX)
        if (payload.isBlank()) return emptyList()
        return payload.split("||").mapNotNull { entry ->
            val parts = entry.split("::", limit = 3)
            if (parts.size < 3) null
            else {
                val id = parts[0].trim()
                val done = parts[1].trim() == "1"
                val title = parts[2].trim()
                if (id.isEmpty() || title.isEmpty()) null
                else TaskSubtaskItem(id = id, title = title, isDone = done)
            }
        }
    }

    fun encode(items: List<TaskSubtaskItem>): String? {
        val clean = items.filter { it.title.isNotBlank() }
        if (clean.isEmpty()) return null
        return PREFIX + clean.joinToString("||") { item ->
            val safeTitle = item.title.replace("||", " ").replace("::", " ").trim()
            "${item.id}::${if (item.isDone) "1" else "0"}::$safeTitle"
        }
    }

    fun generateSmartSubtasks(taskTitle: String, isEnglish: Boolean): List<TaskSubtaskItem> {
        val clean = taskTitle.trim().ifEmpty { if (isEnglish) "this task" else "المهمة" }
        val lower = clean.lowercase()
        val steps = when {
            lower.contains("امتحان") || lower.contains("مذاكر") || lower.contains("محاضر") ||
                lower.contains("فصل") || lower.contains("exam") || lower.contains("study") ||
                lower.contains("chapter") || lower.contains("lecture") -> {
                if (isEnglish) {
                    listOf(
                        "Skim key headings & concepts for $clean (10m)",
                        "Summarize core points & formulas in your own words",
                        "Solve 5 practice questions to lock it in",
                    )
                } else {
                    listOf(
                        "قراءة سريعة لأهم العناوين والأفكار في $clean (١٠ د)",
                        "تلخيص النقاط والقوانين الأساسية بطريقتك",
                        "حل ٥ أسئلة تطبيقية أو امتحانات سابقة لتثبيت المعلومة",
                    )
                }
            }
            lower.contains("مشروع") || lower.contains("تقرير") || lower.contains("عرض") ||
                lower.contains("بحث") || lower.contains("project") || lower.contains("report") ||
                lower.contains("presentation") -> {
                if (isEnglish) {
                    listOf(
                        "Outline the 3 main sections of $clean",
                        "Draft the first core section without perfectionism",
                        "Quick review & final polish",
                    )
                } else {
                    listOf(
                        "تحديد العناصر الـ ٣ الأساسية في $clean",
                        "كتابة وتجهيز الجزء الأول من غير مثالية زيادة",
                        "مراجعة سريعة وتقفيل الشكل النهائي",
                    )
                }
            }
            else -> {
                if (isEnglish) {
                    listOf(
                        "Prepare tools & clear distractions for $clean (5m)",
                        "Focus on the main part of $clean for one calm block",
                        "Wrap up & check off completion",
                    )
                } else {
                    listOf(
                        "تجهيز الأدوات وإبعاد المشتتات لبدء $clean (٥ د)",
                        "التركيز على الجزء الأساسي من $clean في جلسة هادية",
                        "مراجعة سريعة وتقفيل المهمة",
                    )
                }
            }
        }
        val baseTs = System.currentTimeMillis()
        return steps.mapIndexed { idx, step ->
            TaskSubtaskItem(
                id = "sub_${baseTs}_$idx",
                title = step,
                isDone = false,
            )
        }
    }
}

@Serializable
data class TaskItem(
    val id: String,
    val userId: String,
    val projectId: String? = null,
    val parentTaskId: String? = null,
    val phaseId: String? = null,
    val dependsOnTaskIds: List<String> = emptyList(),
    val durationUncertainty: String? = null,
    val title: String,
    val description: String? = null,
    val status: TaskStatus = TaskStatus.inbox,
    val priority: TaskPriority = TaskPriority.medium,
    val dueAtMs: Long? = null,
    val scheduledStartAtMs: Long? = null,
    val estimatedDurationMinutes: Int? = null,
    val actualDurationMinutes: Int? = null,
    val energyLevel: EnergyLevel = EnergyLevel.medium,
    val source: TaskSource = TaskSource.manual,
    val aiConfidence: Double? = null,
    val createdAtMs: Long = System.currentTimeMillis(),
    val updatedAtMs: Long = System.currentTimeMillis(),
    val version: Int = 1,
    val syncStatus: SyncStatus = SyncStatus.pending,
    val recurrence: TaskRecurrence = TaskRecurrence.none,
    val deletedAtMs: Long? = null,
) {
    val isCompleted: Boolean get() = status == TaskStatus.completed
    val isCancelled: Boolean get() = status == TaskStatus.cancelled
    val isDeleted: Boolean get() = deletedAtMs != null
    val subtasks: List<TaskSubtaskItem> get() = TaskSubtasksCodec.decode(durationUncertainty)
    val completedSubtasksCount: Int get() = subtasks.count { it.isDone }
}

object TaskRecurrenceService {
    fun nextOccurrenceMs(task: TaskItem, fromMs: Long? = null): Long? {
        if (task.recurrence == TaskRecurrence.none) return null
        val baseMs = fromMs ?: task.scheduledStartAtMs ?: task.dueAtMs ?: System.currentTimeMillis()
        val cal = Calendar.getInstance().apply { timeInMillis = baseMs }
        when (task.recurrence) {
            TaskRecurrence.daily -> cal.add(Calendar.DAY_OF_YEAR, 1)
            TaskRecurrence.weekly -> cal.add(Calendar.DAY_OF_YEAR, 7)
            TaskRecurrence.weekdays -> {
                cal.add(Calendar.DAY_OF_YEAR, 1)
                while (cal.get(Calendar.DAY_OF_WEEK) == Calendar.FRIDAY ||
                    cal.get(Calendar.DAY_OF_WEEK) == Calendar.SATURDAY
                ) {
                    cal.add(Calendar.DAY_OF_YEAR, 1)
                }
            }
            TaskRecurrence.none -> return null
        }
        return cal.timeInMillis
    }
}

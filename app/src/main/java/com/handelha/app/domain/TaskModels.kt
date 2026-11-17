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

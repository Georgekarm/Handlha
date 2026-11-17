package com.handelha.app.data.repo

import com.handelha.app.domain.EnergyLevel
import com.handelha.app.domain.FocusSessionItem
import com.handelha.app.domain.StoredSubscriptionRecord
import com.handelha.app.domain.SyncStatus
import com.handelha.app.domain.TaskItem
import com.handelha.app.domain.TaskPriority
import com.handelha.app.domain.TaskRecurrence
import com.handelha.app.domain.TaskSource
import com.handelha.app.domain.TaskStatus
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class BackupTaskDto(
    val id: String,
    val projectId: String? = null,
    val parentTaskId: String? = null,
    val phaseId: String? = null,
    val dependsOnTaskIds: List<String> = emptyList(),
    val durationUncertainty: String? = null,
    val title: String,
    val description: String? = null,
    val status: String,
    val priority: String,
    val dueAt: String? = null,
    val scheduledStartAt: String? = null,
    val estimatedDurationMinutes: Int? = null,
    val actualDurationMinutes: Int? = null,
    val energyLevel: String = "medium",
    val source: String = "manual",
    val aiConfidence: Double? = null,
    val createdAt: String,
    val updatedAt: String,
    val version: Int = 1,
    val syncStatus: String = "pending",
    val recurrence: String = "none",
    val deletedAt: String? = null,
)

@Serializable
data class BackupSessionDto(
    val id: String,
    val taskId: String? = null,
    val taskTitle: String,
    val startedAt: String,
    val endedAt: String,
    val elapsedMinutes: Int,
    val completed: Boolean,
)

@Serializable
data class BackupPayloadDto(
    val schema: Int,
    val product: String,
    val exportedAt: String,
    val userId: String,
    val subscription: StoredSubscriptionRecord,
    val tasks: List<BackupTaskDto>,
    val focusSessions: List<BackupSessionDto> = emptyList(),
)

class LocalBackupManager(
    private val workspace: WorkspaceRepository,
    private val subscriptionStore: LocalSubscriptionStore,
) {
    companion object {
        const val SCHEMA_VERSION = 1
    }

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        prettyPrint = true
    }

    private fun isoFormat(): SimpleDateFormat =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }

    private fun toIso(ms: Long?): String? = ms?.let { isoFormat().format(Date(it)) }

    private fun parseIso(raw: String?): Long? {
        if (raw.isNullOrBlank()) return null
        return runCatching {
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }.parse(raw.substringBefore('.').removeSuffix("Z"))?.time
        }.getOrNull()
    }

    suspend fun exportForUser(userId: String): String {
        val tasks = workspace.getTasksForUser(userId)
        val sessions = workspace.getFocusSessionsForUser(userId)
        val subscription = subscriptionStore.loadForUser(userId)

        val payload = BackupPayloadDto(
            schema = SCHEMA_VERSION,
            product = "handelha",
            exportedAt = isoFormat().format(Date()),
            userId = userId,
            subscription = subscription,
            tasks = tasks.map { t ->
                BackupTaskDto(
                    id = t.id,
                    projectId = t.projectId,
                    parentTaskId = t.parentTaskId,
                    phaseId = t.phaseId,
                    dependsOnTaskIds = t.dependsOnTaskIds,
                    durationUncertainty = t.durationUncertainty,
                    title = t.title,
                    description = t.description,
                    status = t.status.name,
                    priority = t.priority.name,
                    dueAt = toIso(t.dueAtMs),
                    scheduledStartAt = toIso(t.scheduledStartAtMs),
                    estimatedDurationMinutes = t.estimatedDurationMinutes,
                    actualDurationMinutes = t.actualDurationMinutes,
                    energyLevel = t.energyLevel.name,
                    source = t.source.name,
                    aiConfidence = t.aiConfidence,
                    createdAt = isoFormat().format(Date(t.createdAtMs)),
                    updatedAt = isoFormat().format(Date(t.updatedAtMs)),
                    version = t.version,
                    syncStatus = t.syncStatus.name,
                    recurrence = t.recurrence.name,
                    deletedAt = toIso(t.deletedAtMs),
                )
            },
            focusSessions = sessions.map { s ->
                BackupSessionDto(
                    id = s.id,
                    taskId = s.taskId,
                    taskTitle = s.taskTitle,
                    startedAt = isoFormat().format(Date(s.startedAtMs)),
                    endedAt = isoFormat().format(Date(s.endedAtMs)),
                    elapsedMinutes = s.elapsedMinutes,
                    completed = s.completed,
                )
            },
        )
        return json.encodeToString(payload)
    }

    suspend fun importTasksForUser(userId: String, backupJson: String): Result<Int> {
        return try {
            val payload = json.decodeFromString<BackupPayloadDto>(backupJson)
            if (payload.product != "handelha" || payload.schema != SCHEMA_VERSION) {
                return Result.failure(IllegalArgumentException("ملف النسخة الاحتياطية غير مدعوم أو قديم."))
            }
            val now = System.currentTimeMillis()
            val imported = payload.tasks.map { dto ->
                TaskItem(
                    id = dto.id,
                    userId = userId,
                    projectId = dto.projectId,
                    parentTaskId = dto.parentTaskId,
                    phaseId = dto.phaseId,
                    dependsOnTaskIds = dto.dependsOnTaskIds,
                    durationUncertainty = dto.durationUncertainty,
                    title = dto.title,
                    description = dto.description,
                    status = runCatching { TaskStatus.valueOf(dto.status) }.getOrDefault(TaskStatus.inbox),
                    priority = runCatching { TaskPriority.valueOf(dto.priority) }.getOrDefault(TaskPriority.medium),
                    dueAtMs = parseIso(dto.dueAt),
                    scheduledStartAtMs = parseIso(dto.scheduledStartAt),
                    estimatedDurationMinutes = dto.estimatedDurationMinutes,
                    actualDurationMinutes = dto.actualDurationMinutes,
                    energyLevel = runCatching { EnergyLevel.valueOf(dto.energyLevel) }.getOrDefault(EnergyLevel.medium),
                    source = TaskSource.import,
                    aiConfidence = dto.aiConfidence,
                    createdAtMs = parseIso(dto.createdAt) ?: now,
                    updatedAtMs = parseIso(dto.updatedAt) ?: now,
                    version = dto.version,
                    syncStatus = SyncStatus.pending,
                    recurrence = runCatching { TaskRecurrence.valueOf(dto.recurrence) }.getOrDefault(TaskRecurrence.none),
                    deletedAtMs = parseIso(dto.deletedAt),
                )
            }
            if (imported.isNotEmpty()) {
                workspace.createApprovedTasks(imported)
            }
            Result.success(imported.size)
        } catch (_: Exception) {
            Result.failure(IllegalArgumentException("ملف النسخة الاحتياطية تالف أو غير صالح."))
        }
    }
}

package com.handelha.app.data.repo

import com.handelha.app.data.local.AppPreferencesStore
import com.handelha.app.data.local.ChatConversationEntity
import com.handelha.app.data.local.ExamGradeEntity
import com.handelha.app.data.local.FocusSessionEntity
import com.handelha.app.data.local.HandelhaDatabase
import com.handelha.app.data.local.ProjectEntity
import com.handelha.app.data.local.TaskEntity
import com.handelha.app.domain.ChatConversationRecord
import com.handelha.app.domain.EnergyLevel
import com.handelha.app.domain.ExamGradeEntry
import com.handelha.app.domain.ExamGradesHelper
import com.handelha.app.domain.FocusSessionItem
import com.handelha.app.domain.ProjectItem
import com.handelha.app.domain.ProjectPhaseRecord
import com.handelha.app.domain.ProjectStatus
import com.handelha.app.domain.SyncStatus
import com.handelha.app.domain.TaskItem
import com.handelha.app.domain.TaskPriority
import com.handelha.app.domain.TaskRecurrence
import com.handelha.app.domain.TaskRecurrenceService
import com.handelha.app.domain.TaskSource
import com.handelha.app.domain.TaskStatus
import com.handelha.app.domain.UserEnergyPreferences
import java.util.Calendar
import java.util.UUID
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class WorkspaceRepository(
    private val db: HandelhaDatabase,
    private val prefs: AppPreferencesStore,
) {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    fun observeTasks(userId: String): Flow<List<TaskItem>> =
        db.taskDao().observeForUser(userId).map { list -> list.map { it.toDomain() } }

    fun observeProjects(userId: String): Flow<List<ProjectItem>> =
        db.projectDao().observeForUser(userId).map { list -> list.map { it.toDomain() } }

    fun observeFocusSessions(userId: String): Flow<List<FocusSessionItem>> =
        db.focusSessionDao().observeForUser(userId).map { list -> list.map { it.toDomain() } }

    fun observeExamGrades(userId: String): Flow<List<ExamGradeEntry>> =
        db.examGradeDao().observeForUser(userId).map { list -> list.map { it.toDomain() } }

    fun observeConversations(userId: String): Flow<List<ChatConversationRecord>> =
        db.chatConversationDao().observeForUser(userId).map { list -> list.map { it.toDomain() } }

    suspend fun getTasksForUser(userId: String): List<TaskItem> {
        healLegacyMergedExamTask(userId)
        return db.taskDao().getForUser(userId).map { it.toDomain() }
    }

    suspend fun getProjectsForUser(userId: String): List<ProjectItem> =
        db.projectDao().getForUser(userId).map { it.toDomain() }

    suspend fun getFocusSessionsForUser(userId: String): List<FocusSessionItem> =
        db.focusSessionDao().getForUser(userId).map { it.toDomain() }

    private suspend fun healLegacyMergedExamTask(userId: String) {
        val current = db.taskDao().getForUser(userId).map { it.toDomain() }
        val merged = current.firstOrNull { it.title.trim() == "امتحان عربي وامتحان انجليزي" } ?: return
        val baseMs = merged.dueAtMs ?: merged.scheduledStartAtMs
            ?: (System.currentTimeMillis() + 86_400_000L)
        val cal = Calendar.getInstance().apply { timeInMillis = baseMs }
        cal.set(Calendar.HOUR_OF_DAY, 8)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val morning = cal.timeInMillis
        cal.set(Calendar.HOUR_OF_DAY, 20)
        val evening = cal.timeInMillis

        val now = System.currentTimeMillis()
        db.taskDao().upsert(TaskEntity.fromDomain(merged.copy(deletedAtMs = now)))
        db.taskDao().upsertAll(
            listOf(
                TaskEntity.fromDomain(
                    merged.copy(
                        id = UUID.randomUUID().toString(),
                        title = "امتحان عربي",
                        dueAtMs = morning,
                        scheduledStartAtMs = morning,
                        priority = TaskPriority.high,
                        updatedAtMs = now,
                    ),
                ),
                TaskEntity.fromDomain(
                    merged.copy(
                        id = UUID.randomUUID().toString(),
                        title = "امتحان انجليزي",
                        dueAtMs = evening,
                        scheduledStartAtMs = evening,
                        priority = TaskPriority.high,
                        updatedAtMs = now,
                    ),
                ),
            ),
        )
    }

    suspend fun createTask(
        userId: String,
        title: String,
        description: String? = null,
        priority: TaskPriority = TaskPriority.medium,
        dueAtMs: Long? = null,
        scheduledStartAtMs: Long? = null,
        estimatedDurationMinutes: Int? = null,
        status: TaskStatus = TaskStatus.inbox,
        energyLevel: EnergyLevel = EnergyLevel.medium,
        source: TaskSource = TaskSource.manual,
        recurrence: TaskRecurrence = TaskRecurrence.none,
        projectId: String? = null,
        phaseId: String? = null,
        dependsOnTaskIds: List<String> = emptyList(),
        durationUncertainty: String? = null,
    ): TaskItem {
        val now = System.currentTimeMillis()
        val task = TaskItem(
            id = UUID.randomUUID().toString(),
            userId = userId,
            projectId = projectId,
            phaseId = phaseId,
            dependsOnTaskIds = dependsOnTaskIds,
            durationUncertainty = durationUncertainty,
            title = title.trim(),
            description = description?.trim()?.ifEmpty { null },
            status = status,
            priority = priority,
            dueAtMs = dueAtMs,
            scheduledStartAtMs = scheduledStartAtMs,
            estimatedDurationMinutes = estimatedDurationMinutes,
            energyLevel = energyLevel,
            source = source,
            createdAtMs = now,
            updatedAtMs = now,
            version = 1,
            syncStatus = SyncStatus.pending,
            recurrence = recurrence,
        )
        db.taskDao().upsert(TaskEntity.fromDomain(task))
        if (!projectId.isNullOrBlank()) {
            syncProjectProgress(userId, projectId)
        }
        return task
    }

    suspend fun createApprovedTasks(tasks: List<TaskItem>) {
        if (tasks.isEmpty()) return
        db.taskDao().upsertAll(tasks.map { TaskEntity.fromDomain(it) })
        val userId = tasks.first().userId
        tasks.mapNotNull { it.projectId }.distinct().forEach { projectId ->
            syncProjectProgress(userId, projectId)
        }
    }

    suspend fun updateTask(updated: TaskItem): TaskItem {
        val next = updated.copy(
            updatedAtMs = System.currentTimeMillis(),
            version = updated.version + 1,
            syncStatus = SyncStatus.pending,
        )
        db.taskDao().upsert(TaskEntity.fromDomain(next))
        if (!next.projectId.isNullOrBlank()) {
            syncProjectProgress(next.userId, next.projectId)
        }
        return next
    }

    suspend fun completeTask(taskId: String): Pair<TaskItem?, TaskItem?> {
        val existing = db.taskDao().getById(taskId)?.toDomain() ?: return null to null
        val now = System.currentTimeMillis()
        val completed = existing.copy(
            status = TaskStatus.completed,
            updatedAtMs = now,
            version = existing.version + 1,
            syncStatus = SyncStatus.pending,
        )
        db.taskDao().upsert(TaskEntity.fromDomain(completed))

        val nextDateMs = TaskRecurrenceService.nextOccurrenceMs(existing)
        var spawned: TaskItem? = null
        if (nextDateMs != null) {
            spawned = TaskItem(
                id = UUID.randomUUID().toString(),
                userId = existing.userId,
                projectId = existing.projectId,
                parentTaskId = existing.parentTaskId,
                phaseId = existing.phaseId,
                dependsOnTaskIds = existing.dependsOnTaskIds,
                durationUncertainty = existing.durationUncertainty,
                title = existing.title,
                description = existing.description,
                status = TaskStatus.planned,
                priority = existing.priority,
                dueAtMs = nextDateMs,
                scheduledStartAtMs = nextDateMs,
                estimatedDurationMinutes = existing.estimatedDurationMinutes,
                energyLevel = existing.energyLevel,
                source = existing.source,
                aiConfidence = existing.aiConfidence,
                createdAtMs = now,
                updatedAtMs = now,
                version = 1,
                syncStatus = SyncStatus.pending,
                recurrence = existing.recurrence,
            )
            db.taskDao().upsert(TaskEntity.fromDomain(spawned))
        }
        if (!existing.projectId.isNullOrBlank()) {
            syncProjectProgress(existing.userId, existing.projectId)
        }
        return completed to spawned
    }

    suspend fun toggleTaskCompletion(taskId: String): Pair<TaskItem?, TaskItem?> {
        val existing = db.taskDao().getById(taskId)?.toDomain() ?: return null to null
        return if (existing.isCompleted) {
            val reopened = updateTask(
                existing.copy(
                    status = if (existing.dueAtMs != null || existing.scheduledStartAtMs != null) {
                        TaskStatus.planned
                    } else {
                        TaskStatus.inbox
                    },
                ),
            )
            reopened to null
        } else {
            completeTask(taskId)
        }
    }

    suspend fun deleteTask(taskId: String) {
        val existing = db.taskDao().getById(taskId)?.toDomain() ?: return
        db.taskDao().upsert(
            TaskEntity.fromDomain(
                existing.copy(
                    deletedAtMs = System.currentTimeMillis(),
                    syncStatus = SyncStatus.pending,
                ),
            ),
        )
        if (!existing.projectId.isNullOrBlank()) {
            syncProjectProgress(existing.userId, existing.projectId)
        }
    }

    suspend fun saveProject(
        userId: String,
        title: String,
        description: String? = null,
        targetDateMs: Long? = null,
        colorValue: Long = 0xFF007067L,
        phases: List<ProjectPhaseRecord> = emptyList(),
        initialStepTitles: List<String> = emptyList(),
    ): ProjectItem {
        val now = System.currentTimeMillis()
        val projectId = UUID.randomUUID().toString()
        val createdTasks = initialStepTitles.filter { it.isNotBlank() }.mapIndexed { idx, stepTitle ->
            TaskItem(
                id = UUID.randomUUID().toString(),
                userId = userId,
                projectId = projectId,
                title = stepTitle.trim(),
                status = TaskStatus.planned,
                priority = if (idx == 0) TaskPriority.high else TaskPriority.medium,
                dueAtMs = targetDateMs,
                estimatedDurationMinutes = 45,
                energyLevel = EnergyLevel.medium,
                source = TaskSource.manual,
                createdAtMs = now + idx,
                updatedAtMs = now + idx,
            )
        }
        if (createdTasks.isNotEmpty()) {
            db.taskDao().upsertAll(createdTasks.map { TaskEntity.fromDomain(it) })
        }
        val project = ProjectItem(
            id = projectId,
            userId = userId,
            title = title.trim(),
            description = description?.trim()?.ifEmpty { null },
            status = ProjectStatus.active,
            progressPercent = 0.0,
            nextStepTitle = createdTasks.firstOrNull()?.title,
            targetDateMs = targetDateMs,
            taskIds = createdTasks.map { it.id },
            phases = phases,
            colorValue = colorValue,
            createdAtMs = now,
            updatedAtMs = now,
        )
        db.projectDao().upsert(ProjectEntity.fromDomain(project))
        return project
    }

    suspend fun updateProject(project: ProjectItem) {
        db.projectDao().upsert(
            ProjectEntity.fromDomain(project.copy(updatedAtMs = System.currentTimeMillis())),
        )
    }

    suspend fun deleteProject(projectId: String) {
        db.projectDao().deleteById(projectId)
    }

    suspend fun syncProjectProgress(userId: String, projectId: String) {
        val project = db.projectDao().getForUser(userId).firstOrNull { it.id == projectId }?.toDomain()
            ?: return
        val projectTasks = db.taskDao().getForUser(userId)
            .map { it.toDomain() }
            .filter { it.projectId == projectId && !it.isCancelled && !it.isDeleted }
        if (projectTasks.isEmpty()) return
        val completedCount = projectTasks.count { it.isCompleted }
        val progress = (completedCount.toDouble() / projectTasks.size.toDouble()) * 100.0
        val nextTask = projectTasks.firstOrNull { !it.isCompleted }
        val nextStatus = if (completedCount == projectTasks.size) ProjectStatus.completed else ProjectStatus.active
        db.projectDao().upsert(
            ProjectEntity.fromDomain(
                project.copy(
                    status = nextStatus,
                    progressPercent = progress,
                    nextStepTitle = nextTask?.title,
                    taskIds = projectTasks.map { it.id },
                    updatedAtMs = System.currentTimeMillis(),
                ),
            ),
        )
    }

    suspend fun recordFocusSession(
        userId: String,
        taskId: String?,
        taskTitle: String,
        startedAtMs: Long,
        endedAtMs: Long,
        elapsedMinutes: Int,
        completed: Boolean,
    ): FocusSessionItem {
        val session = FocusSessionItem(
            id = UUID.randomUUID().toString(),
            userId = userId,
            taskId = taskId,
            taskTitle = taskTitle.trim().ifEmpty { "جلسة تركيز هادئة" },
            startedAtMs = startedAtMs,
            endedAtMs = maxOf(endedAtMs, startedAtMs),
            elapsedMinutes = elapsedMinutes.coerceAtLeast(0),
            completed = completed,
        )
        db.focusSessionDao().insert(FocusSessionEntity.fromDomain(session))
        return session
    }

    suspend fun addExamGrade(
        userId: String,
        examTitle: String,
        gradeTier: String,
        scoreLabel: String,
    ): ExamGradeEntry {
        val msg = ExamGradesHelper.buildEncouragement(examTitle, gradeTier, scoreLabel)
        val entry = ExamGradeEntry(
            id = "grade_${System.currentTimeMillis()}",
            userId = userId,
            examTitle = examTitle.trim(),
            gradeTier = gradeTier,
            scoreLabel = scoreLabel.trim(),
            encouragementAr = msg.ar,
            encouragementEn = msg.en,
            recordedAtMs = System.currentTimeMillis(),
        )
        db.examGradeDao().insert(ExamGradeEntity.fromDomain(entry))
        return entry
    }

    suspend fun deleteExamGrade(id: String) {
        db.examGradeDao().deleteById(id)
    }

    suspend fun loadEnergyPreferences(userId: String): UserEnergyPreferences {
        val raw = prefs.snapshot()[prefs.userEnergyPrefsKey(userId)] ?: return UserEnergyPreferences()
        return runCatching { json.decodeFromString<UserEnergyPreferences>(raw) }
            .getOrDefault(UserEnergyPreferences())
    }

    suspend fun saveEnergyPreferences(userId: String, value: UserEnergyPreferences) {
        prefs.update { ed ->
            ed[prefs.userEnergyPrefsKey(userId)] = json.encodeToString(value)
        }
    }

    suspend fun saveConversation(record: ChatConversationRecord) {
        db.chatConversationDao().upsert(ChatConversationEntity.fromDomain(record))
    }

    suspend fun getConversation(conversationId: String): ChatConversationRecord? =
        db.chatConversationDao().getById(conversationId)?.toDomain()

    suspend fun deleteConversation(conversationId: String) {
        db.chatConversationDao().deleteById(conversationId)
    }
}

package com.handelha.app.data.local

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import com.handelha.app.domain.ChatConversationRecord
import com.handelha.app.domain.ChatMessageItem
import com.handelha.app.domain.EnergyLevel
import com.handelha.app.domain.ExamGradeEntry
import com.handelha.app.domain.FocusSessionItem
import com.handelha.app.domain.ProjectItem
import com.handelha.app.domain.ProjectPhaseRecord
import com.handelha.app.domain.ProjectStatus
import com.handelha.app.domain.SyncStatus
import com.handelha.app.domain.TaskItem
import com.handelha.app.domain.TaskPriority
import com.handelha.app.domain.TaskRecurrence
import com.handelha.app.domain.TaskSource
import com.handelha.app.domain.TaskStatus
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val roomJson = Json {
    ignoreUnknownKeys = true
    encodeDefaults = true
}

@Entity(tableName = "tasks")
data class TaskEntity(
    @PrimaryKey val id: String,
    val userId: String,
    val projectId: String?,
    val parentTaskId: String?,
    val phaseId: String?,
    val dependsOnJson: String,
    val durationUncertainty: String?,
    val title: String,
    val description: String?,
    val status: String,
    val priority: String,
    val dueAtMs: Long?,
    val scheduledStartAtMs: Long?,
    val estimatedDurationMinutes: Int?,
    val actualDurationMinutes: Int?,
    val energyLevel: String,
    val source: String,
    val aiConfidence: Double?,
    val createdAtMs: Long,
    val updatedAtMs: Long,
    val version: Int,
    val syncStatus: String,
    val recurrence: String,
    val deletedAtMs: Long?,
) {
    fun toDomain(): TaskItem = TaskItem(
        id = id,
        userId = userId,
        projectId = projectId,
        parentTaskId = parentTaskId,
        phaseId = phaseId,
        dependsOnTaskIds = runCatching { roomJson.decodeFromString<List<String>>(dependsOnJson) }.getOrDefault(emptyList()),
        durationUncertainty = durationUncertainty,
        title = title,
        description = description,
        status = runCatching { TaskStatus.valueOf(status) }.getOrDefault(TaskStatus.inbox),
        priority = runCatching { TaskPriority.valueOf(priority) }.getOrDefault(TaskPriority.medium),
        dueAtMs = dueAtMs,
        scheduledStartAtMs = scheduledStartAtMs,
        estimatedDurationMinutes = estimatedDurationMinutes,
        actualDurationMinutes = actualDurationMinutes,
        energyLevel = runCatching { EnergyLevel.valueOf(energyLevel) }.getOrDefault(EnergyLevel.medium),
        source = runCatching { TaskSource.valueOf(source) }.getOrDefault(TaskSource.manual),
        aiConfidence = aiConfidence,
        createdAtMs = createdAtMs,
        updatedAtMs = updatedAtMs,
        version = version,
        syncStatus = runCatching { SyncStatus.valueOf(syncStatus) }.getOrDefault(SyncStatus.pending),
        recurrence = runCatching { TaskRecurrence.valueOf(recurrence) }.getOrDefault(TaskRecurrence.none),
        deletedAtMs = deletedAtMs,
    )

    companion object {
        fun fromDomain(t: TaskItem): TaskEntity = TaskEntity(
            id = t.id,
            userId = t.userId,
            projectId = t.projectId,
            parentTaskId = t.parentTaskId,
            phaseId = t.phaseId,
            dependsOnJson = roomJson.encodeToString(t.dependsOnTaskIds),
            durationUncertainty = t.durationUncertainty,
            title = t.title,
            description = t.description,
            status = t.status.name,
            priority = t.priority.name,
            dueAtMs = t.dueAtMs,
            scheduledStartAtMs = t.scheduledStartAtMs,
            estimatedDurationMinutes = t.estimatedDurationMinutes,
            actualDurationMinutes = t.actualDurationMinutes,
            energyLevel = t.energyLevel.name,
            source = t.source.name,
            aiConfidence = t.aiConfidence,
            createdAtMs = t.createdAtMs,
            updatedAtMs = t.updatedAtMs,
            version = t.version,
            syncStatus = t.syncStatus.name,
            recurrence = t.recurrence.name,
            deletedAtMs = t.deletedAtMs,
        )
    }
}

@Entity(tableName = "projects")
data class ProjectEntity(
    @PrimaryKey val id: String,
    val userId: String,
    val title: String,
    val description: String?,
    val status: String,
    val progressPercent: Double,
    val nextStepTitle: String?,
    val targetDateMs: Long?,
    val taskIdsJson: String,
    val phasesJson: String,
    val colorValue: Long,
    val createdAtMs: Long,
    val updatedAtMs: Long,
) {
    fun toDomain(): ProjectItem = ProjectItem(
        id = id,
        userId = userId,
        title = title,
        description = description,
        status = runCatching { ProjectStatus.valueOf(status) }.getOrDefault(ProjectStatus.active),
        progressPercent = progressPercent,
        nextStepTitle = nextStepTitle,
        targetDateMs = targetDateMs,
        taskIds = runCatching { roomJson.decodeFromString<List<String>>(taskIdsJson) }.getOrDefault(emptyList()),
        phases = runCatching { roomJson.decodeFromString<List<ProjectPhaseRecord>>(phasesJson) }.getOrDefault(emptyList()),
        colorValue = colorValue,
        createdAtMs = createdAtMs,
        updatedAtMs = updatedAtMs,
    )

    companion object {
        fun fromDomain(p: ProjectItem): ProjectEntity = ProjectEntity(
            id = p.id,
            userId = p.userId,
            title = p.title,
            description = p.description,
            status = p.status.name,
            progressPercent = p.progressPercent,
            nextStepTitle = p.nextStepTitle,
            targetDateMs = p.targetDateMs,
            taskIdsJson = roomJson.encodeToString(p.taskIds),
            phasesJson = roomJson.encodeToString(p.phases),
            colorValue = p.colorValue,
            createdAtMs = p.createdAtMs,
            updatedAtMs = p.updatedAtMs,
        )
    }
}

@Entity(tableName = "focus_sessions")
data class FocusSessionEntity(
    @PrimaryKey val id: String,
    val userId: String,
    val taskId: String?,
    val taskTitle: String,
    val startedAtMs: Long,
    val endedAtMs: Long,
    val elapsedMinutes: Int,
    val completed: Boolean,
) {
    fun toDomain(): FocusSessionItem = FocusSessionItem(
        id = id,
        userId = userId,
        taskId = taskId,
        taskTitle = taskTitle,
        startedAtMs = startedAtMs,
        endedAtMs = endedAtMs,
        elapsedMinutes = elapsedMinutes,
        completed = completed,
    )

    companion object {
        fun fromDomain(s: FocusSessionItem): FocusSessionEntity = FocusSessionEntity(
            id = s.id,
            userId = s.userId,
            taskId = s.taskId,
            taskTitle = s.taskTitle,
            startedAtMs = s.startedAtMs,
            endedAtMs = s.endedAtMs,
            elapsedMinutes = s.elapsedMinutes,
            completed = s.completed,
        )
    }
}

@Entity(tableName = "exam_grades")
data class ExamGradeEntity(
    @PrimaryKey val id: String,
    val userId: String,
    val examTitle: String,
    val gradeTier: String,
    val scoreLabel: String,
    val encouragementAr: String,
    val encouragementEn: String,
    val recordedAtMs: Long,
) {
    fun toDomain(): ExamGradeEntry = ExamGradeEntry(
        id = id,
        userId = userId,
        examTitle = examTitle,
        gradeTier = gradeTier,
        scoreLabel = scoreLabel,
        encouragementAr = encouragementAr,
        encouragementEn = encouragementEn,
        recordedAtMs = recordedAtMs,
    )

    companion object {
        fun fromDomain(e: ExamGradeEntry): ExamGradeEntity = ExamGradeEntity(
            id = e.id,
            userId = e.userId,
            examTitle = e.examTitle,
            gradeTier = e.gradeTier,
            scoreLabel = e.scoreLabel,
            encouragementAr = e.encouragementAr,
            encouragementEn = e.encouragementEn,
            recordedAtMs = e.recordedAtMs,
        )
    }
}

@Entity(tableName = "chat_conversations")
data class ChatConversationEntity(
    @PrimaryKey val id: String,
    val userId: String,
    val title: String,
    val createdAtMs: Long,
    val updatedAtMs: Long,
    val messagesJson: String,
) {
    fun toDomain(): ChatConversationRecord = ChatConversationRecord(
        id = id,
        userId = userId,
        title = title,
        createdAtMs = createdAtMs,
        updatedAtMs = updatedAtMs,
        messages = runCatching { roomJson.decodeFromString<List<ChatMessageItem>>(messagesJson) }.getOrDefault(emptyList()),
    )

    companion object {
        fun fromDomain(c: ChatConversationRecord): ChatConversationEntity = ChatConversationEntity(
            id = c.id,
            userId = c.userId,
            title = c.title,
            createdAtMs = c.createdAtMs,
            updatedAtMs = c.updatedAtMs,
            messagesJson = roomJson.encodeToString(c.messages),
        )
    }
}

@Dao
interface TaskDao {
    @Query("SELECT * FROM tasks WHERE userId = :userId AND deletedAtMs IS NULL ORDER BY createdAtMs DESC")
    fun observeForUser(userId: String): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE userId = :userId AND deletedAtMs IS NULL")
    suspend fun getForUser(userId: String): List<TaskEntity>

    @Query("SELECT * FROM tasks WHERE id = :id LIMIT 1")
    suspend fun getById(id: String): TaskEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(task: TaskEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(tasks: List<TaskEntity>)

    @Query("DELETE FROM tasks WHERE userId = :userId")
    suspend fun deleteForUser(userId: String)
}

@Dao
interface ProjectDao {
    @Query("SELECT * FROM projects WHERE userId = :userId ORDER BY updatedAtMs DESC")
    fun observeForUser(userId: String): Flow<List<ProjectEntity>>

    @Query("SELECT * FROM projects WHERE userId = :userId ORDER BY updatedAtMs DESC")
    suspend fun getForUser(userId: String): List<ProjectEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(project: ProjectEntity)

    @Query("DELETE FROM projects WHERE id = :projectId")
    suspend fun deleteById(projectId: String)

    @Query("DELETE FROM projects WHERE userId = :userId")
    suspend fun deleteForUser(userId: String)
}

@Dao
interface FocusSessionDao {
    @Query("SELECT * FROM focus_sessions WHERE userId = :userId ORDER BY endedAtMs DESC")
    fun observeForUser(userId: String): Flow<List<FocusSessionEntity>>

    @Query("SELECT * FROM focus_sessions WHERE userId = :userId ORDER BY endedAtMs DESC")
    suspend fun getForUser(userId: String): List<FocusSessionEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(session: FocusSessionEntity)

    @Query("DELETE FROM focus_sessions WHERE userId = :userId")
    suspend fun deleteForUser(userId: String)
}

@Dao
interface ExamGradeDao {
    @Query("SELECT * FROM exam_grades WHERE userId = :userId ORDER BY recordedAtMs DESC")
    fun observeForUser(userId: String): Flow<List<ExamGradeEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entry: ExamGradeEntity)

    @Query("DELETE FROM exam_grades WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM exam_grades WHERE userId = :userId")
    suspend fun deleteForUser(userId: String)
}

@Dao
interface ChatConversationDao {
    @Query("SELECT * FROM chat_conversations WHERE userId = :userId ORDER BY updatedAtMs DESC")
    fun observeForUser(userId: String): Flow<List<ChatConversationEntity>>

    @Query("SELECT * FROM chat_conversations WHERE id = :id LIMIT 1")
    suspend fun getById(id: String): ChatConversationEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(conversation: ChatConversationEntity)

    @Query("DELETE FROM chat_conversations WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM chat_conversations WHERE userId = :userId")
    suspend fun deleteForUser(userId: String)
}

@Database(
    entities = [
        TaskEntity::class,
        ProjectEntity::class,
        FocusSessionEntity::class,
        ExamGradeEntity::class,
        ChatConversationEntity::class,
    ],
    version = 1,
    exportSchema = false,
)
abstract class HandelhaDatabase : RoomDatabase() {
    abstract fun taskDao(): TaskDao
    abstract fun projectDao(): ProjectDao
    abstract fun focusSessionDao(): FocusSessionDao
    abstract fun examGradeDao(): ExamGradeDao
    abstract fun chatConversationDao(): ChatConversationDao

    companion object {
        @Volatile
        private var instance: HandelhaDatabase? = null

        fun getInstance(context: Context): HandelhaDatabase {
            return instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    HandelhaDatabase::class.java,
                    "handelha_room_v1.db",
                ).build().also { instance = it }
            }
        }
    }
}

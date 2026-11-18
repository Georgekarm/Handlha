package com.handelha.app.ui

import android.app.Application
import android.content.Intent
import android.provider.Settings
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.handelha.app.NativeAlarmScheduler
import com.handelha.app.core.audio.AmbientSoundscape
import com.handelha.app.core.audio.HandelhaSoundEngine
import com.handelha.app.data.local.AppPreferencesStore
import com.handelha.app.data.local.HandelhaDatabase
import com.handelha.app.data.repo.AuthResult
import com.handelha.app.data.repo.LocalAuthRepository
import com.handelha.app.data.repo.LocalBackupManager
import com.handelha.app.data.repo.LocalNotificationScheduler
import com.handelha.app.data.repo.LocalSubscriptionStore
import com.handelha.app.data.repo.TokenBalanceRepository
import com.handelha.app.data.repo.WorkspaceRepository
import com.handelha.app.domain.ActiveAlarmRing
import com.handelha.app.domain.AlarmReminderItem
import com.handelha.app.domain.AlarmReminderState
import com.handelha.app.domain.AppUser
import com.handelha.app.domain.AssistantActionProposal
import com.handelha.app.domain.AssistantTone
import com.handelha.app.domain.AuthProviderType
import com.handelha.app.domain.ChatConversationRecord
import com.handelha.app.domain.ChatMessageItem
import com.handelha.app.domain.ChatMessageRole
import com.handelha.app.domain.EnergyLevel
import com.handelha.app.domain.ExamGradeEntry
import com.handelha.app.domain.FocusSessionItem
import com.handelha.app.domain.NotificationPermissionStatus
import com.handelha.app.domain.NotificationPreferences
import com.handelha.app.domain.ProjectItem
import com.handelha.app.domain.ProjectPhaseRecord
import com.handelha.app.domain.ProjectStatus
import com.handelha.app.domain.StudentMotivationState
import com.handelha.app.domain.StudentQuoteCategory
import com.handelha.app.domain.StudentQuoteItem
import com.handelha.app.domain.StudentQuotesCatalog
import com.handelha.app.domain.StudentStudyMood
import com.handelha.app.domain.SubscriptionOffer
import com.handelha.app.domain.SubscriptionState
import com.handelha.app.domain.TaskItem
import com.handelha.app.domain.TaskPriority
import com.handelha.app.domain.TaskRecurrence
import com.handelha.app.domain.TaskSource
import com.handelha.app.domain.TaskStatus
import com.handelha.app.domain.TokenBalanceState
import com.handelha.app.domain.UserEnergyPreferences
import com.handelha.app.ui.theme.AppThemeMode
import com.handelha.app.util.ArabicFormatters
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.UUID
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ToastFeedback(
    val id: Long = System.currentTimeMillis(),
    val message: String,
    val isError: Boolean = false,
)

data class FocusTimerUiState(
    val linkedTaskId: String? = null,
    val linkedTaskTitle: String = "",
    val selectedFocusMinutes: Int = 25,
    val selectedBreakMinutes: Int = 5,
    val isBreakMode: Boolean = false,
    val isRunning: Boolean = false,
    val remainingSeconds: Int = 25 * 60,
    val totalSeconds: Int = 25 * 60,
    val startedAtMs: Long? = null,
    val selectedSound: AmbientSoundscape = AmbientSoundscape.SILENT,
    val volume: Float = 0.65f,
    val showCompletionCelebration: Boolean = false,
    val lastCompletedMinutes: Int = 0,
)

data class ChatUiState(
    val activeConversationId: String = UUID.randomUUID().toString(),
    val messages: List<ChatMessageItem> = emptyList(),
    val isSending: Boolean = false,
    val voiceStatusLabel: String? = null,
    val isListening: Boolean = false,
    val pendingProposal: AssistantActionProposal? = null,
    val showTokenRefillSheet: Boolean = false,
)

data class HandelhaAppUiState(
    val isInitializing: Boolean = true,
    val onboardingComplete: Boolean = false,
    val user: AppUser? = null,
    val authLoading: Boolean = false,
    val themeMode: AppThemeMode = AppThemeMode.SYSTEM,
    val isEnglish: Boolean = false,
    val isStudentMode: Boolean = false,
    val tasks: List<TaskItem> = emptyList(),
    val projects: List<ProjectItem> = emptyList(),
    val focusSessions: List<FocusSessionItem> = emptyList(),
    val examGrades: List<ExamGradeEntry> = emptyList(),
    val conversations: List<ChatConversationRecord> = emptyList(),
    val energyPrefs: UserEnergyPreferences = UserEnergyPreferences(),
    val notifPrefs: NotificationPreferences = NotificationPreferences(),
    val readNotifIds: Set<String> = emptySet(),
    val alarmState: AlarmReminderState = AlarmReminderState(),
    val notifPermissions: NotificationPermissionStatus = NotificationPermissionStatus(false, false, true, true),
    val activeAlarmRing: ActiveAlarmRing? = null,
    val tokenState: TokenBalanceState = TokenBalanceState(),
    val subscriptionState: SubscriptionState = SubscriptionState(),
    val focusState: FocusTimerUiState = FocusTimerUiState(),
    val chatState: ChatUiState = ChatUiState(),
    val studentMotivation: StudentMotivationState = StudentMotivationState(),
)

class HandelhaAppViewModel(application: Application) : AndroidViewModel(application) {
    private val appContext = application.applicationContext
    val prefs = AppPreferencesStore(appContext)
    private val db = HandelhaDatabase.getInstance(appContext)
    val subStore = LocalSubscriptionStore(prefs)
    val authRepo = LocalAuthRepository(prefs, db, subStore)
    val workspaceRepo = WorkspaceRepository(db, prefs)
    val notifScheduler = LocalNotificationScheduler(appContext, prefs)
    val tokenRepo = TokenBalanceRepository(prefs)
    val backupManager = LocalBackupManager(workspaceRepo, subStore)
    val soundEngine = HandelhaSoundEngine(appContext)

    private val _uiState = MutableStateFlow(HandelhaAppUiState())
    val uiState: StateFlow<HandelhaAppUiState> = _uiState.asStateFlow()

    private val _toast = MutableStateFlow<ToastFeedback?>(null)
    val toast: StateFlow<ToastFeedback?> = _toast.asStateFlow()

    private var userDataJob: Job? = null
    private var focusTickerJob: Job? = null

    init {
        viewModelScope.launch {
            combine(
                prefs.themeModeFlow,
                prefs.languageCodeFlow,
                prefs.studentModeFlow,
            ) { mode, lang, student ->
                Triple(mode, lang == "en", student)
            }.collectLatest { (mode, isEn, student) ->
                ArabicFormatters.useEnglish = isEn
                val uid = _uiState.value.user?.id
                val subState = if (uid != null) subStore.loadStateForUser(uid, isEn) else SubscriptionState(offers = subStore.buildOffers(isEn))
                _uiState.update {
                    it.copy(
                        themeMode = mode,
                        isEnglish = isEn,
                        isStudentMode = student || subState.isStudent,
                        subscriptionState = subState,
                    )
                }
            }
        }
        viewModelScope.launch {
            bootstrapSession()
        }
    }

    private suspend fun bootstrapSession() {
        val snap = prefs.snapshot()
        val onboardingDone = snap[AppPreferencesStore.AuthKeys.ONBOARDING_COMPLETE] ?: false
        val user = authRepo.getCurrentUser()
        val perms = notifScheduler.checkPermissions()
        _uiState.update {
            it.copy(
                isInitializing = false,
                onboardingComplete = onboardingDone || user?.onboardingComplete == true,
                user = user,
                notifPermissions = perms,
            )
        }
        if (user != null) {
            attachUserStreams(user.id)
        }
    }

    private fun attachUserStreams(userId: String) {
        userDataJob?.cancel()
        userDataJob = viewModelScope.launch {
            launch {
                workspaceRepo.getTasksForUser(userId)
                refreshUserMeta(userId)
            }
            combine(
                workspaceRepo.observeTasks(userId),
                workspaceRepo.observeProjects(userId),
                workspaceRepo.observeFocusSessions(userId),
                workspaceRepo.observeExamGrades(userId),
                workspaceRepo.observeConversations(userId),
            ) { tasks, projects, sessions, grades, convs ->
                WorkspaceBundle(tasks, projects, sessions, grades, convs)
            }.collectLatest { b ->
                _uiState.update {
                    it.copy(
                        tasks = b.tasks.filter { t -> !t.isDeleted },
                        projects = b.projects,
                        focusSessions = b.sessions,
                        examGrades = b.grades,
                        conversations = b.convs,
                    )
                }
            }
        }
    }

    private data class WorkspaceBundle(
        val tasks: List<TaskItem>,
        val projects: List<ProjectItem>,
        val sessions: List<FocusSessionItem>,
        val grades: List<ExamGradeEntry>,
        val convs: List<ChatConversationRecord>,
    )

    private suspend fun refreshUserMeta(userId: String) {
        val isEn = _uiState.value.isEnglish
        val energy = workspaceRepo.loadEnergyPreferences(userId)
        val nPrefs = notifScheduler.loadNotificationPreferences(userId)
        val readIds = notifScheduler.loadReadIds(userId)
        val alarm = notifScheduler.loadAlarmReminderState(userId)
        val tokens = tokenRepo.load(userId)
        val sub = subStore.loadStateForUser(userId, isEn)
        val perms = notifScheduler.checkPermissions()
        val studentMot = loadStudentMotivation(userId)
        _uiState.update {
            it.copy(
                energyPrefs = energy,
                notifPrefs = nPrefs,
                readNotifIds = readIds,
                alarmState = alarm,
                tokenState = tokens,
                subscriptionState = sub,
                isStudentMode = it.isStudentMode || sub.isStudent,
                notifPermissions = perms,
                studentMotivation = studentMot,
            )
        }
    }

    fun showToast(message: String, isError: Boolean = false) {
        _toast.value = ToastFeedback(System.currentTimeMillis(), message, isError)
    }

    fun dismissToast() {
        _toast.value = null
    }

    fun refreshPermissions() {
        val perms = notifScheduler.checkPermissions()
        _uiState.update { it.copy(notifPermissions = perms) }
    }

    fun openNotificationSettings() {
        runCatching {
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, appContext.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            appContext.startActivity(intent)
        }
    }

    // ---------------------------------------------------------------------
    // Onboarding, Language, Theme, Auth
    // ---------------------------------------------------------------------

    fun completeOnboarding() {
        viewModelScope.launch {
            authRepo.markOnboardingComplete()
            _uiState.update { it.copy(onboardingComplete = true) }
        }
    }

    fun setThemeMode(mode: AppThemeMode) {
        viewModelScope.launch { prefs.setThemeMode(mode) }
    }

    fun toggleThemeQuick() {
        val cur = _uiState.value.themeMode
        val next = if (cur == AppThemeMode.DARK) AppThemeMode.LIGHT else AppThemeMode.DARK
        setThemeMode(next)
    }

    fun setEnglish(isEn: Boolean) {
        ArabicFormatters.useEnglish = isEn
        viewModelScope.launch { prefs.setLanguageCode(if (isEn) "en" else "ar") }
    }

    fun toggleLanguage() = setEnglish(!_uiState.value.isEnglish)

    fun setStudentMode(enabled: Boolean) {
        val isEn = _uiState.value.isEnglish
        if (_uiState.value.subscriptionState.isStudent && !enabled) {
            showToast(
                if (isEn) "Student Mode stays active with your current Student plan."
                else "وضع الطالب مفعّل تلقائيًا مع اشتراك الطلاب الحالي.",
            )
            return
        }
        viewModelScope.launch {
            prefs.setStudentMode(enabled)
            showToast(
                if (enabled) {
                    if (isEn) "Student Mode enabled — exam grade features are now active"
                    else "تم تفعيل وضع الطالب — ميزات الامتحانات والتقديرات بقت ظاهرة دلوقتي"
                } else {
                    if (isEn) "Switched to Standard Mode" else "تم التبديل للوضع العادي"
                },
            )
        }
    }

    fun signInWithEmail(email: String, password: String, onDone: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _uiState.update { it.copy(authLoading = true) }
            val res = authRepo.signInWithEmail(email, password)
            _uiState.update { it.copy(authLoading = false) }
            when (res) {
                is AuthResult.Success -> {
                    _uiState.update { it.copy(user = res.user, onboardingComplete = true) }
                    attachUserStreams(res.user.id)
                    onDone(true, null)
                }
                is AuthResult.Error -> {
                    val msg = if (_uiState.value.isEnglish) res.messageEn else res.messageAr
                    onDone(false, msg)
                }
            }
        }
    }

    fun signUpWithEmail(email: String, password: String, name: String?, onDone: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _uiState.update { it.copy(authLoading = true) }
            val res = authRepo.createAccountWithEmail(email, password, name)
            _uiState.update { it.copy(authLoading = false) }
            when (res) {
                is AuthResult.Success -> {
                    authRepo.markOnboardingComplete()
                    _uiState.update { it.copy(user = res.user, onboardingComplete = true) }
                    attachUserStreams(res.user.id)
                    onDone(true, null)
                }
                is AuthResult.Error -> {
                    val msg = if (_uiState.value.isEnglish) res.messageEn else res.messageAr
                    onDone(false, msg)
                }
            }
        }
    }

    fun signInWithSocial(provider: AuthProviderType, email: String, name: String, onDone: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _uiState.update { it.copy(authLoading = true) }
            val res = authRepo.signInWithSocialProfile(provider, email, name)
            _uiState.update { it.copy(authLoading = false) }
            when (res) {
                is AuthResult.Success -> {
                    authRepo.markOnboardingComplete()
                    _uiState.update { it.copy(user = res.user, onboardingComplete = true) }
                    attachUserStreams(res.user.id)
                    onDone(true, null)
                }
                is AuthResult.Error -> {
                    val msg = if (_uiState.value.isEnglish) res.messageEn else res.messageAr
                    onDone(false, msg)
                }
            }
        }
    }

    fun resetLocalPassword(email: String, newPassword: String, onDone: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _uiState.update { it.copy(authLoading = true) }
            val res = authRepo.resetLocalPassword(email, newPassword)
            _uiState.update { it.copy(authLoading = false) }
            when (res) {
                is AuthResult.Success -> {
                    _uiState.update { it.copy(user = res.user, onboardingComplete = true) }
                    attachUserStreams(res.user.id)
                    onDone(true, null)
                }
                is AuthResult.Error -> {
                    val msg = if (_uiState.value.isEnglish) res.messageEn else res.messageAr
                    onDone(false, msg)
                }
            }
        }
    }

    fun updateAssistantTone(tone: AssistantTone) {
        viewModelScope.launch {
            authRepo.updateAssistantTone(tone)
            _uiState.update { st -> st.copy(user = st.user?.copy(tone = tone)) }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            userDataJob?.cancel()
            soundEngine.stopAmbient()
            authRepo.signOut()
            _uiState.update {
                it.copy(
                    user = null,
                    tasks = emptyList(),
                    projects = emptyList(),
                    focusSessions = emptyList(),
                    examGrades = emptyList(),
                    conversations = emptyList(),
                    chatState = ChatUiState(),
                )
            }
        }
    }

    fun deleteAccount() {
        viewModelScope.launch {
            val current = _uiState.value.user
            userDataJob?.cancel()
            soundEngine.stopAmbient()
            notifScheduler.cancelAll()
            authRepo.deleteAccount(current)
            _uiState.update {
                it.copy(
                    user = null,
                    tasks = emptyList(),
                    projects = emptyList(),
                    focusSessions = emptyList(),
                    examGrades = emptyList(),
                    conversations = emptyList(),
                    chatState = ChatUiState(),
                )
            }
            val isEn = _uiState.value.isEnglish
            showToast(if (isEn) "Account and all local data erased." else "تم حذف الحساب وكافة البيانات نهائيًا.")
        }
    }

    // ---------------------------------------------------------------------
    // Energy Preferences
    // ---------------------------------------------------------------------

    fun saveEnergyPreferences(prefsValue: UserEnergyPreferences) {
        val uid = _uiState.value.user?.id ?: return
        viewModelScope.launch {
            workspaceRepo.saveEnergyPreferences(uid, prefsValue)
            _uiState.update { it.copy(energyPrefs = prefsValue) }
            val isEn = _uiState.value.isEnglish
            showToast(if (isEn) "Energy profile updated!" else "تم حفظ بصمة طاقتك بنجاح!")
        }
    }

    // ---------------------------------------------------------------------
    // Tasks & Reminders
    // ---------------------------------------------------------------------

    fun saveTask(
        editingTask: TaskItem?,
        title: String,
        description: String?,
        priority: TaskPriority,
        dueAtMs: Long?,
        estimatedMinutes: Int?,
        recurrence: TaskRecurrence,
        projectId: String?,
        alertMode: String, // "alarm" | "notification"
        subtasksJson: String? = null,
        onComplete: () -> Unit = {},
    ) {
        val uid = _uiState.value.user?.id ?: return
        viewModelScope.launch {
            val savedTask = if (editingTask == null) {
                workspaceRepo.createTask(
                    userId = uid,
                    title = title,
                    description = description,
                    priority = priority,
                    dueAtMs = dueAtMs,
                    scheduledStartAtMs = dueAtMs,
                    estimatedDurationMinutes = estimatedMinutes,
                    status = if (dueAtMs != null) TaskStatus.planned else TaskStatus.inbox,
                    energyLevel = when (priority) {
                        TaskPriority.urgent, TaskPriority.high -> EnergyLevel.high
                        TaskPriority.low -> EnergyLevel.low
                        else -> EnergyLevel.medium
                    },
                    source = TaskSource.manual,
                    recurrence = recurrence,
                    projectId = projectId,
                    durationUncertainty = subtasksJson,
                )
            } else {
                workspaceRepo.updateTask(
                    editingTask.copy(
                        title = title.trim(),
                        description = description?.trim()?.ifEmpty { null },
                        priority = priority,
                        dueAtMs = dueAtMs,
                        scheduledStartAtMs = dueAtMs,
                        estimatedDurationMinutes = estimatedMinutes,
                        recurrence = recurrence,
                        projectId = projectId,
                        durationUncertainty = subtasksJson,
                    ),
                )
            }

            // Persist alarm / notification preference for this task
            if (dueAtMs != null) {
                scheduleTaskReminder(uid, savedTask, alertMode)
            }
            onComplete()
        }
    }

    fun toggleTaskSubtask(taskId: String, subtaskId: String) {
        val task = _uiState.value.tasks.firstOrNull { it.id == taskId } ?: return
        val currentSubs = task.subtasks
        if (currentSubs.isEmpty()) return
        val updatedSubs = currentSubs.map {
            if (it.id == subtaskId) it.copy(isDone = !it.isDone) else it
        }
        val encoded = com.handelha.app.domain.TaskSubtasksCodec.encode(updatedSubs)
        viewModelScope.launch {
            val saved = workspaceRepo.updateTask(task.copy(durationUncertainty = encoded))
            if (updatedSubs.all { it.isDone } && !saved.isCompleted) {
                val isEn = _uiState.value.isEnglish
                showToast(
                    if (isEn) "All steps finished! Task marked completed"
                    else "عاش! خلّصت كل الخطوات الفرعية واتقفلت المهمة",
                )
                toggleTaskComplete(taskId)
            }
        }
    }

    fun createTaskFromStudyBoost(
        minutes: Int,
        stepTitle: String,
        description: String,
        onTaskReady: (String, String) -> Unit,
    ) {
        val uid = _uiState.value.user?.id ?: return
        val isEn = _uiState.value.isEnglish
        viewModelScope.launch {
            val smartSubs = com.handelha.app.domain.TaskSubtasksCodec.generateSmartSubtasks(stepTitle, isEn)
            val created = workspaceRepo.createTask(
                userId = uid,
                title = stepTitle,
                description = description,
                priority = TaskPriority.high,
                dueAtMs = System.currentTimeMillis() + minutes * 60_000L,
                scheduledStartAtMs = System.currentTimeMillis(),
                estimatedDurationMinutes = minutes,
                status = TaskStatus.inProgress,
                energyLevel = EnergyLevel.medium,
                source = TaskSource.ai,
                durationUncertainty = com.handelha.app.domain.TaskSubtasksCodec.encode(smartSubs),
            )
            setFocusDuration(minutes)
            onTaskReady(created.id, created.title)
        }
    }

    private suspend fun scheduleTaskReminder(uid: String, task: TaskItem, alertMode: String) {
        val dueAt = task.scheduledStartAtMs ?: task.dueAtMs ?: return
        notifScheduler.scheduleTask(task, alertModeOverride = alertMode)
        val currentState = _uiState.value.alarmState
        val nextModes = currentState.taskAlertModes.toMutableMap().apply { put(task.id, alertMode) }
        val existingIdx = currentState.items.indexOfFirst { it.taskId == task.id }
        val item = AlarmReminderItem(
            id = if (existingIdx >= 0) currentState.items[existingIdx].id else task.id,
            title = task.title,
            scheduledAtMs = dueAt,
            alertMode = alertMode,
            isEnabled = true,
            taskId = task.id,
        )
        val nextItems = currentState.items.filterNot { it.taskId == task.id } + item
        val nextState = currentState.copy(
            items = nextItems.sortedBy { it.scheduledAtMs },
            taskAlertModes = nextModes,
        )
        notifScheduler.saveAlarmReminderState(uid, nextState)
        _uiState.update { it.copy(alarmState = nextState) }
    }

    fun toggleTaskComplete(taskId: String) {
        viewModelScope.launch {
            val (updated, _) = workspaceRepo.toggleTaskCompletion(taskId)
            if (updated?.isCompleted == true) {
                notifScheduler.cancelById(taskId)
            } else if (updated != null && updated.dueAtMs != null) {
                val mode = _uiState.value.alarmState.alertModeForTask(taskId)
                notifScheduler.scheduleTask(updated, alertModeOverride = mode)
            }
        }
    }

    fun deleteTask(taskId: String) {
        val uid = _uiState.value.user?.id ?: return
        viewModelScope.launch {
            workspaceRepo.deleteTask(taskId)
            notifScheduler.cancelById(taskId)
            val cur = _uiState.value.alarmState
            val next = cur.copy(
                items = cur.items.filterNot { it.id == taskId || it.taskId == taskId },
                taskAlertModes = cur.taskAlertModes - taskId,
            )
            notifScheduler.saveAlarmReminderState(uid, next)
            _uiState.update { it.copy(alarmState = next) }
        }
    }

    // ---------------------------------------------------------------------
    // Projects
    // ---------------------------------------------------------------------

    fun createProject(
        title: String,
        description: String?,
        targetDateMs: Long?,
        colorValue: Long,
        initialStepTitle: String?,
        onCreated: (ProjectItem) -> Unit,
    ) {
        val uid = _uiState.value.user?.id ?: return
        viewModelScope.launch {
            val steps = listOfNotNull(initialStepTitle?.trim()?.takeIf { it.isNotEmpty() })
            val proj = workspaceRepo.saveProject(
                userId = uid,
                title = title,
                description = description,
                targetDateMs = targetDateMs,
                colorValue = colorValue,
                phases = emptyList(),
                initialStepTitles = steps,
            )
            onCreated(proj)
        }
    }

    fun updateProjectColor(project: ProjectItem, newColor: Long) {
        viewModelScope.launch {
            workspaceRepo.updateProject(project.copy(colorValue = newColor))
        }
    }

    fun addProjectStep(project: ProjectItem, stepTitle: String, dueAtMs: Long? = project.targetDateMs) {
        val uid = _uiState.value.user?.id ?: return
        viewModelScope.launch {
            workspaceRepo.createTask(
                userId = uid,
                title = stepTitle,
                priority = TaskPriority.medium,
                dueAtMs = dueAtMs,
                scheduledStartAtMs = dueAtMs,
                estimatedDurationMinutes = _uiState.value.energyPrefs.preferredSessionMinutes,
                status = TaskStatus.planned,
                projectId = project.id,
            )
        }
    }

    fun smartBreakdownProject(project: ProjectItem) {
        val uid = _uiState.value.user?.id ?: return
        val isEn = _uiState.value.isEnglish
        val energy = _uiState.value.energyPrefs
        val block = energy.preferredSessionMinutes
        val stepTitles = if (isEn) {
            listOf(
                "Scope & key milestones for ${project.title}",
                "Prepare tools & references for ${project.title}",
                "Core build block (${block}m) — ${project.title}",
                "Review & wrap up ${project.title}",
            )
        } else {
            listOf(
                "تحديد أهم نقاط البداية في ${project.title}",
                "تجهيز الأدوات والمصادر اللازمة لـ ${project.title}",
                "تنفيذ الجزء الأساسي (${ArabicFormatters.toArabicDigits(block)} د) في ${project.title}",
                "مراجعة نهائية وتقفيل ${project.title}",
            )
        }
        viewModelScope.launch {
            val baseCal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, energy.workStartMinute / 60)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
            }
            val phases = stepTitles.mapIndexed { idx, st ->
                ProjectPhaseRecord(
                    id = UUID.randomUUID().toString(),
                    title = st,
                    estimatedDurationMinutes = block,
                )
            }
            workspaceRepo.updateProject(project.copy(phases = phases))
            val created = stepTitles.mapIndexed { idx, st ->
                val cal = (baseCal.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, idx) }
                TaskItem(
                    id = UUID.randomUUID().toString(),
                    userId = uid,
                    projectId = project.id,
                    phaseId = phases[idx].id,
                    title = st,
                    status = TaskStatus.planned,
                    priority = if (idx == 0) TaskPriority.high else TaskPriority.medium,
                    dueAtMs = cal.timeInMillis,
                    scheduledStartAtMs = cal.timeInMillis,
                    estimatedDurationMinutes = block,
                    energyLevel = if (energy.hardTaskStrategy == "peak_first" && idx == 0) EnergyLevel.high else EnergyLevel.medium,
                    source = TaskSource.ai,
                )
            }
            workspaceRepo.createApprovedTasks(created)
            showToast(if (isEn) "Smart steps added according to your energy!" else "اتقسّم لخطوات متناسقة مع بصمة طاقتك!")
        }
    }

    fun deleteProject(projectId: String, onDone: () -> Unit) {
        viewModelScope.launch {
            workspaceRepo.deleteProject(projectId)
            onDone()
        }
    }

    // ---------------------------------------------------------------------
    // Focus Timer & Soundscape
    // ---------------------------------------------------------------------

    fun prepareFocusSession(taskId: String?, title: String) {
        val cur = _uiState.value.focusState
        if (cur.isRunning) return
        val defaultTitle = if (_uiState.value.isEnglish) "Calm Focus Session" else "جلسة تركيز هادئة"
        val cleanTitle = title.trim().ifBlank { defaultTitle }
        _uiState.update {
            it.copy(
                focusState = cur.copy(
                    linkedTaskId = taskId,
                    linkedTaskTitle = cleanTitle,
                    showCompletionCelebration = false,
                ),
            )
        }
    }

    fun setFocusDuration(minutes: Int) {
        val cur = _uiState.value.focusState
        if (cur.isRunning) return
        _uiState.update {
            it.copy(
                focusState = if (cur.isBreakMode) {
                    cur.copy(selectedBreakMinutes = minutes, remainingSeconds = minutes * 60, totalSeconds = minutes * 60)
                } else {
                    cur.copy(selectedFocusMinutes = minutes, remainingSeconds = minutes * 60, totalSeconds = minutes * 60)
                },
            )
        }
    }

    fun setFocusBreakMode(isBreak: Boolean) {
        val cur = _uiState.value.focusState
        if (cur.isRunning) return
        val mins = if (isBreak) cur.selectedBreakMinutes else cur.selectedFocusMinutes
        _uiState.update {
            it.copy(
                focusState = cur.copy(
                    isBreakMode = isBreak,
                    remainingSeconds = mins * 60,
                    totalSeconds = mins * 60,
                    showCompletionCelebration = false,
                ),
            )
        }
    }

    fun toggleFocusRunPause() {
        val cur = _uiState.value.focusState
        if (cur.isRunning) {
            focusTickerJob?.cancel()
            soundEngine.stopAmbient()
            notifScheduler.cancelFocusTimerNotification()
            _uiState.update { it.copy(focusState = cur.copy(isRunning = false)) }
        } else {
            val started = cur.startedAtMs ?: System.currentTimeMillis()
            val secs = if (cur.remainingSeconds <= 0) cur.totalSeconds else cur.remainingSeconds
            if (cur.selectedSound != AmbientSoundscape.SILENT) {
                soundEngine.playAmbient(cur.selectedSound, cur.volume)
            }
            _uiState.update {
                it.copy(
                    focusState = cur.copy(
                        isRunning = true,
                        remainingSeconds = secs,
                        startedAtMs = started,
                        showCompletionCelebration = false,
                    ),
                )
            }
            notifScheduler.postFocusTimerNotification(
                taskTitle = cur.linkedTaskTitle,
                remainingSeconds = secs,
                isBreakMode = cur.isBreakMode,
                isEnglish = _uiState.value.isEnglish,
            )
            startFocusTicker()
        }
    }

    private fun startFocusTicker() {
        focusTickerJob?.cancel()
        focusTickerJob = viewModelScope.launch {
            while (_uiState.value.focusState.isRunning) {
                delay(1000L)
                val fs = _uiState.value.focusState
                if (!fs.isRunning) break
                val next = fs.remainingSeconds - 1
                if (next <= 0) {
                    finishFocusSession(completedNaturally = true)
                    break
                } else {
                    _uiState.update { it.copy(focusState = fs.copy(remainingSeconds = next)) }
                    if (next % 5 == 0 || next <= 10) {
                        notifScheduler.postFocusTimerNotification(
                            taskTitle = fs.linkedTaskTitle,
                            remainingSeconds = next,
                            isBreakMode = fs.isBreakMode,
                            isEnglish = _uiState.value.isEnglish,
                        )
                    }
                }
            }
        }
    }

    fun finishFocusSession(completedNaturally: Boolean) {
        focusTickerJob?.cancel()
        soundEngine.stopAmbient()
        notifScheduler.cancelFocusTimerNotification()
        val st = _uiState.value
        val fs = st.focusState
        val elapsedSec = (fs.totalSeconds - fs.remainingSeconds).coerceAtLeast(0)
        val elapsedMins = if (completedNaturally) {
            fs.totalSeconds / 60
        } else {
            (elapsedSec / 60).coerceAtLeast(if (elapsedSec >= 30) 1 else 0)
        }
        val uid = st.user?.id
        val resetSecs = (if (fs.isBreakMode) fs.selectedBreakMinutes else fs.selectedFocusMinutes) * 60

        _uiState.update {
            it.copy(
                focusState = fs.copy(
                    isRunning = false,
                    remainingSeconds = resetSecs,
                    totalSeconds = resetSecs,
                    startedAtMs = null,
                    showCompletionCelebration = !fs.isBreakMode && (completedNaturally || elapsedMins >= 1),
                    lastCompletedMinutes = elapsedMins.coerceAtLeast(1),
                ),
            )
        }

        if (completedNaturally) {
            soundEngine.playAlarmChime(loop = false)
        }
        if (uid != null && !fs.isBreakMode && (completedNaturally || elapsedMins >= 1)) {
            viewModelScope.launch {
                val defaultTitle = if (st.isEnglish) "Calm Focus Session" else "جلسة تركيز هادئة"
                workspaceRepo.recordFocusSession(
                    userId = uid,
                    taskId = fs.linkedTaskId,
                    taskTitle = fs.linkedTaskTitle.ifBlank { defaultTitle },
                    startedAtMs = fs.startedAtMs ?: (System.currentTimeMillis() - elapsedSec * 1000L),
                    endedAtMs = System.currentTimeMillis(),
                    elapsedMinutes = elapsedMins.coerceAtLeast(1),
                    completed = completedNaturally,
                )
            }
        }
    }

    fun dismissFocusCelebration() {
        _uiState.update {
            it.copy(focusState = it.focusState.copy(showCompletionCelebration = false))
        }
    }

    fun selectSoundscape(sound: AmbientSoundscape) {
        val fs = _uiState.value.focusState
        _uiState.update { it.copy(focusState = fs.copy(selectedSound = sound)) }
        if (sound == AmbientSoundscape.SILENT) {
            soundEngine.stopAmbient()
        } else {
            soundEngine.playAmbient(sound, fs.volume)
        }
    }

    fun setSoundVolume(vol: Float) {
        val safe = vol.coerceIn(0.05f, 1f)
        _uiState.update { it.copy(focusState = it.focusState.copy(volume = safe)) }
        soundEngine.setAmbientVolume(safe)
    }

    // ---------------------------------------------------------------------
    // Assistant / Chat & Tokens
    // ---------------------------------------------------------------------

    fun sendChatMessage(rawText: String, isVoice: Boolean = false) {
        val text = rawText.trim()
        if (text.isEmpty()) return
        val st = _uiState.value
        val uid = st.user?.id ?: return

        viewModelScope.launch {
            val cost = if (isVoice) TokenBalanceState.VOICE_MESSAGE_COST else TokenBalanceState.TEXT_MESSAGE_COST
            val (ok, nextTokens) = tokenRepo.consume(uid, cost)
            _uiState.update { it.copy(tokenState = nextTokens) }
            if (!ok) {
                _uiState.update { it.copy(chatState = it.chatState.copy(showTokenRefillSheet = true)) }
                return@launch
            }

            val userMsg = ChatMessageItem(
                id = UUID.randomUUID().toString(),
                role = ChatMessageRole.user,
                text = text,
            )
            val currentMessages = st.chatState.messages + userMsg
            _uiState.update {
                it.copy(
                    chatState = it.chatState.copy(
                        messages = currentMessages,
                        isSending = true,
                    ),
                )
            }

            delay(280L)
            val turn = LocalAssistantEngine.processMessage(
                userId = uid,
                userMessage = text,
                isEnglish = st.isEnglish,
                isStudentMode = st.isStudentMode,
                tone = st.user.tone,
                energyPrefs = st.energyPrefs,
                tasks = st.tasks,
                projects = st.projects,
                previousPendingProposal = st.chatState.pendingProposal,
            )

            if (turn.confirmedTasksToCreate.isNotEmpty()) {
                workspaceRepo.createApprovedTasks(turn.confirmedTasksToCreate)
                turn.confirmedTasksToCreate.forEach { t ->
                    scheduleTaskReminder(uid, t, "alarm")
                }
            }
            if (turn.markTaskCompletedId != null) {
                workspaceRepo.completeTask(turn.markTaskCompletedId)
            }
            if (turn.scheduleAlarmRequest != null) {
                val (aTitle, aWhen, aMode) = turn.scheduleAlarmRequest
                val created = workspaceRepo.createTask(
                    userId = uid,
                    title = aTitle,
                    priority = TaskPriority.high,
                    dueAtMs = aWhen,
                    scheduledStartAtMs = aWhen,
                    estimatedDurationMinutes = st.energyPrefs.preferredSessionMinutes,
                    status = TaskStatus.planned,
                    source = TaskSource.ai,
                )
                scheduleTaskReminder(uid, created, aMode)
            }
            if (turn.recordExamGrade != null) {
                val (exTitle, tier, score) = turn.recordExamGrade
                workspaceRepo.addExamGrade(uid, exTitle, tier, score)
            }

            val aiMsg = ChatMessageItem(
                id = UUID.randomUUID().toString(),
                role = ChatMessageRole.assistant,
                text = turn.replyText,
                quickReplies = turn.quickReplies,
                proposal = turn.proposal,
            )
            val allMsgs = currentMessages + aiMsg
            val nextPending = if (turn.proposal?.draftStatus == "pending") turn.proposal else null

            _uiState.update {
                it.copy(
                    chatState = it.chatState.copy(
                        messages = allMsgs,
                        isSending = false,
                        pendingProposal = nextPending,
                    ),
                )
            }

            val convTitle = currentMessages.firstOrNull { it.role == ChatMessageRole.user }?.text?.take(48)
                ?: (if (st.isEnglish) "Handelha Assistant" else "محادثة هندلها")
            workspaceRepo.saveConversation(
                ChatConversationRecord(
                    id = _uiState.value.chatState.activeConversationId,
                    userId = uid,
                    title = convTitle,
                    createdAtMs = allMsgs.firstOrNull()?.createdAtMs ?: System.currentTimeMillis(),
                    updatedAtMs = System.currentTimeMillis(),
                    messages = allMsgs,
                ),
            )
        }
    }

    fun setVoiceStatus(label: String?, listening: Boolean) {
        _uiState.update {
            it.copy(chatState = it.chatState.copy(voiceStatusLabel = label, isListening = listening))
        }
    }

    fun setTokenRefillSheetVisible(visible: Boolean) {
        _uiState.update { it.copy(chatState = it.chatState.copy(showTokenRefillSheet = visible)) }
    }

    fun claimAdTokensReward() {
        val uid = _uiState.value.user?.id ?: return
        viewModelScope.launch {
            _uiState.update { it.copy(tokenState = it.tokenState.copy(isLoadingAd = true)) }
            delay(800L)
            val next = tokenRepo.rewardFromAd(uid)
            _uiState.update { it.copy(tokenState = next) }
            val isEn = _uiState.value.isEnglish
            showToast(if (isEn) "+15 Tokens added!" else "تم إضافة +١٥ توكن بنجاح!")
        }
    }

    fun startNewConversation() {
        _uiState.update {
            it.copy(
                chatState = ChatUiState(activeConversationId = UUID.randomUUID().toString()),
            )
        }
    }

    fun openConversation(record: ChatConversationRecord) {
        val pending = record.messages.lastOrNull { it.proposal?.draftStatus == "pending" }?.proposal
        _uiState.update {
            it.copy(
                chatState = ChatUiState(
                    activeConversationId = record.id,
                    messages = record.messages,
                    pendingProposal = pending,
                ),
            )
        }
    }

    fun deleteConversation(id: String) {
        viewModelScope.launch {
            workspaceRepo.deleteConversation(id)
            if (_uiState.value.chatState.activeConversationId == id) {
                startNewConversation()
            }
        }
    }

    // ---------------------------------------------------------------------
    // Exam Grades (Student Mode)
    // ---------------------------------------------------------------------

    fun addExamGrade(examTitle: String, gradeTier: String, scoreLabel: String, onAdded: (ExamGradeEntry) -> Unit) {
        val uid = _uiState.value.user?.id ?: return
        viewModelScope.launch {
            val entry = workspaceRepo.addExamGrade(uid, examTitle, gradeTier, scoreLabel)
            onAdded(entry)
        }
    }

    fun deleteExamGrade(id: String) {
        viewModelScope.launch { workspaceRepo.deleteExamGrade(id) }
    }

    // ---------------------------------------------------------------------
    // Notifications, Quiet Hours & Alarms
    // ---------------------------------------------------------------------

    fun toggleNotificationsEnabled(enabled: Boolean) {
        val uid = _uiState.value.user?.id ?: return
        viewModelScope.launch {
            val next = _uiState.value.notifPrefs.copy(enabled = enabled)
            notifScheduler.saveNotificationPreferences(uid, next)
            _uiState.update { it.copy(notifPrefs = next) }
            if (enabled) {
                _uiState.value.tasks.forEach { t ->
                    if (!t.isCompleted && !t.isCancelled && t.dueAtMs != null) {
                        notifScheduler.scheduleTask(t, alertModeOverride = _uiState.value.alarmState.alertModeForTask(t.id))
                    }
                }
            } else {
                notifScheduler.cancelAll()
            }
        }
    }

    fun saveQuietHours(startMinutes: Int, endMinutes: Int) {
        val uid = _uiState.value.user?.id ?: return
        viewModelScope.launch {
            val next = _uiState.value.notifPrefs.copy(
                quietHoursStartMinutes = startMinutes,
                quietHoursEndMinutes = endMinutes,
            )
            notifScheduler.saveNotificationPreferences(uid, next)
            _uiState.update { it.copy(notifPrefs = next) }
            val isEn = _uiState.value.isEnglish
            showToast(if (isEn) "Quiet hours updated!" else "تم تحديث ساعات الهدوء بنجاح!")
        }
    }

    fun markNotificationRead(id: String) {
        val uid = _uiState.value.user?.id ?: return
        if (_uiState.value.readNotifIds.contains(id)) return
        _uiState.update { it.copy(readNotifIds = it.readNotifIds + id) }
        viewModelScope.launch { notifScheduler.markAsRead(uid, id) }
    }

    fun markAllNotificationsRead(ids: List<String>) {
        val uid = _uiState.value.user?.id ?: return
        _uiState.update { it.copy(readNotifIds = it.readNotifIds + ids) }
        viewModelScope.launch { notifScheduler.markAllAsRead(uid, ids) }
    }

    fun toggleAlarmEnabled(alarmId: String) {
        val uid = _uiState.value.user?.id ?: return
        viewModelScope.launch {
            val cur = _uiState.value.alarmState
            val updated = cur.items.map { if (it.id == alarmId) it.copy(isEnabled = !it.isEnabled) else it }
            val target = updated.firstOrNull { it.id == alarmId }
            if (target != null) {
                if (target.isEnabled) {
                    notifScheduler.scheduleReminderItem(target.id, target.title, target.scheduledAtMs, target.alertMode, target.taskId, uid)
                } else {
                    notifScheduler.cancelById(target.id)
                }
            }
            val next = cur.copy(items = updated)
            notifScheduler.saveAlarmReminderState(uid, next)
            _uiState.update { it.copy(alarmState = next) }
        }
    }

    fun toggleAlarmMode(alarmId: String) {
        val uid = _uiState.value.user?.id ?: return
        viewModelScope.launch {
            val cur = _uiState.value.alarmState
            val updated = cur.items.map {
                if (it.id == alarmId) {
                    val nextMode = if (it.alertMode == "alarm") "notification" else "alarm"
                    it.copy(alertMode = nextMode)
                } else {
                    it
                }
            }
            val target = updated.firstOrNull { it.id == alarmId }
            if (target != null && target.isEnabled) {
                notifScheduler.scheduleReminderItem(target.id, target.title, target.scheduledAtMs, target.alertMode, target.taskId, uid)
            }
            val next = cur.copy(items = updated)
            notifScheduler.saveAlarmReminderState(uid, next)
            _uiState.update { it.copy(alarmState = next) }
        }
    }

    fun deleteAlarmItem(alarmId: String) {
        val uid = _uiState.value.user?.id ?: return
        viewModelScope.launch {
            notifScheduler.cancelById(alarmId)
            val cur = _uiState.value.alarmState
            val next = cur.copy(items = cur.items.filterNot { it.id == alarmId })
            notifScheduler.saveAlarmReminderState(uid, next)
            _uiState.update { it.copy(alarmState = next) }
        }
    }

    fun previewAlarm(item: AlarmReminderItem) {
        val isEn = _uiState.value.isEnglish
        if (!item.isFullAlarm) {
            val encouraging = com.handelha.app.data.repo.ReminderMessageCatalog.dailyMessage(
                nowMs = System.currentTimeMillis(),
                tone = com.handelha.app.domain.ReminderTone.supportive,
            )
            notifScheduler.postQuietNotificationNow(
                id = item.id,
                title = item.title,
                body = if (isEn) "Take it one step at a time; 5 minutes of focus is a great start." else encouraging,
                badgeText = if (isEn) "Your Next Step" else "خطوتك الجاية",
                isEnglish = isEn,
            )
            showToast(if (isEn) "External notification sent to your status bar" else "تم إرسال الإشعار الخارجي في شريط الإشعارات بالأعلى")
            return
        }
        _uiState.update {
            it.copy(
                activeAlarmRing = ActiveAlarmRing(
                    id = item.id,
                    title = item.title,
                    taskId = item.taskId,
                    isPreview = false,
                ),
            )
        }
        soundEngine.playAlarmChime(loop = true)
    }

    fun dismissAlarmRing() {
        soundEngine.stopAlarmChime()
        _uiState.update { it.copy(activeAlarmRing = null) }
    }

    fun snoozeAlarmRing(minutes: Int) {
        val ring = _uiState.value.activeAlarmRing
        dismissAlarmRing()
        val uid = _uiState.value.user?.id ?: return
        if (ring == null) return
        viewModelScope.launch {
            val snoozeAt = System.currentTimeMillis() + minutes * 60_000L
            notifScheduler.scheduleReminderItem(
                id = ring.id,
                title = ring.title,
                scheduledAtMs = snoozeAt,
                alertMode = "alarm",
                taskId = ring.taskId,
                userId = uid,
            )
            val isEn = _uiState.value.isEnglish
            showToast(if (isEn) "Snoozed for ${minutes}m" else "اتأجل المنبه ${ArabicFormatters.toArabicDigits(minutes)} دقايق")
        }
    }

    // ---------------------------------------------------------------------
    // Subscriptions & Backup
    // ---------------------------------------------------------------------

    fun selectSubscriptionPlan(offer: SubscriptionOffer) {
        val uid = _uiState.value.user?.id ?: return
        viewModelScope.launch {
            val rec = subStore.activatePlanForUser(uid, offer)
            val isEn = _uiState.value.isEnglish
            val nextSub = subStore.loadStateForUser(uid, isEn)
            val nextUser = _uiState.value.user?.copy(
                subscriptionCategory = rec.category,
                activePlanId = rec.activePlanId,
            )
            _uiState.update {
                it.copy(
                    subscriptionState = nextSub,
                    user = nextUser,
                    isStudentMode = it.isStudentMode || nextSub.isStudent,
                )
            }
            val planTitle = nextSub.resolvedPlanTitle(isEn)
            val catTitle = rec.category.label(isEn)
            showToast(
                if (isEn) "Subscribed to $planTitle ($catTitle)"
                else "تم اشتراكك بنجاح في: $planTitle ($catTitle)",
            )
        }
    }

    fun cancelLocalSubscription() {
        val uid = _uiState.value.user?.id ?: return
        viewModelScope.launch {
            subStore.clearForUser(uid)
            val nextSub = subStore.loadStateForUser(uid, _uiState.value.isEnglish)
            _uiState.update {
                it.copy(
                    subscriptionState = nextSub,
                    user = it.user?.copy(
                        subscriptionCategory = com.handelha.app.domain.UserSubscriptionCategory.free,
                        activePlanId = null,
                    ),
                )
            }
            val isEn = _uiState.value.isEnglish
            showToast(if (isEn) "Switched back to the Free account tier." else "تم الرجوع إلى الحساب المجاني.")
        }
    }

    suspend fun exportBackupJson(): String? {
        val uid = _uiState.value.user?.id ?: return null
        return backupManager.exportForUser(uid)
    }

    fun importBackupJson(rawJson: String, onDone: (Boolean, String) -> Unit) {
        val uid = _uiState.value.user?.id ?: return
        val isEn = _uiState.value.isEnglish
        viewModelScope.launch {
            val res = backupManager.importTasksForUser(uid, rawJson)
            res.fold(
                onSuccess = { count ->
                    onDone(
                        true,
                        if (isEn) "Restored $count tasks successfully!"
                        else "تم استعادة ${ArabicFormatters.toArabicDigits(count)} مهام وخطوات بنجاح!",
                    )
                },
                onFailure = { err ->
                    onDone(
                        false,
                        err.message ?: if (isEn) "Invalid backup JSON" else "ملف النسخة الاحتياطية غير صالح",
                    )
                },
            )
        }
    }

    fun clearChatHistory() {
        val uid = _uiState.value.user?.id ?: return
        viewModelScope.launch {
            _uiState.value.conversations.forEach { workspaceRepo.deleteConversation(it.id) }
            startNewConversation()
            val isEn = _uiState.value.isEnglish
            showToast(if (isEn) "Chat history cleared." else "تم مسح سجل المحادثات.")
        }
    }

    // ---------------------------------------------------------------------
    // Student Mode Motivation & Quotes
    // ---------------------------------------------------------------------

    private suspend fun loadStudentMotivation(userId: String): StudentMotivationState {
        val raw = prefs.readString(prefs.userStudentMotivationKey(userId)) ?: return StudentMotivationState()
        return runCatching {
            val obj = JSONObject(raw)
            val favArr = obj.optJSONArray("favoriteQuoteIds") ?: JSONArray()
            val favs = buildSet {
                for (i in 0 until favArr.length()) {
                    val id = favArr.optString(i)
                    if (id.isNotBlank()) add(id)
                }
            }
            val customArr = obj.optJSONArray("customQuotes") ?: JSONArray()
            val customs = buildList {
                for (i in 0 until customArr.length()) {
                    val qObj = customArr.optJSONObject(i) ?: continue
                    val id = qObj.optString("id")
                    val textAr = qObj.optString("textAr")
                    if (id.isBlank() || textAr.isBlank()) continue
                    add(
                        StudentQuoteItem(
                            id = id,
                            textAr = textAr,
                            textEn = qObj.optString("textEn", textAr),
                            tagAr = qObj.optString("tagAr", "كلمتي الخاصة"),
                            tagEn = qObj.optString("tagEn", "My Quote"),
                            category = StudentQuoteCategory.fromId(qObj.optString("category")),
                            isCustom = true,
                        ),
                    )
                }
            }
            val pinned = obj.optString("pinnedQuoteId").takeIf { it.isNotBlank() }
            StudentMotivationState(
                currentQuoteId = obj.optString("currentQuoteId", "sci_1").ifBlank { "sci_1" },
                selectedMood = StudentStudyMood.fromId(obj.optString("selectedMood")),
                personalMotto = obj.optString("personalMotto", ""),
                pinnedQuoteId = pinned,
                favoriteQuoteIds = favs,
                customQuotes = customs,
            )
        }.getOrDefault(StudentMotivationState())
    }

    private suspend fun persistStudentMotivation(state: StudentMotivationState) {
        val uid = _uiState.value.user?.id ?: "guest"
        val obj = JSONObject().apply {
            put("currentQuoteId", state.currentQuoteId)
            put("selectedMood", state.selectedMood.id)
            put("personalMotto", state.personalMotto)
            put("pinnedQuoteId", state.pinnedQuoteId ?: "")
            val favArr = JSONArray()
            state.favoriteQuoteIds.forEach { favArr.put(it) }
            put("favoriteQuoteIds", favArr)
            val customArr = JSONArray()
            state.customQuotes.forEach { q ->
                customArr.put(
                    JSONObject().apply {
                        put("id", q.id)
                        put("textAr", q.textAr)
                        put("textEn", q.textEn)
                        put("tagAr", q.tagAr)
                        put("tagEn", q.tagEn)
                        put("category", q.category.id)
                    },
                )
            }
            put("customQuotes", customArr)
        }
        prefs.update { it[prefs.userStudentMotivationKey(uid)] = obj.toString() }
    }

    fun nextStudentQuote(preferCategory: StudentQuoteCategory? = null) {
        val cur = _uiState.value.studentMotivation
        val all = cur.allQuotes()
        val pool = when {
            preferCategory != null && preferCategory != StudentQuoteCategory.ALL ->
                all.filter { it.category == preferCategory || (preferCategory == StudentQuoteCategory.CUSTOM && it.isCustom) }
                    .ifEmpty { all }
            else -> all
        }
        val currentIdx = pool.indexOfFirst { it.id == cur.currentQuoteId }
        val nextItem = if (pool.size <= 1) {
            pool.firstOrNull() ?: StudentQuotesCatalog.builtInQuotes.first()
        } else {
            val nextIdx = (currentIdx + 1) % pool.size
            pool[nextIdx]
        }
        val updated = cur.copy(currentQuoteId = nextItem.id, pinnedQuoteId = null)
        _uiState.update { it.copy(studentMotivation = updated) }
        viewModelScope.launch { persistStudentMotivation(updated) }
    }

    fun toggleFavoriteQuote(quoteId: String) {
        val cur = _uiState.value.studentMotivation
        val isEn = _uiState.value.isEnglish
        val nextFavs = if (cur.favoriteQuoteIds.contains(quoteId)) {
            cur.favoriteQuoteIds - quoteId
        } else {
            showToast(if (isEn) "Added to your favorite quotes" else "تمت الإضافة إلى المفضلة")
            cur.favoriteQuoteIds + quoteId
        }
        val updated = cur.copy(favoriteQuoteIds = nextFavs)
        _uiState.update { it.copy(studentMotivation = updated) }
        viewModelScope.launch { persistStudentMotivation(updated) }
    }

    fun setStudentStudyMood(mood: StudentStudyMood) {
        val cur = _uiState.value.studentMotivation
        val matchingQuote = cur.allQuotes().firstOrNull { it.category == mood.recommendedCategory }
        val updated = cur.copy(
            selectedMood = mood,
            currentQuoteId = matchingQuote?.id ?: cur.currentQuoteId,
        )
        _uiState.update { it.copy(studentMotivation = updated) }
        viewModelScope.launch { persistStudentMotivation(updated) }
    }

    fun setStudentPersonalMotto(motto: String) {
        val cur = _uiState.value.studentMotivation
        val updated = cur.copy(personalMotto = motto.trim())
        _uiState.update { it.copy(studentMotivation = updated) }
        viewModelScope.launch { persistStudentMotivation(updated) }
        val isEn = _uiState.value.isEnglish
        showToast(if (isEn) "Your personal study motto is saved" else "تم حفظ شعارك الدراسي بنجاح")
    }

    fun togglePinQuoteToWidget(quoteId: String) {
        val cur = _uiState.value.studentMotivation
        val isEn = _uiState.value.isEnglish
        val nextPinned = if (cur.pinnedQuoteId == quoteId) {
            showToast(if (isEn) "Unpinned from Home widget" else "تم إلغاء تثبيت الاقتباس من الرئيسية")
            null
        } else {
            showToast(if (isEn) "Pinned to your Home Student Widget" else "تم تثبيت الاقتباس في الرئيسية")
            quoteId
        }
        val updated = cur.copy(pinnedQuoteId = nextPinned, currentQuoteId = quoteId)
        _uiState.update { it.copy(studentMotivation = updated) }
        viewModelScope.launch { persistStudentMotivation(updated) }
    }

    fun addCustomStudentQuote(
        textAr: String,
        tagAr: String,
        category: StudentQuoteCategory,
        pinToWidget: Boolean,
    ) {
        val cleanText = textAr.trim()
        if (cleanText.isEmpty()) return
        val cleanTag = tagAr.trim().ifEmpty { "كلمتي لنفسي" }
        val newItem = StudentQuoteItem(
            id = "custom_${System.currentTimeMillis()}",
            textAr = cleanText,
            textEn = cleanText,
            tagAr = cleanTag,
            tagEn = cleanTag,
            category = category,
            isCustom = true,
        )
        val cur = _uiState.value.studentMotivation
        val updated = cur.copy(
            customQuotes = listOf(newItem) + cur.customQuotes,
            currentQuoteId = newItem.id,
            pinnedQuoteId = if (pinToWidget) newItem.id else cur.pinnedQuoteId,
            favoriteQuoteIds = cur.favoriteQuoteIds + newItem.id,
        )
        _uiState.update { it.copy(studentMotivation = updated) }
        viewModelScope.launch { persistStudentMotivation(updated) }
        val isEn = _uiState.value.isEnglish
        showToast(if (isEn) "Your custom quote was added" else "تمت إضافة اقتباسك الخاص بنجاح")
    }

    fun deleteCustomStudentQuote(quoteId: String) {
        val cur = _uiState.value.studentMotivation
        val nextCustoms = cur.customQuotes.filterNot { it.id == quoteId }
        val updated = cur.copy(
            customQuotes = nextCustoms,
            favoriteQuoteIds = cur.favoriteQuoteIds - quoteId,
            pinnedQuoteId = if (cur.pinnedQuoteId == quoteId) null else cur.pinnedQuoteId,
            currentQuoteId = if (cur.currentQuoteId == quoteId) "sci_1" else cur.currentQuoteId,
        )
        _uiState.update { it.copy(studentMotivation = updated) }
        viewModelScope.launch { persistStudentMotivation(updated) }
    }

    override fun onCleared() {
        super.onCleared()
        focusTickerJob?.cancel()
        soundEngine.release()
    }
}

package com.handelha.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.handelha.app.data.local.AppPreferencesStore
import com.handelha.app.data.repo.LocalNotificationScheduler
import com.handelha.app.domain.TaskItem
import com.handelha.app.ui.HandelhaAppViewModel
import com.handelha.app.ui.ToastFeedback
import com.handelha.app.ui.components.EnergyPreferencesWizardSheet
import com.handelha.app.ui.components.HandelhaAmbientBackground
import com.handelha.app.ui.components.HandelhaBottomNav
import com.handelha.app.ui.screens.AddTaskScreen
import com.handelha.app.ui.screens.AlarmRingingDialog
import com.handelha.app.ui.screens.AuthFlowScreen
import com.handelha.app.ui.screens.ChatHistoryScreen
import com.handelha.app.ui.screens.ChatScreen
import com.handelha.app.ui.screens.DashboardScreen
import com.handelha.app.ui.screens.FocusSessionScreen
import com.handelha.app.ui.screens.NewProjectScreen
import com.handelha.app.ui.screens.NotificationsScreen
import com.handelha.app.ui.screens.OnboardingScreen
import com.handelha.app.ui.screens.ProjectWorkspaceScreen
import com.handelha.app.ui.screens.ProjectsScreen
import com.handelha.app.ui.screens.SettingsScreen
import com.handelha.app.ui.screens.SplashScreen
import com.handelha.app.ui.screens.StudentQuotesScreen
import com.handelha.app.ui.screens.SubscriptionScreen
import com.handelha.app.ui.screens.TasksScreen
import com.handelha.app.ui.screens.TrackingScreen
import com.handelha.app.ui.theme.HandelhaTheme
import com.handelha.app.util.ArabicFormatters
import kotlinx.coroutines.delay

private sealed interface SubRoute {
    data class AddTask(val editingTaskId: String? = null) : SubRoute
    data object NewProject : SubRoute
    data class ProjectWorkspace(val projectId: String) : SubRoute
    data class FocusSession(val initialTab: Int = 0) : SubRoute
    data object ChatHistory : SubRoute
    data object Settings : SubRoute
    data object Notifications : SubRoute
    data object Subscription : SubRoute
    data object StudentQuotes : SubRoute
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        handleTriggerIntent(intent)

        setContent {
            val vm: HandelhaAppViewModel = viewModel()
            HandelhaAppShell(vm = vm)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleTriggerIntent(intent)
    }

    private fun handleTriggerIntent(intent: Intent?) {
        if (intent?.action == LocalNotificationScheduler.ACTION_QUIET_TRIGGER) {
            val prefs = AppPreferencesStore(applicationContext)
            val scheduler = LocalNotificationScheduler(applicationContext, prefs)
            val id = intent.getStringExtra(NativeAlarmScheduler.EXTRA_ALARM_ID) ?: "reminder"
            val title = intent.getStringExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE) ?: "تذكير مهمة"
            scheduler.postQuietNotificationNow(
                id = id,
                title = "تذكير هندلها",
                body = title,
            )
        }
    }
}

@Composable
private fun HandelhaAppShell(vm: HandelhaAppViewModel) {
    val state by vm.uiState.collectAsStateWithLifecycle()
    val toast by vm.toast.collectAsStateWithLifecycle()

    LaunchedEffect(toast?.id) {
        if (toast != null) {
            delay(2800L)
            vm.dismissToast()
        }
    }

    val layoutDir = if (state.isEnglish) LayoutDirection.Ltr else LayoutDirection.Rtl

    HandelhaTheme(themeMode = state.themeMode) {
        CompositionLocalProvider(LocalLayoutDirection provides layoutDir) {
            HandelhaAmbientBackground {
                Box(modifier = Modifier.fillMaxSize()) {
                    when {
                        state.isInitializing -> {
                            SplashScreen(isEnglish = state.isEnglish)
                        }

                        !state.onboardingComplete && state.user == null -> {
                            OnboardingScreen(
                                isEnglish = state.isEnglish,
                                onToggleLanguage = vm::toggleLanguage,
                                onFinishOnboarding = vm::completeOnboarding,
                            )
                        }

                        state.user == null -> {
                            AuthFlowScreen(
                                isEnglish = state.isEnglish,
                                isLoading = state.authLoading,
                                onToggleLanguage = vm::toggleLanguage,
                                onSignInEmail = vm::signInWithEmail,
                                onSignUpEmail = vm::signUpWithEmail,
                                onSocialSignIn = vm::signInWithSocial,
                                onResetPassword = vm::resetLocalPassword,
                                onShowToast = vm::showToast,
                            )
                        }

                        else -> {
                            AuthenticatedWorkspaceShell(vm = vm)
                        }
                    }

                    state.activeAlarmRing?.let { ring ->
                        AlarmRingingDialog(
                            ring = ring,
                            isEnglish = state.isEnglish,
                            onDismiss = vm::dismissAlarmRing,
                            onSnooze5 = { vm.snoozeAlarmRing(5) },
                        )
                    }

                    FloatingToastBanner(
                        toast = toast,
                        onDismiss = vm::dismissToast,
                        modifier = Modifier
                            .align(Alignment.TopCenter)
                            .windowInsetsPadding(WindowInsets.statusBars)
                            .padding(horizontal = 20.dp, vertical = 10.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun AuthenticatedWorkspaceShell(vm: HandelhaAppViewModel) {
    val state by vm.uiState.collectAsStateWithLifecycle()
    var currentTab by rememberSaveable { mutableIntStateOf(0) }
    val subStack = remember { mutableStateListOf<SubRoute>() }
    var showEnergyWizard by remember { mutableStateOf(false) }

    fun pushRoute(route: SubRoute) {
        subStack.add(route)
    }

    fun popRoute() {
        if (subStack.isNotEmpty()) {
            subStack.removeAt(subStack.lastIndex)
        }
    }

    fun startFocusFor(taskId: String?, title: String, initialTab: Int = 0) {
        vm.prepareFocusSession(taskId, title)
        pushRoute(SubRoute.FocusSession(initialTab = initialTab))
    }

    fun openAddTask(task: TaskItem? = null) {
        pushRoute(SubRoute.AddTask(editingTaskId = task?.id))
    }

    fun askAssistantFromDraft(promptText: String) {
        while (subStack.isNotEmpty()) {
            subStack.removeAt(subStack.lastIndex)
        }
        currentTab = 3
        if (promptText.isNotBlank()) {
            vm.sendChatMessage(promptText, isVoice = false)
        }
    }

    BackHandler(enabled = subStack.isEmpty() && currentTab != 0) {
        currentTab = 0
    }

    val topSubRoute = subStack.lastOrNull()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.statusBars),
    ) {
        if (topSubRoute != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .windowInsetsPadding(WindowInsets.navigationBars),
            ) {
                when (topSubRoute) {
                    is SubRoute.AddTask -> {
                        val editingTask = remember(topSubRoute.editingTaskId, state.tasks) {
                            topSubRoute.editingTaskId?.let { tid -> state.tasks.firstOrNull { it.id == tid } }
                        }
                        val initialAlertMode = editingTask?.let { state.alarmState.alertModeForTask(it.id) } ?: "alarm"
                        AddTaskScreen(
                            editingTask = editingTask,
                            projects = state.projects,
                            initialAlertMode = initialAlertMode,
                            isEnglish = state.isEnglish,
                            onBack = ::popRoute,
                            onAskAssistant = ::askAssistantFromDraft,
                            onSave = { title, desc, priority, dueAt, estMins, recurrence, projectId, alertMode ->
                                vm.saveTask(
                                    editingTask = editingTask,
                                    title = title,
                                    description = desc,
                                    priority = priority,
                                    dueAtMs = dueAt,
                                    estimatedMinutes = estMins,
                                    recurrence = recurrence,
                                    projectId = projectId,
                                    alertMode = alertMode,
                                    onComplete = ::popRoute,
                                )
                            },
                            onShowToast = vm::showToast,
                        )
                    }

                    SubRoute.NewProject -> {
                        NewProjectScreen(
                            isEnglish = state.isEnglish,
                            onBack = ::popRoute,
                            onCreateProject = { title, goal, targetDateMs, colorValue, starterStep ->
                                vm.createProject(
                                    title = title,
                                    description = goal,
                                    targetDateMs = targetDateMs,
                                    colorValue = colorValue,
                                    initialStepTitle = starterStep,
                                    onCreated = { created ->
                                        popRoute()
                                        pushRoute(SubRoute.ProjectWorkspace(created.id))
                                    },
                                )
                            },
                            onShowToast = vm::showToast,
                        )
                    }

                    is SubRoute.ProjectWorkspace -> {
                        val project = state.projects.firstOrNull { it.id == topSubRoute.projectId }
                        if (project == null) {
                            LaunchedEffect(topSubRoute.projectId) {
                                popRoute()
                            }
                        } else {
                            ProjectWorkspaceScreen(
                                project = project,
                                allTasks = state.tasks,
                                energyPrefs = state.energyPrefs,
                                isEnglish = state.isEnglish,
                                onBack = ::popRoute,
                                onAddStep = { stepTitle -> vm.addProjectStep(project, stepTitle) },
                                onSmartBreakdown = { vm.smartBreakdownProject(project) },
                                onToggleTask = vm::toggleTaskComplete,
                                onEditTask = { task -> openAddTask(task) },
                                onDeleteProject = {
                                    vm.deleteProject(project.id) { popRoute() }
                                },
                            )
                        }
                    }

                    is SubRoute.FocusSession -> {
                        FocusSessionScreen(
                            focusState = state.focusState,
                            sessions = state.focusSessions,
                            initialTab = topSubRoute.initialTab,
                            isEnglish = state.isEnglish,
                            onBack = ::popRoute,
                            onToggleRunPause = vm::toggleFocusRunPause,
                            onEndSession = { vm.finishFocusSession(completedNaturally = false) },
                            onSelectDuration = vm::setFocusDuration,
                            onToggleBreakMode = vm::setFocusBreakMode,
                            onSelectSound = vm::selectSoundscape,
                            onVolumeChange = vm::setSoundVolume,
                            onDismissCelebration = vm::dismissFocusCelebration,
                        )
                    }

                    SubRoute.ChatHistory -> {
                        ChatHistoryScreen(
                            conversations = state.conversations,
                            isEnglish = state.isEnglish,
                            onBack = ::popRoute,
                            onNewChat = {
                                vm.startNewConversation()
                                popRoute()
                            },
                            onOpenConversation = { rec ->
                                vm.openConversation(rec)
                                popRoute()
                            },
                            onDeleteConversation = vm::deleteConversation,
                        )
                    }

                    SubRoute.Settings -> {
                        SettingsScreen(
                            user = state.user,
                            themeMode = state.themeMode,
                            isEnglish = state.isEnglish,
                            isStudentMode = state.isStudentMode,
                            energyPrefs = state.energyPrefs,
                            notifPrefs = state.notifPrefs,
                            subscriptionState = state.subscriptionState,
                            onBack = ::popRoute,
                            onOpenEnergyWizard = { showEnergyWizard = true },
                            onSetStudentMode = vm::setStudentMode,
                            onOpenStudentQuotes = { pushRoute(SubRoute.StudentQuotes) },
                            onSetEnglish = vm::setEnglish,
                            onSetThemeMode = vm::setThemeMode,
                            onToggleNotifications = vm::toggleNotificationsEnabled,
                            onSaveQuietHours = vm::saveQuietHours,
                            onOpenSubscriptions = { pushRoute(SubRoute.Subscription) },
                            onUpdateTone = vm::updateAssistantTone,
                            onExportBackup = vm::exportBackupJson,
                            onClearChatHistory = vm::clearChatHistory,
                            onDeleteAccount = {
                                subStack.clear()
                                vm.deleteAccount()
                            },
                            onSignOut = {
                                subStack.clear()
                                vm.signOut()
                            },
                            onShowToast = vm::showToast,
                        )
                    }

                    SubRoute.Notifications -> {
                        NotificationsScreen(
                            tasks = state.tasks,
                            alarmState = state.alarmState,
                            notifPrefs = state.notifPrefs,
                            readNotifIds = state.readNotifIds,
                            isEnglish = state.isEnglish,
                            onBack = ::popRoute,
                            onMarkRead = vm::markNotificationRead,
                            onMarkAllRead = vm::markAllNotificationsRead,
                            onToggleAlarmEnabled = vm::toggleAlarmEnabled,
                            onToggleAlarmMode = vm::toggleAlarmMode,
                            onPreviewAlarm = vm::previewAlarm,
                            onDeleteAlarm = vm::deleteAlarmItem,
                        )
                    }

                    SubRoute.Subscription -> {
                        SubscriptionScreen(
                            subscriptionState = state.subscriptionState,
                            isStudentMode = state.isStudentMode,
                            isEnglish = state.isEnglish,
                            onBack = ::popRoute,
                            onSelectPlan = vm::selectSubscriptionPlan,
                            onCancelLocalPlan = vm::cancelLocalSubscription,
                            onToggleStudentMode = vm::setStudentMode,
                        )
                    }

                    SubRoute.StudentQuotes -> {
                        val openHeroTask = remember(state.tasks) {
                            state.tasks.firstOrNull { !it.isCompleted && !it.isCancelled && !it.isDeleted }
                        }
                        StudentQuotesScreen(
                            motivationState = state.studentMotivation,
                            isEnglish = state.isEnglish,
                            onBack = ::popRoute,
                            onNextQuote = { vm.nextStudentQuote() },
                            onToggleFavorite = vm::toggleFavoriteQuote,
                            onPinQuote = vm::togglePinQuoteToWidget,
                            onSelectMood = vm::setStudentStudyMood,
                            onSavePersonalMotto = vm::setStudentPersonalMotto,
                            onAddCustomQuote = { text, tag ->
                                vm.addCustomStudentQuote(
                                    textAr = text,
                                    tagAr = tag,
                                    category = com.handelha.app.domain.StudentQuoteCategory.CUSTOM,
                                    pinToWidget = true,
                                )
                            },
                            onDeleteCustomQuote = vm::deleteCustomStudentQuote,
                            onStartQuickFocus = { boostMins, boostTitle ->
                                popRoute()
                                startFocusFor(
                                    openHeroTask?.id,
                                    "$boostTitle (${ArabicFormatters.toArabicDigits(boostMins)} د)",
                                    0,
                                )
                            },
                            onShowToast = vm::showToast,
                        )
                    }
                }
            }
        } else {
            Box(modifier = Modifier.fillMaxSize()) {
                when (currentTab) {
                    0 -> DashboardScreen(
                        user = state.user,
                        tasks = state.tasks,
                        projects = state.projects,
                        focusSessions = state.focusSessions,
                        readNotifIds = state.readNotifIds,
                        isStudentMode = state.isStudentMode,
                        studentMotivation = state.studentMotivation,
                        isEnglish = state.isEnglish,
                        onToggleTheme = vm::toggleThemeQuick,
                        onOpenNotifications = { pushRoute(SubRoute.Notifications) },
                        onOpenSettings = { pushRoute(SubRoute.Settings) },
                        onOpenAddTask = { task -> openAddTask(task) },
                        onToggleTaskComplete = vm::toggleTaskComplete,
                        onStartFocus = { taskId, title, tab ->
                            startFocusFor(taskId, title, tab)
                        },
                        onOpenAssistant = { currentTab = 3 },
                        onOpenAllTasks = { currentTab = 1 },
                        onNextStudentQuote = { vm.nextStudentQuote() },
                        onToggleFavoriteQuote = vm::toggleFavoriteQuote,
                        onPinQuoteToWidget = { qId -> if (qId != null) vm.togglePinQuoteToWidget(qId) },
                        onSelectStudentMood = vm::setStudentStudyMood,
                        onOpenStudentQuotesHub = { pushRoute(SubRoute.StudentQuotes) },
                        onToggleStudentMode = vm::setStudentMode,
                        onShowToast = vm::showToast,
                    )

                    1 -> TasksScreen(
                        tasks = state.tasks,
                        projects = state.projects,
                        isEnglish = state.isEnglish,
                        onOpenSettings = { pushRoute(SubRoute.Settings) },
                        onOpenAddTask = { task -> openAddTask(task) },
                        onOpenAssistant = { currentTab = 3 },
                        onStartFocus = { taskId, title ->
                            startFocusFor(taskId, title, 0)
                        },
                        onToggleComplete = vm::toggleTaskComplete,
                        onDeleteTask = vm::deleteTask,
                    )

                    2 -> ProjectsScreen(
                        projects = state.projects,
                        tasks = state.tasks,
                        isEnglish = state.isEnglish,
                        onOpenSettings = { pushRoute(SubRoute.Settings) },
                        onOpenNewProject = { pushRoute(SubRoute.NewProject) },
                        onOpenWorkspace = { proj -> pushRoute(SubRoute.ProjectWorkspace(proj.id)) },
                        onOpenAssistant = { currentTab = 3 },
                    )

                    3 -> ChatScreen(
                        user = state.user,
                        chatState = state.chatState,
                        tokenState = state.tokenState,
                        energyPrefs = state.energyPrefs,
                        tasks = state.tasks,
                        projects = state.projects,
                        isEnglish = state.isEnglish,
                        onSendMessage = vm::sendChatMessage,
                        onStartFocus = { taskId, title ->
                            startFocusFor(taskId, title, 0)
                        },
                        onOpenAddTask = { openAddTask(null) },
                        onOpenHistory = { pushRoute(SubRoute.ChatHistory) },
                        onOpenSettings = { pushRoute(SubRoute.Settings) },
                        onOpenEnergyWizard = { showEnergyWizard = true },
                        onShowRefillSheet = vm::setTokenRefillSheetVisible,
                        onClaimAdReward = vm::claimAdTokensReward,
                        onShowToast = vm::showToast,
                    )

                    else -> TrackingScreen(
                        user = state.user,
                        tasks = state.tasks,
                        projects = state.projects,
                        focusSessions = state.focusSessions,
                        examGrades = state.examGrades,
                        isStudentMode = state.isStudentMode,
                        isEnglish = state.isEnglish,
                        onOpenSettings = { pushRoute(SubRoute.Settings) },
                        onOpenAddTask = { openAddTask(null) },
                        onOpenSubscription = { pushRoute(SubRoute.Subscription) },
                        onOpenStudentQuotes = { pushRoute(SubRoute.StudentQuotes) },
                        onAddExamGrade = vm::addExamGrade,
                        onDeleteExamGrade = vm::deleteExamGrade,
                    )
                }

                HandelhaBottomNav(
                    currentIndex = currentTab,
                    isEnglish = state.isEnglish,
                    onTabSelected = { currentTab = it },
                    modifier = Modifier.align(Alignment.BottomCenter),
                )
            }
        }
    }

    if (showEnergyWizard) {
        EnergyPreferencesWizardSheet(
            initial = state.energyPrefs,
            isEnglish = state.isEnglish,
            onDismiss = { showEnergyWizard = false },
            onSave = { updated ->
                vm.saveEnergyPreferences(updated)
                showEnergyWizard = false
            },
        )
    }
}

@Composable
private fun FloatingToastBanner(
    toast: ToastFeedback?,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = HandelhaTheme.colors
    AnimatedVisibility(
        visible = toast != null,
        enter = fadeIn() + slideInVertically { -it / 2 },
        exit = fadeOut() + slideOutVertically { -it / 2 },
        modifier = modifier,
    ) {
        toast?.let { feedback ->
            val accent = if (feedback.isError) c.danger else c.primary
            val shape = RoundedCornerShape(18.dp)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .shadow(14.dp, shape, ambientColor = accent.copy(alpha = 0.22f))
                    .clip(shape)
                    .background(c.surface, shape)
                    .border(1.2.dp, accent.copy(alpha = 0.45f), shape)
                    .clickable(onClick = onDismiss)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    imageVector = if (feedback.isError) Icons.Rounded.ErrorOutline else Icons.Rounded.CheckCircle,
                    contentDescription = null,
                    tint = accent,
                    modifier = Modifier.size(20.dp),
                )
                Spacer(Modifier.width(10.dp))
                Text(
                    text = feedback.message,
                    fontSize = 13.5.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = c.textPrimary,
                )
            }
        }
    }
}

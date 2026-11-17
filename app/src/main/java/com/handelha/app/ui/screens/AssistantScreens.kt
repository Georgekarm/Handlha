package com.handelha.app.ui.screens

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.speech.RecognizerIntent
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.FormatListBulleted
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.EventAvailable
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material.icons.rounded.NightsStay
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.text.style.TextAlign
import com.handelha.app.domain.AppUser
import com.handelha.app.domain.ChatConversationRecord
import com.handelha.app.domain.ChatMessageItem
import com.handelha.app.domain.ChatMessageRole
import com.handelha.app.domain.ProjectItem
import com.handelha.app.domain.TaskItem
import com.handelha.app.domain.TokenBalanceState
import com.handelha.app.domain.UserEnergyPreferences
import com.handelha.app.ui.ChatUiState
import com.handelha.app.ui.components.FeatureEmptyState
import com.handelha.app.ui.components.HandelhaBottomSheetFrame
import com.handelha.app.ui.components.HandelhaHeader
import com.handelha.app.ui.components.HandelhaHeaderIconButton
import com.handelha.app.ui.theme.HandelhaTheme
import com.handelha.app.ui.theme.IbmPlexSansArabic
import com.handelha.app.util.ArabicFormatters

@Composable
fun ChatScreen(
    user: AppUser?,
    chatState: ChatUiState,
    tokenState: TokenBalanceState,
    energyPrefs: UserEnergyPreferences,
    tasks: List<TaskItem>,
    projects: List<ProjectItem>,
    isEnglish: Boolean,
    onSendMessage: (String, Boolean) -> Unit,
    onStartFocus: (taskId: String, title: String) -> Unit,
    onOpenAddTask: () -> Unit = {},
    onOpenHistory: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenEnergyWizard: () -> Unit,
    onShowRefillSheet: (Boolean) -> Unit,
    onClaimAdReward: () -> Unit,
    onShowToast: (String, Boolean) -> Unit,
) {
    val c = HandelhaTheme.colors
    val context = LocalContext.current
    var inputText by remember { mutableStateOf("") }
    val listState = rememberLazyListState()

    val openTasks = remember(tasks) { tasks.filter { !it.isCompleted && !it.isCancelled && !it.isDeleted } }
    val topOpenTask = openTasks.firstOrNull()
    val projectMap = remember(projects) { projects.associateBy { it.id } }

    LaunchedEffect(chatState.messages.size) {
        if (chatState.messages.isNotEmpty()) {
            listState.animateScrollToItem(chatState.messages.size)
        }
    }

    val speechLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { res ->
        if (res.resultCode == Activity.RESULT_OK) {
            val results = res.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
            val spoken = results?.firstOrNull()?.trim().orEmpty()
            if (spoken.isNotEmpty()) {
                onSendMessage(spoken, true)
            }
        }
    }

    val micPermLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, if (isEnglish) "en-US" else "ar-EG")
                putExtra(RecognizerIntent.EXTRA_PROMPT, if (isEnglish) "Speak calmly..." else "احكي اللي في بالك بهدوء...")
            }
            runCatching { speechLauncher.launch(intent) }.onFailure {
                onShowToast(if (isEnglish) "Voice input not available on this device" else "الإدخال الصوتي غير متاح حاليًا على الجهاز ده", false)
            }
        } else {
            onShowToast(if (isEnglish) "Microphone permission is required for voice input" else "إذن الميكروفون مطلوب للتحدث مع المساعد", false)
        }
    }

    fun triggerVoice() {
        if (!tokenState.canSendVoice) {
            onShowRefillSheet(true)
            return
        }
        val hasMic = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        if (hasMic) {
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, if (isEnglish) "en-US" else "ar-EG")
                putExtra(RecognizerIntent.EXTRA_PROMPT, if (isEnglish) "Speak calmly..." else "احكي اللي في بالك بهدوء...")
            }
            runCatching { speechLauncher.launch(intent) }.onFailure {
                onShowToast(if (isEnglish) "Voice input not available on this device" else "الإدخال الصوتي غير متاح حاليًا على الجهاز ده", false)
            }
        } else {
            micPermLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    fun submitText() {
        val clean = inputText.trim()
        if (clean.isEmpty()) return
        inputText = ""
        onSendMessage(clean, false)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .imePadding(),
    ) {
        // Header + Token Quota & Energy Profile Bar
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .border(width = 0.5.dp, color = c.border.copy(alpha = 0.45f))
                .padding(horizontal = 16.dp, vertical = 10.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier.size(42.dp).clip(RoundedCornerShape(14.dp)).background(c.primarySoft),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Outlined.AutoAwesome, null, tint = c.primary, modifier = Modifier.size(21.dp))
                }
                Spacer(Modifier.width(10.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (isEnglish) "Handelha Assistant" else "مساعد هندلها",
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        fontSize = 19.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = c.textPrimary,
                    )
                    Text(
                        text = if (isEnglish) "With you, no rush" else "معاك، مش مستعجلك",
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        fontSize = 12.sp,
                        color = c.textSecondary,
                    )
                }
                Spacer(Modifier.width(6.dp))
                // Token Header Badge
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(if (tokenState.balance <= 10) c.dangerSoft else c.primarySoft)
                        .clickable { onShowRefillSheet(true) }
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                        .testTag("chat_token_badge"),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Rounded.Bolt,
                        null,
                        tint = if (tokenState.balance <= 10) c.danger else c.primary,
                        modifier = Modifier.size(15.dp),
                    )
                    Spacer(Modifier.width(3.dp))
                    Text(
                        text = ArabicFormatters.toArabicDigits(tokenState.balance),
                        fontSize = 12.5.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = if (tokenState.balance <= 10) c.danger else c.primary,
                    )
                }
                HandelhaHeaderIconButton(
                    icon = Icons.AutoMirrored.Rounded.FormatListBulleted,
                    tooltip = if (isEnglish) "Chat History" else "سجل المحادثات",
                    iconColor = c.primary,
                    onClick = onOpenHistory,
                    testTag = "chat_history_button",
                )
                HandelhaHeaderIconButton(
                    icon = Icons.Outlined.Settings,
                    tooltip = if (isEnglish) "Settings" else "الإعدادات",
                    onClick = onOpenSettings,
                    testTag = "chat_settings_button",
                )
            }

            Spacer(Modifier.height(8.dp))

            // Quota & Energy Bar
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(12.dp))
                        .background(c.surface, RoundedCornerShape(12.dp))
                        .border(1.dp, c.border, RoundedCornerShape(12.dp))
                        .clickable { onShowRefillSheet(true) }
                        .padding(horizontal = 10.dp, vertical = 7.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Rounded.Bolt,
                        null,
                        tint = if (tokenState.balance <= 10) c.danger else c.warning,
                        modifier = Modifier.size(15.dp),
                    )
                    Spacer(Modifier.width(5.dp))
                    Text(
                        text = if (isEnglish) "Tokens: ${tokenState.balance}/${tokenState.dailyAllowance} (+15 Ad)"
                        else "التوكنز: ${ArabicFormatters.toArabicDigits(tokenState.balance)}/${ArabicFormatters.toArabicDigits(tokenState.dailyAllowance)} (+١٥ بإعلان)",
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.textSecondary,
                    )
                }
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(c.primarySoft, RoundedCornerShape(12.dp))
                        .border(1.dp, c.primary.copy(alpha = 0.35f), RoundedCornerShape(12.dp))
                        .clickable(onClick = onOpenEnergyWizard)
                        .padding(horizontal = 10.dp, vertical = 7.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Rounded.Tune, null, tint = c.primary, modifier = Modifier.size(14.dp))
                    Spacer(Modifier.width(4.dp))
                    Text(
                        text = if (isEnglish) "Energy: ${energyPrefs.peakShort(true)}" else "طاقتك: ${energyPrefs.peakShort(false)}",
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = c.primary,
                    )
                }
            }
        }

        // Messages List
        LazyColumn(
            state = listState,
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(start = 20.dp, top = 16.dp, end = 20.dp, bottom = 14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "${if (isEnglish) "Today" else "النهارده"} • ${ArabicFormatters.timeOfDayAr(System.currentTimeMillis())}",
                        fontSize = 11.5.sp,
                        color = c.textSecondary,
                    )
                    Spacer(Modifier.height(12.dp))
                    // Welcome Card
                    val first = ArabicFormatters.trData(user?.firstName ?: if (isEnglish) "friend" else "صديقي")
                    AssistantTextBubble(
                        text = if (isEnglish) {
                            "Welcome $first, how is your day going?\nTell me what is on your plate and we will plan it together."
                        } else {
                            "أهلًا يا $first، يومك عامل إيه؟\nقولّي اللي وراك ونرتّبه سوا."
                        },
                    )
                }
            }

            if (chatState.messages.isEmpty() && topOpenTask != null) {
                item {
                    AssistantSuggestedTaskBubble(
                        task = topOpenTask,
                        projectName = topOpenTask.projectId?.let { projectMap[it]?.title },
                        isEnglish = isEnglish,
                        onStartFocus = { onStartFocus(topOpenTask.id, topOpenTask.title) },
                    )
                }
            }

            items(chatState.messages, key = { it.id }) { msg ->
                if (msg.role == ChatMessageRole.user) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp, bottomStart = 20.dp, bottomEnd = 6.dp))
                                .background(c.primary)
                                .padding(horizontal = 16.dp, vertical = 12.dp),
                        ) {
                            Text(msg.text, fontSize = 14.5.sp, color = c.textOnPrimary, lineHeight = 21.sp)
                        }
                    }
                } else {
                    val msgShape = RoundedCornerShape(22.dp)
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .then(
                                if (!c.isDark) Modifier.shadow(6.dp, msgShape, ambientColor = Color.Black.copy(alpha = 0.04f), spotColor = Color.Black.copy(alpha = 0.04f))
                                else Modifier,
                            )
                            .clip(msgShape)
                            .background(c.surface, msgShape)
                            .border(1.dp, c.border, msgShape)
                            .padding(16.dp),
                    ) {
                        SecretaryRichMessageCard(
                            msg = msg,
                            isEnglish = isEnglish,
                            onQuickReply = { reply -> onSendMessage(reply, false) },
                        )
                    }
                }
            }

            if (chatState.isSending) {
                item {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp, color = c.primary)
                        Text(if (isEnglish) "Preparing your reply..." else "برتب لك الرد...", fontSize = 13.sp, color = c.textSecondary)
                    }
                }
            }
        }

        // Quick suggestions + Composer Card (raised cleanly above floating bottom nav bar)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.navigationBars)
                .padding(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 104.dp),
        ) {
            // 2 Quick Suggestion Pills matching Flutter chat_screen.dart ("رتّب مهامي" | "اختار أول خطوة")
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                val pill1Label = if (isEnglish) "Organize my tasks" else "رتّب مهامي"
                val pill1Prompt = if (isEnglish) "Organize my tasks today" else "رتّبلي مهام النهارده"
                val pill2Label = if (isEnglish) "Pick first step" else "اختار أول خطوة"
                val pill2Prompt = if (isEnglish) "Pick my first step now" else "اختارلي أول خطوة أبدأ بيها دلوقتي"

                listOf(pill1Label to pill1Prompt, pill2Label to pill2Prompt).forEach { (label, prompt) ->
                    val pillShape = RoundedCornerShape(14.dp)
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .then(
                                if (!c.isDark) Modifier.shadow(4.dp, pillShape, ambientColor = Color.Black.copy(alpha = 0.04f))
                                else Modifier,
                            )
                            .clip(pillShape)
                            .background(c.surface, pillShape)
                            .border(1.dp, c.border, pillShape)
                            .clickable { onSendMessage(prompt, false) }
                            .padding(vertical = 10.dp, horizontal = 8.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = label,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = c.textPrimary,
                        )
                    }
                }
            }

            Spacer(Modifier.height(8.dp))

            val quickSuggestions = if (isEnglish) {
                listOf("Show my tasks", "Study sprint 45m", "Break down my project")
            } else {
                listOf("عرض مهامي", "مذاكرة ٤٥ دقيقة", "قسّملي مشروعي")
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(bottom = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                quickSuggestions.forEach { q ->
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(999.dp))
                            .background(c.surface)
                            .border(1.dp, c.border, RoundedCornerShape(999.dp))
                            .clickable { onSendMessage(q, false) }
                            .padding(horizontal = 12.dp, vertical = 6.dp),
                    ) {
                        Text(q, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = c.primary)
                    }
                }
            }

            val composerShape = RoundedCornerShape(24.dp)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .then(
                        if (!c.isDark) Modifier.shadow(10.dp, composerShape, ambientColor = Color.Black.copy(alpha = 0.06f), spotColor = Color.Black.copy(alpha = 0.06f))
                        else Modifier,
                    )
                    .clip(composerShape)
                    .background(c.surface, composerShape)
                    .border(1.dp, c.border, composerShape)
                    .padding(horizontal = 8.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(
                    onClick = onOpenAddTask,
                    modifier = Modifier.size(40.dp).testTag("chat_add_task_button"),
                ) {
                    Icon(
                        imageVector = Icons.Rounded.Add,
                        contentDescription = if (isEnglish) "Add Task" else "إضافة مهمة",
                        tint = c.textSecondary,
                        modifier = Modifier.size(22.dp),
                    )
                }

                Box(modifier = Modifier.weight(1f).padding(horizontal = 4.dp)) {
                    if (inputText.isEmpty()) {
                        Text(
                            text = if (isEnglish) "Write what's on your mind..." else "اكتب اللي في بالك...",
                            fontSize = 14.sp,
                            color = c.textMuted,
                        )
                    }
                    BasicTextField(
                        value = inputText,
                        onValueChange = { inputText = it },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                        keyboardActions = KeyboardActions(onSend = { submitText() }),
                        cursorBrush = SolidColor(c.primary),
                        textStyle = TextStyle(fontFamily = IbmPlexSansArabic, fontSize = 14.5.sp, color = c.textPrimary),
                        modifier = Modifier.fillMaxWidth().testTag("chat_text_input"),
                    )
                }

                IconButton(
                    onClick = ::triggerVoice,
                    modifier = Modifier.size(40.dp).testTag("chat_mic_button"),
                ) {
                    Icon(
                        imageVector = Icons.Rounded.Mic,
                        contentDescription = if (isEnglish) "Voice input" else "إدخال صوتي",
                        tint = c.textSecondary,
                        modifier = Modifier.size(21.dp),
                    )
                }

                Spacer(Modifier.width(4.dp))

                Box(
                    modifier = Modifier
                        .size(42.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(c.primary)
                        .clickable { submitText() }
                        .testTag("chat_send_button"),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Rounded.Send,
                        contentDescription = if (isEnglish) "Send" else "إرسال",
                        tint = c.textOnPrimary,
                        modifier = Modifier.size(18.dp),
                    )
                }
            }

            Spacer(Modifier.height(6.dp))
            Text(
                text = if (isEnglish) "No need to organize your words, I'm with you."
                else "مش لازم ترتّب كلامك، أنا معاك.",
                textAlign = TextAlign.Center,
                fontSize = 11.5.sp,
                color = c.textSecondary,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }

    if (chatState.showTokenRefillSheet) {
        HandelhaBottomSheetFrame(onDismiss = { onShowRefillSheet(false) }) {
            Text(
                text = if (isEnglish) "Assistant Tokens Balance" else "رصيد التوكنز للمساعد",
                fontSize = 18.sp,
                fontWeight = FontWeight.ExtraBold,
                color = c.textPrimary,
            )
            Spacer(Modifier.height(6.dp))
            Text(
                text = if (isEnglish) "You have ${tokenState.balance} tokens left today (Text = 2, Voice = 5). Watch a quick reward ad to refill +15 tokens instantly."
                else "رصيدك الحالي ${ArabicFormatters.toArabicDigits(tokenState.balance)} توكن (النص = ٢، الصوت = ٥). تقدر تضيف +١٥ توكن فورًا بمشاهدة إعلان مكافأة.",
                fontSize = 13.5.sp,
                color = c.textSecondary,
                lineHeight = 20.sp,
            )
            Spacer(Modifier.height(16.dp))
            Button(
                onClick = {
                    onClaimAdReward()
                    onShowRefillSheet(false)
                },
                enabled = !tokenState.isLoadingAd,
                modifier = Modifier.fillMaxWidth().height(50.dp).testTag("token_refill_claim"),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = c.ctaBackground, contentColor = c.ctaForeground),
            ) {
                Icon(Icons.Rounded.Bolt, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(if (isEnglish) "Refill +15 Tokens" else "شحن +١٥ توكن الآن", fontWeight = FontWeight.ExtraBold)
            }
        }
    }
}

@Composable
private fun AssistantTextBubble(text: String) {
    val c = HandelhaTheme.colors
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(c.surface, RoundedCornerShape(22.dp))
            .border(1.dp, c.border, RoundedCornerShape(22.dp))
            .padding(16.dp),
    ) {
        Text(text, fontSize = 14.5.sp, lineHeight = 22.sp, color = c.textPrimary)
    }
}

@Composable
private fun AssistantSuggestedTaskBubble(
    task: TaskItem,
    projectName: String?,
    isEnglish: Boolean,
    onStartFocus: () -> Unit,
) {
    val c = HandelhaTheme.colors
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(c.surface, RoundedCornerShape(22.dp))
            .border(1.dp, c.border, RoundedCornerShape(22.dp))
            .padding(16.dp),
    ) {
        Text(
            text = if (isEnglish) "Ready to start with this?" else "تحب نبدأ بدي دلوقتي؟",
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            color = c.primary,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            text = ArabicFormatters.trData(task.title),
            fontSize = 16.sp,
            fontWeight = FontWeight.ExtraBold,
            color = c.textPrimary,
        )
        if (!projectName.isNullOrBlank()) {
            Spacer(Modifier.height(2.dp))
            Text(ArabicFormatters.trData(projectName), fontSize = 12.sp, color = c.textSecondary)
        }
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = onStartFocus,
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(containerColor = c.primary, contentColor = c.textOnPrimary),
        ) {
            Icon(Icons.Rounded.PlayArrow, null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
            Text(if (isEnglish) "Start Focus Session" else "ابدأ جلسة تركيز", fontWeight = FontWeight.Bold)
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SecretaryRichMessageCard(
    msg: ChatMessageItem,
    isEnglish: Boolean,
    onQuickReply: (String) -> Unit,
) {
    val c = HandelhaTheme.colors
    val trimmed = msg.text.trim()
    val isScheduleDraft = trimmed.contains("مسودة ترتيب المهام") ||
        trimmed.contains("حدّثت المسودة") ||
        trimmed.contains("Prepared your schedule draft") ||
        trimmed.contains("Updated draft")

    if (isScheduleDraft && msg.proposal != null) {
        val slots = msg.proposal.slots
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Brush.linearGradient(listOf(c.heroTeal, c.primary)))
                    .padding(horizontal = 14.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier.size(38.dp).clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = 0.16f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Rounded.EventAvailable, null, tint = Color.White, modifier = Modifier.size(20.dp))
                }
                Spacer(Modifier.width(10.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (isEnglish) "Executive Schedule Proposal" else "خطة مكتب السكرتير المقترحة",
                        fontSize = 14.5.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = Color.White,
                    )
                    Text(
                        text = if (isEnglish) "${slots.size} tasks organized by priority"
                        else "ترتيب ذكي لـ ${ArabicFormatters.toArabicDigits(slots.size)} مهام حسب الأولوية",
                        fontSize = 11.5.sp,
                        color = Color.White.copy(alpha = 0.85f),
                    )
                }
            }
            Spacer(Modifier.height(10.dp))
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                slots.forEachIndexed { idx, slot ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(14.dp))
                            .background(c.surfaceSoft)
                            .border(1.dp, c.border, RoundedCornerShape(14.dp))
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(
                            modifier = Modifier.size(28.dp).clip(CircleShape).background(c.primarySoft),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(ArabicFormatters.toArabicDigits(idx + 1), fontSize = 12.sp, fontWeight = FontWeight.ExtraBold, color = c.primary)
                        }
                        Spacer(Modifier.width(10.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(slot.title, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = c.textPrimary)
                            Text(
                                text = "${slot.startAtIso.substringAfter('T').take(5)} – ${slot.endAtIso.substringAfter('T').take(5)}",
                                fontSize = 11.5.sp,
                                color = c.primary,
                            )
                        }
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = { onQuickReply(if (isEnglish) "confirm schedule" else "اعتمد الخطة") },
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = c.primary, contentColor = c.textOnPrimary),
                    modifier = Modifier.testTag("secretary_confirm_schedule"),
                ) {
                    Icon(Icons.Rounded.Verified, null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(if (isEnglish) "Confirm & Save Schedule" else "اعتمد الجدول الآن", fontSize = 12.5.sp, fontWeight = FontWeight.ExtraBold)
                }
                OutlinedButton(
                    onClick = { onQuickReply(if (isEnglish) "make it from 6 to 9 pm" else "خليه من 6 ل 9 بليل") },
                    shape = RoundedCornerShape(12.dp),
                ) {
                    Icon(Icons.Rounded.NightsStay, null, tint = c.primary, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(if (isEnglish) "Shift to Evening" else "نقل للفترة المسائية", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = c.primary)
                }
            }
        }
    } else {
        Column {
            if (trimmed.startsWith("تمام") || trimmed.startsWith("Added ")) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(bottom = 6.dp)) {
                    Icon(Icons.Rounded.CheckCircle, null, tint = c.success, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(
                        text = if (isEnglish) "Schedule Saved" else "تم حفظ الجدول في مهامك",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = c.success,
                    )
                }
            }
            Text(trimmed, fontSize = 14.5.sp, lineHeight = 22.sp, color = c.textPrimary)
            if (msg.quickReplies.isNotEmpty()) {
                Spacer(Modifier.height(10.dp))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    msg.quickReplies.forEach { reply ->
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(12.dp))
                                .background(c.primarySoft)
                                .clickable { onQuickReply(reply) }
                                .padding(horizontal = 12.dp, vertical = 7.dp),
                        ) {
                            Text(reply, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = c.primary)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ChatHistoryScreen(
    conversations: List<ChatConversationRecord>,
    isEnglish: Boolean,
    onBack: () -> Unit,
    onNewChat: () -> Unit,
    onOpenConversation: (ChatConversationRecord) -> Unit,
    onDeleteConversation: (String) -> Unit,
) {
    BackHandler(onBack = onBack)

    val c = HandelhaTheme.colors
    var search by remember { mutableStateOf("") }
    val filtered = remember(conversations, search) {
        val q = search.trim().lowercase()
        if (q.isEmpty()) conversations else conversations.filter { it.title.lowercase().contains(q) }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(bottom = 32.dp),
    ) {
        HandelhaHeader(
            title = if (isEnglish) "Chat History" else "سجل المحادثات",
            subtitle = if (isEnglish) "Resume any previous calm plan" else "ارجع لأي خطة أو محادثة سابقة",
            isEnglish = isEnglish,
            showBack = true,
            onBack = onBack,
        )

        Column(modifier = Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(c.surface, RoundedCornerShape(16.dp))
                    .border(1.dp, c.border, RoundedCornerShape(16.dp))
                    .padding(horizontal = 14.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Rounded.Search, null, tint = c.textMuted, modifier = Modifier.size(19.dp))
                Spacer(Modifier.width(8.dp))
                Box(modifier = Modifier.weight(1f)) {
                    if (search.isEmpty()) Text(if (isEnglish) "Search conversations..." else "ابحث في المحادثات...", fontSize = 14.sp, color = c.textMuted)
                    BasicTextField(
                        value = search,
                        onValueChange = { search = it },
                        singleLine = true,
                        textStyle = TextStyle(fontFamily = IbmPlexSansArabic, fontSize = 14.sp, color = c.textPrimary),
                        cursorBrush = SolidColor(c.primary),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            Button(
                onClick = onNewChat,
                modifier = Modifier.fillMaxWidth().height(48.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = c.ctaBackground, contentColor = c.ctaForeground),
            ) {
                Icon(Icons.Rounded.Add, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(if (isEnglish) "New Conversation" else "محادثة جديدة", fontWeight = FontWeight.Bold)
            }

            if (filtered.isEmpty()) {
                FeatureEmptyState(
                    title = if (isEnglish) "No saved conversations yet" else "لسه مفيش محادثات محفوظة",
                    subtitle = if (isEnglish) "Start chatting with Handelha and your conversations will stay organized here."
                    else "ابدأ اتكلم مع مساعد هندلها ومحادثاتك هتتحفظ هنا تلقائيًا.",
                    primaryCtaLabel = if (isEnglish) "Start Chatting" else "ابدأ محادثة",
                    onPrimaryCta = onNewChat,
                )
            } else {
                filtered.forEach { rec ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(18.dp))
                            .background(c.surface, RoundedCornerShape(18.dp))
                            .border(1.dp, c.border, RoundedCornerShape(18.dp))
                            .clickable { onOpenConversation(rec) }
                            .padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(rec.title, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = c.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Spacer(Modifier.height(3.dp))
                            Text(
                                text = "${ArabicFormatters.dateShort(rec.updatedAtMs)} • ${ArabicFormatters.toArabicDigits(rec.messages.size)} ${if (isEnglish) "messages" else "رسائل"}",
                                fontSize = 12.sp,
                                color = c.textSecondary,
                            )
                        }
                        IconButton(onClick = { onDeleteConversation(rec.id) }) {
                            Icon(Icons.Outlined.DeleteOutline, if (isEnglish) "Delete" else "حذف", tint = c.danger)
                        }
                    }
                }
            }
        }
    }
}

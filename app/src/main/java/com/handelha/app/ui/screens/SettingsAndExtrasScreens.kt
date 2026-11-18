package com.handelha.app.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Logout
import androidx.compose.material.icons.outlined.Alarm
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.NotificationsNone
import androidx.compose.material.icons.outlined.NotificationsOff
import androidx.compose.material.icons.outlined.PersonOutline
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.VerifiedUser
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Download
import androidx.compose.material.icons.rounded.FactCheck
import androidx.compose.material.icons.rounded.Insights
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.rounded.NightsStay
import androidx.compose.material.icons.rounded.PersonRemove
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Policy
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.School
import androidx.compose.material.icons.rounded.Snooze
import androidx.compose.material.icons.rounded.Translate
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.WorkspacePremium
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.material.icons.rounded.FormatQuote
import androidx.compose.ui.draw.shadow
import com.handelha.app.domain.ActiveAlarmRing
import com.handelha.app.domain.AlarmReminderItem
import com.handelha.app.domain.AlarmReminderState
import com.handelha.app.domain.AppUser
import com.handelha.app.domain.AssistantTone
import com.handelha.app.domain.NotificationPreferences
import com.handelha.app.domain.SubscriptionOffer
import com.handelha.app.domain.SubscriptionPlanTrack
import com.handelha.app.domain.SubscriptionState
import com.handelha.app.domain.TaskItem
import com.handelha.app.domain.UserEnergyPreferences
import com.handelha.app.domain.UserSubscriptionCategory
import com.handelha.app.ui.components.FeatureEmptyState
import com.handelha.app.ui.components.HandelhaBottomSheetFrame
import com.handelha.app.ui.components.HandelhaConfirmDialog
import com.handelha.app.ui.components.HandelhaHeader
import com.handelha.app.ui.components.HandelhaPrivacyPolicySheet
import com.handelha.app.ui.components.HandelhaSegmentOption
import com.handelha.app.ui.components.HandelhaSegmentedSwitch
import com.handelha.app.ui.theme.AppThemeMode
import com.handelha.app.ui.theme.HandelhaTheme
import com.handelha.app.util.ArabicFormatters
import kotlinx.coroutines.launch

@Composable
fun SettingsScreen(
    user: AppUser?,
    themeMode: AppThemeMode,
    isEnglish: Boolean,
    isStudentMode: Boolean,
    energyPrefs: UserEnergyPreferences,
    notifPrefs: NotificationPreferences,
    subscriptionState: SubscriptionState,
    onBack: () -> Unit,
    onOpenEnergyWizard: () -> Unit,
    onSetStudentMode: (Boolean) -> Unit,
    onOpenStudentQuotes: () -> Unit = {},
    onSetEnglish: (Boolean) -> Unit,
    onSetThemeMode: (AppThemeMode) -> Unit,
    onToggleNotifications: (Boolean) -> Unit,
    onSaveQuietHours: (Int, Int) -> Unit,
    onOpenSubscriptions: () -> Unit,
    onUpdateTone: (AssistantTone) -> Unit,
    onExportBackup: suspend () -> String?,
    onImportBackup: (String, (Boolean, String) -> Unit) -> Unit = { _, _ -> },
    onClearChatHistory: () -> Unit,
    onDeleteAccount: () -> Unit,
    onSignOut: () -> Unit,
    onShowToast: (String, Boolean) -> Unit,
) {
    BackHandler(onBack = onBack)

    val c = HandelhaTheme.colors
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var showAccountSheet by remember { mutableStateOf(false) }
    var showQuietHoursSheet by remember { mutableStateOf(false) }
    var showPrivacyHubSheet by remember { mutableStateOf(false) }
    var showPolicySheet by remember { mutableStateOf(false) }
    var showToneSheet by remember { mutableStateOf(false) }
    var showSignOutConfirm by remember { mutableStateOf(false) }
    var showDeleteAccountConfirm by remember { mutableStateOf(false) }
    var exportedJsonPreview by remember { mutableStateOf<String?>(null) }
    var showRestoreBackupSheet by remember { mutableStateOf(false) }

    val accountCategory = if (subscriptionState.isPro) subscriptionState.category
    else (user?.subscriptionCategory ?: UserSubscriptionCategory.free)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, end = 20.dp, bottom = 36.dp),
    ) {
        HandelhaHeader(
            title = if (isEnglish) "Settings" else "الإعدادات",
            isEnglish = isEnglish,
            showBack = true,
            onBack = onBack,
            padding = androidx.compose.foundation.layout.PaddingValues(top = 10.dp, bottom = 18.dp),
        )

        // Account Card
        val accountCardShape = RoundedCornerShape(22.dp)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .then(
                    if (!c.isDark) Modifier.shadow(6.dp, accountCardShape, ambientColor = Color.Black.copy(alpha = 0.05f))
                    else Modifier,
                )
                .clip(accountCardShape)
                .background(c.surface, accountCardShape)
                .border(1.dp, c.border, accountCardShape)
                .clickable(enabled = user != null) { showAccountSheet = true }
                .padding(18.dp)
                .testTag("settings_account_card"),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Outlined.VerifiedUser, null, tint = c.primary, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(10.dp))
                Text(
                    text = ArabicFormatters.trData(user?.displayName ?: user?.firstName ?: if (isEnglish) "Handelha User" else "مستخدم هندلها"),
                    fontSize = 18.5.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = c.textPrimary,
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(
                            when (accountCategory) {
                                UserSubscriptionCategory.student -> c.studentIndigoSoft
                                UserSubscriptionCategory.regularPro -> c.primarySoft
                                else -> c.surfaceSoft
                            },
                        )
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                ) {
                    Text(
                        text = accountCategory.shortBadge(isEnglish),
                        fontSize = 11.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = when (accountCategory) {
                            UserSubscriptionCategory.student -> c.studentIndigo
                            UserSubscriptionCategory.regularPro -> c.primary
                            else -> c.textSecondary
                        },
                    )
                }
            }
            Spacer(Modifier.height(6.dp))
            Text(
                text = if (isEnglish) "Account & Personal Data" else "إدارة الحساب والبيانات الشخصية",
                fontSize = 13.5.sp,
                color = c.textSecondary,
            )
        }

        Spacer(Modifier.height(16.dp))

        // Energy & Productivity Profile Card
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .then(
                    if (!c.isDark) Modifier.shadow(6.dp, accountCardShape, ambientColor = Color.Black.copy(alpha = 0.05f))
                    else Modifier,
                )
                .clip(accountCardShape)
                .background(c.surface, accountCardShape)
                .border(1.dp, c.border, accountCardShape)
                .clickable(onClick = onOpenEnergyWizard)
                .padding(16.dp)
                .testTag("settings_energy_card"),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier.size(42.dp).clip(RoundedCornerShape(13.dp)).background(c.primarySoft),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Rounded.Bolt, null, tint = c.primary, modifier = Modifier.size(22.dp))
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (isEnglish) "Energy Profile & Task Breakdown ⚡" else "بصمة طاقتك وتقسيم التاسكات والمشاريع ⚡",
                    fontSize = 14.5.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = c.textPrimary,
                )
                Spacer(Modifier.height(3.dp))
                Text(
                    text = if (isEnglish) "${energyPrefs.peakLabel(true)} • ${energyPrefs.preferredSessionMinutes}m blocks"
                    else "${energyPrefs.peakLabel(false)} • جلسات ${ArabicFormatters.toArabicDigits(energyPrefs.preferredSessionMinutes)} د",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = c.primary,
                )
            }
            Icon(
                imageVector = if (isEnglish) Icons.Rounded.ChevronRight else Icons.Rounded.ChevronLeft,
                contentDescription = null,
                tint = c.textSecondary,
            )
        }

        Spacer(Modifier.height(20.dp))

        // App Mode (Standard / Student)
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text(if (isEnglish) "App Mode" else "وضع التطبيق", fontSize = 15.5.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary, modifier = Modifier.weight(1f))
            if (isStudentMode) {
                Box(
                    modifier = Modifier.clip(RoundedCornerShape(999.dp)).background(Brush.linearGradient(listOf(c.studentIndigo, c.studentTeal))).padding(horizontal = 10.dp, vertical = 4.dp),
                ) {
                    Text(if (isEnglish) "Student" else "وضع الطالب", fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, color = Color.White)
                }
            }
        }
        Spacer(Modifier.height(4.dp))
        Text(
            text = if (isEnglish) "Student quotes widget, study moods, exam grades, and academic badges appear when Student Mode is active."
            else "ويدجت الـ Quotes والتشجيع بالمصري، مود المذاكرة، وتقديرات الامتحانات بتظهر لما تختار وضع الطالب.",
            fontSize = 12.5.sp,
            color = c.textSecondary,
        )
        Spacer(Modifier.height(10.dp))
        HandelhaSegmentedSwitch(
            options = listOf(
                HandelhaSegmentOption(false, if (isEnglish) "Standard" else "الوضع العادي", Icons.Outlined.PersonOutline, "settings_mode_standard"),
                HandelhaSegmentOption(true, if (isEnglish) "Student" else "وضع الطالب", Icons.Rounded.School, "settings_mode_student"),
            ),
            selected = isStudentMode,
            onChanged = onSetStudentMode,
        )

        if (isStudentMode) {
            Spacer(Modifier.height(12.dp))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(18.dp))
                    .background(c.studentIndigoSoft, RoundedCornerShape(18.dp))
                    .border(1.dp, c.studentIndigo.copy(alpha = 0.35f), RoundedCornerShape(18.dp))
                    .clickable(onClick = onOpenStudentQuotes)
                    .padding(14.dp)
                    .testTag("settings_student_quotes_card"),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier.size(38.dp).clip(RoundedCornerShape(12.dp)).background(c.studentIndigo),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Rounded.FormatQuote, null, tint = Color.White, modifier = Modifier.size(20.dp))
                }
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (isEnglish) "Your Desk — Wisdom & Books" else "مكتبك — حِكم وكتب وتشجيع",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = c.studentIndigo,
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = if (isEnglish) "72+ quotes from books, scientific studies & study motivation"
                        else "أكتر من ٧٢ اقتباسًا من الكتب والأبحاث العلمية وتشجيع المذاكرة",
                        fontSize = 11.5.sp,
                        color = c.textSecondary,
                    )
                }
                Icon(
                    imageVector = if (isEnglish) Icons.Rounded.ChevronRight else Icons.Rounded.ChevronLeft,
                    contentDescription = null,
                    tint = c.studentIndigo,
                )
            }
        }

        Spacer(Modifier.height(20.dp))

        // Language
        Text(if (isEnglish) "App & Assistant Language" else "لغة التطبيق والمساعد", fontSize = 15.5.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
        Spacer(Modifier.height(10.dp))
        HandelhaSegmentedSwitch(
            options = listOf(
                HandelhaSegmentOption(false, "عربي مصري", Icons.Rounded.Translate, "settings_lang_ar"),
                HandelhaSegmentOption(true, "English", Icons.Rounded.Language, "settings_lang_en"),
            ),
            selected = isEnglish,
            onChanged = onSetEnglish,
        )

        Spacer(Modifier.height(18.dp))

        // Theme 3-way pill (فاتح / داكن / تلقائي)
        Text(if (isEnglish) "Appearance" else "المظهر", fontSize = 15.5.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
        Spacer(Modifier.height(10.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(if (c.isDark) c.surfaceSoft else Color(0xFFE1E8E4))
                .padding(4.dp),
        ) {
            listOf(
                AppThemeMode.LIGHT to (if (isEnglish) "Light" else "فاتح"),
                AppThemeMode.DARK to (if (isEnglish) "Dark" else "داكن"),
                AppThemeMode.SYSTEM to (if (isEnglish) "Auto" else "تلقائي"),
            ).forEach { (m, lbl) ->
                val sel = themeMode == m
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(40.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (sel) c.surface else Color.Transparent)
                        .clickable { onSetThemeMode(m) }
                        .testTag("settings_theme_${m.storedValue}"),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(lbl, fontSize = 13.5.sp, fontWeight = if (sel) FontWeight.ExtraBold else FontWeight.Medium, color = if (sel) c.primary else c.textSecondary)
                }
            }
        }

        Spacer(Modifier.height(18.dp))

        // Notifications Card with Quiet Hours & Switch
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(22.dp))
                .background(c.surface, RoundedCornerShape(22.dp))
                .border(1.dp, c.border, RoundedCornerShape(22.dp))
                .padding(18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .clickable(enabled = user != null) { showQuietHoursSheet = true },
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Outlined.NotificationsNone, null, tint = c.primary, modifier = Modifier.size(21.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(if (isEnglish) "Remind me of what matters" else "فكّرني باللي يهمّني", fontSize = 15.5.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
                }
                Spacer(Modifier.height(4.dp))
                val startH = notifPrefs.quietHoursStartMinutes / 60
                val endH = notifPrefs.quietHoursEndMinutes / 60
                val startDisp = if (startH > 12) startH - 12 else startH
                Text(
                    text = if (isEnglish) "From $endH:00 AM to $startDisp:00 PM"
                    else "من ${ArabicFormatters.toArabicDigits(endH)} الصبح لـ ${ArabicFormatters.toArabicDigits(startDisp)} بالليل",
                    fontSize = 12.5.sp,
                    color = c.textSecondary,
                )
            }
            Spacer(Modifier.width(8.dp))
            Switch(
                checked = notifPrefs.enabled,
                onCheckedChange = onToggleNotifications,
                colors = SwitchDefaults.colors(checkedThumbColor = c.textOnPrimary, checkedTrackColor = c.primary),
                modifier = Modifier.testTag("settings_notif_switch"),
            )
        }

        Spacer(Modifier.height(12.dp))

        // Navigation / Action Tiles
        SettingsNavCard(
            icon = Icons.Rounded.WorkspacePremium,
            title = if (isEnglish) "Student & Pro Plans" else "باقات الطلاب و Pro",
            subtitle = if (subscriptionState.isPro) subscriptionState.resolvedPlanTitle(isEnglish)
            else if (isEnglish) "Student & Pro plans tailored to your pace" else "خطط مرنة تناسب دراستك أو شغلك",
            isEnglish = isEnglish,
            onClick = onOpenSubscriptions,
            testTag = "settings_subscriptions_tile",
        )
        Spacer(Modifier.height(10.dp))

        val toneLabel = when (user?.tone ?: AssistantTone.friendly) {
            AssistantTone.friendly -> if (isEnglish) "Friendly & Warm" else "ودود وقريب"
            AssistantTone.formal -> if (isEnglish) "Formal & Structured" else "رسمي ومرتب"
            AssistantTone.brief -> if (isEnglish) "Short & Direct" else "مختصر ومباشر"
            AssistantTone.custom -> if (isEnglish) "Custom" else "مخصص"
        }
        SettingsNavCard(
            icon = Icons.Rounded.AutoAwesome,
            title = if (isEnglish) "Assistant Tone" else "نبرة المساعد",
            subtitle = toneLabel,
            isEnglish = isEnglish,
            onClick = { showToneSheet = true },
            testTag = "settings_tone_tile",
        )
        Spacer(Modifier.height(10.dp))

        SettingsNavCard(
            icon = Icons.Outlined.Shield,
            title = if (isEnglish) "Privacy, Data & Backup" else "الخصوصية والبيانات والنسخ الاحتياطي",
            subtitle = if (isEnglish) "Policy, JSON backup, clear history & account deletion"
            else "سياسة الخصوصية، نسخة JSON، وحذف الحساب",
            isEnglish = isEnglish,
            onClick = { showPrivacyHubSheet = true },
            testTag = "settings_privacy_tile",
        )

        Spacer(Modifier.height(18.dp))

        OutlinedButton(
            onClick = { showSignOutConfirm = true },
            modifier = Modifier.fillMaxWidth().height(50.dp).testTag("settings_signout_button"),
            shape = RoundedCornerShape(16.dp),
        ) {
            Icon(Icons.AutoMirrored.Rounded.Logout, null, tint = c.danger, modifier = Modifier.size(19.dp))
            Spacer(Modifier.width(8.dp))
            Text(if (isEnglish) "Sign Out" else "تسجيل الخروج", color = c.danger, fontWeight = FontWeight.ExtraBold)
        }

        Spacer(Modifier.height(16.dp))
        Text(
            text = if (isEnglish) "Handelha v1.0 • Local-First Privacy" else "هندلها الإصدار ١.٠ • بياناتك محلية وآمنة",
            textAlign = TextAlign.Center,
            fontSize = 11.5.sp,
            color = c.textMuted,
            modifier = Modifier.fillMaxWidth(),
        )
    }

    // Account Sheet
    if (showAccountSheet && user != null) {
        HandelhaBottomSheetFrame(onDismiss = { showAccountSheet = false }) {
            Text(if (isEnglish) "Account & Personal Data" else "إدارة الحساب والبيانات الشخصية", fontSize = 17.5.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
            Spacer(Modifier.height(12.dp))
            Column(
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(c.surfaceSoft).border(1.dp, c.border, RoundedCornerShape(16.dp)).padding(14.dp),
            ) {
                Text(
                    text = if (isEnglish) {
                        "Name: ${ArabicFormatters.trData(user.displayName ?: user.firstName)}\nEmail: ${user.email ?: "—"}\nTier: ${accountCategory.label(true)}"
                    } else {
                        "الاسم: ${user.displayName ?: user.firstName}\nالبريد: ${user.email ?: "—"}\nالتصنيف: ${accountCategory.label(false)}"
                    },
                    fontSize = 13.5.sp,
                    color = c.textSecondary,
                    lineHeight = 22.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            Spacer(Modifier.height(12.dp))
            TextButton(
                onClick = { showAccountSheet = false; showDeleteAccountConfirm = true },
                modifier = Modifier.fillMaxWidth().testTag("account_sheet_delete_btn"),
            ) {
                Text(if (isEnglish) "Delete Account & All Data Permanently" else "حذف الحساب وكل بياناته نهائيًا", color = c.danger, fontWeight = FontWeight.Bold)
            }
        }
    }

    // Quiet Hours Sheet
    if (showQuietHoursSheet) {
        var startTotalMins by remember { mutableIntStateOf(notifPrefs.quietHoursStartMinutes) }
        var endTotalMins by remember { mutableIntStateOf(notifPrefs.quietHoursEndMinutes) }
        var pickingStartOrEnd by remember { mutableStateOf<String?>(null) } // "start" or "end"

        fun minsToTimeLabel(totalMins: Int): String {
            val h24 = (totalMins / 60).coerceIn(0, 23)
            val m = (totalMins % 60).coerceIn(0, 59)
            val isPm = h24 >= 12
            val h12 = when {
                h24 == 0 -> 12
                h24 > 12 -> h24 - 12
                else -> h24
            }
            val mm = m.toString().padStart(2, '0')
            val suffix = if (isEnglish) (if (isPm) "PM" else "AM") else (if (isPm) "م" else "ص")
            return if (isEnglish) "$h12:$mm $suffix"
            else "${ArabicFormatters.toArabicDigits(h12)}:${ArabicFormatters.toArabicDigits(mm)} $suffix"
        }

        HandelhaBottomSheetFrame(onDismiss = { showQuietHoursSheet = false }) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.NightsStay, null, tint = c.primary)
                Spacer(Modifier.width(8.dp))
                Text(if (isEnglish) "Quiet Hours" else "أوقات الهدوء والتذكير", fontSize = 17.5.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
            }
            Spacer(Modifier.height(6.dp))
            Text(
                text = if (isEnglish) "Tap either time to pick the exact hour & minute"
                else "اضغط على وقت البداية أو النهاية لاختيار الساعة والدقيقة بدقة",
                fontSize = 12.5.sp,
                color = c.textSecondary,
            )
            Spacer(Modifier.height(12.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .background(c.surfaceSoft)
                        .border(1.dp, c.border, RoundedCornerShape(14.dp))
                        .clickable { pickingStartOrEnd = "start" }
                        .padding(14.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(if (isEnglish) "Starts" else "تبدأ في", fontSize = 12.sp, color = c.textSecondary)
                    Spacer(Modifier.height(6.dp))
                    Text(minsToTimeLabel(startTotalMins), fontSize = 17.sp, fontWeight = FontWeight.ExtraBold, color = c.primary)
                }
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .background(c.surfaceSoft)
                        .border(1.dp, c.border, RoundedCornerShape(14.dp))
                        .clickable { pickingStartOrEnd = "end" }
                        .padding(14.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(if (isEnglish) "Ends" else "تنتهي في", fontSize = 12.sp, color = c.textSecondary)
                    Spacer(Modifier.height(6.dp))
                    Text(minsToTimeLabel(endTotalMins), fontSize = 17.sp, fontWeight = FontWeight.ExtraBold, color = c.primary)
                }
            }
            Spacer(Modifier.height(16.dp))
            Button(
                onClick = { onSaveQuietHours(startTotalMins, endTotalMins); showQuietHoursSheet = false },
                modifier = Modifier.fillMaxWidth().height(48.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = c.primary, contentColor = c.textOnPrimary),
            ) {
                Text(if (isEnglish) "Save Quiet Hours" else "حفظ ساعات الهدوء", fontWeight = FontWeight.Bold)
            }
        }

        if (pickingStartOrEnd != null) {
            val isStart = pickingStartOrEnd == "start"
            val currentMins = if (isStart) startTotalMins else endTotalMins
            val initialCal = java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.HOUR_OF_DAY, (currentMins / 60).coerceIn(0, 23))
                set(java.util.Calendar.MINUTE, (currentMins % 60).coerceIn(0, 59))
                set(java.util.Calendar.SECOND, 0)
            }
            com.handelha.app.ui.components.HandelhaDateTimePickerSheet(
                mode = com.handelha.app.ui.components.HandelhaPickerMode.TIME_ONLY,
                initialEpochMs = initialCal.timeInMillis,
                isEnglish = isEnglish,
                title = if (isStart) {
                    if (isEnglish) "Quiet Hours Start" else "بداية ساعات الهدوء"
                } else {
                    if (isEnglish) "Quiet Hours End" else "نهاية ساعات الهدوء"
                },
                onDismiss = { pickingStartOrEnd = null },
                onConfirm = { pickedMs ->
                    val pickedCal = java.util.Calendar.getInstance().apply { timeInMillis = pickedMs }
                    val pickedMins = pickedCal.get(java.util.Calendar.HOUR_OF_DAY) * 60 + pickedCal.get(java.util.Calendar.MINUTE)
                    if (isStart) startTotalMins = pickedMins else endTotalMins = pickedMins
                    pickingStartOrEnd = null
                },
            )
        }
    }

    // Tone Sheet
    if (showToneSheet) {
        val currentTone = user?.tone ?: AssistantTone.friendly
        HandelhaBottomSheetFrame(onDismiss = { showToneSheet = false }) {
            Text(if (isEnglish) "Assistant Tone" else "نبرة المساعد", fontSize = 17.5.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
            Spacer(Modifier.height(12.dp))
            listOf(
                AssistantTone.friendly to (if (isEnglish) "Friendly & Warm" else "ودود وقريب"),
                AssistantTone.formal to (if (isEnglish) "Formal & Structured" else "رسمي ومرتب"),
                AssistantTone.brief to (if (isEnglish) "Short & Direct" else "مختصر ومباشر"),
            ).forEach { (t, lbl) ->
                val sel = currentTone == t
                Row(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp).clip(RoundedCornerShape(14.dp))
                        .background(if (sel) c.primarySoft else c.surfaceSoft)
                        .clickable { onUpdateTone(t); showToneSheet = false }
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(lbl, fontSize = 14.5.sp, fontWeight = FontWeight.Bold, color = if (sel) c.primary else c.textPrimary, modifier = Modifier.weight(1f))
                    if (sel) Icon(Icons.Rounded.Check, null, tint = c.primary, modifier = Modifier.size(18.dp))
                }
            }
        }
    }

    // Privacy & Data Hub Sheet
    if (showPrivacyHubSheet) {
        HandelhaBottomSheetFrame(onDismiss = { showPrivacyHubSheet = false }) {
            Text(if (isEnglish) "Privacy & Data" else "الخصوصية والبيانات", fontSize = 17.5.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
            Spacer(Modifier.height(6.dp))
            Text(
                text = if (isEnglish) "All tasks, projects, focus sessions, and chats stay on your device. No tracking or external sharing."
                else "كل مهامك ومشروعاتك وجلساتك ومحادثاتك بتتخزن محليًا على جهازك فقط.",
                fontSize = 13.sp,
                color = c.textSecondary,
                lineHeight = 20.sp,
            )
            Spacer(Modifier.height(14.dp))
            OutlinedButton(
                onClick = { showPrivacyHubSheet = false; showPolicySheet = true },
                modifier = Modifier.fillMaxWidth().height(46.dp),
                shape = RoundedCornerShape(14.dp),
            ) {
                Icon(Icons.Rounded.Policy, null, tint = c.primary, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(if (isEnglish) "Read Privacy Policy & Terms" else "قراءة سياسة الخصوصية والشروط", fontWeight = FontWeight.Bold, color = c.primary)
            }
            Spacer(Modifier.height(8.dp))
            Button(
                onClick = {
                    scope.launch {
                        val json = onExportBackup()
                        showPrivacyHubSheet = false
                        if (json != null) exportedJsonPreview = json
                    }
                },
                modifier = Modifier.fillMaxWidth().height(46.dp).testTag("settings_export_backup_btn"),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = c.primary, contentColor = c.textOnPrimary),
            ) {
                Icon(Icons.Rounded.Download, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(if (isEnglish) "Export Backup (JSON)" else "تصدير نسخة احتياطية (JSON)", fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = {
                    showPrivacyHubSheet = false
                    showRestoreBackupSheet = true
                },
                modifier = Modifier.fillMaxWidth().height(46.dp).testTag("settings_restore_backup_btn"),
                shape = RoundedCornerShape(14.dp),
            ) {
                Icon(Icons.Rounded.FactCheck, null, tint = c.primary, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(if (isEnglish) "Restore Backup (JSON)" else "استعادة نسخة احتياطية (JSON)", fontWeight = FontWeight.Bold, color = c.primary)
            }
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = { showPrivacyHubSheet = false; onClearChatHistory() },
                modifier = Modifier.fillMaxWidth().height(46.dp),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text(if (isEnglish) "Clear Assistant Chat History" else "مسح سجل محادثات المساعد", color = c.danger, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(6.dp))
            TextButton(
                onClick = { showPrivacyHubSheet = false; showDeleteAccountConfirm = true },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(Icons.Rounded.PersonRemove, null, tint = c.danger, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(if (isEnglish) "Delete Account & All Data Permanently" else "حذف الحساب وكل بياناته نهائيًا", color = c.danger, fontWeight = FontWeight.Bold)
            }
        }
    }

    if (showRestoreBackupSheet) {
        var restoreDraft by remember { mutableStateOf("") }
        HandelhaBottomSheetFrame(onDismiss = { showRestoreBackupSheet = false }) {
            Text(
                text = if (isEnglish) "Restore Data Backup" else "استعادة نسخة احتياطية",
                fontSize = 17.5.sp,
                fontWeight = FontWeight.ExtraBold,
                color = c.textPrimary,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = if (isEnglish) "Paste your exported Handelha JSON backup below to restore your tasks and steps."
                else "الصق كود النسخة الاحتياطية (JSON) لاستعادة مهامك وخطواتك المحفوظة فورًا.",
                fontSize = 12.5.sp,
                color = c.textSecondary,
            )
            Spacer(Modifier.height(10.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                OutlinedButton(
                    onClick = {
                        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                        val clipText = cm?.primaryClip?.getItemAt(0)?.coerceToText(context)?.toString().orEmpty()
                        if (clipText.isNotBlank()) {
                            restoreDraft = clipText
                        } else {
                            onShowToast(if (isEnglish) "Clipboard is empty" else "الحافظة فارغة حاليًا", true)
                        }
                    },
                    shape = RoundedCornerShape(10.dp),
                ) {
                    Icon(Icons.Rounded.ContentCopy, null, modifier = Modifier.size(15.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(if (isEnglish) "Paste from Clipboard" else "لصق من الحافظة", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }
            }
            Spacer(Modifier.height(8.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(130.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(c.surfaceSoft)
                    .border(1.dp, c.border, RoundedCornerShape(14.dp))
                    .padding(12.dp),
            ) {
                if (restoreDraft.isEmpty()) {
                    Text(
                        text = "{\"schema\": 1, \"product\": \"handelha\", ...}",
                        fontSize = 12.sp,
                        color = c.textMuted,
                    )
                }
                BasicTextField(
                    value = restoreDraft,
                    onValueChange = { restoreDraft = it },
                    textStyle = androidx.compose.ui.text.TextStyle(
                        fontSize = 12.sp,
                        color = c.textPrimary,
                    ),
                    cursorBrush = androidx.compose.ui.graphics.SolidColor(c.primary),
                    modifier = Modifier.fillMaxSize().testTag("restore_backup_json_input"),
                )
            }
            Spacer(Modifier.height(14.dp))
            Button(
                onClick = {
                    val clean = restoreDraft.trim()
                    if (clean.isEmpty()) {
                        onShowToast(if (isEnglish) "Paste your backup JSON first" else "الصق كود النسخة الاحتياطية الأول", true)
                        return@Button
                    }
                    onImportBackup(clean) { ok, msg ->
                        if (ok) showRestoreBackupSheet = false
                        onShowToast(msg, !ok)
                    }
                },
                modifier = Modifier.fillMaxWidth().height(48.dp).testTag("restore_backup_confirm_btn"),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = c.primary, contentColor = c.textOnPrimary),
            ) {
                Icon(Icons.Rounded.Check, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(if (isEnglish) "Restore My Data Now" else "استعادة بياناتي الآن", fontWeight = FontWeight.ExtraBold)
            }
        }
    }

    if (showPolicySheet) {
        HandelhaPrivacyPolicySheet(isEnglish = isEnglish, onDismiss = { showPolicySheet = false })
    }

    if (exportedJsonPreview != null) {
        val rawJson = exportedJsonPreview!!
        Dialog(onDismissRequest = { exportedJsonPreview = null }) {
            Column(
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(c.surface, RoundedCornerShape(24.dp)).padding(18.dp),
            ) {
                Text(if (isEnglish) "JSON Backup Ready" else "النسخة الاحتياطية جاهزة", fontSize = 17.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
                Spacer(Modifier.height(8.dp))
                Box(
                    modifier = Modifier.fillMaxWidth().height(200.dp).clip(RoundedCornerShape(14.dp)).background(c.surfaceSoft).verticalScroll(rememberScrollState()).padding(12.dp),
                ) {
                    Text(rawJson.take(2400), fontSize = 11.5.sp, color = c.textSecondary)
                }
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = { exportedJsonPreview = null }, modifier = Modifier.weight(0.9f), shape = RoundedCornerShape(12.dp)) {
                        Text(if (isEnglish) "Close" else "إغلاق", fontSize = 12.sp)
                    }
                    OutlinedButton(
                        onClick = {
                            runCatching {
                                val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                    type = "text/plain"
                                    putExtra(Intent.EXTRA_SUBJECT, "Handelha Backup JSON")
                                    putExtra(Intent.EXTRA_TEXT, rawJson)
                                }
                                context.startActivity(Intent.createChooser(sendIntent, if (isEnglish) "Share Backup" else "مشاركة النسخة الاحتياطية"))
                            }
                        },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(12.dp),
                    ) {
                        Text(if (isEnglish) "Share" else "مشاركة", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                    Button(
                        onClick = {
                            val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                            cm?.setPrimaryClip(ClipData.newPlainText("Handelha Backup", rawJson))
                            exportedJsonPreview = null
                            onShowToast(if (isEnglish) "Backup copied to clipboard!" else "تم نسخ النسخة الاحتياطية!", false)
                        },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(12.dp),
                    ) {
                        Icon(Icons.Rounded.ContentCopy, null, modifier = Modifier.size(15.dp))
                        Spacer(Modifier.width(4.dp))
                        Text(if (isEnglish) "Copy" else "نسخ", fontSize = 12.sp)
                    }
                }
            }
        }
    }

    if (showSignOutConfirm) {
        HandelhaConfirmDialog(
            icon = Icons.AutoMirrored.Rounded.Logout,
            title = if (isEnglish) "Sign Out?" else "تسجيل الخروج؟",
            message = if (isEnglish) "You can sign back in anytime and your tasks will remain saved." else "تقدر ترجع تدخل تاني في أي وقت ومهامك هتفضل محفوظة.",
            confirmLabel = if (isEnglish) "Sign Out" else "تسجيل الخروج",
            cancelLabel = if (isEnglish) "Stay" else "خليك",
            onConfirm = { showSignOutConfirm = false; onSignOut() },
            onDismiss = { showSignOutConfirm = false },
        )
    }

    if (showDeleteAccountConfirm) {
        HandelhaConfirmDialog(
            icon = Icons.Rounded.PersonRemove,
            title = if (isEnglish) "Delete Account Permanently?" else "حذف الحساب نهائيًا؟",
            message = if (isEnglish) "All tasks, projects, focus sessions, conversations, and reminders linked to this account will be permanently erased from this device. This action cannot be undone."
            else "سيتم مسح جميع المهام والمشروعات والجلسات والمحادثات والتنبيهات المرتبطة بهذا الحساب نهائيًا من الجهاز ولا يمكن التراجع عن هذا الإجراء.",
            confirmLabel = if (isEnglish) "Delete Forever" else "حذف نهائي",
            cancelLabel = if (isEnglish) "Cancel" else "إلغاء",
            isDanger = true,
            onConfirm = { showDeleteAccountConfirm = false; onDeleteAccount() },
            onDismiss = { showDeleteAccountConfirm = false },
        )
    }
}

@Composable
private fun SettingsNavCard(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    subtitle: String,
    isEnglish: Boolean,
    onClick: () -> Unit,
    testTag: String,
) {
    val c = HandelhaTheme.colors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(c.surface, RoundedCornerShape(20.dp))
            .border(1.dp, c.border, RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .padding(16.dp)
            .testTag(testTag),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(modifier = Modifier.size(38.dp).clip(RoundedCornerShape(12.dp)).background(c.primarySoft), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = c.primary, modifier = Modifier.size(20.dp))
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 15.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
            Spacer(Modifier.height(2.dp))
            Text(subtitle, fontSize = 12.sp, color = c.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Icon(if (isEnglish) Icons.Rounded.ChevronRight else Icons.Rounded.ChevronLeft, null, tint = c.textSecondary)
    }
}

@Composable
fun NotificationsScreen(
    tasks: List<TaskItem>,
    alarmState: AlarmReminderState,
    notifPrefs: NotificationPreferences,
    readNotifIds: Set<String>,
    isEnglish: Boolean,
    onBack: () -> Unit,
    onMarkRead: (String) -> Unit,
    onMarkAllRead: (List<String>) -> Unit,
    onToggleAlarmEnabled: (String) -> Unit,
    onToggleAlarmMode: (String) -> Unit,
    onPreviewAlarm: (AlarmReminderItem) -> Unit,
    onDeleteAlarm: (String) -> Unit,
) {
    BackHandler(onBack = onBack)

    val c = HandelhaTheme.colors
    var filter by remember { mutableIntStateOf(0) } // 0 = all, 1 = unread

    val inboxItems = remember(tasks, readNotifIds, isEnglish) {
        val list = mutableListOf<Triple<String, String, Triple<String, String, Boolean>>>()
        val now = System.currentTimeMillis()
        tasks.filter { !it.isCompleted && !it.isCancelled && !it.isDeleted && it.dueAtMs != null }
            .sortedBy { it.dueAtMs }
            .take(5)
            .forEach { t ->
                val due = t.dueAtMs!!
                val mins = t.estimatedDurationMinutes ?: 25
                val overdue = due < now
                val clean = ArabicFormatters.trData(t.title)
                val title = if (overdue) (if (isEnglish) "Time for your next step" else "وقت خطوتك الجاية") else clean
                val body = if (overdue) {
                    if (isEnglish) "\"$clean\" is waiting for you. Give it ${ArabicFormatters.durationMinutesFull(mins)}?"
                    else "«${t.title}» مستنياك. نديها ${ArabicFormatters.durationMinutesFull(mins)}؟"
                } else {
                    if (isEnglish) "Scheduled for ${ArabicFormatters.timeOfDayAr(due)}" else "ميعادها ${ArabicFormatters.timeOfDayAr(due)}"
                }
                list += Triple(t.id, title, Triple(body, ArabicFormatters.timeOfDayAr(due), !readNotifIds.contains(t.id)))
            }
        val completedCount = tasks.count { it.isCompleted }
        if (completedCount > 0) {
            list += Triple(
                "notif-summary-completed",
                if (isEnglish) "Great job on what you finished" else "عاش على اللي خلّصته",
                Triple(
                    if (isEnglish) "$completedCount tasks completed." else "${ArabicFormatters.toArabicDigits(completedCount)} مهام خلصوا.",
                    if (isEnglish) "Today" else "اليوم",
                    !readNotifIds.contains("notif-summary-completed"),
                ),
            )
        }
        list
    }

    val shown = if (filter == 0) inboxItems else inboxItems.filter { it.third.third }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, end = 20.dp, bottom = 36.dp),
    ) {
        HandelhaHeader(
            title = if (isEnglish) "Notifications" else "الإشعارات",
            isEnglish = isEnglish,
            showBack = true,
            onBack = onBack,
            padding = androidx.compose.foundation.layout.PaddingValues(top = 10.dp, bottom = 14.dp),
            actions = {
                if (inboxItems.any { it.third.third }) {
                    TextButton(onClick = { onMarkAllRead(inboxItems.map { it.first }) }) {
                        Text(if (isEnglish) "Mark all read" else "قراءة الكل", fontSize = 12.5.sp, fontWeight = FontWeight.Bold, color = c.primary)
                    }
                }
            },
        )

        if (alarmState.items.isNotEmpty()) {
            Text(
                text = if (isEnglish) "Scheduled Alarms & Reminders" else "المنبهات والتذكيرات المجدولة",
                fontSize = 15.sp,
                fontWeight = FontWeight.ExtraBold,
                color = c.textPrimary,
            )
            Spacer(Modifier.height(10.dp))
            alarmState.items.forEach { alarm ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 10.dp)
                        .clip(RoundedCornerShape(18.dp))
                        .background(c.surface, RoundedCornerShape(18.dp))
                        .border(1.dp, c.border, RoundedCornerShape(18.dp))
                        .padding(14.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(38.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(c.primarySoft),
                            contentAlignment = Alignment.Center,
                        ) {
                            androidx.compose.foundation.Image(
                                painter = androidx.compose.ui.res.painterResource(id = com.handelha.app.R.drawable.logo),
                                contentDescription = null,
                                modifier = Modifier.size(26.dp),
                                contentScale = androidx.compose.ui.layout.ContentScale.Fit,
                            )
                        }
                        Spacer(Modifier.width(10.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(ArabicFormatters.trData(alarm.title), fontSize = 14.5.sp, fontWeight = FontWeight.Bold, color = c.textPrimary)
                            Text("${ArabicFormatters.dateShort(alarm.scheduledAtMs)} • ${ArabicFormatters.timeOfDayAr(alarm.scheduledAtMs)}", fontSize = 12.sp, color = c.primary)
                        }
                        Switch(checked = alarm.isEnabled, onCheckedChange = { onToggleAlarmEnabled(alarm.id) })
                    }
                    Spacer(Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        OutlinedButton(onClick = { onToggleAlarmMode(alarm.id) }, shape = RoundedCornerShape(10.dp)) {
                            Text(if (alarm.isFullAlarm) (if (isEnglish) "Alarm" else "منبه") else (if (isEnglish) "Quiet" else "هادئ"), fontSize = 11.5.sp)
                        }
                        IconButton(onClick = { onDeleteAlarm(alarm.id) }) {
                            Icon(Icons.Outlined.DeleteOutline, null, tint = c.danger)
                        }
                    }
                }
            }
        }

        if (!notifPrefs.enabled) {
            Column(
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(c.surface).border(1.dp, c.border, RoundedCornerShape(22.dp)).padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(Icons.Outlined.NotificationsOff, null, tint = c.textSecondary, modifier = Modifier.size(38.dp))
                Spacer(Modifier.height(10.dp))
                Text(if (isEnglish) "Notifications are paused in Settings" else "الإشعارات متوقفة مؤقتًا من الإعدادات", fontWeight = FontWeight.Bold, color = c.textPrimary)
            }
        } else {
            HandelhaSegmentedSwitch(
                options = listOf(
                    HandelhaSegmentOption(0, if (isEnglish) "All" else "الكل"),
                    HandelhaSegmentOption(1, if (isEnglish) "Unread" else "غير المقروءة"),
                ),
                selected = filter,
                onChanged = { filter = it },
            )
            Spacer(Modifier.height(14.dp))
            if (shown.isEmpty()) {
                FeatureEmptyState(
                    title = if (isEnglish) "All caught up!" else "كل الإشعارات رايقة",
                    subtitle = if (isEnglish) "Scheduled reminders and daily encouragements appear here." else "هتلاقي هنا تذكيرات مهامك والملخصات اليومية.",
                    primaryCtaLabel = if (isEnglish) "Back" else "رجوع",
                    onPrimaryCta = onBack,
                )
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    shown.forEach { (id, title, meta) ->
                        val (body, time, unread) = meta
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(18.dp))
                                .background(c.surface, RoundedCornerShape(18.dp))
                                .border(1.dp, if (unread) c.primary.copy(alpha = 0.4f) else c.border, RoundedCornerShape(18.dp))
                                .clickable { onMarkRead(id) }
                                .padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(modifier = Modifier.size(38.dp).clip(RoundedCornerShape(12.dp)).background(c.primarySoft), contentAlignment = Alignment.Center) {
                                androidx.compose.foundation.Image(
                                    painter = androidx.compose.ui.res.painterResource(id = com.handelha.app.R.drawable.logo),
                                    contentDescription = null,
                                    modifier = Modifier.size(26.dp),
                                    contentScale = androidx.compose.ui.layout.ContentScale.Fit,
                                )
                            }
                            Spacer(Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                                    Text(title, fontSize = 14.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary, modifier = Modifier.weight(1f))
                                    Text(time, fontSize = 11.sp, color = c.textMuted)
                                }
                                Spacer(Modifier.height(3.dp))
                                Text(body, fontSize = 12.5.sp, color = c.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun SubscriptionScreen(
    subscriptionState: SubscriptionState,
    isStudentMode: Boolean,
    isEnglish: Boolean,
    onBack: () -> Unit,
    onSelectPlan: (SubscriptionOffer) -> Unit,
    onCancelLocalPlan: () -> Unit,
    onToggleStudentMode: (Boolean) -> Unit,
) {
    BackHandler(onBack = onBack)

    val c = HandelhaTheme.colors
    var selectedTrack by remember(subscriptionState) {
        mutableStateOf(if (subscriptionState.isStudent || isStudentMode) SubscriptionPlanTrack.student else SubscriptionPlanTrack.pro)
    }
    var showPolicySheet by remember { mutableStateOf(false) }

    val trackOffers = subscriptionState.offers.filter { it.track == selectedTrack }
    val isStudentSelected = selectedTrack == SubscriptionPlanTrack.student

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, end = 20.dp, bottom = 36.dp),
    ) {
        HandelhaHeader(
            title = if (isEnglish) "Subscription Plans" else "خطط الاشتراك",
            subtitle = if (isEnglish) "Choose between Student Plans and Pro Plans" else "باقات مخصصة للطلاب وباقات Pro العادية فقط",
            isEnglish = isEnglish,
            showBack = true,
            onBack = onBack,
            padding = androidx.compose.foundation.layout.PaddingValues(top = 12.dp, bottom = 10.dp),
        )

        if (subscriptionState.isPro) {
            Column(
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(c.primarySoft).border(1.dp, c.primary, RoundedCornerShape(20.dp)).padding(16.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.CheckCircle, null, tint = c.primary)
                    Spacer(Modifier.width(8.dp))
                    Text(subscriptionState.resolvedPlanTitle(isEnglish), fontSize = 16.sp, fontWeight = FontWeight.ExtraBold, color = c.primary)
                }
                Spacer(Modifier.height(6.dp))
                Text(
                    text = if (isEnglish) "Active plan benefits unlocked." else "اشتراكك مفعّل وكل المميزات متاحة.",
                    fontSize = 13.sp,
                    color = c.textSecondary,
                )
                if (subscriptionState.isLocalActivation) {
                    Spacer(Modifier.height(8.dp))
                    OutlinedButton(onClick = onCancelLocalPlan, shape = RoundedCornerShape(12.dp)) {
                        Text(if (isEnglish) "Switch to Free Tier" else "الرجوع للحساب المجاني", fontWeight = FontWeight.Bold)
                    }
                }
            }
        } else {
            Box(
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(c.surface).border(1.dp, c.border, RoundedCornerShape(18.dp)).padding(14.dp),
            ) {
                Text(
                    text = if (isEnglish) "Current tier: Free Account — upgrade anytime for full planning power."
                    else "التصنيف الحالي: حساب مجاني — تقدر ترقّي في أي وقت.",
                    fontSize = 13.sp,
                    color = c.textSecondary,
                )
            }
        }

        Spacer(Modifier.height(14.dp))

        HandelhaSegmentedSwitch(
            options = listOf(
                HandelhaSegmentOption(SubscriptionPlanTrack.student, if (isEnglish) "Student Track" else "باقات الطلاب", Icons.Rounded.School),
                HandelhaSegmentOption(SubscriptionPlanTrack.pro, if (isEnglish) "Pro Track" else "باقات Pro", Icons.Rounded.WorkspacePremium),
            ),
            selected = selectedTrack,
            onChanged = { selectedTrack = it },
        )

        Spacer(Modifier.height(14.dp))

        // Hero Card
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(
                    if (isStudentSelected) Brush.linearGradient(listOf(c.studentIndigo, c.studentTeal))
                    else Brush.linearGradient(listOf(c.heroTeal, c.primary)),
                )
                .padding(18.dp),
        ) {
            Icon(
                imageVector = if (isStudentSelected) Icons.Rounded.School else Icons.Rounded.WorkspacePremium,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(30.dp),
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = if (isStudentSelected) {
                    if (isEnglish) "Handelha Student Edition" else "هندلها للطلاب"
                } else {
                    if (isEnglish) "Handelha Pro Productivity" else "هندلها Pro للإنتاجية"
                },
                fontSize = 20.sp,
                fontWeight = FontWeight.Black,
                color = Color.White,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = if (isStudentSelected) {
                    if (isEnglish) "Discounted academic plan with exam grades record, semester badges & study plans."
                    else "سعر مخفّض للطلاب + سجل تقديرات الامتحانات + أوسمة التفوق وتنظيم المذاكرة."
                } else {
                    if (isEnglish) "Full executive scheduling, project roadmaps, deep focus analytics & voice planning."
                    else "تنظيم شامل للمشروعات، تحليلات عميقة للتركيز، وسكرتير ذكي بسعة أكبر."
                },
                fontSize = 13.sp,
                color = Color.White.copy(alpha = 0.88f),
                lineHeight = 19.sp,
            )
        }

        Spacer(Modifier.height(16.dp))

        trackOffers.forEach { offer ->
            val isCurrent = subscriptionState.isPlanActive(offer.identifier)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 10.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(c.surface, RoundedCornerShape(20.dp))
                    .border(
                        width = if (isCurrent || offer.isAnnual) 1.5.dp else 1.dp,
                        color = if (isCurrent || offer.isAnnual) (if (isStudentSelected) c.studentIndigo else c.primary) else c.border,
                        shape = RoundedCornerShape(20.dp),
                    )
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(offer.title, fontSize = 16.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
                    Spacer(Modifier.height(2.dp))
                    Text(offer.description, fontSize = 12.sp, color = c.textSecondary)
                    Spacer(Modifier.height(6.dp))
                    Text("${offer.price} ${offer.periodLabel}", fontSize = 16.sp, fontWeight = FontWeight.Black, color = if (isStudentSelected) c.studentIndigo else c.primary)
                }
                Spacer(Modifier.width(10.dp))
                Button(
                    onClick = { onSelectPlan(offer) },
                    enabled = !isCurrent,
                    shape = RoundedCornerShape(14.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isStudentSelected) c.studentIndigo else c.ctaBackground,
                        contentColor = if (isStudentSelected) Color.White else c.ctaForeground,
                    ),
                ) {
                    Text(if (isCurrent) (if (isEnglish) "Active" else "مفعّلة") else (if (isEnglish) "Subscribe" else "اشتراك"), fontWeight = FontWeight.ExtraBold)
                }
            }
        }

        if (isStudentSelected) {
            Spacer(Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(c.surface).border(1.dp, c.border, RoundedCornerShape(18.dp)).padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Rounded.Tune, null, tint = c.studentIndigo)
                Spacer(Modifier.width(10.dp))
                Text(if (isEnglish) "Preview Student Mode UI" else "معاينة وضع الطالب حاليًا", fontSize = 13.5.sp, fontWeight = FontWeight.Bold, color = c.textPrimary, modifier = Modifier.weight(1f))
                Switch(checked = isStudentMode, onCheckedChange = onToggleStudentMode)
            }
        }

        Spacer(Modifier.height(14.dp))

        // Google Play Billing Disclosure Card (required for Play review)
        Column(
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(c.surfaceSoft).border(1.dp, c.border, RoundedCornerShape(18.dp)).padding(14.dp),
        ) {
            Text(
                text = if (isEnglish) "Billing & Auto-Renewal Terms" else "شروط الاشتراك والتجديد التلقائي عبر Google Play",
                fontSize = 13.sp,
                fontWeight = FontWeight.ExtraBold,
                color = c.textPrimary,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = if (isEnglish) "Subscriptions are billed via your Google Play account and renew automatically unless canceled at least 24 hours before the period ends in Google Play Subscriptions."
                else "تتم معالجة الاشتراكات عبر حسابك في Google Play، وتتجدد تلقائيًا ما لم يتم الإلغاء قبل ٢٤ ساعة من انتهاء الفترة من إعدادات اشتراكات Google Play.",
                fontSize = 11.5.sp,
                color = c.textSecondary,
                lineHeight = 18.sp,
            )
            TextButton(onClick = { showPolicySheet = true }) {
                Text(if (isEnglish) "Privacy Policy & Terms" else "سياسة الخصوصية وشروط الاستخدام", fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
        }
    }

    if (showPolicySheet) {
        HandelhaPrivacyPolicySheet(isEnglish = isEnglish, onDismiss = { showPolicySheet = false })
    }
}

@Composable
fun AlarmRingingDialog(
    ring: ActiveAlarmRing,
    isEnglish: Boolean,
    onDismiss: () -> Unit,
    onSnooze5: () -> Unit,
) {
    val c = HandelhaTheme.colors
    Dialog(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(28.dp))
                .background(c.surface, RoundedCornerShape(28.dp))
                .border(1.5.dp, c.primary, RoundedCornerShape(28.dp))
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier.size(64.dp).clip(CircleShape).background(c.primarySoft),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Outlined.Alarm, null, tint = c.primary, modifier = Modifier.size(34.dp))
            }
            Spacer(Modifier.height(14.dp))
            Text(if (isEnglish) "Handelha Reminder" else "منبه هندلها", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = c.primary)
            Spacer(Modifier.height(6.dp))
            Text(ArabicFormatters.trData(ring.title), fontSize = 20.sp, fontWeight = FontWeight.Black, color = c.textPrimary, textAlign = TextAlign.Center)
            Spacer(Modifier.height(20.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedButton(onClick = onSnooze5, modifier = Modifier.weight(1f).height(48.dp), shape = RoundedCornerShape(14.dp)) {
                    Icon(Icons.Rounded.Snooze, null, modifier = Modifier.size(17.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(if (isEnglish) "5m Snooze" else "غفوة ٥ د", fontWeight = FontWeight.Bold)
                }
                Button(
                    onClick = onDismiss,
                    modifier = Modifier.weight(1f).height(48.dp),
                    shape = RoundedCornerShape(14.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = c.ctaBackground, contentColor = c.ctaForeground),
                ) {
                    Text(if (isEnglish) "Got it" else "تم", fontWeight = FontWeight.ExtraBold)
                }
            }
        }
    }
}

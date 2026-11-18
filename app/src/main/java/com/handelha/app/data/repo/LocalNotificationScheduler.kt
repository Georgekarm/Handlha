package com.handelha.app.data.repo

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.handelha.app.MainActivity
import com.handelha.app.NativeAlarmScheduler
import com.handelha.app.R
import com.handelha.app.data.local.AppPreferencesStore
import com.handelha.app.domain.AlarmReminderItem
import com.handelha.app.domain.AlarmReminderState
import com.handelha.app.domain.NotificationPermissionStatus
import com.handelha.app.domain.NotificationPreferences
import com.handelha.app.domain.ReminderMessage
import com.handelha.app.domain.ReminderTone
import com.handelha.app.domain.ReminderUrgency
import com.handelha.app.domain.TaskItem
import java.util.Calendar
import java.util.concurrent.TimeUnit
import kotlin.math.abs
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

object ReminderMessageCatalog {
    private val dailySupportive = listOf(
        "خدها واحدة واحدة؛ مش لازم تخلّص الدنيا كلها النهارده.",
        "حتى لو أنجزت حتة صغيرة، دي خطوة حقيقية لقدّام.",
        "يومك مش سباق. اختار أهم حاجة وابدأ براحتك.",
        "لو دماغك زحمة، اكتب أول خطوة بس وسيب الباقي بعدين.",
        "الراحة جزء من الخطة، مش مكافأة لازم تستناها.",
        "إنت ماشي كويس، كمّل على قد طاقتك ومن غير جلد ذات.",
        "مش لازم تستنى المزاج المثالي؛ خمس دقايق بداية حلوة.",
        "لو الخطة اتلخبطت، عادي. نرتبها تاني خطوة خطوة.",
    )
    private val dailyDirect = listOf(
        "يلا نختار حاجة واحدة ونبدأ فيها دلوقتي.",
        "افتح المهمة وخد أول خطوة؛ الباقي هيبان بعدها.",
        "خمس دقايق تركيز أحسن من تأجيلها لآخر اليوم.",
        "رتّب أولوياتك بسرعة وابدأ بالأهم.",
        "بلاش تسيب المهمة معلّقة؛ يا تبدأها يا تحدد لها معاد.",
        "جاهز تخلّص خطوة صغيرة وتريح دماغك؟",
        "اختار مهمة واحدة، اقفل المشتتات، وابدأ.",
        "النهارده لسه فيه وقت؛ استغله في حاجة واحدة مفيدة.",
    )
    private val overdueSupportive = listOf(
        "المعاد فات، بس عادي. خد نفس وقرّر: نبدأ فيها ولا نعيد جدولتها؟",
        "اتأخرت شوية؟ ولا يهمك. ظبّط المعاد على قد يومك وكمّل.",
        "مش محتاج تلوم نفسك؛ اختار أصغر خطوة أو أجّلها بوضوح.",
        "لسه تقدر تلحقها. ابدأ حتة بسيطة، أو غيّر معادها من غير ضغط.",
    )
    private val overdueDirect = listOf(
        "المهمة اتأخرت. يلا نخلّص منها خطوة، أو نحدد لها معاد جديد.",
        "ما تسيبهاش معلّقة: ابدأ فيها دلوقتي أو أعد جدولتها.",
        "المعاد عدى؛ خد قرار واضح للمهمة دي وريح دماغك.",
        "يلا نبصّ لها: محتاجة تنفيذ دلوقتي ولا معاد أنسب؟",
    )
    private val todaySupportive = listOf(
        "دي على جدول النهارده. ابدأ بخمس دقايق بس وشوف هتوصل لفين.",
        "لو عندك طاقة، ابدأ فيها دلوقتي. ولو لأ، ظبّط وقتها براحتك.",
        "خطوة صغيرة في المهمة دي كفاية كبداية حلوة.",
        "افتكر المهمة دي وسط يومك، وخليها على قد وقتك وطاقتك.",
    )
    private val todayDirect = listOf(
        "يلا نخلّصها النهارده. ابدأ دلوقتي أو اختار لها ساعة واضحة.",
        "المهمة دي مستنياك النهارده؛ افتحها وخد أول خطوة.",
        "ما تأجلهاش من غير خطة. ابدأ أو غيّر معادها دلوقتي.",
        "خصص لها وقت النهارده وخلّصها من دماغك.",
    )
    private val upcomingSupportive = listOf(
        "المهمة لسه قدامها وقت؛ مش لازم تشيل همّها دلوقتي.",
        "سجلناها لمعادها. ركّز في اللي عليك النهارده وسيب دي لوقتها.",
        "لسه بدري عليها؛ لما يقرب معادها هنفكّرك بيها هنا.",
        "خليها في بالك من غير استعجال، لسه عندك وقت ترتّبها.",
    )
    private val upcomingDirect = listOf(
        "المهمة جاية قريب. بصّ على معادها وخطّط لها من دلوقتي.",
        "لسه فيه وقت، بس حدّد هتشتغل عليها إمتى.",
        "راجع تجهيزات المهمة قبل معادها عشان ما تتزنقش.",
        "المعاد قرب؛ حضّر أول خطوة بدل ما تسيبها لآخر لحظة.",
    )

    fun dailyMessage(nowMs: Long, tone: ReminderTone): String {
        val pool = if (tone == ReminderTone.supportive) dailySupportive else dailyDirect
        val days = TimeUnit.MILLISECONDS.toDays(nowMs).toInt().coerceAtLeast(0)
        return pool[days % pool.size]
    }

    fun forTask(task: TaskItem, nowMs: Long, tone: ReminderTone): ReminderMessage {
        val dueMs = task.dueAtMs ?: nowMs
        val dayStart = Calendar.getInstance().apply {
            timeInMillis = nowMs
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val dueCal = Calendar.getInstance().apply { timeInMillis = dueMs }
        val isDateOnly = dueCal.get(Calendar.HOUR_OF_DAY) == 0 &&
            dueCal.get(Calendar.MINUTE) == 0 &&
            dueCal.get(Calendar.SECOND) == 0
        val dueDayStart = (dueCal.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        val isOverdue = dueDayStart < dayStart || (!isDateOnly && dueMs < nowMs)
        val urgency = when {
            isOverdue -> ReminderUrgency.overdue
            dueDayStart == dayStart -> ReminderUrgency.today
            else -> ReminderUrgency.upcoming
        }
        val pool = when (urgency to tone) {
            ReminderUrgency.overdue to ReminderTone.supportive -> overdueSupportive
            ReminderUrgency.overdue to ReminderTone.direct -> overdueDirect
            ReminderUrgency.today to ReminderTone.supportive -> todaySupportive
            ReminderUrgency.today to ReminderTone.direct -> todayDirect
            ReminderUrgency.upcoming to ReminderTone.supportive -> upcomingSupportive
            else -> upcomingDirect
        }
        val dayNum = TimeUnit.MILLISECONDS.toDays(nowMs).toInt().coerceAtLeast(0)
        val stableHash = abs(task.id.hashCode())
        val index = (dayNum + stableHash) % pool.size
        val title = when (urgency) {
            ReminderUrgency.overdue -> "المعاد عدى — لسه نقدر نتصرف"
            ReminderUrgency.today -> "مهمة ليك النهارده"
            ReminderUrgency.upcoming -> "تذكير جاي في وقته"
        }
        return ReminderMessage(urgency = urgency, title = title, body = pool[index])
    }
}

class LocalNotificationScheduler(
    context: Context,
    private val prefs: AppPreferencesStore,
) {
    private val appContext = context.applicationContext
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    companion object {
        const val QUIET_CHANNEL_ID = "handelha_task_reminders"
        const val ACTION_QUIET_TRIGGER = "com.handelha.app.ACTION_QUIET_REMINDER"
    }

    fun checkPermissions(): NotificationPermissionStatus {
        val notifGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                appContext,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        return NotificationPermissionStatus(
            notificationsGranted = notifGranted,
            exactAlarmsGranted = NativeAlarmScheduler.canScheduleExactAlarms(appContext),
            overlayGranted = NativeAlarmScheduler.canDrawOverlays(appContext),
            fullScreenIntentGranted = NativeAlarmScheduler.canUseFullScreenIntent(appContext),
        )
    }

    suspend fun loadNotificationPreferences(userId: String): NotificationPreferences {
        val raw = prefs.snapshot()[prefs.userNotifPrefsKey(userId)] ?: return NotificationPreferences()
        return runCatching { json.decodeFromString<NotificationPreferences>(raw) }
            .getOrDefault(NotificationPreferences())
    }

    suspend fun saveNotificationPreferences(userId: String, value: NotificationPreferences) {
        prefs.update { ed -> ed[prefs.userNotifPrefsKey(userId)] = json.encodeToString(value) }
    }

    suspend fun loadReadIds(userId: String): Set<String> =
        prefs.snapshot()[prefs.userNotifReadIdsKey(userId)] ?: emptySet()

    suspend fun markAsRead(userId: String, id: String) {
        prefs.update { ed ->
            val current = ed[prefs.userNotifReadIdsKey(userId)] ?: emptySet()
            ed[prefs.userNotifReadIdsKey(userId)] = current + id
        }
    }

    suspend fun markAllAsRead(userId: String, ids: Iterable<String>) {
        prefs.update { ed ->
            val current = ed[prefs.userNotifReadIdsKey(userId)] ?: emptySet()
            ed[prefs.userNotifReadIdsKey(userId)] = current + ids
        }
    }

    suspend fun loadAlarmReminderState(userId: String): AlarmReminderState {
        val snap = prefs.snapshot()
        val perms = checkPermissions()
        val defaultMode = snap[prefs.userAlarmDefaultModeKey(userId)] ?: "alarm"
        val itemsRaw = snap[prefs.userAlarmsKey(userId)]
        val items = if (!itemsRaw.isNullOrBlank()) {
            runCatching { json.decodeFromString<List<AlarmReminderItem>>(itemsRaw) }
                .getOrDefault(emptyList())
                .sortedBy { it.scheduledAtMs }
        } else {
            emptyList()
        }
        val modesRaw = snap[prefs.userTaskAlertModesKey(userId)]
        val taskModes = if (!modesRaw.isNullOrBlank()) {
            runCatching { json.decodeFromString<Map<String, String>>(modesRaw) }
                .getOrDefault(emptyMap())
        } else {
            emptyMap()
        }
        return AlarmReminderState(
            permissionGranted = perms.notificationsGranted,
            exactAlarmGranted = perms.exactAlarmsGranted,
            defaultAlertMode = defaultMode,
            items = items,
            taskAlertModes = taskModes,
        )
    }

    suspend fun saveAlarmReminderState(userId: String, state: AlarmReminderState) {
        prefs.update { ed ->
            ed[prefs.userAlarmDefaultModeKey(userId)] = state.defaultAlertMode
            ed[prefs.userAlarmsKey(userId)] = json.encodeToString(state.items)
            ed[prefs.userTaskAlertModesKey(userId)] = json.encodeToString(state.taskAlertModes)
        }
    }

    suspend fun scheduleReminderItem(
        id: String,
        title: String,
        scheduledAtMs: Long,
        alertMode: String,
        taskId: String?,
        userId: String,
    ) {
        val isAlarm = alertMode == "alarm"
        val preferences = loadNotificationPreferences(userId)
        if (!isAlarm && !preferences.enabled) {
            cancelById(id)
            return
        }

        val now = System.currentTimeMillis()
        val resolvedMs = if (isAlarm) scheduledAtMs else moveOutOfQuietHours(scheduledAtMs, preferences)
        if (resolvedMs <= now + 500L) {
            cancelById(id)
            return
        }

        if (isAlarm) {
            NativeAlarmScheduler.scheduleAlarm(
                context = appContext,
                id = id,
                title = title,
                triggerAtMs = resolvedMs,
                alertMode = "alarm",
                taskId = taskId,
            )
            return
        }

        // Quiet notification via NotificationManager immediate/scheduled fallback
        NativeAlarmScheduler.cancelAlarm(appContext, id)
        scheduleQuietAlarmBroadcast(id, title, resolvedMs)
    }

    suspend fun scheduleTask(task: TaskItem, alertModeOverride: String? = null, userModes: Map<String, String> = emptyMap()) {
        val rawDateMs = task.dueAtMs ?: task.scheduledStartAtMs
        if (rawDateMs == null || task.isCompleted || task.isCancelled || task.isDeleted) {
            cancelById(task.id)
            return
        }
        val cal = Calendar.getInstance().apply { timeInMillis = rawDateMs }
        if (cal.get(Calendar.HOUR_OF_DAY) == 0 && cal.get(Calendar.MINUTE) == 0 && cal.get(Calendar.SECOND) == 0) {
            cal.set(Calendar.HOUR_OF_DAY, 9)
        }
        val mode = alertModeOverride ?: userModes[task.id] ?: "notification"
        scheduleReminderItem(
            id = task.id,
            title = task.title,
            scheduledAtMs = cal.timeInMillis,
            alertMode = mode,
            taskId = task.id,
            userId = task.userId,
        )
    }

    fun cancelById(id: String) {
        NativeAlarmScheduler.cancelAlarm(appContext, id)
        val nm = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        nm?.cancel(NativeAlarmScheduler.stableRequestCode(id))
    }

    fun cancelAll() {
        NativeAlarmScheduler.cancelAllAlarms(appContext)
        val nm = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        nm?.cancelAll()
    }

    fun postQuietNotificationNow(
        id: String,
        title: String,
        body: String,
        badgeText: String = "خطوتك الجاية",
        isEnglish: Boolean = false,
    ) {
        val nm = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        com.handelha.app.AlarmReceiver.ensureQuietChannel(nm)

        val reqCode = NativeAlarmScheduler.stableRequestCode(id)
        val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        val launchIntent = Intent(appContext, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(NativeAlarmScheduler.EXTRA_ALARM_ID, id)
            putExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE, title)
        }
        val contentPi = PendingIntent.getActivity(appContext, reqCode + 1, launchIntent, piFlags)

        val snoozeIntent = Intent(appContext, com.handelha.app.AlarmReceiver::class.java).apply {
            action = com.handelha.app.AlarmReceiver.ACTION_SNOOZE_NOTIF
            putExtra(NativeAlarmScheduler.EXTRA_ALARM_ID, id)
            putExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE, title)
            putExtra(com.handelha.app.AlarmReceiver.EXTRA_ALERT_MODE, "notification")
        }
        val snoozePi = PendingIntent.getBroadcast(appContext, reqCode + 4, snoozeIntent, piFlags)

        val dismissIntent = Intent(appContext, com.handelha.app.AlarmReceiver::class.java).apply {
            action = com.handelha.app.AlarmReceiver.ACTION_DISMISS_NOTIF
            putExtra(NativeAlarmScheduler.EXTRA_ALARM_ID, id)
            putExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE, title)
            putExtra(com.handelha.app.AlarmReceiver.EXTRA_ALERT_MODE, "notification")
        }
        val dismissPi = PendingIntent.getBroadcast(appContext, reqCode + 3, dismissIntent, piFlags)

        val notif = com.handelha.app.AlarmReceiver.buildThemedNotification(
            context = appContext,
            channelId = com.handelha.app.AlarmReceiver.QUIET_CHANNEL_ID,
            id = id,
            taskTitle = title,
            subtitleText = body,
            badgeText = badgeText,
            brandHeaderText = if (isEnglish) "Handelha • Your Companion" else "هندلها • رفيق يومك",
            primaryButtonText = if (isEnglish) "Start Focus" else "ابدأ جلسة تركيز",
            snoozeButtonText = if (isEnglish) "Snooze 10m" else "تأجيل ١٠ د",
            dismissButtonText = if (isEnglish) "Done ✓" else "خلصتها ✓",
            contentPendingIntent = contentPi,
            snoozePendingIntent = snoozePi,
            dismissPendingIntent = dismissPi,
            isFullAlarm = false,
        )
        nm.notify(reqCode, notif)
    }

    fun postFocusTimerNotification(
        taskTitle: String,
        remainingSeconds: Int,
        isBreakMode: Boolean,
        isEnglish: Boolean,
    ) {
        val nm = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        com.handelha.app.AlarmReceiver.ensureFocusChannel(nm)

        val mins = (remainingSeconds / 60).coerceAtLeast(0)
        val secs = (remainingSeconds % 60).coerceAtLeast(0)
        val formattedTime = String.format(java.util.Locale.US, "%02d:%02d", mins, secs)
        val badgeText = if (isEnglish) {
            if (isBreakMode) "Break • $formattedTime" else "Focus • $formattedTime"
        } else {
            val arTime = com.handelha.app.util.ArabicFormatters.toArabicDigits(formattedTime)
            if (isBreakMode) "استراحة • $arTime" else "تركيز • $arTime"
        }

        val subtitle = if (isEnglish) {
            if (isBreakMode) "Take a calm breath before your next focus block."
            else "Stay with this single step — your focus tree is growing."
        } else {
            if (isBreakMode) "خد نفس هادي وريّح دماغك شوية قبل الجولة الجاية."
            else "ركّز في خطوتك الحالية بهدوء — شجرتك بتكبر مع كل دقيقة."
        }

        val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val launchIntent = Intent(appContext, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val contentPi = PendingIntent.getActivity(appContext, 9910, launchIntent, piFlags)

        val notif = com.handelha.app.AlarmReceiver.buildThemedNotification(
            context = appContext,
            channelId = com.handelha.app.AlarmReceiver.FOCUS_CHANNEL_ID,
            id = "focus_live_session",
            taskTitle = taskTitle.ifBlank { if (isEnglish) "Calm Focus Session" else "جلسة تركيز هادئة" },
            subtitleText = subtitle,
            badgeText = badgeText,
            brandHeaderText = if (isEnglish) "Handelha • Focus Session" else "هندلها • جلسة تركيز نشطة",
            primaryButtonText = if (isEnglish) "Return to Timer" else "العودة للمؤقت",
            snoozeButtonText = badgeText,
            dismissButtonText = if (isEnglish) "Open" else "فتح",
            contentPendingIntent = contentPi,
            snoozePendingIntent = contentPi,
            dismissPendingIntent = contentPi,
            isFullAlarm = false,
        )
        nm.notify(9910, notif)
    }

    fun cancelFocusTimerNotification() {
        val nm = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        nm?.cancel(9910)
    }

    private fun scheduleQuietAlarmBroadcast(id: String, title: String, triggerAtMs: Long) {
        val am = appContext.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val encouragingSubtitle = ReminderMessageCatalog.dailyMessage(
            nowMs = triggerAtMs + abs(id.hashCode()) * 86_400_000L,
            tone = ReminderTone.supportive,
        )
        val intent = Intent(appContext, com.handelha.app.AlarmReceiver::class.java).apply {
            action = com.handelha.app.AlarmReceiver.ACTION_QUIET_REMINDER
            data = Uri.parse("handelha://quiet/$id")
            putExtra(NativeAlarmScheduler.EXTRA_ALARM_ID, id)
            putExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE, title)
            putExtra(com.handelha.app.AlarmReceiver.EXTRA_ALERT_MODE, "notification")
            putExtra(com.handelha.app.AlarmReceiver.EXTRA_SUBTITLE, encouragingSubtitle)
            putExtra(com.handelha.app.AlarmReceiver.EXTRA_BADGE, "خطوتك الجاية")
        }
        val reqCode = NativeAlarmScheduler.stableRequestCode("q_$id")
        val pi = PendingIntent.getBroadcast(
            appContext,
            reqCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        try {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
        } catch (_: Exception) {
        }
    }

    private fun moveOutOfQuietHours(timeMs: Long, prefs: NotificationPreferences): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = timeMs }
        val start = prefs.quietHoursStartMinutes
        val end = prefs.quietHoursEndMinutes
        val minute = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        val overnight = start > end
        val quiet = if (overnight) (minute >= start || minute < end) else (start < end && minute in start until end)
        if (!quiet) return timeMs

        if (!(overnight && minute < end)) {
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        cal.set(Calendar.HOUR_OF_DAY, end / 60)
        cal.set(Calendar.MINUTE, end % 60)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }
}

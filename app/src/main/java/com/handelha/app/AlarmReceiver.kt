package com.handelha.app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import com.handelha.app.data.repo.ReminderMessageCatalog
import com.handelha.app.domain.ReminderTone
import kotlinx.coroutines.launch
import kotlin.math.abs

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ALARM_CHANNEL_ID = "handelha_native_alarms_v2"
        const val QUIET_CHANNEL_ID = "handelha_task_reminders_v2"
        const val ACTION_DISMISS_NOTIF = "com.handelha.app.ACTION_DISMISS_ALARM_NOTIF"
        const val ACTION_SNOOZE_NOTIF = "com.handelha.app.ACTION_SNOOZE_ALARM_NOTIF"
        const val ACTION_QUIET_REMINDER = "com.handelha.app.ACTION_QUIET_REMINDER"
        const val EXTRA_ALERT_MODE = "handelha_alert_mode"
        const val EXTRA_SUBTITLE = "handelha_notif_subtitle"
        const val EXTRA_BADGE = "handelha_notif_badge"

        fun buildThemedNotification(
            context: Context,
            channelId: String,
            id: String,
            taskTitle: String,
            subtitleText: String,
            badgeText: String,
            brandHeaderText: String,
            primaryButtonText: String,
            snoozeButtonText: String,
            dismissButtonText: String,
            contentPendingIntent: PendingIntent,
            snoozePendingIntent: PendingIntent,
            dismissPendingIntent: PendingIntent,
            isFullAlarm: Boolean,
            fullScreenPendingIntent: PendingIntent? = null,
        ): Notification {
            val pkg = context.packageName

            val collapsedView = RemoteViews(pkg, R.layout.notification_handelha_collapsed).apply {
                setTextViewText(R.id.notif_brand_label, brandHeaderText)
                setTextViewText(R.id.notif_pill_badge, badgeText)
                setTextViewText(R.id.notif_task_title, taskTitle)
                setTextViewText(R.id.notif_task_subtitle, subtitleText)
            }

            val expandedView = RemoteViews(pkg, R.layout.notification_handelha_expanded).apply {
                setTextViewText(R.id.notif_brand_label, brandHeaderText)
                setTextViewText(R.id.notif_pill_badge, badgeText)
                setTextViewText(R.id.notif_task_title, taskTitle)
                setTextViewText(R.id.notif_task_subtitle, subtitleText)
                setTextViewText(R.id.notif_btn_primary, primaryButtonText)
                setTextViewText(R.id.notif_btn_snooze, snoozeButtonText)
                setTextViewText(R.id.notif_btn_dismiss, dismissButtonText)
                setOnClickPendingIntent(R.id.notif_btn_primary, contentPendingIntent)
                setOnClickPendingIntent(R.id.notif_btn_snooze, snoozePendingIntent)
                setOnClickPendingIntent(R.id.notif_btn_dismiss, dismissPendingIntent)
            }

            val largeLogo = runCatching {
                BitmapFactory.decodeResource(context.resources, R.drawable.logo)
            }.getOrNull()

            val builder = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setLargeIcon(largeLogo)
                .setColor(0xFF0E3B33.toInt())
                .setColorized(true)
                .setContentTitle(taskTitle)
                .setContentText(subtitleText)
                .setSubText(badgeText)
                .setCustomContentView(collapsedView)
                .setCustomBigContentView(expandedView)
                .setPriority(if (isFullAlarm) NotificationCompat.PRIORITY_MAX else NotificationCompat.PRIORITY_HIGH)
                .setCategory(if (isFullAlarm) NotificationCompat.CATEGORY_ALARM else NotificationCompat.CATEGORY_REMINDER)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setContentIntent(contentPendingIntent)
                .setOngoing(isFullAlarm)
                .setAutoCancel(!isFullAlarm)

            if (isFullAlarm && fullScreenPendingIntent != null) {
                builder.setSilent(true)
                builder.setFullScreenIntent(fullScreenPendingIntent, true)
                builder.setCustomHeadsUpContentView(expandedView)
            } else {
                builder.setCustomHeadsUpContentView(expandedView)
            }

            val notification = builder.build()
            if (isFullAlarm) {
                notification.flags = notification.flags or Notification.FLAG_INSISTENT
            }
            return notification
        }

        fun ensureQuietChannel(nm: NotificationManager) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    QUIET_CHANNEL_ID,
                    "تذكيرات هندلها",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "إشعارات هندلها الهادئة لتذكيرات المهام والمواعيد"
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    enableVibration(true)
                }
                nm.createNotificationChannel(channel)
            }
        }

        fun ensureAlarmChannel(nm: NotificationManager) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    ALARM_CHANNEL_ID,
                    "منبه هندلها",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "شاشة المنبه الخارجي لتنبيهات المهام والمواعيد المهمة"
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    setSound(null, null)
                    enableVibration(false)
                    setBypassDnd(true)
                }
                nm.createNotificationChannel(channel)
            }
        }

        const val FOCUS_CHANNEL_ID = "handelha_focus_live_v1"

        fun ensureFocusChannel(nm: NotificationManager) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    FOCUS_CHANNEL_ID,
                    "مؤقت التركيز الحي",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "يعرض الوقت المتبقي في جلسة التركيز الحالية بهدوء"
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    setSound(null, null)
                    enableVibration(false)
                }
                nm.createNotificationChannel(channel)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val id = intent.getStringExtra(NativeAlarmScheduler.EXTRA_ALARM_ID)
            ?: "alarm_${System.currentTimeMillis()}"
        val title = intent.getStringExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE)
            ?.takeIf { it.isNotBlank() }
            ?: "تذكير مهمة"
        val taskId = intent.getStringExtra(NativeAlarmScheduler.EXTRA_TASK_ID)
        val alertMode = intent.getStringExtra(EXTRA_ALERT_MODE) ?: "alarm"
        val reqCode = NativeAlarmScheduler.stableRequestCode(id)
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

        if (action == ACTION_DISMISS_NOTIF) {
            AlarmAudioController.stop(context)
            nm?.cancel(reqCode)
            if (id.isNotBlank()) {
                NativeAlarmScheduler.cancelAlarm(context, id)
                NativeAlarmStore.enqueuePendingAction(
                    context = context,
                    action = "dismiss",
                    id = id,
                    title = title,
                    taskId = taskId,
                )
                val resolvedTaskId = taskId?.takeIf { it.isNotBlank() } ?: id
                val pendingResult = goAsync()
                kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.IO).launch {
                    try {
                        val db = com.handelha.app.data.local.HandelhaDatabase.getInstance(context.applicationContext)
                        val prefs = com.handelha.app.data.local.AppPreferencesStore(context.applicationContext)
                        val repo = com.handelha.app.data.repo.WorkspaceRepository(db, prefs)
                        repo.completeTask(resolvedTaskId)
                    } catch (_: Exception) {
                    } finally {
                        pendingResult.finish()
                    }
                }
            }
            return
        }

        if (action == ACTION_SNOOZE_NOTIF) {
            AlarmAudioController.stop(context)
            nm?.cancel(reqCode)
            val snoozeAtMs = System.currentTimeMillis() + 10 * 60_000L
            if (alertMode == "alarm") {
                NativeAlarmScheduler.scheduleAlarm(
                    context = context,
                    id = id,
                    title = title,
                    triggerAtMs = snoozeAtMs,
                    alertMode = "alarm",
                    taskId = taskId,
                )
            } else {
                val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                val snoozeIntent = Intent(context, AlarmReceiver::class.java).apply {
                    this.action = ACTION_QUIET_REMINDER
                    data = Uri.parse("handelha://quiet/$id")
                    putExtra(NativeAlarmScheduler.EXTRA_ALARM_ID, id)
                    putExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE, title)
                    putExtra(EXTRA_ALERT_MODE, "notification")
                    if (!taskId.isNullOrBlank()) putExtra(NativeAlarmScheduler.EXTRA_TASK_ID, taskId)
                }
                val pi = PendingIntent.getBroadcast(
                    context,
                    NativeAlarmScheduler.stableRequestCode("q_$id"),
                    snoozeIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                if (pi != null) {
                    runCatching { am?.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, snoozeAtMs, pi) }
                }
            }
            return
        }

        val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        val dismissIntent = Intent(context, AlarmReceiver::class.java).apply {
            this.action = ACTION_DISMISS_NOTIF
            putExtra(NativeAlarmScheduler.EXTRA_ALARM_ID, id)
            putExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE, title)
            putExtra(EXTRA_ALERT_MODE, alertMode)
            if (!taskId.isNullOrBlank()) putExtra(NativeAlarmScheduler.EXTRA_TASK_ID, taskId)
        }
        val dismissPi = PendingIntent.getBroadcast(context, reqCode + 3, dismissIntent, piFlags)

        val snoozeIntent = Intent(context, AlarmReceiver::class.java).apply {
            this.action = ACTION_SNOOZE_NOTIF
            putExtra(NativeAlarmScheduler.EXTRA_ALARM_ID, id)
            putExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE, title)
            putExtra(EXTRA_ALERT_MODE, alertMode)
            if (!taskId.isNullOrBlank()) putExtra(NativeAlarmScheduler.EXTRA_TASK_ID, taskId)
        }
        val snoozePi = PendingIntent.getBroadcast(context, reqCode + 4, snoozeIntent, piFlags)

        // Quiet Notification branch (non-ringing themed card notification)
        if (action == ACTION_QUIET_REMINDER || alertMode == "notification") {
            if (nm != null) {
                ensureQuietChannel(nm)
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra(NativeAlarmScheduler.EXTRA_ALARM_ID, id)
                    putExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE, title)
                    if (!taskId.isNullOrBlank()) putExtra(NativeAlarmScheduler.EXTRA_TASK_ID, taskId)
                }
                val contentPi = PendingIntent.getActivity(context, reqCode + 1, launchIntent, piFlags)
                val customSubtitle = intent.getStringExtra(EXTRA_SUBTITLE)?.takeIf { it.isNotBlank() }
                    ?: ReminderMessageCatalog.dailyMessage(
                        nowMs = System.currentTimeMillis() + abs(id.hashCode()) * 86_400_000L,
                        tone = ReminderTone.supportive,
                    )
                val badge = intent.getStringExtra(EXTRA_BADGE)?.takeIf { it.isNotBlank() } ?: "خطوتك الجاية"

                val notif = buildThemedNotification(
                    context = context,
                    channelId = QUIET_CHANNEL_ID,
                    id = id,
                    taskTitle = title,
                    subtitleText = customSubtitle,
                    badgeText = badge,
                    brandHeaderText = "هندلها • رفيق يومك",
                    primaryButtonText = "ابدأ جلسة تركيز",
                    snoozeButtonText = "تأجيل ١٠ د",
                    dismissButtonText = "خلصتها ✓",
                    contentPendingIntent = contentPi,
                    snoozePendingIntent = snoozePi,
                    dismissPendingIntent = dismissPi,
                    isFullAlarm = false,
                )
                nm.notify(reqCode, notif)
            }
            return
        }

        // Full Alarm branch
        val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = try {
            pm?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "handelha:AlarmWakeLock",
            )?.apply { acquire(10_000L) }
        } catch (_: Exception) {
            null
        }

        try {
            NativeAlarmStore.removeAlarm(context, id)
            AlarmAudioController.start(context)

            val fullScreenIntent = NativeAlarmScheduler.buildAlarmActivityIntent(
                context = context,
                id = id,
                title = title,
                taskId = taskId,
                isPreview = false,
            )
            val fullScreenPi = PendingIntent.getActivity(context, reqCode + 2, fullScreenIntent, piFlags)

            if (nm != null) {
                ensureAlarmChannel(nm)
                val encouragingLine = ReminderMessageCatalog.dailyMessage(
                    nowMs = System.currentTimeMillis() + abs(id.hashCode()) * 86_400_000L,
                    tone = ReminderTone.supportive,
                )
                val notification = buildThemedNotification(
                    context = context,
                    channelId = ALARM_CHANNEL_ID,
                    id = id,
                    taskTitle = title,
                    subtitleText = encouragingLine,
                    badgeText = "ميعاد المهمة الآن",
                    brandHeaderText = "منبه هندلها • خطوة بخطوة",
                    primaryButtonText = "فتح المنبه والبدء",
                    snoozeButtonText = "غفوة ١٠ د",
                    dismissButtonText = "إيقاف",
                    contentPendingIntent = fullScreenPi,
                    snoozePendingIntent = snoozePi,
                    dismissPendingIntent = dismissPi,
                    isFullAlarm = true,
                    fullScreenPendingIntent = fullScreenPi,
                )
                nm.notify(reqCode, notification)
            }

            try {
                context.startActivity(fullScreenIntent)
            } catch (_: Exception) {
            }
        } finally {
            try {
                if (wakeLock?.isHeld == true) {
                    wakeLock.release()
                }
            } catch (_: Exception) {
            }
        }
    }
}

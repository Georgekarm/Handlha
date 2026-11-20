package com.handelha.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val ALARM_CHANNEL_ID = "handelha_native_alarms_v1"
        private const val ACTION_DISMISS_NOTIF = "com.handelha.app.ACTION_DISMISS_ALARM_NOTIF"
        private const val ACTION_SNOOZE_NOTIF = "com.handelha.app.ACTION_SNOOZE_ALARM_NOTIF"
        private const val SNOOZE_MS = 10 * 60 * 1000L
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_DISMISS_NOTIF) {
            val id = intent.getStringExtra(NativeAlarmScheduler.EXTRA_ALARM_ID) ?: ""
            val title = intent.getStringExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE) ?: ""
            val taskId = intent.getStringExtra(NativeAlarmScheduler.EXTRA_TASK_ID)
            AlarmAudioController.stop(context)
            if (id.isNotBlank()) {
                NativeAlarmScheduler.cancelAlarm(context, id)
                NativeAlarmStore.enqueuePendingAction(
                    context = context,
                    action = "dismiss",
                    id = id,
                    title = title,
                    taskId = taskId,
                )
            }
            return
        }

        if (intent.action == ACTION_SNOOZE_NOTIF) {
            val id = intent.getStringExtra(NativeAlarmScheduler.EXTRA_ALARM_ID) ?: ""
            val title = intent.getStringExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE) ?: ""
            val taskId = intent.getStringExtra(NativeAlarmScheduler.EXTRA_TASK_ID)
            val isEn = intent.getBooleanExtra(NativeAlarmScheduler.EXTRA_IS_EN, false)
            AlarmAudioController.stop(context)
            if (id.isNotBlank()) {
                val snoozeAtMs = System.currentTimeMillis() + SNOOZE_MS
                NativeAlarmScheduler.cancelAlarm(context, id)
                NativeAlarmScheduler.scheduleAlarm(
                    context = context,
                    id = id,
                    title = title,
                    triggerAtMs = snoozeAtMs,
                    alertMode = "alarm",
                    taskId = taskId,
                    isEn = isEn,
                    saveRecord = true,
                )
                NativeAlarmStore.enqueuePendingAction(
                    context = context,
                    action = "snooze",
                    id = id,
                    title = title,
                    taskId = taskId,
                    snoozeAtMs = snoozeAtMs,
                )
            }
            return
        }

        val id = intent.getStringExtra(NativeAlarmScheduler.EXTRA_ALARM_ID)
            ?: "alarm_${System.currentTimeMillis()}"
        val isEn = intent.getBooleanExtra(NativeAlarmScheduler.EXTRA_IS_EN, false)
        val title = intent.getStringExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE)
            ?.takeIf { it.isNotBlank() }
            ?: if (isEn) "Task Reminder" else "تذكير مهمة"
        val taskId = intent.getStringExtra(NativeAlarmScheduler.EXTRA_TASK_ID)

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
            // Remove single-shot scheduled alarm entry once triggered
            NativeAlarmStore.removeAlarm(context, id)

            // Begin crisp alarm audio & vibration via USAGE_ALARM immediately
            AlarmAudioController.start(context)

            // Prepare full-screen external alarm activity intent
            val fullScreenIntent = NativeAlarmScheduler.buildAlarmActivityIntent(
                context = context,
                id = id,
                title = title,
                taskId = taskId,
                isEn = isEn,
                isPreview = false,
            )

            val reqCode = NativeAlarmScheduler.stableRequestCode(id)
            val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val fullScreenPi = PendingIntent.getActivity(
                context,
                reqCode + 2,
                fullScreenIntent,
                piFlags,
            )

            val dismissIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_DISMISS_NOTIF
                putExtra(NativeAlarmScheduler.EXTRA_ALARM_ID, id)
                putExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE, title)
                putExtra(NativeAlarmScheduler.EXTRA_IS_EN, isEn)
                if (!taskId.isNullOrBlank()) putExtra(NativeAlarmScheduler.EXTRA_TASK_ID, taskId)
            }
            val dismissPi = PendingIntent.getBroadcast(
                context,
                reqCode + 3,
                dismissIntent,
                piFlags,
            )

            val snoozeIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_SNOOZE_NOTIF
                putExtra(NativeAlarmScheduler.EXTRA_ALARM_ID, id)
                putExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE, title)
                putExtra(NativeAlarmScheduler.EXTRA_IS_EN, isEn)
                if (!taskId.isNullOrBlank()) putExtra(NativeAlarmScheduler.EXTRA_TASK_ID, taskId)
            }
            val snoozePi = PendingIntent.getBroadcast(
                context,
                reqCode + 4,
                snoozeIntent,
                piFlags,
            )

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            if (nm != null) {
                ensureChannel(nm, isEn)
                val builder = NotificationCompat.Builder(context, ALARM_CHANNEL_ID)
                    .setSmallIcon(R.drawable.ic_stat_handelha)
                    .setContentTitle(if (isEn) "Handelha Alarm" else "منبه هندلها")
                    .setContentText(title)
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                    .setOngoing(true)
                    .setAutoCancel(false)
                    .setSilent(true) // Audio played directly by AlarmAudioController on USAGE_ALARM
                    .setContentIntent(fullScreenPi)
                    .addAction(0, if (isEn) "Snooze 10m" else "غفوة ١٠ د", snoozePi)
                    .addAction(0, if (isEn) "Dismiss" else "إيقاف", dismissPi)
                if (NativeAlarmScheduler.canUseFullScreenIntent(context)) {
                    builder.setFullScreenIntent(fullScreenPi, true)
                }
                val notification = builder.build()
                notification.flags = notification.flags or Notification.FLAG_INSISTENT
                nm.notify(reqCode, notification)
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

    private fun ensureChannel(nm: NotificationManager, isEn: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                ALARM_CHANNEL_ID,
                if (isEn) "Handelha Alarm" else "منبه هندلها",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = if (isEn) {
                    "High-priority ringing alarms for tasks and exams"
                } else {
                    "شاشة المنبه الخارجي لتنبيهات المهام والمواعيد المهمة"
                }
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                setSound(null, null)
                enableVibration(false)
                setBypassDnd(true)
            }
            nm.createNotificationChannel(channel)
        }
    }
}

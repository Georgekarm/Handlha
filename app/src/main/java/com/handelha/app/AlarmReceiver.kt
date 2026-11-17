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

        val id = intent.getStringExtra(NativeAlarmScheduler.EXTRA_ALARM_ID)
            ?: "alarm_${System.currentTimeMillis()}"
        val title = intent.getStringExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE)
            ?.takeIf { it.isNotBlank() }
            ?: "تذكير مهمة"
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
            NativeAlarmStore.removeAlarm(context, id)
            AlarmAudioController.start(context)

            val fullScreenIntent = NativeAlarmScheduler.buildAlarmActivityIntent(
                context = context,
                id = id,
                title = title,
                taskId = taskId,
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
                if (!taskId.isNullOrBlank()) putExtra(NativeAlarmScheduler.EXTRA_TASK_ID, taskId)
            }
            val dismissPi = PendingIntent.getBroadcast(
                context,
                reqCode + 3,
                dismissIntent,
                piFlags,
            )

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            if (nm != null) {
                ensureChannel(nm)
                val notification = NotificationCompat.Builder(context, ALARM_CHANNEL_ID)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle("منبه هندلها")
                    .setContentText(title)
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setOngoing(true)
                    .setAutoCancel(false)
                    .setSilent(true)
                    .setFullScreenIntent(fullScreenPi, true)
                    .setContentIntent(fullScreenPi)
                    .addAction(0, "إيقاف", dismissPi)
                    .build()
                notification.flags = notification.flags or Notification.FLAG_INSISTENT
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

    private fun ensureChannel(nm: NotificationManager) {
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
}

package com.handelha.app

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import kotlin.math.abs

object NativeAlarmScheduler {
    const val EXTRA_ALARM_ID = "handelha_alarm_id"
    const val EXTRA_ALARM_TITLE = "handelha_alarm_title"
    const val EXTRA_TASK_ID = "handelha_task_id"
    const val EXTRA_IS_EN = "handelha_is_en"
    const val EXTRA_IS_PREVIEW = "handelha_is_preview"

    fun stableRequestCode(id: String): Int {
        val raw = abs(id.hashCode()) % 1_000_000_000
        return 100_000 + raw
    }

    fun canScheduleExactAlarms(context: Context): Boolean {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                am.canScheduleExactAlarms()
            } catch (_: Exception) {
                false
            }
        } else {
            true
        }
    }

    fun canDrawOverlays(@Suppress("UNUSED_PARAMETER") context: Context): Boolean {
        // Overlay permission (SYSTEM_ALERT_WINDOW) is intentionally omitted for Google Play compliance.
        return true
    }

    fun canUseFullScreenIntent(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            return nm?.canUseFullScreenIntent() ?: false
        }
        return true
    }

    fun openOverlayPermissionSettings(@Suppress("UNUSED_PARAMETER") context: Context) {
        // No-op: SYSTEM_ALERT_WINDOW is removed to comply with Google Play policy.
    }

    fun openExactAlarmSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (canScheduleExactAlarms(context)) return
            try {
                val intent = Intent(
                    Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                    Uri.parse("package:${context.packageName}"),
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                return
            } catch (_: Exception) {
            }
        }
        try {
            val fallback = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:${context.packageName}"),
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(fallback)
        } catch (_: Exception) {
        }
    }

    fun scheduleAlarm(
        context: Context,
        id: String,
        title: String,
        triggerAtMs: Long,
        alertMode: String,
        taskId: String?,
        isEn: Boolean = false,
        saveRecord: Boolean = true,
    ) {
        val appContext = context.applicationContext
        if (alertMode != "alarm") {
            cancelAlarm(appContext, id)
            return
        }

        val cal = java.util.Calendar.getInstance().apply {
            timeInMillis = triggerAtMs
        }
        if (saveRecord) {
            NativeAlarmStore.upsertAlarm(
                appContext,
                NativeAlarmRecord(
                    id = id,
                    title = title,
                    scheduledAtMs = triggerAtMs,
                    alertMode = "alarm",
                    taskId = taskId,
                    hour = cal.get(java.util.Calendar.HOUR_OF_DAY),
                    minute = cal.get(java.util.Calendar.MINUTE),
                    isEn = isEn,
                ),
            )
        }

        val now = System.currentTimeMillis()
        if (triggerAtMs <= now + 500L) {
            return
        }

        val am = appContext.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val reqCode = stableRequestCode(id)

        val receiverIntent = Intent(appContext, AlarmReceiver::class.java).apply {
            action = "com.handelha.app.ACTION_TRIGGER_ALARM"
            data = Uri.parse("handelha://alarm/$id")
            putExtra(EXTRA_ALARM_ID, id)
            putExtra(EXTRA_ALARM_TITLE, title)
            putExtra(EXTRA_IS_EN, isEn)
            if (!taskId.isNullOrBlank()) {
                putExtra(EXTRA_TASK_ID, taskId)
            }
        }

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = PendingIntent.getBroadcast(appContext, reqCode, receiverIntent, flags)

        val showAppIntent = Intent(appContext, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val showPendingIntent = PendingIntent.getActivity(appContext, reqCode + 1, showAppIntent, flags)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && canScheduleExactAlarms(appContext)) {
                am.setAlarmClock(
                    AlarmManager.AlarmClockInfo(triggerAtMs, showPendingIntent),
                    pendingIntent,
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
            }
        } catch (_: SecurityException) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
                } else {
                    am.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
                }
            } catch (_: Exception) {
            }
        }
    }

    fun cancelAlarm(context: Context, id: String) {
        val appContext = context.applicationContext
        NativeAlarmStore.removeAlarm(appContext, id)
        val reqCode = stableRequestCode(id)

        val am = appContext.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        val receiverIntent = Intent(appContext, AlarmReceiver::class.java).apply {
            action = "com.handelha.app.ACTION_TRIGGER_ALARM"
            data = Uri.parse("handelha://alarm/$id")
        }
        val flags = PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        val existing = PendingIntent.getBroadcast(appContext, reqCode, receiverIntent, flags)
        if (existing != null) {
            am?.cancel(existing)
            existing.cancel()
        }

        val nm = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        nm?.cancel(reqCode)
    }

    fun cancelAllAlarms(context: Context) {
        val appContext = context.applicationContext
        for (item in NativeAlarmStore.getAlarms(appContext)) {
            cancelAlarm(appContext, item.id)
        }
        NativeAlarmStore.clearAllAlarms(appContext)
    }

    fun buildAlarmActivityIntent(
        context: Context,
        id: String,
        title: String,
        taskId: String?,
        isEn: Boolean = false,
        isPreview: Boolean = false,
    ): Intent {
        return Intent(context, AlarmActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_NO_USER_ACTION,
            )
            putExtra(EXTRA_ALARM_ID, id)
            putExtra(EXTRA_ALARM_TITLE, title)
            if (!taskId.isNullOrBlank()) {
                putExtra(EXTRA_TASK_ID, taskId)
            }
            putExtra(EXTRA_IS_EN, isEn)
            putExtra(EXTRA_IS_PREVIEW, isPreview)
        }
    }

    fun launchAlarmActivityNow(
        context: Context,
        id: String,
        title: String,
        taskId: String?,
        isEn: Boolean = false,
        isPreview: Boolean = false,
    ): Boolean {
        val intent = buildAlarmActivityIntent(
            context = context,
            id = id,
            title = title,
            taskId = taskId,
            isEn = isEn,
            isPreview = isPreview,
        )
        if (context is android.app.Activity) {
            intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return try {
            context.startActivity(intent)
            true
        } catch (_: Throwable) {
            false
        }
    }
}

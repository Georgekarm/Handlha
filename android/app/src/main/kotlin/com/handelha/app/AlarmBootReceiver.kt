package com.handelha.app

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.Calendar

class AlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val relevant = action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == Intent.ACTION_TIME_CHANGED ||
            action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON"

        if (!relevant) return

        val now = System.currentTimeMillis()
        val stored = NativeAlarmStore.getAlarms(context)
        for (item in stored) {
            if (item.alertMode != "alarm") continue
            var targetMs = item.scheduledAtMs
            if (action == Intent.ACTION_TIMEZONE_CHANGED &&
                item.hour in 0..23 &&
                item.minute in 0..59
            ) {
                val cal = Calendar.getInstance().apply {
                    timeInMillis = item.scheduledAtMs
                    set(Calendar.HOUR_OF_DAY, item.hour)
                    set(Calendar.MINUTE, item.minute)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                targetMs = cal.timeInMillis
            }
            if (targetMs > now + 1_000L) {
                NativeAlarmScheduler.scheduleAlarm(
                    context = context,
                    id = item.id,
                    title = item.title,
                    triggerAtMs = targetMs,
                    alertMode = item.alertMode,
                    taskId = item.taskId,
                    isEn = item.isEn,
                    saveRecord = targetMs != item.scheduledAtMs,
                )
            }
        }
    }
}

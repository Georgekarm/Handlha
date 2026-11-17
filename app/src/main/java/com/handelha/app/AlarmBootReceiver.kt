package com.handelha.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val relevant = action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == Intent.ACTION_TIME_CHANGED ||
            action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON"

        if (!relevant) return

        val now = System.currentTimeMillis()
        val stored = NativeAlarmStore.getAlarms(context)
        for (item in stored) {
            if (item.alertMode == "alarm" && item.scheduledAtMs > now + 1_000L) {
                NativeAlarmScheduler.scheduleAlarm(
                    context = context,
                    id = item.id,
                    title = item.title,
                    triggerAtMs = item.scheduledAtMs,
                    alertMode = item.alertMode,
                    taskId = item.taskId,
                    saveRecord = false,
                )
            }
        }
    }
}

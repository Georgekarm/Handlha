package com.handelha.app.domain

import kotlinx.serialization.Serializable

@Serializable
enum class ReminderTone { supportive, direct }

enum class ReminderUrgency { overdue, today, upcoming }

@Serializable
data class NotificationPreferences(
    val enabled: Boolean = true,
    val tone: ReminderTone = ReminderTone.supportive,
    val quietHoursStartMinutes: Int = 22 * 60,
    val quietHoursEndMinutes: Int = 8 * 60,
)

data class ReminderMessage(
    val urgency: ReminderUrgency,
    val title: String,
    val body: String,
)

@Serializable
data class AlarmReminderItem(
    val id: String,
    val title: String,
    val scheduledAtMs: Long,
    val alertMode: String = "alarm", // "alarm" | "notification"
    val isEnabled: Boolean = true,
    val taskId: String? = null,
) {
    val isFullAlarm: Boolean get() = alertMode == "alarm"
}

data class AlarmReminderState(
    val permissionGranted: Boolean = false,
    val exactAlarmGranted: Boolean = false,
    val defaultAlertMode: String = "alarm",
    val items: List<AlarmReminderItem> = emptyList(),
    val taskAlertModes: Map<String, String> = emptyMap(),
) {
    fun alertModeForTask(taskId: String, fallback: String = "notification"): String =
        taskAlertModes[taskId] ?: fallback
}

data class ActiveAlarmRing(
    val id: String,
    val title: String,
    val taskId: String? = null,
    val isPreview: Boolean = false,
)

data class NotificationPermissionStatus(
    val notificationsGranted: Boolean,
    val exactAlarmsGranted: Boolean,
    val overlayGranted: Boolean,
    val fullScreenIntentGranted: Boolean,
)

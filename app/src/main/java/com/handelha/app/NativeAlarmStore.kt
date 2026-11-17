package com.handelha.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class NativeAlarmRecord(
    val id: String,
    val title: String,
    val scheduledAtMs: Long,
    val alertMode: String,
    val taskId: String?,
)

data class PendingAlarmAction(
    val action: String,
    val id: String,
    val title: String,
    val taskId: String?,
    val snoozeAtMs: Long,
)

object NativeAlarmStore {
    private const val PREFS_NAME = "handelha_native_alarms"
    private const val KEY_ALARMS = "scheduled_items_json"
    private const val KEY_ACTIONS = "pending_actions_json"

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    @Synchronized
    fun upsertAlarm(context: Context, record: NativeAlarmRecord) {
        val current = getAlarms(context).filter { it.id != record.id }.toMutableList()
        if (record.alertMode == "alarm") {
            current.add(record)
        }
        saveAlarms(context, current)
    }

    @Synchronized
    fun removeAlarm(context: Context, id: String) {
        val current = getAlarms(context).filter { it.id != id }
        saveAlarms(context, current)
    }

    @Synchronized
    fun clearAllAlarms(context: Context) {
        prefs(context).edit().remove(KEY_ALARMS).apply()
    }

    @Synchronized
    fun getAlarms(context: Context): List<NativeAlarmRecord> {
        val raw = prefs(context).getString(KEY_ALARMS, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            val list = ArrayList<NativeAlarmRecord>(arr.length())
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                val id = obj.optString("id", "")
                if (id.isBlank()) continue
                list.add(
                    NativeAlarmRecord(
                        id = id,
                        title = obj.optString("title", ""),
                        scheduledAtMs = obj.optLong("scheduledAtMs", 0L),
                        alertMode = obj.optString("alertMode", "alarm"),
                        taskId = obj.optString("taskId", "").ifBlank { null },
                    ),
                )
            }
            list
        } catch (_: Exception) {
            emptyList()
        }
    }

    @Synchronized
    private fun saveAlarms(context: Context, items: List<NativeAlarmRecord>) {
        val arr = JSONArray()
        for (item in items) {
            arr.put(
                JSONObject().apply {
                    put("id", item.id)
                    put("title", item.title)
                    put("scheduledAtMs", item.scheduledAtMs)
                    put("alertMode", item.alertMode)
                    if (!item.taskId.isNullOrBlank()) {
                        put("taskId", item.taskId)
                    }
                },
            )
        }
        prefs(context).edit().putString(KEY_ALARMS, arr.toString()).apply()
    }

    @Synchronized
    fun enqueuePendingAction(
        context: Context,
        action: String,
        id: String,
        title: String,
        taskId: String?,
        snoozeAtMs: Long = 0L,
    ) {
        val raw = prefs(context).getString(KEY_ACTIONS, null)
        val arr = try {
            if (raw.isNullOrBlank()) JSONArray() else JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
        arr.put(
            JSONObject().apply {
                put("action", action)
                put("id", id)
                put("title", title)
                if (!taskId.isNullOrBlank()) put("taskId", taskId)
                put("snoozeAtMs", snoozeAtMs)
                put("ts", System.currentTimeMillis())
            },
        )
        prefs(context).edit().putString(KEY_ACTIONS, arr.toString()).apply()
    }

    @Synchronized
    fun drainPendingActions(context: Context): List<PendingAlarmAction> {
        val p = prefs(context)
        val raw = p.getString(KEY_ACTIONS, null) ?: return emptyList()
        p.edit().remove(KEY_ACTIONS).apply()
        return try {
            val arr = JSONArray(raw)
            val list = ArrayList<PendingAlarmAction>(arr.length())
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                list.add(
                    PendingAlarmAction(
                        action = obj.optString("action", "dismiss"),
                        id = obj.optString("id", ""),
                        title = obj.optString("title", ""),
                        taskId = obj.optString("taskId", "").ifBlank { null },
                        snoozeAtMs = obj.optLong("snoozeAtMs", 0L),
                    ),
                )
            }
            list
        } catch (_: Exception) {
            emptyList()
        }
    }
}

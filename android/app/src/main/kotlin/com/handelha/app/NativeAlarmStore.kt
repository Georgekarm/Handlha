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
    val hour: Int = -1,
    val minute: Int = -1,
    val isEn: Boolean = false,
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
        prefs(context).edit().remove(KEY_ALARMS).remove(KEY_ACTIONS).apply()
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
                        hour = obj.optInt("hour", -1),
                        minute = obj.optInt("minute", -1),
                        isEn = obj.optBoolean("isEn", false),
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
                    put("hour", item.hour)
                    put("minute", item.minute)
                    put("isEn", item.isEn)
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
    fun drainPendingActions(context: Context): List<Map<String, Any?>> {
        val p = prefs(context)
        val raw = p.getString(KEY_ACTIONS, null) ?: return emptyList()
        p.edit().remove(KEY_ACTIONS).apply()
        return try {
            val arr = JSONArray(raw)
            val list = ArrayList<Map<String, Any?>>(arr.length())
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                list.add(
                    mapOf(
                        "action" to obj.optString("action", "dismiss"),
                        "id" to obj.optString("id", ""),
                        "title" to obj.optString("title", ""),
                        "taskId" to obj.optString("taskId", "").ifBlank { null },
                        "snoozeAtMs" to obj.optLong("snoozeAtMs", 0L),
                    ),
                )
            }
            list
        } catch (_: Exception) {
            emptyList()
        }
    }
}

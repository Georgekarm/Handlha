package com.handelha.app.data.local

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.handelha.app.ui.theme.AppThemeMode
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "handelha_prefs")

class AppPreferencesStore(private val context: Context) {
    private val ds = context.applicationContext.dataStore

    companion object {
        private val KEY_THEME_MODE = stringPreferencesKey("theme_mode")
        private val KEY_LANGUAGE_CODE = stringPreferencesKey("language_code")
        private val KEY_STUDENT_MODE = booleanPreferencesKey("student_mode")

        // Session & local email account keys
        private val KEY_USER_ID = stringPreferencesKey("auth_user_id")
        private val KEY_USER_EMAIL = stringPreferencesKey("auth_user_email")
        private val KEY_USER_NAME = stringPreferencesKey("auth_user_name")
        private val KEY_USER_AVATAR = stringPreferencesKey("auth_user_avatar")
        private val KEY_AUTH_PROVIDER = stringPreferencesKey("auth_provider")
        private val KEY_ASSISTANT_TONE = stringPreferencesKey("assistant_tone")
        private val KEY_ONBOARDING_COMPLETE = booleanPreferencesKey("onboarding_complete")
        private val KEY_SUBSCRIPTION_CATEGORY = stringPreferencesKey("subscription_category")
        private val KEY_ACTIVE_PLAN_ID = stringPreferencesKey("active_plan_id")
        private val KEY_ACTIVE_PLAN_TITLE = stringPreferencesKey("active_plan_title")

        private val KEY_LOCAL_ACCOUNT_ID = stringPreferencesKey("local_account_id")
        private val KEY_LOCAL_EMAIL = stringPreferencesKey("local_email")
        private val KEY_LOCAL_ACCOUNT_NAME = stringPreferencesKey("local_account_name")
        private val KEY_LOCAL_PW_SALT = stringPreferencesKey("local_pw_salt")
        private val KEY_LOCAL_PW_HASH = stringPreferencesKey("local_pw_hash")
    }

    val themeModeFlow: Flow<AppThemeMode> = ds.data.map {
        AppThemeMode.fromString(it[KEY_THEME_MODE])
    }

    val languageCodeFlow: Flow<String> = ds.data.map {
        it[KEY_LANGUAGE_CODE] ?: "ar"
    }

    val studentModeFlow: Flow<Boolean> = ds.data.map {
        it[KEY_STUDENT_MODE] ?: true
    }

    suspend fun setThemeMode(mode: AppThemeMode) {
        ds.edit { it[KEY_THEME_MODE] = mode.storedValue }
    }

    suspend fun setLanguageCode(code: String) {
        ds.edit { it[KEY_LANGUAGE_CODE] = if (code == "en") "en" else "ar" }
    }

    suspend fun setStudentMode(enabled: Boolean) {
        ds.edit { it[KEY_STUDENT_MODE] = enabled }
    }

    suspend fun readString(key: Preferences.Key<String>): String? = ds.data.first()[key]

    suspend fun snapshot(): Preferences = ds.data.first()

    suspend fun update(block: suspend (androidx.datastore.preferences.core.MutablePreferences) -> Unit) {
        ds.edit(block)
    }

    // Typed key helpers for per-user storage
    fun userEnergyPrefsKey(userId: String) = stringPreferencesKey("energy_prefs_$userId")
    fun userNotifPrefsKey(userId: String) = stringPreferencesKey("notif_prefs_$userId")
    fun userNotifReadIdsKey(userId: String) = stringSetPreferencesKey("notif_read_ids_$userId")
    fun userNotifLastSyncKey(userId: String) = stringPreferencesKey("notif_last_sync_$userId")
    fun userAlarmsKey(userId: String) = stringPreferencesKey("alarms_items_$userId")
    fun userAlarmDefaultModeKey(userId: String) = stringPreferencesKey("alarm_default_mode_$userId")
    fun userTaskAlertModesKey(userId: String) = stringPreferencesKey("task_alert_modes_$userId")
    fun userSubscriptionKey(userId: String) = stringPreferencesKey("subscription_$userId")
    fun userTokenBalanceKey(userId: String) = intPreferencesKey("token_balance_$userId")
    fun userTokenDateKey(userId: String) = stringPreferencesKey("token_date_$userId")
    fun userTokenAdsKey(userId: String) = intPreferencesKey("token_ads_$userId")
    fun userStudentMotivationKey(userId: String) = stringPreferencesKey("student_motivation_$userId")

    // Expose auth preference keys cleanly
    object AuthKeys {
        val USER_ID = KEY_USER_ID
        val USER_EMAIL = KEY_USER_EMAIL
        val USER_NAME = KEY_USER_NAME
        val USER_AVATAR = KEY_USER_AVATAR
        val AUTH_PROVIDER = KEY_AUTH_PROVIDER
        val ASSISTANT_TONE = KEY_ASSISTANT_TONE
        val ONBOARDING_COMPLETE = KEY_ONBOARDING_COMPLETE
        val SUBSCRIPTION_CATEGORY = KEY_SUBSCRIPTION_CATEGORY
        val ACTIVE_PLAN_ID = KEY_ACTIVE_PLAN_ID
        val ACTIVE_PLAN_TITLE = KEY_ACTIVE_PLAN_TITLE
        val LOCAL_ACCOUNT_ID = KEY_LOCAL_ACCOUNT_ID
        val LOCAL_EMAIL = KEY_LOCAL_EMAIL
        val LOCAL_ACCOUNT_NAME = KEY_LOCAL_ACCOUNT_NAME
        val LOCAL_PW_SALT = KEY_LOCAL_PW_SALT
        val LOCAL_PW_HASH = KEY_LOCAL_PW_HASH
    }
}

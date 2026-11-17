package com.handelha.app.data.repo

import com.handelha.app.data.local.AppPreferencesStore
import com.handelha.app.data.local.HandelhaDatabase
import com.handelha.app.domain.AppUser
import com.handelha.app.domain.AssistantTone
import com.handelha.app.domain.AuthProviderType
import com.handelha.app.domain.OnboardingUsageType
import com.handelha.app.domain.UserSubscriptionCategory
import java.security.MessageDigest
import java.util.UUID
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

sealed class AuthResult {
    data class Success(val user: AppUser) : AuthResult()
    data class Error(val messageAr: String, val messageEn: String) : AuthResult()
}

class LocalAuthRepository(
    private val prefs: AppPreferencesStore,
    private val db: HandelhaDatabase,
    private val subscriptionStore: LocalSubscriptionStore,
) {
    companion object {
        private const val KDF_PREFIX = "pbkdf2_sha256"
        private const val KDF_ITERATIONS = 10_000
    }

    suspend fun getCurrentUser(): AppUser? {
        val snap = prefs.snapshot()
        val userId = snap[AppPreferencesStore.AuthKeys.USER_ID] ?: return null
        val email = snap[AppPreferencesStore.AuthKeys.USER_EMAIL]
            ?: snap[AppPreferencesStore.AuthKeys.LOCAL_EMAIL]
            ?: return null
        val displayName = snap[AppPreferencesStore.AuthKeys.USER_NAME]
        val avatarUrl = snap[AppPreferencesStore.AuthKeys.USER_AVATAR]
        val provider = runCatching {
            AuthProviderType.valueOf(snap[AppPreferencesStore.AuthKeys.AUTH_PROVIDER] ?: "email")
        }.getOrDefault(AuthProviderType.email)
        val onboardingDone = snap[AppPreferencesStore.AuthKeys.ONBOARDING_COMPLETE] ?: false
        val tone = runCatching {
            AssistantTone.valueOf(snap[AppPreferencesStore.AuthKeys.ASSISTANT_TONE] ?: "friendly")
        }.getOrDefault(AssistantTone.friendly)
        val sub = subscriptionStore.loadForUser(userId)

        return AppUser(
            id = userId,
            displayName = displayName?.ifBlank { null },
            email = email.ifBlank { null },
            avatarUrl = avatarUrl?.ifBlank { null },
            authProvider = provider,
            usageType = OnboardingUsageType.mixed,
            tone = tone,
            focusHours = listOf(9, 10, 11, 14, 15, 16),
            onboardingComplete = onboardingDone,
            subscriptionCategory = sub.category,
            activePlanId = sub.activePlanId,
        )
    }

    suspend fun signInWithEmail(email: String, password: String): AuthResult {
        val normalized = email.trim().lowercase()
        val emailError = validateEmail(normalized)
        if (emailError != null) return AuthResult.Error(emailError.first, emailError.second)

        val snap = prefs.snapshot()
        val savedEmail = snap[AppPreferencesStore.AuthKeys.LOCAL_EMAIL]
        val savedHash = snap[AppPreferencesStore.AuthKeys.LOCAL_PW_HASH]
        val salt = snap[AppPreferencesStore.AuthKeys.LOCAL_PW_SALT]
        if (savedEmail == null || savedHash == null || salt == null) {
            return AuthResult.Error(
                "مفيش حساب مسجل بالإيميل ده على الجهاز.",
                "No local account found for this email.",
            )
        }
        if (savedEmail != normalized || !verifyPassword(password, salt, savedHash)) {
            return AuthResult.Error(
                "البريد الإلكتروني أو كلمة المرور غير صحيحة.",
                "Invalid email or password.",
            )
        }

        // Transparently upgrade legacy SHA-256 hash to PBKDF2-HMAC-SHA256
        if (!savedHash.startsWith("$KDF_PREFIX$")) {
            val upgraded = hashPassword(password, salt)
            prefs.update { it[AppPreferencesStore.AuthKeys.LOCAL_PW_HASH] = upgraded }
        }

        val userId = snap[AppPreferencesStore.AuthKeys.LOCAL_ACCOUNT_ID]
            ?: return AuthResult.Error("الحساب غير موجود.", "Account not found.")
        val displayName = snap[AppPreferencesStore.AuthKeys.LOCAL_ACCOUNT_NAME]
            ?: snap[AppPreferencesStore.AuthKeys.USER_NAME]
        val onboardingDone = snap[AppPreferencesStore.AuthKeys.ONBOARDING_COMPLETE] ?: false
        val tone = runCatching {
            AssistantTone.valueOf(snap[AppPreferencesStore.AuthKeys.ASSISTANT_TONE] ?: "friendly")
        }.getOrDefault(AssistantTone.friendly)
        val sub = subscriptionStore.loadForUser(userId)

        val user = AppUser(
            id = userId,
            displayName = displayName?.ifBlank { null },
            email = savedEmail,
            authProvider = AuthProviderType.email,
            usageType = OnboardingUsageType.mixed,
            tone = tone,
            onboardingComplete = onboardingDone,
            subscriptionCategory = sub.category,
            activePlanId = sub.activePlanId,
        )
        startSession(user)
        return AuthResult.Success(user)
    }

    suspend fun createAccountWithEmail(
        email: String,
        password: String,
        displayName: String?,
    ): AuthResult {
        val normalized = email.trim().lowercase()
        val emailError = validateEmail(normalized)
        if (emailError != null) return AuthResult.Error(emailError.first, emailError.second)

        val pwError = validatePassword(password)
        if (pwError != null) return AuthResult.Error(pwError.first, pwError.second)

        val snap = prefs.snapshot()
        val existingEmail = snap[AppPreferencesStore.AuthKeys.LOCAL_EMAIL]
        if (existingEmail != null) {
            return AuthResult.Error(
                "فيه حساب بريد إلكتروني مسجل بالفعل على الجهاز ده.",
                "An email account is already registered on this device.",
            )
        }

        val uid = UUID.randomUUID().toString()
        val salt = UUID.randomUUID().toString()
        val hash = hashPassword(password, salt)
        val cleanName = displayName?.trim()?.ifBlank { null }
        val onboardingDone = snap[AppPreferencesStore.AuthKeys.ONBOARDING_COMPLETE] ?: false
        val tone = runCatching {
            AssistantTone.valueOf(snap[AppPreferencesStore.AuthKeys.ASSISTANT_TONE] ?: "friendly")
        }.getOrDefault(AssistantTone.friendly)

        val user = AppUser(
            id = uid,
            displayName = cleanName,
            email = normalized,
            authProvider = AuthProviderType.email,
            usageType = OnboardingUsageType.mixed,
            tone = tone,
            onboardingComplete = onboardingDone,
        )

        prefs.update { ed ->
            ed[AppPreferencesStore.AuthKeys.LOCAL_ACCOUNT_ID] = uid
            ed[AppPreferencesStore.AuthKeys.LOCAL_EMAIL] = normalized
            if (cleanName != null) {
                ed[AppPreferencesStore.AuthKeys.LOCAL_ACCOUNT_NAME] = cleanName
            }
            ed[AppPreferencesStore.AuthKeys.LOCAL_PW_SALT] = salt
            ed[AppPreferencesStore.AuthKeys.LOCAL_PW_HASH] = hash
        }
        subscriptionStore.clearForUser(uid)
        startSession(user)
        return AuthResult.Success(user)
    }

    suspend fun signInWithSocialProfile(
        provider: AuthProviderType,
        email: String,
        displayName: String,
    ): AuthResult {
        val normalizedEmail = email.trim().lowercase()
        val emailErr = validateEmail(normalizedEmail)
        if (emailErr != null) return AuthResult.Error(emailErr.first, emailErr.second)

        val cleanName = displayName.trim().ifBlank { normalizedEmail.substringBefore('@') }
        val profileHash = sha256Hex("${provider.name}:$normalizedEmail").take(12)
        val userId = "${provider.name}_$profileHash"
        val snap = prefs.snapshot()
        val onboardingDone = snap[AppPreferencesStore.AuthKeys.ONBOARDING_COMPLETE] ?: false
        val tone = runCatching {
            AssistantTone.valueOf(snap[AppPreferencesStore.AuthKeys.ASSISTANT_TONE] ?: "friendly")
        }.getOrDefault(AssistantTone.friendly)
        val sub = subscriptionStore.loadForUser(userId)

        val user = AppUser(
            id = userId,
            displayName = cleanName,
            email = normalizedEmail,
            authProvider = provider,
            usageType = OnboardingUsageType.mixed,
            tone = tone,
            onboardingComplete = onboardingDone,
            subscriptionCategory = sub.category,
            activePlanId = sub.activePlanId,
        )
        startSession(user)
        return AuthResult.Success(user)
    }

    suspend fun markOnboardingComplete() {
        prefs.update { it[AppPreferencesStore.AuthKeys.ONBOARDING_COMPLETE] = true }
    }

    suspend fun updateAssistantTone(tone: AssistantTone) {
        prefs.update { it[AppPreferencesStore.AuthKeys.ASSISTANT_TONE] = tone.name }
    }

    suspend fun signOut() {
        prefs.update { ed ->
            ed.remove(AppPreferencesStore.AuthKeys.USER_ID)
            ed.remove(AppPreferencesStore.AuthKeys.USER_EMAIL)
            ed.remove(AppPreferencesStore.AuthKeys.USER_NAME)
            ed.remove(AppPreferencesStore.AuthKeys.USER_AVATAR)
            ed.remove(AppPreferencesStore.AuthKeys.AUTH_PROVIDER)
            ed.remove(AppPreferencesStore.AuthKeys.SUBSCRIPTION_CATEGORY)
            ed.remove(AppPreferencesStore.AuthKeys.ACTIVE_PLAN_ID)
            ed.remove(AppPreferencesStore.AuthKeys.ACTIVE_PLAN_TITLE)
        }
    }

    suspend fun deleteAccount(currentUser: AppUser?) {
        val uid = currentUser?.id ?: prefs.readString(AppPreferencesStore.AuthKeys.USER_ID)
        if (!uid.isNullOrBlank()) {
            db.taskDao().deleteForUser(uid)
            db.projectDao().deleteForUser(uid)
            db.focusSessionDao().deleteForUser(uid)
            db.examGradeDao().deleteForUser(uid)
            db.chatConversationDao().deleteForUser(uid)
            subscriptionStore.clearForUser(uid)
            prefs.update { ed ->
                ed.remove(prefs.userEnergyPrefsKey(uid))
                ed.remove(prefs.userNotifPrefsKey(uid))
                ed.remove(prefs.userNotifReadIdsKey(uid))
                ed.remove(prefs.userNotifLastSyncKey(uid))
                ed.remove(prefs.userAlarmsKey(uid))
                ed.remove(prefs.userAlarmDefaultModeKey(uid))
                ed.remove(prefs.userTaskAlertModesKey(uid))
                ed.remove(prefs.userTokenBalanceKey(uid))
                ed.remove(prefs.userTokenDateKey(uid))
                ed.remove(prefs.userTokenAdsKey(uid))
            }
        }
        signOut()
        if (currentUser?.authProvider == AuthProviderType.email) {
            prefs.update { ed ->
                ed.remove(AppPreferencesStore.AuthKeys.LOCAL_ACCOUNT_ID)
                ed.remove(AppPreferencesStore.AuthKeys.LOCAL_EMAIL)
                ed.remove(AppPreferencesStore.AuthKeys.LOCAL_ACCOUNT_NAME)
                ed.remove(AppPreferencesStore.AuthKeys.LOCAL_PW_SALT)
                ed.remove(AppPreferencesStore.AuthKeys.LOCAL_PW_HASH)
                ed.remove(AppPreferencesStore.AuthKeys.ONBOARDING_COMPLETE)
            }
        }
    }

    suspend fun resetLocalPassword(email: String, newPassword: String): AuthResult {
        val normalized = email.trim().lowercase()
        val emailError = validateEmail(normalized)
        if (emailError != null) return AuthResult.Error(emailError.first, emailError.second)

        val pwError = validatePassword(newPassword)
        if (pwError != null) return AuthResult.Error(pwError.first, pwError.second)

        val snap = prefs.snapshot()
        val savedEmail = snap[AppPreferencesStore.AuthKeys.LOCAL_EMAIL]
        val uid = snap[AppPreferencesStore.AuthKeys.LOCAL_ACCOUNT_ID]
        if (savedEmail == null || uid == null || savedEmail != normalized) {
            return AuthResult.Error(
                "مفيش حساب مسجل بالإيميل ده على الجهاز.",
                "No local account found for this email on this device.",
            )
        }

        val salt = UUID.randomUUID().toString()
        val hash = hashPassword(newPassword, salt)
        prefs.update { ed ->
            ed[AppPreferencesStore.AuthKeys.LOCAL_PW_SALT] = salt
            ed[AppPreferencesStore.AuthKeys.LOCAL_PW_HASH] = hash
        }
        return signInWithEmail(normalized, newPassword)
    }

    private suspend fun startSession(user: AppUser) {
        prefs.update { ed ->
            ed[AppPreferencesStore.AuthKeys.USER_ID] = user.id
            ed[AppPreferencesStore.AuthKeys.USER_EMAIL] = user.email.orEmpty()
            ed[AppPreferencesStore.AuthKeys.AUTH_PROVIDER] = user.authProvider.name
            ed[AppPreferencesStore.AuthKeys.SUBSCRIPTION_CATEGORY] = user.subscriptionCategory.name
            if (!user.activePlanId.isNullOrBlank()) {
                ed[AppPreferencesStore.AuthKeys.ACTIVE_PLAN_ID] = user.activePlanId
            } else {
                ed.remove(AppPreferencesStore.AuthKeys.ACTIVE_PLAN_ID)
            }
            if (!user.displayName.isNullOrBlank()) {
                ed[AppPreferencesStore.AuthKeys.USER_NAME] = user.displayName
            } else {
                ed.remove(AppPreferencesStore.AuthKeys.USER_NAME)
            }
            if (!user.avatarUrl.isNullOrBlank()) {
                ed[AppPreferencesStore.AuthKeys.USER_AVATAR] = user.avatarUrl
            } else {
                ed.remove(AppPreferencesStore.AuthKeys.USER_AVATAR)
            }
        }
    }

    private fun validateEmail(email: String): Pair<String, String>? {
        if (email.isEmpty()) return "البريد الإلكتروني مطلوب." to "Email is required."
        if (email.length > 120) return "البريد الإلكتروني طويل جدًا." to "Email is too long."
        val valid = Regex("""^[\w.\-+]+@[\w\-]+\.\w{2,}$""").matches(email)
        return if (valid) null else ("البريد الإلكتروني غير صالح." to "Invalid email address.")
    }

    private fun validatePassword(password: String): Pair<String, String>? {
        if (password.length < 8) {
            return "كلمة المرور قصيرة. استخدم 8 أحرف أو أكثر." to
                "Password must be at least 8 characters."
        }
        if (password.length > 128) {
            return "كلمة المرور طويلة جدًا." to
                "Password is too long (max 128 characters)."
        }
        if (!Regex("[A-Za-z]").containsMatchIn(password) || !Regex("\\d").containsMatchIn(password)) {
            return "كلمة المرور لازم تحتوي على حروف وأرقام." to
                "Password must contain both letters and numbers."
        }
        return null
    }

    fun hashPassword(password: String, salt: String, iterations: Int = KDF_ITERATIONS): String {
        val hex = pbkdf2Sha256Hex(password, salt, iterations)
        return "$KDF_PREFIX$$iterations$$hex"
    }

    fun verifyPassword(password: String, salt: String, storedHash: String): Boolean {
        if (storedHash.startsWith("$KDF_PREFIX$")) {
            val parts = storedHash.split('$')
            if (parts.size == 3) {
                val iterations = parts[1].toIntOrNull() ?: KDF_ITERATIONS
                val expectedHex = parts[2]
                val actualHex = pbkdf2Sha256Hex(password, salt, iterations)
                return constantTimeEquals(actualHex, expectedHex)
            }
        }
        val legacyHex = sha256Hex("$salt:$password")
        return constantTimeEquals(legacyHex, storedHash)
    }

    private fun pbkdf2Sha256Hex(password: String, salt: String, iterations: Int): String {
        val keySpec = SecretKeySpec(password.toByteArray(Charsets.UTF_8), "HmacSHA256")
        val mac = Mac.getInstance("HmacSHA256").apply { init(keySpec) }

        val saltBytes = salt.toByteArray(Charsets.UTF_8)
        val blockInput = ByteArray(saltBytes.size + 4)
        System.arraycopy(saltBytes, 0, blockInput, 0, saltBytes.size)
        blockInput[saltBytes.size] = 0
        blockInput[saltBytes.size + 1] = 0
        blockInput[saltBytes.size + 2] = 0
        blockInput[saltBytes.size + 3] = 1

        var u = mac.doFinal(blockInput)
        val out = u.copyOf()
        for (i in 1 until iterations) {
            u = mac.doFinal(u)
            for (j in out.indices) {
                out[j] = (out[j].toInt() xor u[j].toInt()).toByte()
            }
        }
        return out.joinToString("") { "%02x".format(it) }
    }

    private fun sha256Hex(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(input.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }

    private fun constantTimeEquals(a: String, b: String): Boolean {
        if (a.length != b.length) return false
        var diff = 0
        for (i in a.indices) {
            diff = diff or (a[i].code xor b[i].code)
        }
        return diff == 0
    }
}

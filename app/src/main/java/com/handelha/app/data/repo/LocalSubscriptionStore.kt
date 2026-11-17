package com.handelha.app.data.repo

import com.handelha.app.data.local.AppPreferencesStore
import com.handelha.app.domain.StoredSubscriptionRecord
import com.handelha.app.domain.SubscriptionOffer
import com.handelha.app.domain.SubscriptionPlanTrack
import com.handelha.app.domain.SubscriptionState
import com.handelha.app.domain.SubscriptionStatus
import com.handelha.app.domain.SubscriptionTier
import com.handelha.app.domain.UserSubscriptionCategory
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class LocalSubscriptionStore(private val prefs: AppPreferencesStore) {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    private fun normalizeUserId(userId: String?): String =
        userId?.trim().takeIf { !it.isNullOrEmpty() } ?: "guest"

    fun buildOffers(isEnglish: Boolean): List<SubscriptionOffer> = if (isEnglish) {
        listOf(
            SubscriptionOffer(
                identifier = "student_monthly",
                title = "Student Monthly",
                description = "Full AI secretary, smart schedules & exam grades tracker.",
                price = "49 EGP",
                periodLabel = "/ month",
                isAnnual = false,
                track = SubscriptionPlanTrack.student,
            ),
            SubscriptionOffer(
                identifier = "student_yearly",
                title = "Student Yearly",
                description = "Full academic year + 32% savings.",
                price = "399 EGP",
                periodLabel = "/ year",
                isAnnual = true,
                track = SubscriptionPlanTrack.student,
            ),
            SubscriptionOffer(
                identifier = "pro_monthly",
                title = "Pro Monthly",
                description = "Unlimited AI planning, deep focus trees & analytics.",
                price = "89 EGP",
                periodLabel = "/ month",
                isAnnual = false,
                track = SubscriptionPlanTrack.pro,
            ),
            SubscriptionOffer(
                identifier = "pro_yearly",
                title = "Pro Yearly",
                description = "Best value for year-round calm productivity.",
                price = "699 EGP",
                periodLabel = "/ year",
                isAnnual = true,
                track = SubscriptionPlanTrack.pro,
            ),
        )
    } else {
        listOf(
            SubscriptionOffer(
                identifier = "student_monthly",
                title = "باقة الطلاب الشهرية",
                description = "السكرتير الذكي، الجداول التلقائية، ومتابعة تقديرات الامتحانات.",
                price = "٤٩ ج.م",
                periodLabel = "/ شهريًا",
                isAnnual = false,
                track = SubscriptionPlanTrack.student,
            ),
            SubscriptionOffer(
                identifier = "student_yearly",
                title = "باقة الطلاب السنوية",
                description = "سنة دراسية كاملة مع توفير ٣٢٪.",
                price = "٣٩٩ ج.م",
                periodLabel = "/ سنويًا",
                isAnnual = true,
                track = SubscriptionPlanTrack.student,
            ),
            SubscriptionOffer(
                identifier = "pro_monthly",
                title = "باقة Pro الشهرية",
                description = "تخطيط ذكي غير محدود، شجرة التركيز، وتحليلات الإنجاز.",
                price = "٨٩ ج.م",
                periodLabel = "/ شهريًا",
                isAnnual = false,
                track = SubscriptionPlanTrack.pro,
            ),
            SubscriptionOffer(
                identifier = "pro_yearly",
                title = "باقة Pro السنوية",
                description = "أفضل قيمة لإنتاجية هادئة طوال العام.",
                price = "٦٩٩ ج.م",
                periodLabel = "/ سنويًا",
                isAnnual = true,
                track = SubscriptionPlanTrack.pro,
            ),
        )
    }

    suspend fun loadForUser(userId: String?): StoredSubscriptionRecord {
        val uid = normalizeUserId(userId)
        val snap = prefs.snapshot()
        val raw = snap[prefs.userSubscriptionKey(uid)]
        if (!raw.isNullOrBlank()) {
            runCatching { return json.decodeFromString<StoredSubscriptionRecord>(raw) }
        }
        val catRaw = snap[AppPreferencesStore.AuthKeys.SUBSCRIPTION_CATEGORY]
        if (!catRaw.isNullOrBlank()) {
            val category = UserSubscriptionCategory.fromName(catRaw)
            if (category != UserSubscriptionCategory.free) {
                return StoredSubscriptionRecord(
                    userId = uid,
                    category = category,
                    tier = if (category == UserSubscriptionCategory.student) SubscriptionTier.student else SubscriptionTier.pro,
                    activePlanId = snap[AppPreferencesStore.AuthKeys.ACTIVE_PLAN_ID],
                    activePlanTitle = snap[AppPreferencesStore.AuthKeys.ACTIVE_PLAN_TITLE],
                    isLocalActivation = true,
                )
            }
        }
        return StoredSubscriptionRecord(userId = uid)
    }

    suspend fun loadStateForUser(userId: String?, isEnglish: Boolean): SubscriptionState {
        val rec = loadForUser(userId)
        val offers = buildOffers(isEnglish)
        if (!rec.isSubscribed) {
            return SubscriptionState(
                status = SubscriptionStatus.free,
                tier = SubscriptionTier.free,
                offers = offers,
            )
        }
        return SubscriptionState(
            status = SubscriptionStatus.active,
            tier = rec.tier,
            offers = offers,
            subscribedAtMs = rec.subscribedAtMs,
            expirationDateMs = rec.expirationDateMs,
            activePlanId = rec.activePlanId,
            activePlanTitle = rec.activePlanTitle,
            activePlanPrice = rec.activePlanPrice,
            isLocalActivation = rec.isLocalActivation,
        )
    }

    suspend fun activatePlanForUser(
        userId: String?,
        offer: SubscriptionOffer,
    ): StoredSubscriptionRecord {
        val uid = normalizeUserId(userId)
        val now = System.currentTimeMillis()
        val days = if (offer.isAnnual) 365L else 30L
        val expiry = now + days * 24L * 60L * 60L * 1000L
        val isStudent = offer.track == SubscriptionPlanTrack.student
        val record = StoredSubscriptionRecord(
            userId = uid,
            category = if (isStudent) UserSubscriptionCategory.student else UserSubscriptionCategory.regularPro,
            tier = if (isStudent) SubscriptionTier.student else SubscriptionTier.pro,
            activePlanId = offer.identifier,
            activePlanTitle = offer.title,
            activePlanPrice = offer.price,
            subscribedAtMs = now,
            expirationDateMs = expiry,
            isLocalActivation = true,
        )
        saveForUser(uid, record)
        return record
    }

    suspend fun saveForUser(userId: String?, record: StoredSubscriptionRecord) {
        val uid = normalizeUserId(userId)
        val normalized = record.copy(userId = uid)
        prefs.update { ed ->
            ed[prefs.userSubscriptionKey(uid)] = json.encodeToString(normalized)
            ed[AppPreferencesStore.AuthKeys.SUBSCRIPTION_CATEGORY] = normalized.category.name
            if (!normalized.activePlanId.isNullOrBlank()) {
                ed[AppPreferencesStore.AuthKeys.ACTIVE_PLAN_ID] = normalized.activePlanId
            } else {
                ed.remove(AppPreferencesStore.AuthKeys.ACTIVE_PLAN_ID)
            }
            if (!normalized.activePlanTitle.isNullOrBlank()) {
                ed[AppPreferencesStore.AuthKeys.ACTIVE_PLAN_TITLE] = normalized.activePlanTitle
            } else {
                ed.remove(AppPreferencesStore.AuthKeys.ACTIVE_PLAN_TITLE)
            }
        }
    }

    suspend fun clearForUser(userId: String?) {
        val uid = normalizeUserId(userId)
        prefs.update { ed ->
            ed.remove(prefs.userSubscriptionKey(uid))
            ed[AppPreferencesStore.AuthKeys.SUBSCRIPTION_CATEGORY] = UserSubscriptionCategory.free.name
            ed.remove(AppPreferencesStore.AuthKeys.ACTIVE_PLAN_ID)
            ed.remove(AppPreferencesStore.AuthKeys.ACTIVE_PLAN_TITLE)
        }
    }
}

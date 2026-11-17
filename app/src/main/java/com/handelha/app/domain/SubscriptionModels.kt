package com.handelha.app.domain

import kotlinx.serialization.Serializable

@Serializable
enum class UserSubscriptionCategory {
    free,
    student,
    regularPro;

    fun label(isEnglish: Boolean = false): String = when (this) {
        free -> if (isEnglish) "Free Account" else "حساب مجاني"
        student -> if (isEnglish) "Student Category" else "تصنيف الطلاب"
        regularPro -> if (isEnglish) "Regular Pro Subscriber" else "تصنيف المشتركين العاديين (Pro)"
    }

    fun shortBadge(isEnglish: Boolean = false): String = when (this) {
        free -> if (isEnglish) "Free" else "مجاني"
        student -> if (isEnglish) "Student" else "تصنيف الطلاب"
        regularPro -> if (isEnglish) "Pro" else "مشترك Pro"
    }

    companion object {
        fun fromName(raw: String?): UserSubscriptionCategory {
            return when (raw?.trim()?.lowercase()) {
                "student" -> student
                "regularpro", "regular_pro", "pro" -> regularPro
                else -> free
            }
        }
    }
}

@Serializable
enum class SubscriptionTier { free, student, pro }

enum class SubscriptionPlanTrack { student, pro }

enum class SubscriptionStatus { free, active, expired }

enum class PremiumFeature {
    advancedPlanning,
    productivityInsights,
    premiumAssistant,
    studentExamTracking,
}

data class SubscriptionOffer(
    val identifier: String,
    val title: String,
    val description: String,
    val price: String,
    val periodLabel: String,
    val isAnnual: Boolean,
    val track: SubscriptionPlanTrack,
)

@Serializable
data class StoredSubscriptionRecord(
    val userId: String,
    val category: UserSubscriptionCategory = UserSubscriptionCategory.free,
    val tier: SubscriptionTier = SubscriptionTier.free,
    val activePlanId: String? = null,
    val activePlanTitle: String? = null,
    val activePlanPrice: String? = null,
    val subscribedAtMs: Long? = null,
    val expirationDateMs: Long? = null,
    val isLocalActivation: Boolean = false,
) {
    val isSubscribed: Boolean
        get() = category != UserSubscriptionCategory.free && tier != SubscriptionTier.free
}

data class SubscriptionState(
    val status: SubscriptionStatus = SubscriptionStatus.free,
    val tier: SubscriptionTier = SubscriptionTier.free,
    val offers: List<SubscriptionOffer> = emptyList(),
    val expirationDateMs: Long? = null,
    val subscribedAtMs: Long? = null,
    val activePlanId: String? = null,
    val activePlanTitle: String? = null,
    val activePlanPrice: String? = null,
    val isLocalActivation: Boolean = false,
    val message: String? = null,
) {
    val isStudent: Boolean
        get() = tier == SubscriptionTier.student && status == SubscriptionStatus.active

    val isRegularPro: Boolean
        get() = tier == SubscriptionTier.pro && status == SubscriptionStatus.active

    val isPro: Boolean
        get() = isRegularPro || isStudent

    val category: UserSubscriptionCategory
        get() = when {
            isStudent -> UserSubscriptionCategory.student
            isRegularPro -> UserSubscriptionCategory.regularPro
            else -> UserSubscriptionCategory.free
        }

    fun resolvedPlanTitle(isEnglish: Boolean = false): String {
        val planId = activePlanId.orEmpty().lowercase()
        if (planId == "student_yearly" || (planId.contains("student") && (planId.contains("year") || planId.contains("annual")))) {
            return if (isEnglish) "Student Yearly" else "باقة الطلاب السنوية"
        }
        if (planId == "student_monthly" || planId.contains("student")) {
            return if (isEnglish) "Student Monthly" else "باقة الطلاب الشهرية"
        }
        if (planId == "pro_yearly" || planId.contains("year") || planId.contains("annual")) {
            return if (isEnglish) "Pro Yearly" else "باقة Pro السنوية"
        }
        if (planId == "pro_monthly" || planId.contains("month")) {
            return if (isEnglish) "Pro Monthly" else "باقة Pro الشهرية"
        }
        if (!activePlanTitle.isNullOrBlank()) return activePlanTitle.trim()
        if (isStudent) return if (isEnglish) "Student Plan" else "باقة الطلاب"
        if (isRegularPro) return if (isEnglish) "Handelha Pro" else "باقة Pro العادية"
        return if (isEnglish) "Free Plan" else "الباقة المجانية"
    }

    fun isPlanActive(planId: String): Boolean =
        isPro && activePlanId?.trim() == planId

    fun canUse(feature: PremiumFeature): Boolean = when (feature) {
        PremiumFeature.studentExamTracking -> isStudent
        else -> isPro
    }
}

package com.handelha.app.domain

import kotlinx.serialization.Serializable

@Serializable
enum class OnboardingUsageType { study, work, personal, mixed }

@Serializable
enum class AssistantTone { friendly, formal, brief, custom }

@Serializable
enum class AuthProviderType { email, google, facebook }

@Serializable
data class AppUser(
    val id: String,
    val displayName: String? = null,
    val email: String? = null,
    val avatarUrl: String? = null,
    val authProvider: AuthProviderType = AuthProviderType.email,
    val usageType: OnboardingUsageType = OnboardingUsageType.mixed,
    val tone: AssistantTone = AssistantTone.friendly,
    val focusHours: List<Int> = listOf(9, 10, 11, 14, 15, 16),
    val onboardingComplete: Boolean = false,
    val subscriptionCategory: UserSubscriptionCategory = UserSubscriptionCategory.free,
    val activePlanId: String? = null,
    val createdAtMs: Long = System.currentTimeMillis(),
) {
    val isStudentSubscriber: Boolean
        get() = subscriptionCategory == UserSubscriptionCategory.student

    val isRegularProSubscriber: Boolean
        get() = subscriptionCategory == UserSubscriptionCategory.regularPro

    val firstName: String
        get() {
            val clean = displayName?.trim().orEmpty()
            return if (clean.isEmpty()) "صديقي" else clean.split(" ").first()
        }
}

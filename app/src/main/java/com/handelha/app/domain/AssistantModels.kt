package com.handelha.app.domain

import kotlinx.serialization.Serializable

@Serializable
data class UserEnergyPreferences(
    val peakEnergyPeriod: String = "morning", // 'morning' | 'afternoon' | 'evening'
    val preferredSessionMinutes: Int = 45, // 25 | 45 | 60
    val hardTaskStrategy: String = "peak_first", // 'peak_first' | 'warmup_first'
    val projectBreakdownStyle: String = "micro_steps", // 'micro_steps' | 'milestone_blocks'
    val completedWizard: Boolean = false,
) {
    val workStartMinute: Int
        get() = when (peakEnergyPeriod) {
            "afternoon" -> 12 * 60
            "evening" -> 17 * 60
            else -> 8 * 60
        }

    val workEndMinute: Int
        get() = when (peakEnergyPeriod) {
            "afternoon" -> 19 * 60
            "evening" -> 23 * 60
            else -> 15 * 60
        }

    fun peakLabel(isEnglish: Boolean): String = if (isEnglish) {
        when (peakEnergyPeriod) {
            "afternoon" -> "Afternoon 🌤️ (12 PM – 7 PM)"
            "evening" -> "Evening 🌙 (5 PM – 11 PM)"
            else -> "Morning ☀️ (8 AM – 3 PM)"
        }
    } else {
        when (peakEnergyPeriod) {
            "afternoon" -> "بعد الظهر 🌤️ (١٢ م – ٧ م)"
            "evening" -> "مسائي 🌙 (٥ م – ١١ م)"
            else -> "صباحي ☀️ (٨ ص – ٣ م)"
        }
    }

    fun peakShort(isEnglish: Boolean): String = if (isEnglish) {
        when (peakEnergyPeriod) {
            "afternoon" -> "Afternoon 🌤️"
            "evening" -> "Evening 🌙"
            else -> "Morning ☀️"
        }
    } else {
        when (peakEnergyPeriod) {
            "afternoon" -> "بعد الظهر 🌤️"
            "evening" -> "مسائي 🌙"
            else -> "صباحي ☀️"
        }
    }

    fun strategyLabel(isEnglish: Boolean): String = if (isEnglish) {
        if (hardTaskStrategy == "warmup_first") "Easy Warm-up First 🌱" else "Hardest at Peak Energy 🔥"
    } else {
        if (hardTaskStrategy == "warmup_first") "تسخين بمهمة خفيفة أولًا 🌱" else "الأصعب في قمة طاقتي 🔥"
    }
}

@Serializable
enum class ChatMessageRole { user, assistant, system, tool }

@Serializable
data class ProposedScheduleSlot(
    val taskId: String,
    val title: String,
    val startAtIso: String,
    val endAtIso: String,
    val priority: String = "medium",
    val alertMode: String = "alarm", // "alarm" | "notification"
    val dependsOnTaskIds: List<String> = emptyList(),
)

@Serializable
data class AssistantActionProposal(
    val id: String,
    val type: String, // "create_tasks" | "create_project" | "complete_task" | "reschedule_task" | "delete_task"
    val summary: String,
    val draftStatus: String = "pending", // "pending" | "confirmed" | "rejected"
    val inputHash: String = "",
    val slots: List<ProposedScheduleSlot> = emptyList(),
    val projectTitle: String? = null,
    val projectColorValue: Long = 0xFF007067L,
    val targetTaskId: String? = null,
    val targetTaskTitle: String? = null,
    val newDueAtIso: String? = null,
)

@Serializable
data class ChatMessageItem(
    val id: String,
    val role: ChatMessageRole,
    val text: String,
    val createdAtMs: Long = System.currentTimeMillis(),
    val quickReplies: List<String> = emptyList(),
    val proposal: AssistantActionProposal? = null,
)

@Serializable
data class ChatConversationRecord(
    val id: String,
    val userId: String,
    val title: String,
    val createdAtMs: Long,
    val updatedAtMs: Long,
    val messages: List<ChatMessageItem>,
)

data class TokenBalanceState(
    val balance: Int = DEFAULT_DAILY_ALLOWANCE,
    val dailyAllowance: Int = DEFAULT_DAILY_ALLOWANCE,
    val lastRenewalDate: String = "",
    val adsWatchedToday: Int = 0,
    val isLoadingAd: Boolean = false,
) {
    val canSendText: Boolean get() = balance >= TEXT_MESSAGE_COST
    val canSendVoice: Boolean get() = balance >= VOICE_MESSAGE_COST
    val fillRatio: Float
        get() = if (dailyAllowance <= 0) 0f else (balance.toFloat() / dailyAllowance.toFloat()).coerceIn(0f, 1f)

    companion object {
        const val DEFAULT_DAILY_ALLOWANCE = 50
        const val TEXT_MESSAGE_COST = 2
        const val VOICE_MESSAGE_COST = 5
        const val GOOGLE_AD_REWARD = 15
    }
}

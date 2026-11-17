package com.handelha.app.domain

import kotlinx.serialization.Serializable

@Serializable
enum class ProjectStatus { active, paused, completed, archived }

@Serializable
data class ProjectPhaseRecord(
    val id: String,
    val title: String,
    val description: String? = null,
    val estimatedDurationMinutes: Int? = null,
    val suggestedDeadlineMs: Long? = null,
)

@Serializable
data class ProjectItem(
    val id: String,
    val userId: String,
    val title: String,
    val description: String? = null,
    val status: ProjectStatus = ProjectStatus.active,
    val progressPercent: Double = 0.0,
    val nextStepTitle: String? = null,
    val targetDateMs: Long? = null,
    val taskIds: List<String> = emptyList(),
    val phases: List<ProjectPhaseRecord> = emptyList(),
    val colorValue: Long = 0xFF007067L,
    val createdAtMs: Long = System.currentTimeMillis(),
    val updatedAtMs: Long = System.currentTimeMillis(),
)

@Serializable
data class FocusSessionItem(
    val id: String,
    val userId: String,
    val taskId: String? = null,
    val taskTitle: String,
    val startedAtMs: Long,
    val endedAtMs: Long,
    val elapsedMinutes: Int,
    val completed: Boolean,
)

@Serializable
data class ExamGradeEntry(
    val id: String,
    val userId: String,
    val examTitle: String,
    val gradeTier: String, // 'excellent' | 'very_good' | 'good' | 'pass'
    val scoreLabel: String,
    val encouragementAr: String,
    val encouragementEn: String,
    val recordedAtMs: Long,
)

data class ExamEncouragement(
    val ar: String,
    val en: String,
    val badgeAr: String,
    val badgeEn: String,
)

object ExamGradesHelper {
    fun buildEncouragement(
        examTitle: String,
        gradeTier: String,
        scoreLabel: String,
    ): ExamEncouragement {
        val cleanExam = examTitle.trim().ifEmpty { "الامتحان" }
        return when (gradeTier) {
            "excellent" -> ExamEncouragement(
                ar = "عاش بجد! تقدير «$scoreLabel» في «$cleanExam» يفرّح القلب، وتعبك ومذاكرتك بانوا في النتيجة. ألف مبروك عليك التقدير ده.",
                en = "Incredible work! Scoring \"$scoreLabel\" in \"$cleanExam\" really shows how much effort you put in. You earned this top mark.",
                badgeAr = "وسام الامتياز والتفوق",
                badgeEn = "Honor & Excellence Badge",
            )
            "very_good" -> ExamEncouragement(
                ar = "برافو عليك بجد! تقدير «$scoreLabel» في «$cleanExam» نتيجة محترمة جدًا وتطمن، وإن شاء الله المادة الجاية تقفّلها على طول.",
                en = "Well done! Scoring \"$scoreLabel\" in \"$cleanExam\" is a strong result to be proud of, and you are right on track for the top.",
                badgeAr = "وسام التقدير المتقدم",
                badgeEn = "Strong Achiever Badge",
            )
            "good" -> ExamEncouragement(
                ar = "عاش يا بطل، مجهود محترم في «$cleanExam» بتقدير «$scoreLabel». عدّيت خطوة مش سهلة، وبترتيب بسيط المرة الجاية مستواك هيعلى أكتر.",
                en = "Solid work on \"$cleanExam\" with \"$scoreLabel\". You cleared an important exam, and with a steadier prep plan the next one gets even better.",
                badgeAr = "وسام التقدّم والثبات",
                badgeEn = "Steady Progress Badge",
            )
            else -> ExamEncouragement(
                ar = "ولا يهمك خالص في «$cleanExam»، المهم إنك دخلت وحاولت وعرفت المادة ماشية إزاي. هناخد نفس ونرتّب خطة مذاكرة هادية تعوّض بيها في اللي جاي.",
                en = "Do not beat yourself up over \"$cleanExam\" — showing up and seeing what needs work is what counts. We will set a calmer study plan to bounce back next time.",
                badgeAr = "وسام المثابرة والتعويض",
                badgeEn = "Persistence & Comeback Badge",
            )
        }
    }

    fun inferTierFromText(norm: String): String {
        if (norm.contains("امتياز") ||
            norm.contains("قفلت") ||
            norm.contains("فول مارك") ||
            norm.contains("full mark") ||
            norm.contains("a+") ||
            Regex("""\b(?:9\d|100)\s*%?""").containsMatchIn(norm)
        ) {
            return "excellent"
        }
        if (norm.contains("جيد جدا") ||
            norm.contains("حلو اوي") ||
            norm.contains("ممتاز") ||
            norm.contains("very good") ||
            norm.contains("b+") ||
            Regex("""\b8\d\s*%?""").containsMatchIn(norm)
        ) {
            return "very_good"
        }
        if (norm.contains("جيد") ||
            norm.contains("كويس") ||
            norm.contains("حليت حلو") ||
            norm.contains("نجحت") ||
            norm.contains("good") ||
            Regex("""\b7\d\s*%?""").containsMatchIn(norm)
        ) {
            return "good"
        }
        return "pass"
    }
}

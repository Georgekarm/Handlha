package com.handelha.app.util

import java.util.Calendar
import kotlin.math.roundToInt

object ArabicFormatters {
    @Volatile
    var useEnglish: Boolean = false

    private val arabicDigits = charArrayOf('٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩')

    private val arabicMonths = listOf(
        "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
        "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
    )

    private val englishMonths = listOf(
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    )

    private val commonTranslations = mapOf(
        "صديقي" to "Friend",
        "ترتيب جدول الأسبوع" to "Weekly Schedule Planning",
        "تحضير عرض العمل" to "Work Presentation Prep",
        "تنظيم مذاكرة الامتحانات" to "Exam Study Plan",
        "جلسة تركيز هادئة" to "Calm Focus Session",
    )

    fun trData(text: String): String {
        if (!useEnglish || text.isEmpty()) return text
        val direct = commonTranslations[text.trim()]
        if (direct != null) return direct
        var out = text
        for ((k, v) in commonTranslations) {
            if (out.contains(k)) {
                out = out.replace(k, v)
            }
        }
        return out
    }

    fun toArabicDigits(value: Any): String {
        val raw = value.toString()
        if (useEnglish) return raw
        val sb = StringBuilder(raw.length)
        for (ch in raw) {
            if (ch in '0'..'9') {
                sb.append(arabicDigits[ch - '0'])
            } else {
                sb.append(ch)
            }
        }
        return sb.toString()
    }

    fun percent(value: Double): String =
        if (useEnglish) "${value.roundToInt()}%" else "${toArabicDigits(value.roundToInt())}٪"

    fun countOf(completed: Int, total: Int): String =
        if (useEnglish) "$completed of $total tasks" else "${toArabicDigits(completed)} من ${toArabicDigits(total)} مهام"

    fun durationMinutes(minutes: Int): String =
        if (useEnglish) "${minutes}m" else "${toArabicDigits(minutes)} د"

    fun durationMinutesFull(minutes: Int): String =
        if (useEnglish) "$minutes min" else "${toArabicDigits(minutes)} دقيقة"

    fun timeOfDayAr(epochMs: Long): String {
        val cal = Calendar.getInstance().apply { timeInMillis = epochMs }
        val hour24 = cal.get(Calendar.HOUR_OF_DAY)
        val hour12 = if (hour24 % 12 == 0) 12 else hour24 % 12
        val minute = cal.get(Calendar.MINUTE).toString().padStart(2, '0')
        return if (useEnglish) {
            val suffix = if (hour24 < 12) "AM" else "PM"
            "$hour12:$minute $suffix"
        } else {
            val suffix = if (hour24 < 12) "ص" else "م"
            "${toArabicDigits("$hour12:$minute")} $suffix"
        }
    }

    fun dateShort(epochMs: Long): String {
        val cal = Calendar.getInstance().apply { timeInMillis = epochMs }
        val monthIdx = cal.get(Calendar.MONTH).coerceIn(0, 11)
        val day = cal.get(Calendar.DAY_OF_MONTH)
        return if (useEnglish) {
            "${englishMonths[monthIdx]} $day"
        } else {
            "${toArabicDigits(day)} ${arabicMonths[monthIdx]}"
        }
    }

    fun dateFull(epochMs: Long): String {
        val cal = Calendar.getInstance().apply { timeInMillis = epochMs }
        val monthIdx = cal.get(Calendar.MONTH).coerceIn(0, 11)
        val day = cal.get(Calendar.DAY_OF_MONTH)
        val year = cal.get(Calendar.YEAR)
        return if (useEnglish) {
            "${englishMonths[monthIdx]} $day, $year"
        } else {
            "${toArabicDigits(day)} ${arabicMonths[monthIdx]} ${toArabicDigits(year)}"
        }
    }

    fun weekdayShort(epochMs: Long): String {
        val cal = Calendar.getInstance().apply { timeInMillis = epochMs }
        val dow = cal.get(Calendar.DAY_OF_WEEK)
        return if (useEnglish) {
            when (dow) {
                Calendar.SATURDAY -> "Saturday"
                Calendar.SUNDAY -> "Sunday"
                Calendar.MONDAY -> "Monday"
                Calendar.TUESDAY -> "Tuesday"
                Calendar.WEDNESDAY -> "Wednesday"
                Calendar.THURSDAY -> "Thursday"
                Calendar.FRIDAY -> "Friday"
                else -> ""
            }
        } else {
            when (dow) {
                Calendar.SATURDAY -> "السبت"
                Calendar.SUNDAY -> "الأحد"
                Calendar.MONDAY -> "الإثنين"
                Calendar.TUESDAY -> "الثلاثاء"
                Calendar.WEDNESDAY -> "الأربعاء"
                Calendar.THURSDAY -> "الخميس"
                Calendar.FRIDAY -> "الجمعة"
                else -> ""
            }
        }
    }

    fun monthName(month1Based: Int): String {
        val idx = (month1Based - 1).coerceIn(0, 11)
        return if (useEnglish) englishMonths[idx] else arabicMonths[idx]
    }

    fun durationCompact(totalMinutes: Int): String {
        val safe = totalMinutes.coerceAtLeast(0)
        if (safe < 60) return durationMinutes(safe)
        val hours = safe / 60
        val rem = safe % 60
        return if (useEnglish) {
            if (rem == 0) "${hours}h" else "${hours}h ${rem}m"
        } else {
            if (rem == 0) "${toArabicDigits(hours)} س" else "${toArabicDigits(hours)} س ${toArabicDigits(rem)} د"
        }
    }

    fun timerMmSs(totalSeconds: Int): String {
        val safe = totalSeconds.coerceAtLeast(0)
        val minutes = (safe / 60).toString().padStart(2, '0')
        val seconds = (safe % 60).toString().padStart(2, '0')
        return "$minutes:$seconds"
    }
}

package com.handelha.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AccessTimeFilled
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.CalendarToday
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handelha.app.ui.theme.HandelhaTheme
import com.handelha.app.util.ArabicFormatters
import java.util.Calendar

enum class HandelhaPickerMode {
    DATE_TIME,
    DATE_ONLY,
    TIME_ONLY,
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun HandelhaDateTimePickerSheet(
    mode: HandelhaPickerMode = HandelhaPickerMode.DATE_TIME,
    initialEpochMs: Long = System.currentTimeMillis(),
    isEnglish: Boolean,
    title: String? = null,
    showFuturePresets: Boolean = false,
    onDismiss: () -> Unit,
    onConfirm: (Long) -> Unit,
) {
    val c = HandelhaTheme.colors
    val initCal = remember(initialEpochMs) {
        Calendar.getInstance().apply { timeInMillis = initialEpochMs }
    }

    var selectedYear by remember(initialEpochMs) { mutableIntStateOf(initCal.get(Calendar.YEAR)) }
    var selectedMonth0 by remember(initialEpochMs) { mutableIntStateOf(initCal.get(Calendar.MONTH)) }
    var selectedDay by remember(initialEpochMs) { mutableIntStateOf(initCal.get(Calendar.DAY_OF_MONTH)) }
    var displayedYear by remember(initialEpochMs) { mutableIntStateOf(initCal.get(Calendar.YEAR)) }
    var displayedMonth0 by remember(initialEpochMs) { mutableIntStateOf(initCal.get(Calendar.MONTH)) }
    var hour24 by remember(initialEpochMs) { mutableIntStateOf(initCal.get(Calendar.HOUR_OF_DAY)) }
    var minute by remember(initialEpochMs) { mutableIntStateOf(initCal.get(Calendar.MINUTE)) }
    var activeTab by remember(mode) {
        mutableIntStateOf(if (mode == HandelhaPickerMode.TIME_ONLY) 1 else 0)
    }

    fun selectCalendarDate(year: Int, month0: Int, day: Int) {
        val cal = Calendar.getInstance().apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month0)
            val maxD = getActualMaximum(Calendar.DAY_OF_MONTH)
            set(Calendar.DAY_OF_MONTH, day.coerceIn(1, maxD))
        }
        selectedYear = cal.get(Calendar.YEAR)
        selectedMonth0 = cal.get(Calendar.MONTH)
        selectedDay = cal.get(Calendar.DAY_OF_MONTH)
        displayedYear = selectedYear
        displayedMonth0 = selectedMonth0
    }

    fun shiftDisplayedMonth(delta: Int) {
        val cal = Calendar.getInstance().apply {
            set(Calendar.YEAR, displayedYear)
            set(Calendar.MONTH, displayedMonth0)
            set(Calendar.DAY_OF_MONTH, 1)
            add(Calendar.MONTH, delta)
        }
        displayedYear = cal.get(Calendar.YEAR)
        displayedMonth0 = cal.get(Calendar.MONTH)
    }

    val previewEpochMs = remember(selectedYear, selectedMonth0, selectedDay, hour24, minute) {
        Calendar.getInstance().apply {
            set(Calendar.YEAR, selectedYear)
            set(Calendar.MONTH, selectedMonth0)
            set(Calendar.DAY_OF_MONTH, selectedDay)
            set(Calendar.HOUR_OF_DAY, if (mode == HandelhaPickerMode.DATE_ONLY) 10 else hour24)
            set(Calendar.MINUTE, if (mode == HandelhaPickerMode.DATE_ONLY) 0 else minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    val resolvedTitle = title ?: when (mode) {
        HandelhaPickerMode.DATE_TIME -> if (isEnglish) "Date & Time" else "اختيار الموعد والوقت"
        HandelhaPickerMode.DATE_ONLY -> if (isEnglish) "Select Date" else "اختيار التاريخ"
        HandelhaPickerMode.TIME_ONLY -> if (isEnglish) "Select Time" else "اختيار الوقت"
    }

    HandelhaBottomSheetFrame(onDismiss = onDismiss) {
        // Header Row
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(38.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(c.primarySoft),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = if (mode == HandelhaPickerMode.TIME_ONLY) Icons.Rounded.Schedule else Icons.Rounded.CalendarMonth,
                    contentDescription = null,
                    tint = c.primary,
                    modifier = Modifier.size(20.dp),
                )
            }
            Spacer(Modifier.width(10.dp))
            Text(
                text = resolvedTitle,
                fontSize = 16.5.sp,
                fontWeight = FontWeight.Bold,
                color = c.textPrimary,
                modifier = Modifier.weight(1f),
            )
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(c.surfaceSoft)
                    .clickable(onClick = onDismiss),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Rounded.Close,
                    contentDescription = if (isEnglish) "Close" else "إغلاق",
                    tint = c.textMuted,
                    modifier = Modifier.size(18.dp),
                )
            }
        }

        Spacer(Modifier.height(12.dp))

        // Live Selected Summary Banner (_SelectedSummaryBanner)
        val dateText = if (mode == HandelhaPickerMode.TIME_ONLY) {
            if (isEnglish) "Daily Schedule" else "التوقيت المحدد"
        } else {
            "${ArabicFormatters.weekdayShort(previewEpochMs)}، ${ArabicFormatters.dateFull(previewEpochMs)}"
        }
        val timeText = ArabicFormatters.timeOfDayAr(previewEpochMs)

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(
                    Brush.horizontalGradient(
                        colors = listOf(c.primarySoft, c.surfaceSoft),
                    ),
                    RoundedCornerShape(18.dp),
                )
                .border(1.dp, c.primary.copy(alpha = 0.25f), RoundedCornerShape(18.dp))
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (isEnglish) "Selected" else "الموعد المختار",
                    fontSize = 11.5.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.primary,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = dateText,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.textPrimary,
                )
            }
            if (mode != HandelhaPickerMode.DATE_ONLY) {
                Spacer(Modifier.width(8.dp))
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(c.primary)
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                ) {
                    Text(
                        text = timeText,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.textOnPrimary,
                    )
                }
            }
        }

        // Date / Time Mode Tabs (_DateTimeModeTabs)
        if (mode == HandelhaPickerMode.DATE_TIME) {
            Spacer(Modifier.height(12.dp))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(c.surfaceSoft, RoundedCornerShape(16.dp))
                    .border(1.dp, c.border, RoundedCornerShape(16.dp))
                    .padding(4.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                DateTimeTabSegment(
                    icon = Icons.Rounded.CalendarToday,
                    label = if (isEnglish) "Date" else "التاريخ",
                    selected = activeTab == 0,
                    onClick = { activeTab = 0 },
                    modifier = Modifier.weight(1f).testTag("picker_tab_date"),
                )
                DateTimeTabSegment(
                    icon = Icons.Rounded.AccessTimeFilled,
                    label = if (isEnglish) "Time" else "الوقت",
                    selected = activeTab == 1,
                    onClick = { activeTab = 1 },
                    modifier = Modifier.weight(1f).testTag("picker_tab_time"),
                )
            }
        }

        Spacer(Modifier.height(12.dp))

        val showTimeView = mode == HandelhaPickerMode.TIME_ONLY ||
            (mode == HandelhaPickerMode.DATE_TIME && activeTab == 1)

        if (showTimeView) {
            TimePickerSection(
                hour24 = hour24,
                minute = minute,
                isEnglish = isEnglish,
                includeLateNightPreset = mode == HandelhaPickerMode.TIME_ONLY,
                onTimeChanged = { newH, newM ->
                    hour24 = newH
                    minute = newM
                },
            )
        } else {
            DateCalendarSection(
                selectedYear = selectedYear,
                selectedMonth0 = selectedMonth0,
                selectedDay = selectedDay,
                displayedYear = displayedYear,
                displayedMonth0 = displayedMonth0,
                isEnglish = isEnglish,
                showFuturePresets = showFuturePresets,
                onSelectDate = ::selectCalendarDate,
                onShiftMonth = ::shiftDisplayedMonth,
                onJumpToTodayMonth = { y, m0 ->
                    displayedYear = y
                    displayedMonth0 = m0
                },
            )
        }

        Spacer(Modifier.height(14.dp))
        HorizontalDivider(color = c.divider.copy(alpha = 0.7f))
        Spacer(Modifier.height(12.dp))

        // Confirm & Cancel Buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OutlinedButton(
                onClick = onDismiss,
                modifier = Modifier.weight(1f).height(48.dp).testTag("picker_cancel_button"),
                shape = RoundedCornerShape(16.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, c.border),
            ) {
                Text(
                    text = if (isEnglish) "Cancel" else "إلغاء",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.textSecondary,
                )
            }
            Button(
                onClick = { onConfirm(previewEpochMs) },
                modifier = Modifier.weight(2f).height(48.dp).testTag("picker_confirm_button"),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = c.primary,
                    contentColor = c.textOnPrimary,
                ),
            ) {
                Icon(Icons.Rounded.Check, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                val confirmText = when (mode) {
                    HandelhaPickerMode.TIME_ONLY -> if (isEnglish) "Confirm Time" else "اعتماد الوقت"
                    HandelhaPickerMode.DATE_ONLY -> if (isEnglish) "Confirm Date" else "اعتماد التاريخ"
                    HandelhaPickerMode.DATE_TIME -> if (isEnglish) "Confirm Schedule" else "تأكيد الموعد"
                }
                Text(
                    text = confirmText,
                    fontSize = 14.5.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

@Composable
private fun DateTimeTabSegment(
    icon: ImageVector,
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = HandelhaTheme.colors
    val shape = RoundedCornerShape(12.dp)
    Row(
        modifier = modifier
            .clip(shape)
            .background(if (selected) c.primarySoft else Color.Transparent, shape)
            .border(
                width = 1.dp,
                color = if (selected) c.primary.copy(alpha = 0.35f) else Color.Transparent,
                shape = shape,
            )
            .clickable(onClick = onClick)
            .padding(vertical = 9.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = if (selected) c.primary else c.textSecondary,
            modifier = Modifier.size(16.dp),
        )
        Spacer(Modifier.width(6.dp))
        Text(
            text = label,
            fontSize = 13.5.sp,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.SemiBold,
            color = if (selected) c.primary else c.textSecondary,
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DateCalendarSection(
    selectedYear: Int,
    selectedMonth0: Int,
    selectedDay: Int,
    displayedYear: Int,
    displayedMonth0: Int,
    isEnglish: Boolean,
    showFuturePresets: Boolean,
    onSelectDate: (year: Int, month0: Int, day: Int) -> Unit,
    onShiftMonth: (Int) -> Unit,
    onJumpToTodayMonth: (year: Int, month0: Int) -> Unit,
) {
    val c = HandelhaTheme.colors
    val todayCal = remember {
        Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
    }
    val todayYear = todayCal.get(Calendar.YEAR)
    val todayMonth0 = todayCal.get(Calendar.MONTH)
    val todayDay = todayCal.get(Calendar.DAY_OF_MONTH)

    data class DatePreset(val label: String, val year: Int, val month0: Int, val day: Int)

    val presets = remember(isEnglish, showFuturePresets, todayYear, todayMonth0, todayDay) {
        fun addDays(days: Int): Triple<Int, Int, Int> {
            val cal = (todayCal.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, days) }
            return Triple(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH))
        }
        fun addMonths(months: Int): Triple<Int, Int, Int> {
            val cal = (todayCal.clone() as Calendar).apply { add(Calendar.MONTH, months) }
            return Triple(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH))
        }
        if (showFuturePresets) {
            val w1 = addDays(7)
            val w2 = addDays(14)
            val m1 = addMonths(1)
            val m3 = addMonths(3)
            listOf(
                DatePreset(if (isEnglish) "In 1 week" else "بعد أسبوع", w1.first, w1.second, w1.third),
                DatePreset(if (isEnglish) "In 2 weeks" else "بعد أسبوعين", w2.first, w2.second, w2.third),
                DatePreset(if (isEnglish) "In 1 month" else "بعد شهر", m1.first, m1.second, m1.third),
                DatePreset(if (isEnglish) "In 3 months" else "بعد ٣ شهور", m3.first, m3.second, m3.third),
            )
        } else {
            val tmr = addDays(1)
            val d2 = addDays(2)
            val w1 = addDays(7)
            listOf(
                DatePreset(if (isEnglish) "Today" else "النهارده", todayYear, todayMonth0, todayDay),
                DatePreset(if (isEnglish) "Tomorrow" else "بكرة", tmr.first, tmr.second, tmr.third),
                DatePreset(if (isEnglish) "In 2 days" else "بعد يومين", d2.first, d2.second, d2.third),
                DatePreset(if (isEnglish) "Next week" else "الأسبوع الجاي", w1.first, w1.second, w1.third),
            )
        }
    }

    val monthCal = remember(displayedYear, displayedMonth0) {
        Calendar.getInstance().apply {
            set(Calendar.YEAR, displayedYear)
            set(Calendar.MONTH, displayedMonth0)
            set(Calendar.DAY_OF_MONTH, 1)
        }
    }
    val daysInMonth = monthCal.getActualMaximum(Calendar.DAY_OF_MONTH)
    val firstDayOfWeek = monthCal.get(Calendar.DAY_OF_WEEK) // Sunday = 1 .. Saturday = 7
    val leadingEmptyCount = if (isEnglish) {
        // Sunday = 0 .. Saturday = 6
        (firstDayOfWeek - 1) % 7
    } else {
        // Saturday = 0, Sunday = 1, Monday = 2 ... Friday = 6
        when (firstDayOfWeek) {
            Calendar.SATURDAY -> 0
            Calendar.SUNDAY -> 1
            Calendar.MONDAY -> 2
            Calendar.TUESDAY -> 3
            Calendar.WEDNESDAY -> 4
            Calendar.THURSDAY -> 5
            Calendar.FRIDAY -> 6
            else -> 0
        }
    }

    val totalCells = ((leadingEmptyCount + daysInMonth + 6) / 7) * 7
    val rowCount = totalCells / 7
    val weekdayLabels = if (isEnglish) {
        listOf("Su", "Mo", "Tu", "We", "Th", "Fr", "Sa")
    } else {
        listOf("س", "ح", "ن", "ث", "ر", "خ", "ج")
    }
    val isViewingTodayMonth = displayedYear == todayYear && displayedMonth0 == todayMonth0

    Column(modifier = Modifier.fillMaxWidth()) {
        // Quick Date Presets
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            presets.forEach { preset ->
                val isSelected = selectedYear == preset.year &&
                    selectedMonth0 == preset.month0 &&
                    selectedDay == preset.day
                QuickPresetChip(
                    label = preset.label,
                    selected = isSelected,
                    onClick = { onSelectDate(preset.year, preset.month0, preset.day) },
                )
            }
        }

        Spacer(Modifier.height(14.dp))

        // Monthly Calendar Card
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(22.dp))
                .background(c.surfaceSoft, RoundedCornerShape(22.dp))
                .border(1.dp, c.border.copy(alpha = 0.7f), RoundedCornerShape(22.dp))
                .padding(start = 12.dp, top = 12.dp, end = 12.dp, bottom = 14.dp),
        ) {
            // Month header & navigation buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                MonthNavButton(
                    icon = Icons.Rounded.ChevronLeft,
                    onClick = { onShiftMonth(if (isEnglish) -1 else 1) },
                )
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = "${ArabicFormatters.monthName(displayedMonth0 + 1)} ${ArabicFormatters.toArabicDigits(displayedYear)}",
                        fontSize = 14.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.textPrimary,
                        textAlign = TextAlign.Center,
                    )
                    if (!isViewingTodayMonth) {
                        Text(
                            text = if (isEnglish) "Jump to current month" else "العودة للشهر الحالي",
                            fontSize = 11.5.sp,
                            fontWeight = FontWeight.Bold,
                            color = c.primary,
                            modifier = Modifier
                                .padding(top = 2.dp)
                                .clickable { onJumpToTodayMonth(todayYear, todayMonth0) },
                        )
                    }
                }
                MonthNavButton(
                    icon = Icons.Rounded.ChevronRight,
                    onClick = { onShiftMonth(if (isEnglish) 1 else -1) },
                )
            }

            Spacer(Modifier.height(10.dp))

            // Weekday labels row
            Row(modifier = Modifier.fillMaxWidth()) {
                weekdayLabels.forEach { lbl ->
                    Box(
                        modifier = Modifier.weight(1f),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = lbl,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = c.textMuted,
                        )
                    }
                }
            }

            Spacer(Modifier.height(8.dp))

            // Month days grid
            for (r in 0 until rowCount) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 2.dp),
                ) {
                    for (col in 0 until 7) {
                        val cellIndex = r * 7 + col
                        val dayNumber = cellIndex - leadingEmptyCount + 1
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .padding(2.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            if (dayNumber in 1..daysInMonth) {
                                val isSelected = displayedYear == selectedYear &&
                                    displayedMonth0 == selectedMonth0 &&
                                    dayNumber == selectedDay
                                val isToday = displayedYear == todayYear &&
                                    displayedMonth0 == todayMonth0 &&
                                    dayNumber == todayDay
                                val cellShape = RoundedCornerShape(12.dp)

                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(36.dp)
                                        .then(
                                            if (isSelected) {
                                                Modifier.shadow(
                                                    elevation = 6.dp,
                                                    shape = cellShape,
                                                    ambientColor = c.primary.copy(alpha = 0.28f),
                                                )
                                            } else {
                                                Modifier
                                            },
                                        )
                                        .clip(cellShape)
                                        .background(
                                            when {
                                                isSelected -> c.primary
                                                isToday -> c.primarySoft
                                                else -> Color.Transparent
                                            },
                                            cellShape,
                                        )
                                        .then(
                                            if (isToday && !isSelected) {
                                                Modifier.border(1.dp, c.primary.copy(alpha = 0.45f), cellShape)
                                            } else {
                                                Modifier
                                            },
                                        )
                                        .clickable {
                                            onSelectDate(displayedYear, displayedMonth0, dayNumber)
                                        }
                                        .testTag("calendar_day_$dayNumber"),
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    verticalArrangement = Arrangement.Center,
                                ) {
                                    Text(
                                        text = ArabicFormatters.toArabicDigits(dayNumber),
                                        fontSize = 13.5.sp,
                                        fontWeight = if (isSelected || isToday) FontWeight.Bold else FontWeight.SemiBold,
                                        color = when {
                                            isSelected -> c.textOnPrimary
                                            isToday -> c.primary
                                            else -> c.textPrimary
                                        },
                                    )
                                    if (isToday && !isSelected) {
                                        Box(
                                            modifier = Modifier
                                                .padding(top = 1.dp)
                                                .size(4.dp)
                                                .clip(CircleShape)
                                                .background(c.primary),
                                        )
                                    }
                                }
                            } else {
                                Spacer(Modifier.height(36.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun TimePickerSection(
    hour24: Int,
    minute: Int,
    isEnglish: Boolean,
    includeLateNightPreset: Boolean,
    onTimeChanged: (hour24: Int, minute: Int) -> Unit,
) {
    val c = HandelhaTheme.colors

    data class TimePreset(val label: String, val h: Int, val m: Int)

    val timePresets = buildList {
        add(TimePreset(if (isEnglish) "9:00 AM" else "٩:٠٠ ص", 9, 0))
        add(TimePreset(if (isEnglish) "12:30 PM" else "١٢:٣٠ م", 12, 30))
        add(TimePreset(if (isEnglish) "4:00 PM" else "٤:٠٠ م", 16, 0))
        add(TimePreset(if (isEnglish) "8:00 PM" else "٨:٠٠ م", 20, 0))
        if (includeLateNightPreset) {
            add(TimePreset(if (isEnglish) "11:00 PM" else "١١:٠٠ م", 23, 0))
        }
    }

    val quickMinutes = listOf(0, 15, 30, 45)
    val isPm = hour24 >= 12
    val hour12 = if (hour24 % 12 == 0) 12 else hour24 % 12

    fun setHour12(newH12: Int) {
        val clamped = newH12.coerceIn(1, 12)
        val nextH24 = if (isPm) {
            if (clamped == 12) 12 else clamped + 12
        } else {
            if (clamped == 12) 0 else clamped
        }
        onTimeChanged(nextH24, minute)
    }

    fun setPeriod(pm: Boolean) {
        if (pm == isPm) return
        val nextH24 = if (pm) (hour24 + 12) % 24 else (hour24 - 12 + 24) % 24
        onTimeChanged(nextH24, minute)
    }

    Column(modifier = Modifier.fillMaxWidth()) {
        // Quick Time Presets
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            timePresets.forEach { preset ->
                QuickPresetChip(
                    label = preset.label,
                    selected = hour24 == preset.h && minute == preset.m,
                    onClick = { onTimeChanged(preset.h, preset.m) },
                )
            }
        }

        Spacer(Modifier.height(14.dp))

        // Time Wheel Card (_TimeWheelCard)
        val hourListState = rememberLazyListState(initialFirstVisibleItemIndex = (hour12 - 1).coerceIn(0, 11))
        val minuteListState = rememberLazyListState(initialFirstVisibleItemIndex = minute.coerceIn(0, 59))

        LaunchedEffect(hour12) {
            hourListState.animateScrollToItem((hour12 - 1).coerceIn(0, 11))
        }
        LaunchedEffect(minute) {
            minuteListState.animateScrollToItem(minute.coerceIn(0, 59))
        }

        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(22.dp))
                    .background(c.surfaceSoft, RoundedCornerShape(22.dp))
                    .border(1.dp, c.border.copy(alpha = 0.7f), RoundedCornerShape(22.dp))
                    .padding(14.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    // Hour Wheel Column
                    Column(
                        modifier = Modifier.weight(1f),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        IconButton(
                            onClick = { setHour12(if (hour12 == 12) 1 else hour12 + 1) },
                            modifier = Modifier.size(28.dp),
                        ) {
                            Icon(Icons.Rounded.KeyboardArrowUp, contentDescription = null, tint = c.textSecondary)
                        }
                        LazyColumn(
                            state = hourListState,
                            modifier = Modifier.height(110.dp).fillMaxWidth(),
                            contentPadding = PaddingValues(vertical = 32.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            items(12) { idx ->
                                val val12 = idx + 1
                                val selected = val12 == hour12
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(44.dp)
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(if (selected) c.primarySoft else Color.Transparent)
                                        .then(
                                            if (selected) {
                                                Modifier.border(1.dp, c.primary.copy(alpha = 0.35f), RoundedCornerShape(12.dp))
                                            } else {
                                                Modifier
                                            },
                                        )
                                        .clickable { setHour12(val12) },
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Text(
                                        text = ArabicFormatters.toArabicDigits(val12),
                                        fontSize = 20.sp,
                                        fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                                        color = if (selected) c.primary else c.textMuted,
                                    )
                                }
                            }
                        }
                        IconButton(
                            onClick = { setHour12(if (hour12 == 1) 12 else hour12 - 1) },
                            modifier = Modifier.size(28.dp),
                        ) {
                            Icon(Icons.Rounded.KeyboardArrowDown, contentDescription = null, tint = c.textSecondary)
                        }
                    }

                    Text(
                        text = ":",
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.primary,
                        modifier = Modifier.padding(horizontal = 6.dp),
                    )

                    // Minute Wheel Column
                    Column(
                        modifier = Modifier.weight(1f),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        IconButton(
                            onClick = { onTimeChanged(hour24, (minute + 5) % 60) },
                            modifier = Modifier.size(28.dp),
                        ) {
                            Icon(Icons.Rounded.KeyboardArrowUp, contentDescription = null, tint = c.textSecondary)
                        }
                        LazyColumn(
                            state = minuteListState,
                            modifier = Modifier.height(110.dp).fillMaxWidth(),
                            contentPadding = PaddingValues(vertical = 32.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            items(60) { mIdx ->
                                val selected = mIdx == minute
                                val label = ArabicFormatters.toArabicDigits(mIdx.toString().padStart(2, '0'))
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(44.dp)
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(if (selected) c.primarySoft else Color.Transparent)
                                        .then(
                                            if (selected) {
                                                Modifier.border(1.dp, c.primary.copy(alpha = 0.35f), RoundedCornerShape(12.dp))
                                            } else {
                                                Modifier
                                            },
                                        )
                                        .clickable { onTimeChanged(hour24, mIdx) },
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Text(
                                        text = label,
                                        fontSize = 20.sp,
                                        fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                                        color = if (selected) c.primary else c.textMuted,
                                    )
                                }
                            }
                        }
                        IconButton(
                            onClick = { onTimeChanged(hour24, (minute - 5 + 60) % 60) },
                            modifier = Modifier.size(28.dp),
                        ) {
                            Icon(Icons.Rounded.KeyboardArrowDown, contentDescription = null, tint = c.textSecondary)
                        }
                    }

                    Spacer(Modifier.width(10.dp))

                    // AM / PM Toggle Column (_PeriodTile)
                    Column(
                        modifier = Modifier
                            .width(66.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(c.surface, RoundedCornerShape(14.dp))
                            .border(1.dp, c.border.copy(alpha = 0.75f), RoundedCornerShape(14.dp))
                            .padding(4.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        PeriodTile(
                            label = if (isEnglish) "AM" else "ص",
                            selected = !isPm,
                            onClick = { setPeriod(false) },
                        )
                        PeriodTile(
                            label = if (isEnglish) "PM" else "م",
                            selected = isPm,
                            onClick = { setPeriod(true) },
                        )
                    }
                }
            }
        }

        Spacer(Modifier.height(12.dp))

        // Quick 15-Minute Chips Row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(c.surfaceSoft, RoundedCornerShape(16.dp))
                .border(1.dp, c.border.copy(alpha = 0.65f), RoundedCornerShape(16.dp))
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Rounded.Bolt, contentDescription = null, tint = c.primary, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text(
                text = if (isEnglish) "Minutes" else "الدقائق",
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = c.textSecondary,
            )
            Spacer(Modifier.width(10.dp))
            Row(
                modifier = Modifier.weight(1f),
                horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.End),
            ) {
                quickMinutes.forEach { m ->
                    val label = ":${ArabicFormatters.toArabicDigits(m.toString().padStart(2, '0'))}"
                    QuickPresetChip(
                        label = label,
                        selected = minute == m,
                        compact = true,
                        onClick = { onTimeChanged(hour24, m) },
                    )
                }
            }
        }
    }
}

@Composable
private fun PeriodTile(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val c = HandelhaTheme.colors
    val shape = RoundedCornerShape(10.dp)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(if (selected) c.primary else Color.Transparent, shape)
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            color = if (selected) c.textOnPrimary else c.textSecondary,
        )
    }
}

@Composable
private fun QuickPresetChip(
    label: String,
    selected: Boolean,
    compact: Boolean = false,
    onClick: () -> Unit,
) {
    val c = HandelhaTheme.colors
    val shape = RoundedCornerShape(14.dp)
    Box(
        modifier = Modifier
            .clip(shape)
            .background(if (selected) c.primary else c.surfaceSoft, shape)
            .border(
                width = 1.dp,
                color = if (selected) c.primary else c.border.copy(alpha = 0.85f),
                shape = shape,
            )
            .clickable(onClick = onClick)
            .padding(
                horizontal = if (compact) 10.dp else 12.dp,
                vertical = if (compact) 6.dp else 8.dp,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            fontSize = 13.sp,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.SemiBold,
            color = if (selected) c.textOnPrimary else c.textPrimary,
        )
    }
}

@Composable
private fun MonthNavButton(
    icon: ImageVector,
    onClick: () -> Unit,
) {
    val c = HandelhaTheme.colors
    val shape = RoundedCornerShape(12.dp)
    Box(
        modifier = Modifier
            .size(34.dp)
            .clip(shape)
            .background(c.surface, shape)
            .border(1.dp, c.border.copy(alpha = 0.7f), shape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = c.textPrimary,
            modifier = Modifier.size(20.dp),
        )
    }
}

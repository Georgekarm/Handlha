import 'package:flutter/material.dart';

import '../../app/theme/app_theme_extension.dart';
import '../utils/arabic_formatters.dart';

/// منتقي التاريخ والوقت المخصص والمودرن لتطبيق «هندلها».
/// يدعم اختيار التاريخ فقط، الوقت فقط، أو التاريخ والوقت معًا مع اختصارات سريعة
/// ودعم كامل للوضعين الفاتح والداكن واللغتين العربية والإنجليزية.
class HandelhaDateTimePicker {
  HandelhaDateTimePicker._();

  /// عرض نافذة أنيقة لاختيار التاريخ والوقت معًا.
  static Future<DateTime?> showDateTimeSheet(
    BuildContext context, {
    required DateTime initialDateTime,
    DateTime? firstDate,
    DateTime? lastDate,
    String? title,
  }) {
    final isEn = Directionality.of(context) == TextDirection.ltr;
    return showModalBottomSheet<DateTime>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HandelhaDateTimeSheet(
        mode: _PickerMode.dateTime,
        initialDateTime: initialDateTime,
        firstDate: firstDate ?? DateTime(2020),
        lastDate: lastDate ?? DateTime(2035, 12, 31),
        title: title ?? (isEn ? 'Date & Time' : 'اختيار الموعد والوقت'),
        showFuturePresets: false,
      ),
    );
  }

  /// عرض نافذة أنيقة لاختيار التاريخ فقط.
  static Future<DateTime?> showDateSheet(
    BuildContext context, {
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String? title,
    bool showFuturePresets = false,
  }) {
    final isEn = Directionality.of(context) == TextDirection.ltr;
    return showModalBottomSheet<DateTime>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HandelhaDateTimeSheet(
        mode: _PickerMode.dateOnly,
        initialDateTime: DateTime(
          initialDate.year,
          initialDate.month,
          initialDate.day,
        ),
        firstDate: firstDate ?? DateTime(2020),
        lastDate: lastDate ?? DateTime(2035, 12, 31),
        title: title ?? (isEn ? 'Select Date' : 'اختيار التاريخ'),
        showFuturePresets: showFuturePresets,
      ),
    );
  }

  /// عرض نافذة أنيقة لاختيار الوقت فقط.
  static Future<TimeOfDay?> showTimeSheet(
    BuildContext context, {
    required TimeOfDay initialTime,
    String? title,
  }) async {
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final now = DateTime.now();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HandelhaDateTimeSheet(
        mode: _PickerMode.timeOnly,
        initialDateTime: DateTime(
          now.year,
          now.month,
          now.day,
          initialTime.hour,
          initialTime.minute,
        ),
        firstDate: DateTime(2020),
        lastDate: DateTime(2035, 12, 31),
        title: title ?? (isEn ? 'Select Time' : 'اختيار الوقت'),
        showFuturePresets: false,
      ),
    );
    if (picked == null) return null;
    return TimeOfDay(hour: picked.hour, minute: picked.minute);
  }
}

enum _PickerMode { dateTime, dateOnly, timeOnly }

class _HandelhaDateTimeSheet extends StatefulWidget {
  final _PickerMode mode;
  final DateTime initialDateTime;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final bool showFuturePresets;

  const _HandelhaDateTimeSheet({
    required this.mode,
    required this.initialDateTime,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.showFuturePresets,
  });

  @override
  State<_HandelhaDateTimeSheet> createState() => _HandelhaDateTimeSheetState();
}

class _HandelhaDateTimeSheetState extends State<_HandelhaDateTimeSheet> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  late int _hour24;
  late int _minute;
  int _activeTab = 0; // 0: التاريخ، 1: الوقت

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    final minDate = _dateOnly(widget.firstDate);
    final maxDate = _dateOnly(widget.lastDate);
    var initial = _dateOnly(widget.initialDateTime);
    if (initial.isBefore(minDate)) initial = minDate;
    if (initial.isAfter(maxDate)) initial = maxDate;

    _selectedDate = initial;
    _displayedMonth = DateTime(initial.year, initial.month);
    _hour24 = widget.initialDateTime.hour;
    _minute = widget.initialDateTime.minute;
    _activeTab = widget.mode == _PickerMode.timeOnly ? 1 : 0;
  }

  void _selectDate(DateTime date) {
    final normalized = _dateOnly(date);
    final minDate = _dateOnly(widget.firstDate);
    final maxDate = _dateOnly(widget.lastDate);
    var clamped = normalized;
    if (clamped.isBefore(minDate)) clamped = minDate;
    if (clamped.isAfter(maxDate)) clamped = maxDate;
    setState(() {
      _selectedDate = clamped;
      _displayedMonth = DateTime(clamped.year, clamped.month);
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + delta,
      );
    });
  }

  void _confirm() {
    Navigator.of(context).pop(
      DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _hour24,
        _minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final screenHeight = MediaQuery.sizeOf(context).height;

    final previewDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _hour24,
      _minute,
    );

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: context.isDark ? 0.45 : 0.14,
                ),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              // مقبض السحب العلوي
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // العنوان وزر الإغلاق
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: colors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            widget.mode == _PickerMode.timeOnly
                                ? Icons.schedule_rounded
                                : Icons.calendar_month_rounded,
                            color: colors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: colors.textMuted,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: colors.surfaceSoft,
                            minimumSize: const Size(36, 36),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // شريط المعاينة الحية للاختيار
                    _SelectedSummaryBanner(
                      mode: widget.mode,
                      dateTime: previewDateTime,
                      isEn: isEn,
                    ),

                    if (widget.mode == _PickerMode.dateTime) ...[
                      const SizedBox(height: 12),
                      _DateTimeModeTabs(
                        activeTab: _activeTab,
                        isEn: isEn,
                        onSelect: (index) => setState(() => _activeTab = index),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // جسم المنتقي القابل للتمرير لضمان عدم حدوث Overflow على الشاشات الصغيرة
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: widget.mode == _PickerMode.timeOnly ||
                          (widget.mode == _PickerMode.dateTime &&
                              _activeTab == 1)
                      ? _buildTimeSection(context, isEn)
                      : _buildDateSection(context, isEn),
                ),
              ),

              // أزرار التأكيد والإلغاء
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(
                    top: BorderSide(
                      color: colors.divider.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.textSecondary,
                          side: BorderSide(color: colors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Text(
                          isEn ? 'Cancel' : 'إلغاء',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _confirm,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          widget.mode == _PickerMode.timeOnly
                              ? (isEn ? 'Confirm Time' : 'اعتماد الوقت')
                              : widget.mode == _PickerMode.dateOnly
                                  ? (isEn ? 'Confirm Date' : 'اعتماد التاريخ')
                                  : (isEn ? 'Confirm Schedule' : 'تأكيد الموعد'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.textOnPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSection(BuildContext context, bool isEn) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final today = _dateOnly(DateTime.now());
    final minDate = _dateOnly(widget.firstDate);
    final maxDate = _dateOnly(widget.lastDate);

    final presets = widget.showFuturePresets
        ? <({String label, DateTime date})>[
            (
              label: isEn ? 'In 1 week' : 'بعد أسبوع',
              date: today.add(const Duration(days: 7)),
            ),
            (
              label: isEn ? 'In 2 weeks' : 'بعد أسبوعين',
              date: today.add(const Duration(days: 14)),
            ),
            (
              label: isEn ? 'In 1 month' : 'بعد شهر',
              date: DateTime(today.year, today.month + 1, today.day),
            ),
            (
              label: isEn ? 'In 3 months' : 'بعد ٣ شهور',
              date: DateTime(today.year, today.month + 3, today.day),
            ),
          ]
        : <({String label, DateTime date})>[
            (label: isEn ? 'Today' : 'النهارده', date: today),
            (
              label: isEn ? 'Tomorrow' : 'بكرة',
              date: today.add(const Duration(days: 1)),
            ),
            (
              label: isEn ? 'In 2 days' : 'بعد يومين',
              date: today.add(const Duration(days: 2)),
            ),
            (
              label: isEn ? 'Next week' : 'الأسبوع الجاي',
              date: today.add(const Duration(days: 7)),
            ),
          ];

    // حساب أيام الشهر في التقويم (السبت بداية الأسبوع في العربية، والأحد في الإنجليزية)
    final firstOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final leadingEmptyCount = isEn
        ? (firstOfMonth.weekday % 7) // الأحد = 0 .. السبت = 6
        : ((firstOfMonth.weekday + 1) % 7); // السبت = 0 .. الجمعة = 6

    final totalCells = ((leadingEmptyCount + daysInMonth + 6) ~/ 7) * 7;
    final rowCount = totalCells ~/ 7;

    final weekdayLabels = isEn
        ? const ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
        : const ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];

    final isViewingTodayMonth =
        _displayedMonth.year == today.year &&
        _displayedMonth.month == today.month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // اختصارات سريعة للتاريخ
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((preset) {
            final presetDate = _dateOnly(preset.date);
            final disabled =
                presetDate.isBefore(minDate) || presetDate.isAfter(maxDate);
            final selected = presetDate == _selectedDate;
            return _QuickPresetChip(
              label: preset.label,
              selected: selected,
              enabled: !disabled,
              onTap: () => _selectDate(presetDate),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // بطاقة التقويم الشهرية المخصصة
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          decoration: BoxDecoration(
            color: colors.surfaceSoft,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Column(
            children: [
              // رأس الشهر وأزرار التنقل
              Row(
                children: [
                  _MonthNavButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _changeMonth(isEn ? -1 : 1),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${ArabicFormatters.monthName(_displayedMonth.month)} ${ArabicFormatters.toArabicDigits(_displayedMonth.year)}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (!isViewingTodayMonth)
                          GestureDetector(
                            onTap: () => setState(() {
                              _displayedMonth = DateTime(today.year, today.month);
                            }),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                isEn ? 'Jump to current month' : 'العودة للشهر الحالي',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _MonthNavButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _changeMonth(isEn ? 1 : -1),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // أسماء أيام الأسبوع
              Row(
                children: weekdayLabels
                    .map(
                      (label) => Expanded(
                        child: Center(
                          child: Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),

              // شبكة أيام الشهر
              for (var r = 0; r < rowCount; r++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      for (var c = 0; c < 7; c++)
                        Expanded(
                          child: _buildDayCell(
                            context: context,
                            cellIndex: r * 7 + c,
                            leadingEmptyCount: leadingEmptyCount,
                            daysInMonth: daysInMonth,
                            today: today,
                            minDate: minDate,
                            maxDate: maxDate,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayCell({
    required BuildContext context,
    required int cellIndex,
    required int leadingEmptyCount,
    required int daysInMonth,
    required DateTime today,
    required DateTime minDate,
    required DateTime maxDate,
  }) {
    final dayNumber = cellIndex - leadingEmptyCount + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 38);
    }

    final colors = context.appColors;
    final theme = Theme.of(context);
    final cellDate = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      dayNumber,
    );
    final isDisabled = cellDate.isBefore(minDate) || cellDate.isAfter(maxDate);
    final isSelected = cellDate == _selectedDate;
    final isToday = cellDate == today;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : () => _selectDate(cellDate),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary
                  : isToday
                      ? colors.primarySoft
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isToday && !isSelected
                  ? Border.all(color: colors.primary.withValues(alpha: 0.45))
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  ArabicFormatters.toArabicDigits(dayNumber),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? colors.textOnPrimary
                        : isDisabled
                            ? colors.textMuted.withValues(alpha: 0.45)
                            : isToday
                                ? colors.primary
                                : colors.textPrimary,
                  ),
                ),
                if (isToday && !isSelected)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSection(BuildContext context, bool isEn) {
    final colors = context.appColors;
    final timePresets = <({String label, int hour, int minute})>[
      (label: isEn ? '9:00 AM' : '٩:٠٠ ص', hour: 9, minute: 0),
      (label: isEn ? '12:30 PM' : '١٢:٣٠ م', hour: 12, minute: 30),
      (label: isEn ? '4:00 PM' : '٤:٠٠ م', hour: 16, minute: 0),
      (label: isEn ? '8:00 PM' : '٨:٠٠ م', hour: 20, minute: 0),
      if (widget.mode == _PickerMode.timeOnly)
        (label: isEn ? '11:00 PM' : '١١:٠٠ م', hour: 23, minute: 0),
    ];

    const quickMinutes = [0, 15, 30, 45];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // اختصارات سريعة للأوقات
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: timePresets.map((preset) {
            final selected =
                _hour24 == preset.hour && _minute == preset.minute;
            return _QuickPresetChip(
              label: preset.label,
              selected: selected,
              enabled: true,
              onTap: () => setState(() {
                _hour24 = preset.hour;
                _minute = preset.minute;
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // بكرات الساعة والدقائق الحديثة
        _TimeWheelCard(
          hour24: _hour24,
          minute: _minute,
          isEn: isEn,
          onChanged: (newHour24, newMinute) {
            setState(() {
              _hour24 = newHour24;
              _minute = newMinute;
            });
          },
        ),
        const SizedBox(height: 12),

        // أزرار ربع ساعة سريعة للدقائق
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border.withValues(alpha: 0.65)),
          ),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                isEn ? 'Minutes' : 'الدقائق',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: quickMinutes.map((m) {
                    final selected = _minute == m;
                    final label =
                        ':${ArabicFormatters.toArabicDigits(m.toString().padLeft(2, '0'))}';
                    return _QuickPresetChip(
                      label: label,
                      selected: selected,
                      enabled: true,
                      compact: true,
                      onTap: () => setState(() => _minute = m),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedSummaryBanner extends StatelessWidget {
  final _PickerMode mode;
  final DateTime dateTime;
  final bool isEn;

  const _SelectedSummaryBanner({
    required this.mode,
    required this.dateTime,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final dateText = mode == _PickerMode.timeOnly
        ? (isEn ? 'Daily Schedule' : 'التوقيت المحدد')
        : '${ArabicFormatters.weekdayShort(dateTime)}، ${ArabicFormatters.dateFull(dateTime)}';
    final timeText = ArabicFormatters.timeOfDayAr(dateTime);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primarySoft,
            colors.surfaceSoft,
          ],
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? 'Selected' : 'الموعد المختار',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (mode != _PickerMode.dateOnly) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                timeText,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.textOnPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateTimeModeTabs extends StatelessWidget {
  final int activeTab;
  final bool isEn;
  final ValueChanged<int> onSelect;

  const _DateTimeModeTabs({
    required this.activeTab,
    required this.isEn,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              icon: Icons.calendar_today_rounded,
              label: isEn ? 'Date' : 'التاريخ',
              selected: activeTab == 0,
              onTap: () => onSelect(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentButton(
              icon: Icons.access_time_filled_rounded,
              label: isEn ? 'Time' : 'الوقت',
              selected: activeTab == 1,
              onTap: () => onSelect(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? colors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? colors.primary.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? colors.primary : colors.textSecondary,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final bool compact;
  final VoidCallback onTap;

  const _QuickPresetChip({
    required this.label,
    required this.selected,
    required this.enabled,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary
              : enabled
                  ? colors.surfaceSoft
                  : colors.surfaceMuted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? colors.primary
                : colors.border.withValues(alpha: enabled ? 0.85 : 0.4),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected
                    ? colors.textOnPrimary
                    : enabled
                        ? colors.textPrimary
                        : colors.textMuted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Icon(icon, size: 20, color: colors.textPrimary),
        ),
      ),
    );
  }
}

class _TimeWheelCard extends StatefulWidget {
  final int hour24;
  final int minute;
  final bool isEn;
  final void Function(int hour24, int minute) onChanged;

  const _TimeWheelCard({
    required this.hour24,
    required this.minute,
    required this.isEn,
    required this.onChanged,
  });

  @override
  State<_TimeWheelCard> createState() => _TimeWheelCardState();
}

class _TimeWheelCardState extends State<_TimeWheelCard> {
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  bool _isSyncingFromWidget = false;

  int get _hour12Index {
    final h12 = widget.hour24 % 12 == 0 ? 12 : widget.hour24 % 12;
    return h12 - 1; // 0..11 corresponds to 1..12
  }

  bool get _isPm => widget.hour24 >= 12;

  @override
  void initState() {
    super.initState();
    _hourController = FixedExtentScrollController(initialItem: _hour12Index);
    _minuteController = FixedExtentScrollController(initialItem: widget.minute);
  }

  @override
  void didUpdateWidget(covariant _TimeWheelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldHour12Index =
        (oldWidget.hour24 % 12 == 0 ? 12 : oldWidget.hour24 % 12) - 1;
    if (oldHour12Index != _hour12Index && _hourController.hasClients) {
      if (_hourController.selectedItem != _hour12Index) {
        _syncWheel(_hourController, _hour12Index);
      }
    }
    if (oldWidget.minute != widget.minute && _minuteController.hasClients) {
      if (_minuteController.selectedItem != widget.minute) {
        _syncWheel(_minuteController, widget.minute);
      }
    }
  }

  Future<void> _syncWheel(FixedExtentScrollController controller, int index) async {
    _isSyncingFromWidget = true;
    try {
      await controller.animateToItem(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _isSyncingFromWidget = false;
    }
  }

  void _updateHour12Index(int index) {
    if (_isSyncingFromWidget) return;
    final h12 = (index % 12) + 1;
    final newHour24 = _isPm ? (h12 == 12 ? 12 : h12 + 12) : (h12 == 12 ? 0 : h12);
    widget.onChanged(newHour24, widget.minute);
  }

  void _updateMinute(int minuteIndex) {
    if (_isSyncingFromWidget) return;
    widget.onChanged(widget.hour24, minuteIndex.clamp(0, 59));
  }

  void _setPeriod(bool pm) {
    if (pm == _isPm) return;
    final newHour24 = pm ? (widget.hour24 + 12) % 24 : (widget.hour24 - 12) % 24;
    widget.onChanged(newHour24, widget.minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 152,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // شريط تمييز المنتصف
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.35),
                  ),
                ),
              ),
              Row(
                children: [
                  // بكرة الساعات
                  Expanded(
                    child: ListWheelScrollView.useDelegate(
                      controller: _hourController,
                      itemExtent: 44,
                      perspective: 0.004,
                      diameterRatio: 1.5,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: _updateHour12Index,
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 12,
                        builder: (context, index) {
                          final val = index + 1;
                          final selected = index == _hour12Index;
                          return Center(
                            child: Text(
                              ArabicFormatters.toArabicDigits(val),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: selected
                                    ? colors.primary
                                    : colors.textMuted,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  Text(
                    ':',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.primary,
                    ),
                  ),

                  // بكرة الدقائق
                  Expanded(
                    child: ListWheelScrollView.useDelegate(
                      controller: _minuteController,
                      itemExtent: 44,
                      perspective: 0.004,
                      diameterRatio: 1.5,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: _updateMinute,
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 60,
                        builder: (context, index) {
                          final selected = index == widget.minute;
                          final text = ArabicFormatters.toArabicDigits(
                            index.toString().padLeft(2, '0'),
                          );
                          return Center(
                            child: Text(
                              text,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: selected
                                    ? colors.primary
                                    : colors.textMuted,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // مفتاح صباحًا / مساءً
                  Container(
                    width: 66,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.75),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PeriodTile(
                          label: widget.isEn ? 'AM' : 'ص',
                          selected: !_isPm,
                          onTap: () => _setPeriod(false),
                        ),
                        const SizedBox(height: 4),
                        _PeriodTile(
                          label: widget.isEn ? 'PM' : 'م',
                          selected: _isPm,
                          onTap: () => _setPeriod(true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: selected ? colors.textOnPrimary : colors.textSecondary,
              ),
        ),
      ),
    );
  }
}

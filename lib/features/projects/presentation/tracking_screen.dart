import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  int _selectedDay = 16;

  // Mock days data for October 2026: (completedTasks, isFuture)
  // Weekday layout starts Saturday to Friday
  final Map<int, int> _tasksCompletedPerDay = {
    1: 1, 2: 2, 3: 0, 4: 3, 5: 1, 6: 0, 7: 2,
    8: 1, 9: 0, 10: 2, 11: 1, 12: 3, 13: 0, 14: 1,
    15: 2, 16: 3, // Today is 16
  };

  Color _getCellColor(int day, bool isDark) {
    if (day > 16) {
      return isDark ? AppColors.darkSurface : AppColors.surfaceSoft;
    }
    final count = _tasksCompletedPerDay[day] ?? 0;
    if (count == 0) {
      return isDark ? const Color(0xFF13201D) : const Color(0xFFE8EFEA);
    } else if (count == 1) {
      return isDark ? const Color(0xFF1D3B35) : const Color(0xFFC3E3DB);
    } else if (count == 2) {
      return isDark ? const Color(0xFF28564E) : const Color(0xFF90D0C3);
    } else {
      return isDark ? const Color(0xFF387A6F) : const Color(0xFF65BEAE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textMutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            // Top Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المتابعة',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'نشاطك في كل المشاريع والمهام',
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.tune_rounded, size: 20, color: textColor),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stat Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إنجاز النهارده',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '٣ من ٨ مهام • خطوة بخطوة',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '٣٨٪',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Calendar Matrix Container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month Selector Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_right_rounded, color: textSecColor),
                        onPressed: () {},
                      ),
                      Text(
                        'أكتوبر ٢٠٢٦',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_left_rounded, color: textSecColor),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Weekday headers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      'سبت', 'أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'
                    ].map((w) => Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textMutedColor,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Grid of Days (October 2026 starts on Thursday, so days 1..31)
                  // For a clean presentation aligned with the PDF:
                  _buildCalendarDaysGrid(isDark, borderColor, textColor, textMutedColor, primaryColor),

                  const SizedBox(height: 20),
                  Divider(color: borderColor, height: 1),
                  const SizedBox(height: 14),

                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('أقل', style: TextStyle(fontSize: 11, color: textMutedColor)),
                          const SizedBox(width: 6),
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: isDark ? const Color(0xFF1D3B35) : const Color(0xFFC3E3DB), borderRadius: BorderRadius.circular(3))),
                          const SizedBox(width: 4),
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: isDark ? const Color(0xFF28564E) : const Color(0xFF90D0C3), borderRadius: BorderRadius.circular(3))),
                          const SizedBox(width: 4),
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: isDark ? const Color(0xFF387A6F) : const Color(0xFF65BEAE), borderRadius: BorderRadius.circular(3))),
                          const SizedBox(width: 6),
                          Text('أكثر', style: TextStyle(fontSize: 11, color: textMutedColor)),
                        ],
                      ),
                      Text(
                        'الرقم = مهام مكتملة',
                        style: TextStyle(fontSize: 11, color: textMutedColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '٠ = بدون نشاط  •  — = أيام جاية',
                        style: TextStyle(fontSize: 11, color: textMutedColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'السجل قبل النهارده توضيحي • حتى ١٦ أكتوبر',
                    style: TextStyle(fontSize: 10, color: textMutedColor.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Today's summary card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.chevron_left_rounded, color: textMutedColor),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'الجمعة ١٦ أكتوبر • النهارده',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '٣ من ٨ مهام خلصوا • باقي ٥',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarDaysGrid(
    bool isDark,
    Color borderColor,
    Color textColor,
    Color textMutedColor,
    Color primaryColor,
  ) {
    // Week rows matching the PDF
    final weeks = [
      [27, 28, 29, 30, 0, 1, 2], // 1, 2
      [3, 4, 5, 6, 7, 8, 9],
      [10, 11, 12, 13, 14, 15, 16],
      [17, 18, 19, 20, 21, 22, 23],
      [24, 25, 26, 27, 28, 29, 30],
      [31, 0, 0, 0, 0, 0, 0],
    ];

    return Column(
      children: weeks.map((week) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: week.map((day) {
              if (day == 0) {
                return const Expanded(child: SizedBox(height: 46));
              }
              final isToday = day == 16;
              final isPast = day <= 16;
              final count = _tasksCompletedPerDay[day] ?? 0;
              final cellColor = _getCellColor(day, isDark);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDay = day),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: cellColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isToday
                              ? primaryColor
                              : (_selectedDay == day ? textColor : borderColor.withValues(alpha: 0.5)),
                          width: isToday ? 1.8 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _toArabicDigits(day),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                              color: isToday ? primaryColor : (isPast ? textColor : textMutedColor),
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (isPast)
                            Text(
                              '${_toArabicDigits(count)} ✓',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: count > 0 ? (isDark ? Colors.white70 : Colors.black87) : textMutedColor,
                              ),
                            )
                          else
                            Text(
                              '—',
                              style: TextStyle(fontSize: 11, color: textMutedColor),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  String _toArabicDigits(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number.toString().split('').map((char) {
      final n = int.tryParse(char);
      return n != null ? arabicDigits[n] : char;
    }).join('');
  }
}

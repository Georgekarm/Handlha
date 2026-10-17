import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
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

    final user = ref.watch(authNotifierProvider).value;
    final displayName = (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? user.displayName!
        : 'أحمد';

    final tasksState = ref.watch(todayTasksProvider);
    final tasks = tasksState.value ?? const <Task>[];
    final done = tasks.where((t) => t.status == TaskStatus.completed).length;
    final total = tasks.isEmpty ? 8 : tasks.length;
    final completedCount = tasks.isEmpty ? 3 : done;
    final percent = total > 0 ? (completedCount / total * 100).round() : 38;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            // Header Row: Notification icon on left, Date & Greeting on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notification Button with green dot
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.notifications_none_rounded, color: textColor, size: 22),
                        onPressed: () => context.push('/notifications'),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),

                // Date & Greeting
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'الجمعة، ١٦ أكتوبر ٢٠٢٦',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: textMutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'صباح الخير، $displayName',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Top Status Cards Row: [طاقتك إيه؟] & [٣ من ٨ مهام خلصوا]
            Row(
              children: [
                // Right Card in LTR (Left in Arabic layout): "طاقتك إيه؟"
                Expanded(
                  child: InkWell(
                    onTap: () => _showEnergyPicker(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.chevron_left_rounded, size: 20, color: textMutedColor),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'طاقتك إيه؟',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'اختار على قدّك',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface2 : const Color(0xFFEFF5F3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.battery_charging_full_rounded, color: primaryColor, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Left Card in LTR (Right in Arabic layout): "٣ من ٨ مهام خلصوا" with 38%
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        // Circular progress ring
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: percent / 100,
                                strokeWidth: 3.5,
                                backgroundColor: isDark ? AppColors.darkDivider : AppColors.divider,
                                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                              ),
                              Text(
                                '$percent٪',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$completedCount من $total',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'مهام خلصوا',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // "خطوتك الجاية" Card (Next Step Card)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card Header: "خطوتك الجاية" & "أولوية عالية" Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF4A2B28) : const Color(0xFFFDE8E6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? AppColors.salmonBadge.withValues(alpha: 0.4) : const Color(0xFFF8B4AC),
                          ),
                        ),
                        child: Text(
                          'أولوية عالية',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.salmonBadge : const Color(0xFFD6453D),
                          ),
                        ),
                      ),
                      Text(
                        'خطوتك الجاية',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textSecColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    'مراجعة تدفق المهام وتجربة المستخدم',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Subtitle
                  Text(
                    'إطلاق نسخة هندلها • قبل ١٢:٠٠ م',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Big Action Button: "ابدأ التركيز • ٢٥ دقيقة"
                  ElevatedButton(
                    onPressed: () {
                      context.push(
                        '/focus-session',
                        extra: 'مراجعة تدفق المهام وتجربة المستخدم',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ابدأ التركيز • ٢٥ دقيقة',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkBackground : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.play_arrow_rounded,
                          size: 20,
                          color: isDark ? AppColors.darkBackground : Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section "وبعدها" & "كل المهام"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => context.go('/tasks'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'كل المهام',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textSecColor,
                      ),
                    ),
                  ),
                ),
                Text(
                  'وبعدها',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Task item card: "إعداد جلسة الاختبار التفاعلية"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'إعداد جلسة الاختبار التفاعلية',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '١:٠٠ م • ٣٠ دقيقة • طاقة متوسطة',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: textMutedColor, width: 1.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Project Card: "إطلاق نسخة هندلها"
            InkWell(
              onTap: () => context.push(
                '/project-workspace',
                extra: {
                  'id': '1',
                  'title': 'إطلاق نسخة هندلها',
                  'goal': 'تجربة مريحة لتنظيم اليوم والبدء بهدوء.',
                },
              ),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    // Header: Folder icon + Title + Chevron
                    Row(
                      children: [
                        Icon(Icons.chevron_left_rounded, color: textMutedColor, size: 20),
                        const Spacer(),
                        Text(
                          'إطلاق نسخة هندلها',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.folder_outlined, color: textSecColor, size: 20),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: 0.50,
                        minHeight: 6,
                        backgroundColor: isDark ? AppColors.darkDivider : AppColors.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Subtitle: Date & %
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '٥٠٪',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textSecColor,
                          ),
                        ),
                        Text(
                          'الموعد ٣١ أكتوبر ٢٠٢٦',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEnergyPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final bgColor = isDark ? AppColors.darkSurface : Colors.white;
        final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'طاقتك النهارده إيه؟',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 16),
                for (final energy in ['طاقة قليلة (خطوات هادية وبسيطة)', 'طاقة متوسطة (تركيز متوازن)', 'طاقة عالية (مستعد لأكبر خطوة)'])
                  ListTile(
                    title: Text(energy, textAlign: TextAlign.right, style: TextStyle(color: textColor)),
                    leading: const Icon(Icons.bolt_rounded, color: AppColors.darkPrimary),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تم ضبط يومك على: $energy'), behavior: SnackBarBehavior.floating),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

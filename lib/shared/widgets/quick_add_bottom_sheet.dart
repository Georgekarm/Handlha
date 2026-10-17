import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../features/tasks/presentation/task_providers.dart';

/// نافذة الاختيار الرئيسية للإضافة: «نفضيّ اللي في بالك؟» (Page 9 في التصميم)
class QuickAddBottomSheet extends ConsumerStatefulWidget {
  const QuickAddBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickAddBottomSheet(),
    );
  }

  @override
  ConsumerState<QuickAddBottomSheet> createState() => _QuickAddBottomSheetState();
}

class _QuickAddBottomSheetState extends ConsumerState<QuickAddBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textMutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final cardBg = isDark ? const Color(0xFF1B2B28) : const Color(0xFFEFF5F3);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row: Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'نفضيّ اللي في بالك؟',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'اختار بداية تناسبك',
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Card 1: "قولها بطريقتك" (الذكاء الاصطناعي - الإضافة الذكية)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: primaryColor, size: 24),
                      Text(
                        'قولها بطريقتك',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '«فكّرني أبعت الدعوات بكرة الصبح». هنفهم التفاصيل، وإنت تأكدها الأول.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecColor,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showSmartAddFlow(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'إضافة ذكية',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkBackground : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: isDark ? AppColors.darkBackground : Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Option 2: أكتب مهمة يدوي (Page 15)
            _ActionOptionRow(
              title: 'أكتب مهمة يدوي',
              subtitle: 'عنوان وتفاصيل',
              icon: Icons.edit_outlined,
              borderColor: borderColor,
              textColor: textColor,
              textSecColor: textSecColor,
              onTap: () {
                Navigator.pop(context);
                _showManualTaskSheet(context);
              },
            ),
            const SizedBox(height: 10),

            // Option 3: أبدأ مشروع (Page 20)
            _ActionOptionRow(
              title: 'أبدأ مشروع',
              subtitle: 'هدف وخطوات',
              icon: Icons.create_new_folder_outlined,
              borderColor: borderColor,
              textColor: textColor,
              textSecColor: textSecColor,
              onTap: () {
                Navigator.pop(context);
                _showNewProjectSheet(context);
              },
            ),
            const SizedBox(height: 10),

            // Option 4: أفكّر مع المساعد
            _ActionOptionRow(
              title: 'أفكّر مع المساعد',
              subtitle: 'نرتّبها سوا',
              icon: Icons.chat_bubble_outline_rounded,
              borderColor: borderColor,
              textColor: textColor,
              textSecColor: textSecColor,
              onTap: () {
                Navigator.pop(context);
                context.push('/chat');
              },
            ),

            const SizedBox(height: 20),
            Center(
              child: Text(
                'كل اقتراح ذكي محتاج تأكيدك قبل الإضافة.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: textMutedColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSmartAddFlow(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SmartAddReviewSheet(),
    );
  }

  void _showManualTaskSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ManualAddTaskSheet(),
    );
  }

  void _showNewProjectSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewProjectSheet(),
    );
  }
}

class _ActionOptionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color borderColor;
  final Color textColor;
  final Color textSecColor;
  final VoidCallback onTap;

  const _ActionOptionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.borderColor,
    required this.textColor,
    required this.textSecColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: textSecColor),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 20, color: textSecColor),
          ],
        ),
      ),
    );
  }
}

/// نافذة مراجعة الإضافة الذكية: Pages 8, 16, 17, 18
class SmartAddReviewSheet extends ConsumerStatefulWidget {
  const SmartAddReviewSheet({super.key});

  @override
  ConsumerState<SmartAddReviewSheet> createState() => _SmartAddReviewSheetState();
}

class _SmartAddReviewSheetState extends ConsumerState<SmartAddReviewSheet> {
  int _stateMode = 0; // 0: Normal review (Page 8), 1: Clarification (Page 16), 2: Error (Page 17), 3: Success (Page 18)

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final surface2 = isDark ? AppColors.darkSurface2 : const Color(0xFFF3F7F5);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    if (_stateMode == 3) {
      // Success confirmation state (Page 18)
      return Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(alpha: 0.2),
                  border: Border.all(color: primaryColor, width: 2),
                ),
                child: Icon(Icons.check_rounded, color: primaryColor, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                'اتضافت، وذهنك أهدى',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 8),
              Text('إرسال دعوات جلسة الاختبار', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 4),
              Text('١٧ أكتوبر • ١٠:٠٠ ص', style: TextStyle(fontSize: 13, color: textSecColor)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.undo_rounded, size: 18, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'تمت إضافة مهمة جديدة • تراجع عن الإضافة',
                      style: TextStyle(fontSize: 12, color: textSecColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('تمام، ارجع لمهامي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkBackground : Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_stateMode == 2) {
      // Error state (Page 17)
      return Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A2B28),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.salmonBadge),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'ما قدرناش نفهم الطلب دلوقتي',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'حصلت مشكلة في الاتصال. كلامك لسه موجود؛ مفيش مهمة اتضافت.',
                      style: TextStyle(fontSize: 12.5, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => setState(() => _stateMode = 0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('جرّب تاني ↻', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkBackground : Colors.white)),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: borderColor),
                ),
                child: Text('أكمّل يدوي', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkDivider : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'إضافة ذكية',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      Text(
                        'راجع اللي فهمناه قبل الإضافة',
                        style: TextStyle(fontSize: 12, color: textSecColor),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Original prompt card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: textSecColor),
                        Text(
                          'كلامك زي ما هو',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'فكّرني أبعت دعوات الاختبار بكرة الساعة ١٠ الصبح، مهمة عالية لمشروع هندلها وطاقة متوسطة.',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 13, color: textColor, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'ده اللي فهمته • كل التفاصيل قابلة للتعديل',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11.5, color: textSecColor),
              ),
              const SizedBox(height: 10),

              // Form summary items
              _DetailField(label: 'عنوان المهمة', value: 'إرسال دعوات جلسة الاختبار', hasEdit: true, textColor: textColor, textSecColor: textSecColor, borderColor: borderColor),
              const SizedBox(height: 8),
              _DetailField(label: 'التاريخ', value: 'بكرة، ١٧ أكتوبر ٢٠٢٦', icon: Icons.calendar_today_outlined, textColor: textColor, textSecColor: textSecColor, borderColor: borderColor),
              const SizedBox(height: 8),
              _DetailField(label: 'الوقت', value: '١٠:٠٠ ص', icon: Icons.access_time_rounded, textColor: textColor, textSecColor: textSecColor, borderColor: borderColor),
              const SizedBox(height: 8),
              _DetailField(label: 'الأولوية', value: 'عالية', icon: Icons.flag_outlined, textColor: textColor, textSecColor: textSecColor, borderColor: borderColor),
              const SizedBox(height: 8),
              _DetailField(label: 'الطاقة', value: 'متوسطة', icon: Icons.battery_charging_full_rounded, textColor: textColor, textSecColor: textSecColor, borderColor: borderColor),
              const SizedBox(height: 8),
              _DetailField(label: 'المشروع', value: 'إطلاق نسخة هندلها', icon: Icons.folder_outlined, textColor: textColor, textSecColor: textSecColor, borderColor: borderColor),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  'لسه ما أضفناش حاجة. القرار ليك.',
                  style: TextStyle(fontSize: 11.5, color: textSecColor),
                ),
              ),
              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: () async {
                  await ref.read(todayTasksProvider.notifier).createTask(
                    title: 'إرسال دعوات جلسة الاختبار',
                  );
                  setState(() => _stateMode = 3);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'تأكيد وإضافة المهمة ✓',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkBackground : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool hasEdit;
  final Color textColor;
  final Color textSecColor;
  final Color borderColor;

  const _DetailField({
    required this.label,
    required this.value,
    this.icon,
    this.hasEdit = false,
    required this.textColor,
    required this.textSecColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          if (hasEdit)
            Icon(Icons.edit_outlined, size: 16, color: textSecColor)
          else
            Icon(Icons.chevron_left_rounded, size: 18, color: textSecColor),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: textSecColor)),
          if (icon != null) ...[
            const SizedBox(width: 8),
            Icon(icon, size: 16, color: textSecColor),
          ],
        ],
      ),
    );
  }
}

/// إضافة مهمة يدوي (Page 15)
class ManualAddTaskSheet extends ConsumerStatefulWidget {
  const ManualAddTaskSheet({super.key});

  @override
  ConsumerState<ManualAddTaskSheet> createState() => _ManualAddTaskSheetState();
}

class _ManualAddTaskSheetState extends ConsumerState<ManualAddTaskSheet> {
  final _titleCtrl = TextEditingController(text: 'إرسال دعوات جلسة الاختبار');

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkDivider : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('مهمة جديدة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor)),
                      Text('تفاصيل بسيطة وتبدأ', style: TextStyle(fontSize: 12, color: textSecColor)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text('عنوان المهمة', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: textSecColor)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.edit_outlined, size: 18, color: textSecColor),
                ),
              ),
              const SizedBox(height: 12),

              _DetailField(label: 'الموعد', value: '١٧ أكتوبر ٢٠٢٦، ١٠:٠٠ ص', icon: Icons.calendar_month_outlined, textColor: textColor, textSecColor: textSecColor, borderColor: borderColor),
              const SizedBox(height: 10),
              _DetailField(label: 'الأولوية', value: 'عالية', icon: Icons.flag_outlined, textColor: textColor, textSecColor: textSecColor, borderColor: borderColor),
              const SizedBox(height: 10),
              _DetailField(label: 'المشروع', value: 'إطلاق نسخة هندلها', icon: Icons.folder_outlined, textColor: textColor, textSecColor: textSecColor, borderColor: borderColor),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.battery_charging_full_rounded, size: 18, color: textSecColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تفصيل اختياري: إضافة طاقة متوسطة ومدة ١٥ دقيقة تساعدك تختار وقت مناسب.',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11, color: textSecColor, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () async {
                  await ref.read(todayTasksProvider.notifier).createTask(title: _titleCtrl.text.trim());
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('احفظ المهمة ✓', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkBackground : Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// مشروع جديد (Page 20)
class NewProjectSheet extends StatefulWidget {
  const NewProjectSheet({super.key});

  @override
  State<NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends State<NewProjectSheet> {
  final _titleCtrl = TextEditingController(text: 'مشروع جديد');
  final _goalCtrl = TextEditingController(text: 'أخلص أساسيات البحث مع المستخدمين');
  int _selectedColorIndex = 0;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    final colors = [
      AppColors.darkPrimary,
      AppColors.darkSecondary,
      AppColors.darkAccent,
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkDivider : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('مشروع جديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor)),
                      Text('هدف واضح، وبداية صغيرة', style: TextStyle(fontSize: 12, color: textSecColor)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text('اسم المشروع', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: textSecColor)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.edit_outlined, size: 18, color: textSecColor),
                ),
              ),
              const SizedBox(height: 12),

              Text('الهدف', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: textSecColor)),
              const SizedBox(height: 6),
              TextField(
                controller: _goalCtrl,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.flag_outlined, size: 18, color: textSecColor),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _DetailField(label: 'المجهود', value: 'ساعتين أسبوعيًا', icon: Icons.access_time_rounded, textColor: textColor, textSecColor: textSecColor, borderColor: borderColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DetailField(label: 'الموعد', value: '١٥ نوفمبر ٢٠٢٦', icon: Icons.calendar_today_outlined, textColor: textColor, textSecColor: textSecColor, borderColor: borderColor),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(colors.length, (idx) {
                      final c = colors[idx];
                      final isSelected = _selectedColorIndex == idx;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColorIndex = idx),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  Text('لون المشروع', style: TextStyle(fontSize: 13, color: textSecColor)),
                ],
              ),
              const SizedBox(height: 16),

              // AI breakdown notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.assistantPurpleSoft : const Color(0xFFEEEBF8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.darkSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'اقترح تقسيمة ذكية: هنعرض مراحل ومهام تراجعها، مش هنضيفها تلقائيًا.',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11.5, color: textColor, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showAiBreakdown(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('إنشاء ومراجعة التقسيمة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkBackground : Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAiBreakdown(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiBreakdownSheet(),
    );
  }
}

/// تقسيم الهدف سوا (Page 27)
class AiBreakdownSheet extends StatefulWidget {
  const AiBreakdownSheet({super.key});

  @override
  State<AiBreakdownSheet> createState() => _AiBreakdownSheetState();
}

class _AiBreakdownSheetState extends State<AiBreakdownSheet> {
  final Set<int> _selectedTasks = {0, 1};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkDivider : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('نقسّم الهدف سوا', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor)),
                      Text('اقتراح لمشروع خطة تعلّم جديدة', style: TextStyle(fontSize: 12, color: textSecColor)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Project header card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.assistantPurpleSoft : const Color(0xFFF0ECF8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تعلّم أساسيات البحث مع المستخدمين', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('المقدّر: ٨ ساعات • الثقة: متوسطة', style: TextStyle(fontSize: 12, color: textSecColor)),
                        Text('٤ أسابيع • ساعتين أسبوعيًا', style: TextStyle(fontSize: 12, color: textSecColor)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Missing info notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.help_outline_rounded, size: 20, color: primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'معلومة ناقصة قبل ما نعتمد: عندك خبرة سابقة بالمقابلات؟ اخترت «مبتدئ» مؤقتًا. عدّلها لو مختلفة.',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11.5, color: textSecColor, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Phase 1
              Text('الأساسيات • ٣ ساعات', textAlign: TextAlign.right, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
              const SizedBox(height: 8),
              _TaskCheckboxRow(
                title: 'قراءة دليل المقابلات • ٦٠ دقيقة',
                selected: _selectedTasks.contains(0),
                onChanged: (v) => setState(() => v! ? _selectedTasks.add(0) : _selectedTasks.remove(0)),
                textColor: textColor,
              ),
              _TaskCheckboxRow(
                title: 'تجهيز ٥ أسئلة مفتوحة • ساعتين',
                selected: _selectedTasks.contains(1),
                onChanged: (v) => setState(() => v! ? _selectedTasks.add(1) : _selectedTasks.remove(1)),
                textColor: textColor,
              ),

              const SizedBox(height: 12),
              // Phase 2
              Text('التطبيق • ٥ ساعات', textAlign: TextAlign.right, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
              const SizedBox(height: 8),
              _TaskCheckboxRow(
                title: 'مقابلة تجريبية • ساعتين',
                selected: _selectedTasks.contains(2),
                onChanged: (v) => setState(() => v! ? _selectedTasks.add(2) : _selectedTasks.remove(2)),
                textColor: textColor,
              ),
              _TaskCheckboxRow(
                title: 'تلخيص الملاحظات • ٣ ساعات',
                selected: _selectedTasks.contains(3),
                onChanged: (v) => setState(() => v! ? _selectedTasks.add(3) : _selectedTasks.remove(3)),
                textColor: textColor,
              ),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  'محدّد: ${_selectedTasks.length} من ٤ • مفيش تغيير قبل موافقتك',
                  style: TextStyle(fontSize: 12, color: textSecColor),
                ),
              ),
              const SizedBox(height: 14),

              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('اعتمد المحدد (${_selectedTasks.length}) ✓', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkBackground : Colors.white)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: borderColor),
                      ),
                      child: Text('رفض الاقتراح', style: TextStyle(color: textSecColor)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _selectedTasks.addAll([0, 1, 2, 3]));
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: borderColor),
                      ),
                      child: Text('اعتماد الكل (٤)', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
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

class _TaskCheckboxRow extends StatelessWidget {
  final String title;
  final bool selected;
  final ValueChanged<bool?> onChanged;
  final Color textColor;

  const _TaskCheckboxRow({
    required this.title,
    required this.selected,
    required this.onChanged,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: onChanged,
            ),
            const Spacer(),
            Text(title, style: TextStyle(fontSize: 13, color: textColor, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

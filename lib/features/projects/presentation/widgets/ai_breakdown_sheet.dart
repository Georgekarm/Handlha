import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class ProposedPhaseItem {
  final String title;
  final String duration;
  final List<ProposedTaskItem> tasks;

  ProposedPhaseItem({
    required this.title,
    required this.duration,
    required this.tasks,
  });
}

class ProposedTaskItem {
  final String title;
  final String duration;
  final String priority;
  final Color priorityColor;
  final String? dependency;

  ProposedTaskItem({
    required this.title,
    required this.duration,
    required this.priority,
    required this.priorityColor,
    this.dependency,
  });
}

/// نافذة تقسيم المشروع بالذكاء الاصطناعي (AI Breakdown Modal)
class AiBreakdownModal extends StatefulWidget {
  final String projectTitle;
  final String projectGoal;
  final VoidCallback? onAccepted;

  const AiBreakdownModal({
    super.key,
    this.projectTitle = 'مشروع تطبيق Flutter',
    this.projectGoal = 'إطلاق أول نسخة تجريبية من التطبيق',
    this.onAccepted,
  });

  static Future<void> show(BuildContext context, {
    String projectTitle = 'مشروع تطبيق Flutter',
    String projectGoal = 'إطلاق أول نسخة تجريبية من التطبيق',
    VoidCallback? onAccepted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiBreakdownModal(
        projectTitle: projectTitle,
        projectGoal: projectGoal,
        onAccepted: onAccepted,
      ),
    );
  }

  @override
  State<AiBreakdownModal> createState() => _AiBreakdownModalState();
}

class _AiBreakdownModalState extends State<AiBreakdownModal> {
  bool _answeredQuestion = false;
  String? _userClarification;
  final _answerCtrl = TextEditingController();
  bool _isAnsweringNow = false;

  late List<ProposedPhaseItem> _phases;

  @override
  void initState() {
    super.initState();
    _phases = [
      ProposedPhaseItem(
        title: 'المرحلة 1: التخطيط والمتطلبات الأساسية',
        duration: '5 ساعات',
        tasks: [
          ProposedTaskItem(
            title: 'تحديد ميزات الـ MVP واستبعاد المشتتات',
            duration: '2س',
            priority: 'عالية',
            priorityColor: AppColors.accentWarm,
          ),
          ProposedTaskItem(
            title: 'هندسة بنية المجلدات وإدارة الحالة (Riverpod)',
            duration: '3س',
            priority: 'متوسطة',
            priorityColor: AppColors.warning,
            dependency: 'اعتماد الميزات',
          ),
        ],
      ),
      ProposedPhaseItem(
        title: 'المرحلة 2: التصميم وبناء هوية الهدوء',
        duration: '7 ساعات',
        tasks: [
          ProposedTaskItem(
            title: 'تصميم شاشات التدفق الرئيسي ونظام الألوان',
            duration: '4س',
            priority: 'عالية',
            priorityColor: AppColors.accentWarm,
          ),
          ProposedTaskItem(
            title: 'مراجعة المكونات المشتركة ونصوص الواجهة',
            duration: '3س',
            priority: 'هادئة',
            priorityColor: AppColors.primaryDark,
            dependency: 'اكتمال التصميم الأولي',
          ),
        ],
      ),
      ProposedPhaseItem(
        title: 'المرحلة 3: التطوير والربط الذكي',
        duration: '8 ساعات',
        tasks: [
          ProposedTaskItem(
            title: 'برمجة شاشة تسجيل الدخول والمصادقة',
            duration: '3س',
            priority: 'عالية',
            priorityColor: AppColors.danger,
          ),
          ProposedTaskItem(
            title: 'بناء تبويبات مساحة المشروع الخمسة',
            duration: '5س',
            priority: 'عالية',
            priorityColor: AppColors.accentWarm,
            dependency: 'شاشة المصادقة',
          ),
        ],
      ),
      ProposedPhaseItem(
        title: 'المرحلة 4: الاختبار والإطلاق التجريبي',
        duration: '4 ساعات',
        tasks: [
          ProposedTaskItem(
            title: 'فحص الأداء والتجربة على مختلف مقاسات الشاشات',
            duration: '2.5س',
            priority: 'متوسطة',
            priorityColor: AppColors.warning,
          ),
          ProposedTaskItem(
            title: 'إنشاء أول نسخة APK ونشرها للمختبرين',
            duration: '1.5س',
            priority: 'عالية',
            priorityColor: AppColors.accentWarm,
            dependency: 'فحص الأداء',
          ),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  void _handleAcceptAll() {
    Navigator.of(context).pop();
    widget.onAccepted?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تم اعتماد الخطة وتقسيم المشروع بنجاح إلى 4 مراحل و18 مهمة ✨'),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Header Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_fix_high_rounded,
                      color: AppColors.primaryDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تقسيم المشروع بالذكاء الاصطناعي',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'تم صياغة خطة هادئة ومدروسة تناسب هدفك',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 1. الملخص العلوي (Top Summary Card)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.flag_rounded, size: 16, color: AppColors.primaryDark),
                            const SizedBox(width: 6),
                            Text(
                              'الهدف الأساسي:',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.projectGoal,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Stats row (24h, 4 phases, 18 tasks)
                        Row(
                          children: [
                            _SummaryPill(
                              label: 'التقدير الأولي',
                              value: '24 ساعة',
                              icon: Icons.access_time_rounded,
                              color: AppColors.primaryDark,
                            ),
                            const SizedBox(width: 8),
                            _SummaryPill(
                              label: 'المراحل',
                              value: '4 مراحل',
                              icon: Icons.layers_rounded,
                              color: AppColors.focus,
                            ),
                            const SizedBox(width: 8),
                            _SummaryPill(
                              label: 'المهام المقترحة',
                              value: '18 مهمة',
                              icon: Icons.checklist_rounded,
                              color: AppColors.accentWarm,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 2. بطاقة الاستفسار (نقط محتاجة توضيح)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.help_outline_rounded,
                                size: 16,
                                color: Color(0xFF8E6A1B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'نقط محتاجة توضيح:',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: const Color(0xFF6E5114),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '«تسجيل الدخول هيكون بإيميل بس ولا سوشيال كمان (Google / Apple)؟ علشان نقدر نحدد الوقت بدقة أكبر.»',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_answeredQuestion)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'تم التوضيح: ${_userClarification ?? "إيميل وسوشيال معاً"} (تم تحديث الخطة)',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_isAnsweringNow) ...[
                          TextField(
                            controller: _answerCtrl,
                            decoration: InputDecoration(
                              hintText: 'اكتب إجابتك هنا...',
                              filled: true,
                              fillColor: AppColors.surface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _answeredQuestion = true;
                                    _userClarification = _answerCtrl.text.isNotEmpty
                                        ? _answerCtrl.text
                                        : 'إيميل فقط في المرحلة الأولى';
                                    _isAnsweringNow = false;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('تأكيد الإجابة'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => setState(() => _isAnsweringNow = false),
                                child: const Text('إلغاء'),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => setState(() => _isAnsweringNow = true),
                                icon: const Icon(Icons.reply_rounded, size: 16),
                                label: const Text('أجاوب دلوقتي'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8E6A1B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _answeredQuestion = true;
                                    _userClarification = 'تم تأجيل التوضيح لاحقاً';
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF6E5114),
                                  side: const BorderSide(color: Color(0xFFC9A75D)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('سيبها لاحقاً'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. قائمة المراحل المقترحة (Accordion)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'المراحل والمهام المقترحة:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'قابلة للتعديل والطي',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  ..._phases.map((phase) => _buildPhaseAccordion(phase, theme)),
                ],
              ),
            ),

            // 4. أزرار التحكم (Bottom Actions)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _handleAcceptAll,
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: const Text('قبول الكل واعتماد الخطة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('يمكنك الآن تعديل أو حذف أي خطوة في القائمة'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('تعديل'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'إلغاء',
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseAccordion(ProposedPhaseItem phase, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
          initiallyExpanded: phase == _phases.first,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              color: AppColors.primaryDark,
              size: 18,
            ),
          ),
          title: Text(
            phase.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            '${phase.duration} • ${phase.tasks.length} مهام',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: phase.tasks.map((task) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: task.priorityColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                task.priority,
                                style: TextStyle(
                                  color: task.priorityColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 13, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              task.duration,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                            if (task.dependency != null) ...[
                              const SizedBox(width: 12),
                              const Icon(Icons.link_rounded, size: 13, color: AppColors.focus),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'تعتمد على: ${task.dependency}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.focus,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

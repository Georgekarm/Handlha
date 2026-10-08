import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class PhaseDetailModel {
  final String id;
  final String title;
  final double progressPercent;
  final String hoursSpent;
  final int totalTasks;
  final int completedTasks;
  final String description;
  final String notes;
  final List<String> dependencies;
  final String nextStepTitle;
  final List<PhaseTaskItem> tasks;

  PhaseDetailModel({
    required this.id,
    required this.title,
    required this.progressPercent,
    required this.hoursSpent,
    required this.totalTasks,
    required this.completedTasks,
    required this.description,
    required this.notes,
    required this.dependencies,
    required this.nextStepTitle,
    required this.tasks,
  });
}

class PhaseTaskItem {
  final String title;
  final String duration;
  bool isCompleted;

  PhaseTaskItem({
    required this.title,
    required this.duration,
    this.isCompleted = false,
  });
}

/// تبويب المراحل (Phases Tab)
class PhasesTabView extends StatefulWidget {
  const PhasesTabView({super.key});

  @override
  State<PhasesTabView> createState() => _PhasesTabViewState();
}

class _PhasesTabViewState extends State<PhasesTabView> {
  int _selectedPhaseIndex = 2; // Default to "مرحلة التطوير" opened

  late List<PhaseDetailModel> _phases;

  @override
  void initState() {
    super.initState();
    _phases = [
      PhaseDetailModel(
        id: '1',
        title: 'التخطيط وتحديد المتطلبات',
        progressPercent: 1.0,
        hoursSpent: '5 ساعات',
        totalTasks: 4,
        completedTasks: 4,
        description: 'تحديد ميزات الـ MVP وهيكلة البنية العامة للمشروع وتوزيع المهام.',
        notes: 'تم اعتماد خطة العمل وجداول التسليم بنجاح.',
        dependencies: ['اعتماد فكرة المشروع من الفريق'],
        nextStepTitle: 'المرحلة مكتملة بالكامل ✓',
        tasks: [
          PhaseTaskItem(title: 'تحديد ميزات الـ MVP واستبعاد المشتتات', duration: '2س', isCompleted: true),
          PhaseTaskItem(title: 'اختيار الحزم والمكتبات المعتمدة', duration: '1س', isCompleted: true),
          PhaseTaskItem(title: 'هندسة بنية المجلدات وإدارة الحالة', duration: '2س', isCompleted: true),
        ],
      ),
      PhaseDetailModel(
        id: '2',
        title: 'التصميم وبناء هوية الهدوء',
        progressPercent: 0.75,
        hoursSpent: '7 ساعات',
        totalTasks: 6,
        completedTasks: 4,
        description: 'تصميم الواجهات بنظام الألوان المريح (Sage / Warm Ivory) وضبط الخطوط.',
        notes: 'ملاحظة: تأكد من تباين النصوص الثانوية لتناسب القراءة في الإضاءة الخافتة.',
        dependencies: ['اعتماد لوحة الألوان الهادئة'],
        nextStepTitle: 'مراجعة المكونات المشتركة ونصوص الواجهة',
        tasks: [
          PhaseTaskItem(title: 'تصميم لوحة الألوان والخطوط العربية', duration: '2س', isCompleted: true),
          PhaseTaskItem(title: 'تصميم تدفق الشاشات الرئيسية', duration: '3س', isCompleted: true),
          PhaseTaskItem(title: 'مراجعة المكونات المشتركة ونصوص الواجهة', duration: '1.5س', isCompleted: false),
          PhaseTaskItem(title: 'إعداد أيقونات التطبيق', duration: '0.5س', isCompleted: false),
        ],
      ),
      PhaseDetailModel(
        id: '3',
        title: 'مرحلة التطوير والبرمجة',
        progressPercent: 0.50,
        hoursSpent: '9 ساعات',
        totalTasks: 10,
        completedTasks: 5,
        description: 'مرحلة بناء المنطق البرمجي والشاشات وربط مزودي الحالة وقاعدة البيانات.',
        notes: 'تنبيه: رسائل الخطأ محتاجة مراجعة لغوية بسيطة باللهجة المصرية الهادئة قبل الاعتماد.',
        dependencies: ['اعتماد نسخة التصميم النهائية من المصمم'],
        nextStepTitle: 'إنهاء شاشة تسجيل الدخول والمصادقة',
        tasks: [
          PhaseTaskItem(title: 'برمجة شاشة تسجيل الدخول وإنشاء الحساب', duration: '3س', isCompleted: false),
          PhaseTaskItem(title: 'ربط واجهة برمجة التطبيقات للمصادقة', duration: '2س', isCompleted: false),
          PhaseTaskItem(title: 'بناء تبويبات مساحة المشروع الخمسة', duration: '4س', isCompleted: false),
          PhaseTaskItem(title: 'إعداد مزود المهام وحفظ الحالة محلياً', duration: '2س', isCompleted: true),
          PhaseTaskItem(title: 'تنفيذ الشاشة الرئيسية ومساحة التفريغ', duration: '3س', isCompleted: true),
        ],
      ),
      PhaseDetailModel(
        id: '4',
        title: 'الاختبار والإطلاق التجريبي',
        progressPercent: 0.20,
        hoursSpent: '2 ساعة',
        totalTasks: 5,
        completedTasks: 1,
        description: 'فحص الأداء والتجربة السلسة على مختلف مقاسات الشاشات وإصدار أول نسخة.',
        notes: 'ملاحظة: التأكد من عمل الإدخال الصوتي وسرعة الاستجابة.',
        dependencies: ['اكتمال مرحلة التطوير بنسبة 90%'],
        nextStepTitle: 'فحص استجابة واجهات الهواتف الصغيرة',
        tasks: [
          PhaseTaskItem(title: 'كتابة اختبارات الوحدة للـ Auth Provider', duration: '2س', isCompleted: false),
          PhaseTaskItem(title: 'فحص الأداء وتجربة المستخدم', duration: '1.5س', isCompleted: false),
          PhaseTaskItem(title: 'بناء ملف الـ APK التجريبي', duration: '1س', isCompleted: false),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activePhase = _phases[_selectedPhaseIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مراحل المشروع (4 مراحل)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // 1. قائمة المراحل (عرض عمودي مع نسبة الإنجاز)
          ...List.generate(_phases.length, (i) {
            final phase = _phases[i];
            final isSelected = _selectedPhaseIndex == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() => _selectedPhaseIndex = i),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primarySoft.withValues(alpha: 0.45) : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: phase.progressPercent == 1.0
                                      ? AppColors.success
                                      : (isSelected ? AppColors.primaryDark : AppColors.surfaceMuted),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: phase.progressPercent == 1.0
                                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                      : Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : AppColors.textSecondary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                phase.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${(phase.progressPercent * 100).toInt()}%',
                            style: TextStyle(
                              color: phase.progressPercent == 1.0 ? AppColors.success : AppColors.primaryDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: phase.progressPercent,
                          backgroundColor: AppColors.divider,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            phase.progressPercent == 1.0 ? AppColors.success : AppColors.primary,
                          ),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 12),

          // 2. المرحلة المفتوحة التفصيلية (Detailed Open Phase)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row of open phase
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'تفاصيل: ${activePhase.title}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${activePhase.hoursSpent} • ${activePhase.totalTasks} مهام',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  activePhase.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 16),

                // قائمة المهام الخاصة بهذه المرحلة مع Checkboxes
                Text(
                  'مهام المرحلة:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                ...activePhase.tasks.map((task) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: task.isCompleted,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) {
                          setState(() {
                            task.isCompleted = val ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                            color: task.isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          task.duration,
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                )),

                const SizedBox(height: 14),

                // ملاحظات المرحلة (Notes / Alerts)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF8E6A1B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ملاحظة المرحلة:',
                              style: TextStyle(
                                color: Color(0xFF6E5114),
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activePhase.notes,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // الاعتماديات (Dependencies)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 16, color: AppColors.focus),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'الاعتماديات:',
                              style: TextStyle(
                                color: AppColors.focus,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activePhase.dependencies.join(' • '),
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // الخطوة التالية (Next Step CTA)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('بدأت الخطوة: ${activePhase.nextStepTitle} 🚀'),
                          backgroundColor: AppColors.primaryDark,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_circle_left_outlined, size: 18),
                    label: Text('الخطوة التالية: ${activePhase.nextStepTitle}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

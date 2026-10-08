import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../tasks/domain/task.dart';
import '../../../tasks/presentation/task_providers.dart';

/// نافذة إضافة مهمة ذكية (Smart Add Task Bottom Sheet)
/// تفهم النص الطبيعي أو الصوت وتحلله إلى: الأولوية، المرحلة، المدة، الموعد
class SmartAddTaskBottomSheet extends ConsumerStatefulWidget {
  final String? initialProject;
  final VoidCallback? onTaskAdded;

  const SmartAddTaskBottomSheet({
    super.key,
    this.initialProject,
    this.onTaskAdded,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialProject,
    VoidCallback? onTaskAdded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmartAddTaskBottomSheet(
        initialProject: initialProject,
        onTaskAdded: onTaskAdded,
      ),
    );
  }

  @override
  ConsumerState<SmartAddTaskBottomSheet> createState() =>
      _SmartAddTaskBottomSheetState();
}

class _SmartAddTaskBottomSheetState
    extends ConsumerState<SmartAddTaskBottomSheet> {
  final _smartInputCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isListening = false;
  bool _isAnalyzing = false;
  bool _showForm = true;

  // Extracted/Edited parameters
  TaskPriority _priority = TaskPriority.high;
  String _phase = 'مرحلة التطوير';
  String _duration = '45 دقيقة';
  String _dueDate = 'غداً، 2:00 م';

  final List<String> _availablePhases = [
    'التخطيط',
    'التصميم',
    'مرحلة التطوير',
    'الاختبار والإطلاق',
  ];

  @override
  void initState() {
    super.initState();
    _smartInputCtrl.addListener(_onSmartInputChanged);
  }

  @override
  void dispose() {
    _smartInputCtrl.removeListener(_onSmartInputChanged);
    _smartInputCtrl.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onSmartInputChanged() {
    final text = _smartInputCtrl.text.trim();
    if (text.isEmpty) return;

    // Smart natural language understanding simulation
    setState(() {
      _titleCtrl.text = text;

      // Detect Priority
      if (text.contains('عاجل') ||
          text.contains('ضروري') ||
          text.contains('طوارئ')) {
        _priority = TaskPriority.urgent;
      } else if (text.contains('مهم') ||
          text.contains('عالي') ||
          text.contains('أولوية')) {
        _priority = TaskPriority.high;
      } else if (text.contains('هادي') ||
          text.contains('خفيف') ||
          text.contains('بسيط')) {
        _priority = TaskPriority.low;
      } else {
        _priority = TaskPriority.medium;
      }

      // Detect Phase
      if (text.contains('تصميم') ||
          text.contains('ديزاين') ||
          text.contains('UI') ||
          text.contains('واجهة')) {
        _phase = 'التصميم';
      } else if (text.contains('تطوير') ||
          text.contains('كود') ||
          text.contains('برمجة') ||
          text.contains('دخول')) {
        _phase = 'مرحلة التطوير';
      } else if (text.contains('تخطيط') ||
          text.contains('أفكار') ||
          text.contains('خطة')) {
        _phase = 'التخطيط';
      } else if (text.contains('اختبار') ||
          text.contains('تست') ||
          text.contains('إطلاق')) {
        _phase = 'الاختبار والإطلاق';
      }

      // Detect Duration
      if (text.contains('ساعة')) {
        _duration = text.contains('نص ساعة') ? '30 دقيقة' : '60 دقيقة';
      } else if (text.contains('دقيقة') || text.contains('دقايق')) {
        _duration = '25 دقيقة';
      } else {
        _duration = '45 دقيقة';
      }

      // Detect Date
      if (text.contains('النهاردة') || text.contains('اليوم')) {
        _dueDate = 'اليوم، 5:00 م';
      } else if (text.contains('بكرة') || text.contains('غداً')) {
        _dueDate = 'غداً، 2:00 م';
      } else if (text.contains('الخميس') || text.contains('الأسبوع')) {
        _dueDate = 'الخميس، 12:00 م';
      }
    });
  }

  void _applyQuickTemplate(String text) {
    _smartInputCtrl.text = text;
  }

  void _toggleVoiceInput() {
    setState(() => _isListening = !_isListening);
    if (_isListening) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() {
          _smartInputCtrl.text =
              'إنهاء شاشة تسجيل الدخول غداً الساعة 2 م محتاجة 45 دقيقة أولوية عالية';
          _isListening = false;
        });
      });
    }
  }

  Future<void> _submitTask() async {
    final title = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : _smartInputCtrl.text.trim();

    if (title.isEmpty) return;

    setState(() => _isAnalyzing = true);

    await ref.read(todayTasksProvider.notifier).createTask(
          title: title,
          priority: _priority,
        );

    if (mounted) {
      setState(() => _isAnalyzing = false);
      widget.onTaskAdded?.call();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إضافة المهمة بنجاح في $_phase'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkPrimary
              : AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final inputBg = isDark ? AppColors.darkSurface2 : AppColors.background;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.textMuted;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sheet Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkPrimarySoft
                          : AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إضافة مهمة ذكية',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'اكتبها بطريقتك أو قولها، وسيتم فهم التفاصيل وترتيبها لك',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick Input area with Mic
              Container(
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: _isListening ? primaryColor : borderColor,
                    width: _isListening ? 1.8 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _smartInputCtrl,
                      autofocus: true,
                      minLines: 2,
                      maxLines: 4,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textPrimary,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText:
                            'مثال: إنهاء شاشة تسجيل الدخول غداً الساعة 2 م، هتاخد 45 دقيقة في مرحلة التطوير...',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: textMuted,
                          fontSize: 13,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Mic Button
                        InkWell(
                          onTap: _toggleVoiceInput,
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _isListening
                                  ? (isDark
                                      ? AppColors.darkDanger.withValues(alpha: 0.2)
                                      : AppColors.dangerSoft)
                                  : (isDark
                                      ? AppColors.darkSurface
                                      : AppColors.surface),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isListening
                                    ? (isDark
                                        ? AppColors.darkDanger
                                        : AppColors.danger)
                                    : borderColor,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isListening
                                      ? Icons.mic_rounded
                                      : Icons.mic_none_rounded,
                                  color: _isListening
                                      ? (isDark
                                          ? AppColors.darkDanger
                                          : AppColors.danger)
                                      : primaryColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isListening
                                      ? 'بيسمعك دلوقتي...'
                                      : 'تسجيل صوتي',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _isListening
                                        ? (isDark
                                            ? AppColors.darkDanger
                                            : AppColors.danger)
                                        : primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Simulated speech hint chip
                        InkWell(
                          onTap: () => _applyQuickTemplate(
                              'إنهاء شاشة تسجيل الدخول بكرة 2 م محتاجة 45 دقيقة وأولوية عالية'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkPrimarySoft.withValues(alpha: 0.4)
                                  : AppColors.primarySoft.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.flash_on_rounded,
                                  size: 14,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'تجربة سريعة',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Section: منطقة تحليل النص (فهمت منك)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface2.withValues(alpha: 0.5)
                      : AppColors.surfaceSecondary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 16,
                          color: isDark
                              ? AppColors.darkWarning
                              : AppColors.warning,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'فهمت منك (شرائح ذكية قابلة للتعديل):',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Priority Chip
                        _EditableSmartChip(
                          icon: Icons.flag_rounded,
                          label: 'الأولوية: ${_getPriorityLabel(_priority)}',
                          color: _getPriorityColor(_priority, isDark),
                          onTap: () => _cyclePriority(),
                        ),
                        // Phase Chip
                        _EditableSmartChip(
                          icon: Icons.layers_rounded,
                          label: 'المرحلة: $_phase',
                          color: primaryColor,
                          onTap: () => _cyclePhase(),
                        ),
                        // Duration Chip
                        _EditableSmartChip(
                          icon: Icons.timer_outlined,
                          label: 'المدة: $_duration',
                          color: isDark
                              ? AppColors.darkSecondary
                              : AppColors.secondary,
                          onTap: () => _cycleDuration(),
                        ),
                        // Due Date Chip
                        _EditableSmartChip(
                          icon: Icons.calendar_today_rounded,
                          label: 'الموعد: $_dueDate',
                          color: isDark
                              ? AppColors.darkInfo
                              : AppColors.info,
                          onTap: () => _cycleDueDate(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Collapsible Manual Form Toggle
              InkWell(
                onTap: () => setState(() => _showForm = !_showForm),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'النموذج اليدوي للتأكيد والتعديل',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Icon(
                        _showForm
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              if (_showForm) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'اسم المهمة',
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الموعد',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: textMuted,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _dueDate,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المدة التقديرية',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: textMuted,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _duration,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'ملاحظات وتفاصيل إضافية (اختياري)',
                    prefixIcon: const Icon(Icons.description_outlined),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isAnalyzing ? null : _submitTask,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          _isAnalyzing
                              ? 'جاري الحفظ...'
                              : 'إضافة المهمة للمشروع',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: isDark
                              ? const Color(0xFF111A19)
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.input),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          // TODO: Implement Bulk Add
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.input),
                          ),
                        ),
                        child: const Text('إضافة متعددة (Bulk)'),
                      ),
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

  void _cyclePriority() {
    setState(() {
      if (_priority == TaskPriority.low) {
        _priority = TaskPriority.medium;
      } else if (_priority == TaskPriority.medium) {
        _priority = TaskPriority.high;
      } else if (_priority == TaskPriority.high) {
        _priority = TaskPriority.urgent;
      } else {
        _priority = TaskPriority.low;
      }
    });
  }

  void _cyclePhase() {
    final curIndex = _availablePhases.indexOf(_phase);
    final nextIndex = (curIndex + 1) % _availablePhases.length;
    setState(() => _phase = _availablePhases[nextIndex]);
  }

  void _cycleDuration() {
    final durations = [
      '20 دقيقة',
      '30 دقيقة',
      '45 دقيقة',
      '60 دقيقة',
      '90 دقيقة',
    ];
    final curIndex = durations.indexOf(_duration);
    final nextIndex =
        curIndex == -1 ? 0 : (curIndex + 1) % durations.length;
    setState(() => _duration = durations[nextIndex]);
  }

  void _cycleDueDate() {
    final dates = [
      'اليوم، 5:00 م',
      'غداً، 2:00 م',
      'الخميس، 12:00 م',
      'نهاية الأسبوع',
    ];
    final curIndex = dates.indexOf(_dueDate);
    final nextIndex = curIndex == -1 ? 0 : (curIndex + 1) % dates.length;
    setState(() => _dueDate = dates[nextIndex]);
  }

  String _getPriorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return 'عاجلة';
      case TaskPriority.high:
        return 'عالية';
      case TaskPriority.medium:
        return 'متوسطة';
      case TaskPriority.low:
        return 'هادئة';
    }
  }

  Color _getPriorityColor(TaskPriority priority, bool isDark) {
    switch (priority) {
      case TaskPriority.urgent:
        return isDark ? AppColors.darkDanger : AppColors.danger;
      case TaskPriority.high:
        return isDark ? AppColors.darkAccent : AppColors.accent;
      case TaskPriority.medium:
        return isDark ? AppColors.darkWarning : AppColors.warning;
      case TaskPriority.low:
        return isDark ? AppColors.darkPrimary : AppColors.primary;
    }
  }
}

class _EditableSmartChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _EditableSmartChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.touch_app_outlined,
              size: 11,
              color: color.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

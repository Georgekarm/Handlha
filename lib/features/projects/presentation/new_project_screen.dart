import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_extension.dart';
import '../../../core/result/result.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../../shared/widgets/handelha_ambient_background.dart';
import '../../../shared/widgets/handelha_bottom_nav.dart';
import '../../../shared/widgets/handelha_date_time_picker.dart';
import '../../../shared/widgets/handelha_feedback.dart';
import '../../../shared/widgets/handelha_header.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_providers.dart';
import '../domain/project.dart';
import 'project_providers.dart';

/// شاشة إنشاء مشروع جديد بتصميم نظيف متطابق مع هوية «هندلها».
class NewProjectScreen extends ConsumerStatefulWidget {
  const NewProjectScreen({super.key});

  @override
  ConsumerState<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends ConsumerState<NewProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _goalController = TextEditingController();
  final _starterStepController = TextEditingController();

  int _selectedColor = 0xFF1D6659;
  DateTime? _targetDate;
  bool _showStarterStep = false;
  bool _isSaving = false;
  bool _isDirty = false;

  static const _palette = <({int value, String arName, String enName})>[
    (value: 0xFF1D6659, arName: 'أخضر هادئ', enName: 'Deep Teal'),
    (value: 0xFF7873A6, arName: 'لافندر', enName: 'Soft Lavender'),
    (value: 0xFFC9735B, arName: 'تيراكوتا دافئ', enName: 'Warm Coral'),
    (value: 0xFF5683A5, arName: 'أزرق سماوي', enName: 'Sky Blue'),
    (value: 0xFFC89B54, arName: 'ذهبي دافئ', enName: 'Amber Gold'),
  ];

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_markDirty);
    _goalController.addListener(_markDirty);
    _starterStepController.addListener(_markDirty);
  }

  void _markDirty() {
    if (!mounted) return;
    setState(() {
      _isDirty = _titleController.text.trim().isNotEmpty ||
          _goalController.text.trim().isNotEmpty ||
          _starterStepController.text.trim().isNotEmpty ||
          _targetDate != null;
    });
  }

  @override
  void dispose() {
    _titleController.removeListener(_markDirty);
    _goalController.removeListener(_markDirty);
    _starterStepController.removeListener(_markDirty);
    _titleController.dispose();
    _goalController.dispose();
    _starterStepController.dispose();
    super.dispose();
  }

  void _navigateBack() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/projects');
      }
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleBack() async {
    final hasTextInput = _titleController.text.trim().isNotEmpty ||
        _goalController.text.trim().isNotEmpty ||
        _starterStepController.text.trim().isNotEmpty ||
        _targetDate != null;
    if (!_isDirty || !hasTextInput || _isSaving) {
      _navigateBack();
      return;
    }
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final discard = await HandelhaDialog.confirm(
      context,
      icon: Icons.edit_off_rounded,
      title: isEn ? 'Discard Draft?' : 'تجاهل المشروع الجديد؟',
      message: isEn
          ? 'Your new project details are not saved yet.'
          : 'تفاصيل المشروع لسه ما اتحفظتش. تحب تخرج بدون حفظ؟',
      confirmLabel: isEn ? 'Discard' : 'خروج',
      cancelLabel: isEn ? 'Keep Editing' : 'كمّل تعديل',
      isDanger: true,
    );
    if (discard == true && mounted) {
      _navigateBack();
    }
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await HandelhaDateTimePicker.showDateSheet(
      context,
      initialDate: _targetDate ?? today.add(const Duration(days: 21)),
      firstDate: today,
      lastDate: DateTime(today.year + 3, 12, 31),
      title: Directionality.of(context) == TextDirection.ltr
          ? 'Target Completion Date'
          : 'تاريخ الإنجاز المستهدف',
      showFuturePresets: true,
    );
    if (picked != null && mounted) {
      setState(() {
        _isDirty = true;
        _targetDate = picked;
      });
    }
  }

  void _applyDateOffset(int days, {int? months}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next = months != null
        ? DateTime(today.year, today.month + months, today.day)
        : today.add(Duration(days: days));
    setState(() {
      _isDirty = true;
      _targetDate = next;
    });
  }

  Future<void> _openTargetDateSheet() async {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEn ? 'Target Date' : 'الموعد المستهدف',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  if (_targetDate != null)
                    TextButton(
                      onPressed: () {
                        setState(() => _targetDate = null);
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        isEn ? 'Clear' : 'بدون موعد',
                        style: TextStyle(color: c.danger),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DatePresetButton(
                    label: isEn ? '1 Week' : 'بعد أسبوع',
                    onTap: () {
                      _applyDateOffset(7);
                      Navigator.pop(ctx);
                    },
                  ),
                  _DatePresetButton(
                    label: isEn ? '2 Weeks' : 'بعد أسبوعين',
                    onTap: () {
                      _applyDateOffset(14);
                      Navigator.pop(ctx);
                    },
                  ),
                  _DatePresetButton(
                    label: isEn ? '1 Month' : 'بعد شهر',
                    onTap: () {
                      _applyDateOffset(0, months: 1);
                      Navigator.pop(ctx);
                    },
                  ),
                  _DatePresetButton(
                    label: isEn ? '3 Months' : 'بعد ٣ شهور',
                    onTap: () {
                      _applyDateOffset(0, months: 3);
                      Navigator.pop(ctx);
                    },
                  ),
                  _DatePresetButton(
                    label: isEn ? 'Custom date' : 'اختر من التقويم',
                    highlighted: true,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _pickCustomDate();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    final isEn = Directionality.of(context) == TextDirection.ltr;

    if (!(_formKey.currentState?.validate() ?? false)) {
      HandelhaFeedback.showWarning(
        context,
        isEn ? 'Please name your project first.' : 'اكتب اسم المشروع الأول.',
      );
      return;
    }

    setState(() => _isSaving = true);

    final starterStep = _starterStepController.text.trim();
    final res = await ref.read(projectsProvider.notifier).createProject(
          title: _titleController.text.trim(),
          description: _goalController.text.trim().isEmpty
              ? null
              : _goalController.text.trim(),
          colorValue: _selectedColor,
          targetDate: _targetDate,
          nextStepTitle: starterStep.isEmpty ? null : starterStep,
        );

    if (!mounted) return;

    if (res is Success<Project>) {
      final project = res.data;
      if (starterStep.isNotEmpty) {
        await ref.read(allTasksProvider.notifier).createTask(
              title: starterStep,
              projectId: project.id,
              status: TaskStatus.inbox,
            );
      }
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isDirty = false;
      });

      HandelhaFeedback.showSuccess(
        context,
        isEn
            ? 'Project "${project.title}" created!'
            : 'تم إنشاء مشروع «${project.title}» بنجاح!',
      );

      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.pushReplacement(
          '/project-workspace',
          extra: {
            'id': project.id,
            'title': project.title,
            'goal': project.description ?? '',
            'color': project.colorValue.toString(),
          },
        );
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(project);
      }
    } else if (res is Failure<Project>) {
      setState(() => _isSaving = false);
      HandelhaFeedback.showError(context, res.failure.message);
    }
  }

  String _formatTargetDate(bool isEn) {
    if (_targetDate == null) {
      return isEn ? 'Choose target date' : 'اختر موعد مستهدف';
    }
    final short = ArabicFormatters.dateShort(_targetDate!);
    final year = isEn
        ? '${_targetDate!.year}'
        : ArabicFormatters.toArabicDigits(_targetDate!.year);
    return '$short $year';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final previewTitle = _titleController.text.trim().isEmpty
        ? (isEn ? 'Launch Brand' : 'إطلاق البراند')
        : _titleController.text.trim();

    return PopScope(
      canPop: !_isDirty || _isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: HandelhaAmbientBackground(
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 114),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HandelhaHeader(
                      title: isEn ? 'New Project' : 'مشروع جديد',
                      subtitle:
                          isEn ? 'Take it step by step' : 'خدها خطوة خطوة',
                      padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
                      onBack: _handleBack,
                    ),

                    // Preview Hero Card
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      decoration: BoxDecoration(
                        color: context.heroBannerBackground,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: context.heroBannerBorder,
                          width: isDark ? 1 : 0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isEn
                                ? 'Every big project starts with an idea.'
                                : 'كل مشروع كبير بيبدأ بفكرة.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  previewTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? context.limeAccent
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: context.heroPillBackground,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  isEn ? 'Preview' : 'معاينة',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? context.limeAccent
                                        : const Color(0xFFCCE8DC),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section header: تفاصيل المشروع + زر إضافة خطوة أولى
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEn ? 'Project Details' : 'تفاصيل المشروع',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setState(
                            () => _showStarterStep = !_showStarterStep,
                          ),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: context.softControlSurface,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              _showStarterStep
                                  ? Icons.remove_rounded
                                  : Icons.add_rounded,
                              size: 16,
                              color: c.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Field 0: اسم المشروع
                    Text(
                      isEn ? 'Project Name' : 'اسم المشروع',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            isEn ? 'Launch Brand' : 'إطلاق البراند',
                        filled: true,
                        fillColor: c.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: context.activeFieldBorder,
                            width: 1.4,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: context.activeFieldBorder,
                            width: 1.8,
                          ),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? (isEn
                              ? 'Project name is required'
                              : 'اكتب اسم المشروع')
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Field 1: عايز توصل لإيه؟
                    Text(
                      isEn ? 'What is your goal?' : 'عايز توصل لإيه؟',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _goalController,
                      minLines: 2,
                      maxLines: 3,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: c.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: isEn
                            ? 'Prepare a simple and organized launch this month.'
                            : 'نجهّز إطلاق بسيط ومنظم خلال الشهر ده.',
                        filled: true,
                        fillColor: c.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: c.border, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: context.activeFieldBorder,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),

                    if (_showStarterStep) ...[
                      const SizedBox(height: 14),
                      Text(
                        isEn ? 'First Step (optional)' : 'أول خطوة (اختياري)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        controller: _starterStepController,
                        style: TextStyle(fontSize: 14, color: c.textPrimary),
                        decoration: InputDecoration(
                          hintText: isEn
                              ? 'e.g. Define main milestones'
                              : 'مثال: تحديد الخطوات الأساسية للمشروع',
                          filled: true,
                          fillColor: c.surface,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Project Color Picker: لون المشروع | خلّيه سهل تميّزه
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEn ? 'Project Color' : 'لون المشروع',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          isEn
                              ? 'Make it easy to spot'
                              : 'خلّيه سهل تميّزه',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _palette.map((entry) {
                        final selected = _selectedColor == entry.value;
                        final swatchColor = Color(entry.value);
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () =>
                              setState(() => _selectedColor = entry.value),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 170),
                            width: 46,
                            height: 46,
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? (isDark ? Colors.white : swatchColor)
                                    : Colors.transparent,
                                width: 1.8,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: swatchColor,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: selected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Target Date Selector: موعد مستهدف (اختياري)
                    Text(
                      isEn
                          ? 'Target Date (optional)'
                          : 'موعد مستهدف (اختياري)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Material(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _openTargetDateSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _formatTargetDate(isEn),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: _targetDate != null
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _targetDate != null
                                        ? c.textPrimary
                                        : c.textSecondary,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: c.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Center(
                      child: Text(
                        isEn
                            ? 'You can edit all these details later'
                            : 'تقدر تعدّل كل التفاصيل دي بعدين',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Create Project CTA
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.ctaBackground,
                          foregroundColor: context.ctaForeground,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: context.ctaForeground,
                                ),
                              )
                            : Text(
                                isEn ? 'Create Project' : 'إنشاء المشروع',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.ctaForeground,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: const HandelhaBottomNav(currentIndex: 2),
      ),
    );
  }
}

class _DatePresetButton extends StatelessWidget {
  final String label;
  final bool highlighted;
  final VoidCallback onTap;

  const _DatePresetButton({
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: highlighted
              ? context.ctaBackground
              : context.softControlSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: highlighted
                ? context.ctaForeground
                : context.appColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

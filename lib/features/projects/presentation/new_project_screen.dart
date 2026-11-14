import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_extension.dart';
import '../../../core/result/result.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../../shared/widgets/handelha_ambient_background.dart';
import '../../../shared/widgets/handelha_date_time_picker.dart';
import '../../../shared/widgets/handelha_feedback.dart';
import '../../../shared/widgets/handelha_header.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_providers.dart';
import '../domain/project.dart';
import 'project_providers.dart';

/// شاشة إنشاء مشروع جديد بتصميم عصري متكامل ومعاينة حية.
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

  int _selectedColor = 0xFF007067;
  DateTime? _targetDate;
  bool _createStarterTask = true;
  bool _isSaving = false;
  bool _isDirty = false;

  static const _palette = <({int value, String arName, String enName})>[
    (value: 0xFF007067, arName: 'فيروزي هادئ', enName: 'Calm Teal'),
    (value: 0xFF6F6B94, arName: 'لافندر', enName: 'Soft Lavender'),
    (value: 0xFF5683A5, arName: 'أزرق سماوي', enName: 'Sky Blue'),
    (value: 0xFFC9735B, arName: 'تيراكوتا دافئ', enName: 'Warm Coral'),
    (value: 0xFFC89B54, arName: 'ذهبي دافئ', enName: 'Amber Gold'),
    (value: 0xFF288E7E, arName: 'زمردي', enName: 'Sage Emerald'),
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
      title: isEn ? 'Discard Changes?' : 'تجاهل التغييرات؟',
      message: isEn
          ? 'Project details are not saved yet. Do you want to leave?'
          : 'تفاصيل المشروع لسه ما اتحفظتش. تحب تخرج من غير ما تحفظه؟',
      confirmLabel: isEn ? 'Leave' : 'خروج بدون حفظ',
      cancelLabel: isEn ? 'Continue' : 'كمّل إعداد',
      isDanger: true,
    );
    if (discard == true && mounted) {
      _navigateBack();
    }
  }

  Future<void> _pickTargetDate() async {
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
      if (starterStep.isNotEmpty && _createStarterTask) {
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

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final theme = Theme.of(context);
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final selectedAccent = Color(_selectedColor);
    final activePaletteEntry =
        _palette.firstWhere((e) => e.value == _selectedColor);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekDate = today.add(const Duration(days: 7));
    final twoWeeksDate = today.add(const Duration(days: 14));
    final oneMonthDate = DateTime(today.year, today.month + 1, today.day);
    final threeMonthsDate = DateTime(today.year, today.month + 3, today.day);

    final starterSuggestions = isEn
        ? const [
            'Define main goal & scope',
            'Break down into 3 phases',
            'Gather notes & resources',
          ]
        : const [
            'تحديد الهدف والخطوات الأساسية',
            'تقسيم المشروع لمراحل واضحة',
            'جمع المراجع والملفات اللازمة',
          ];

    final daysLeft = _targetDate == null
        ? null
        : DateTime(
            _targetDate!.year,
            _targetDate!.month,
            _targetDate!.day,
          ).difference(today).inDays;

    return PopScope(
      canPop: !_isDirty || _isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: HandelhaAmbientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                HandelhaHeader(
                  title: isEn ? 'New Project' : 'مشروع جديد',
                  subtitle: isEn
                      ? 'Shape your vision into calm milestones'
                      : 'رتّب فكرتك وحوّلها لمراحل واضحة ومريحة',
                  onBack: _handleBack,
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // بطاقة المعاينة الحية لبنر المشروع
                          _ProjectHeroPreviewCard(
                            title: _titleController.text.trim(),
                            goal: _goalController.text.trim(),
                            starterStep: _starterStepController.text.trim(),
                            accentColor: selectedAccent,
                            colorName: isEn
                                ? activePaletteEntry.enName
                                : activePaletteEntry.arName,
                            targetDate: _targetDate,
                            daysLeft: daysLeft,
                            isEn: isEn,
                          ),
                          const SizedBox(height: 16),

                          // القسم ١: اسم المشروع والهدف
                          _ProjectSectionCard(
                            icon: Icons.rocket_launch_outlined,
                            accentColor: selectedAccent,
                            title: isEn
                                ? 'Project Identity'
                                : 'اسم المشروع والرؤية',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _titleController,
                                  textInputAction: TextInputAction.next,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: isEn
                                        ? 'e.g. Semester Study Plan or New Project'
                                        : 'مثال: خطة مذاكرة الترم أو مشروع التخرج',
                                    hintStyle: TextStyle(
                                      color: c.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.folder_special_rounded,
                                      color: selectedAccent,
                                    ),
                                    filled: true,
                                    fillColor: c.surfaceSoft,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: c.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: c.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: selectedAccent,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? (isEn
                                          ? 'Project title is required'
                                          : 'اكتب اسم المشروع')
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _goalController,
                                  minLines: 3,
                                  maxLines: 4,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: c.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: isEn
                                        ? 'What outcome makes this project a success?'
                                        : 'إيه النتيجة اللي نفسك توصلها في المشروع ده؟ (اختياري)',
                                    hintStyle: TextStyle(color: c.textMuted),
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.only(bottom: 38),
                                      child: Icon(
                                        Icons.track_changes_rounded,
                                        color: c.textMuted,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: c.surfaceSoft,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: c.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: c.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: selectedAccent,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // القسم ٢: لون المشروع المميز
                          _ProjectSectionCard(
                            icon: Icons.palette_outlined,
                            accentColor: selectedAccent,
                            title: isEn ? 'Project Color Theme' : 'لون وطابع المشروع',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: selectedAccent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isEn
                                    ? activePaletteEntry.enName
                                    : activePaletteEntry.arName,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: selectedAccent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _palette.map((entry) {
                                final selected = _selectedColor == entry.value;
                                final swatchColor = Color(entry.value);
                                return GestureDetector(
                                  onTap: () => setState(() {
                                    _selectedColor = entry.value;
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: swatchColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selected
                                            ? c.textPrimary
                                            : Colors.transparent,
                                        width: 2.5,
                                      ),
                                      boxShadow: selected
                                          ? [
                                              BoxShadow(
                                                color: swatchColor.withValues(
                                                  alpha: 0.42,
                                                ),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: selected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 22,
                                          )
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // القسم ٣: الموعد المستهدف
                          _ProjectSectionCard(
                            icon: Icons.flag_circle_outlined,
                            accentColor: selectedAccent,
                            title: isEn
                                ? 'Target Completion Date'
                                : 'تاريخ التسليم أو الإنجاز',
                            trailing: _targetDate != null
                                ? TextButton.icon(
                                    onPressed: () => setState(() {
                                      _targetDate = null;
                                      _markDirty();
                                    }),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: c.textMuted,
                                    ),
                                    label: Text(
                                      isEn ? 'Clear' : 'مسح',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: c.textMuted,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  )
                                : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _ProjectPresetChip(
                                      label: isEn ? '1 Week' : 'أسبوع',
                                      selected: _targetDate == weekDate,
                                      accentColor: selectedAccent,
                                      onTap: () => _applyDateOffset(7),
                                    ),
                                    _ProjectPresetChip(
                                      label: isEn ? '2 Weeks' : 'أسبوعين',
                                      selected: _targetDate == twoWeeksDate,
                                      accentColor: selectedAccent,
                                      onTap: () => _applyDateOffset(14),
                                    ),
                                    _ProjectPresetChip(
                                      label: isEn ? '1 Month' : 'شهر',
                                      selected: _targetDate == oneMonthDate,
                                      accentColor: selectedAccent,
                                      onTap: () =>
                                          _applyDateOffset(30, months: 1),
                                    ),
                                    _ProjectPresetChip(
                                      label: isEn ? '3 Months' : '٣ شهور',
                                      selected: _targetDate == threeMonthsDate,
                                      accentColor: selectedAccent,
                                      onTap: () =>
                                          _applyDateOffset(90, months: 3),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _pickTargetDate,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _targetDate != null
                                            ? selectedAccent.withValues(
                                                alpha: context.isDark
                                                    ? 0.18
                                                    : 0.1,
                                              )
                                            : c.surfaceSoft,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _targetDate != null
                                              ? selectedAccent.withValues(
                                                  alpha: 0.4,
                                                )
                                              : c.border,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: _targetDate != null
                                                  ? selectedAccent
                                                  : c.surface,
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                            ),
                                            child: Icon(
                                              Icons.calendar_today_rounded,
                                              size: 18,
                                              color: _targetDate != null
                                                  ? Colors.white
                                                  : selectedAccent,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _targetDate != null
                                                      ? '${ArabicFormatters.weekdayShort(_targetDate!)}، ${ArabicFormatters.dateFull(_targetDate!)}'
                                                      : (isEn
                                                          ? 'Pick custom target date'
                                                          : 'اختيار تاريخ مستهدف مخصص'),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        color: c.textPrimary,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  daysLeft != null
                                                      ? (daysLeft == 0
                                                          ? (isEn
                                                              ? 'Due today'
                                                              : 'الموعد اليوم')
                                                          : (isEn
                                                              ? '$daysLeft days remaining'
                                                              : 'متبقي ${ArabicFormatters.toArabicDigits(daysLeft)} يوم'))
                                                      : (isEn
                                                          ? 'Optional — helps pace your milestones'
                                                          : 'اختياري — بيساعدك تقسّم وقت المشروع بهدوء'),
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: _targetDate !=
                                                                null
                                                            ? selectedAccent
                                                            : c.textSecondary,
                                                        fontWeight:
                                                            _targetDate != null
                                                                ? FontWeight.w700
                                                                : FontWeight.w500,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.tune_rounded,
                                            color: selectedAccent,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // القسم ٤: أول خطوة عملية (اختياري)
                          _ProjectSectionCard(
                            icon: Icons.bolt_rounded,
                            accentColor: selectedAccent,
                            title: isEn
                                ? 'First Step to Kickstart'
                                : 'أول خطوة تبدأ بيها (اختياري)',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _starterStepController,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: isEn
                                        ? 'Write the first small action step...'
                                        : 'مثال: تجهيز قائمة الأدوات المطلوبة...',
                                    hintStyle: TextStyle(color: c.textMuted),
                                    prefixIcon: Icon(
                                      Icons.playlist_add_check_rounded,
                                      color: selectedAccent,
                                    ),
                                    filled: true,
                                    fillColor: c.surfaceSoft,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: c.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: c.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: selectedAccent,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: starterSuggestions.map((item) {
                                    return _ProjectPresetChip(
                                      label: item,
                                      selected:
                                          _starterStepController.text.trim() ==
                                          item,
                                      accentColor: selectedAccent,
                                      onTap: () {
                                        _starterStepController.text = item;
                                        _markDirty();
                                      },
                                    );
                                  }).toList(),
                                ),
                                if (_starterStepController.text
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () => setState(
                                      () => _createStarterTask =
                                          !_createStarterTask,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: c.surfaceSoft,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: c.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _createStarterTask
                                                ? Icons.check_box_rounded
                                                : Icons
                                                    .check_box_outline_blank_rounded,
                                            color: _createStarterTask
                                                ? selectedAccent
                                                : c.textMuted,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              isEn
                                                  ? 'Also create as first task in this project'
                                                  : 'أضفها تلقائيًا كأول مهمة جوه المشروع',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: c.textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // شريط إنشاء المشروع السفلي الحديث
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  decoration: BoxDecoration(
                    color: c.surface.withValues(alpha: 0.94),
                    border: Border(
                      top: BorderSide(color: c.border.withValues(alpha: 0.7)),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.create_new_folder_rounded, size: 20),
                      label: Text(
                        isEn ? 'Create Project' : 'إنشاء المشروع',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: selectedAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectHeroPreviewCard extends StatelessWidget {
  final String title;
  final String goal;
  final String starterStep;
  final Color accentColor;
  final String colorName;
  final DateTime? targetDate;
  final int? daysLeft;
  final bool isEn;

  const _ProjectHeroPreviewCard({
    required this.title,
    required this.goal,
    required this.starterStep,
    required this.accentColor,
    required this.colorName,
    required this.targetDate,
    required this.daysLeft,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final theme = Theme.of(context);
    final isPlaceholder = title.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(
              accentColor.withValues(alpha: context.isDark ? 0.22 : 0.13),
              c.surface,
            ),
            c.surface,
          ],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: context.isDark ? 0.45 : 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: context.isDark ? 0.18 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.folder_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Project Preview' : 'معاينة المشروع',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPlaceholder
                          ? (isEn
                              ? 'Your project title appears here...'
                              : 'اسم مشروعك هيظهر هنا...')
                          : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isPlaceholder ? c.textMuted : c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (goal.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              goal,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: c.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroTagPill(
                icon: Icons.palette_rounded,
                label: colorName,
                accentColor: accentColor,
              ),
              if (targetDate != null)
                _HeroTagPill(
                  icon: Icons.event_rounded,
                  label: daysLeft != null && daysLeft! > 0
                      ? '${ArabicFormatters.dateShort(targetDate!)} • ${isEn ? '${daysLeft}d left' : 'باقي ${ArabicFormatters.toArabicDigits(daysLeft!)} ي'}'
                      : ArabicFormatters.dateShort(targetDate!),
                  accentColor: accentColor,
                ),
              if (starterStep.isNotEmpty)
                _HeroTagPill(
                  icon: Icons.bolt_rounded,
                  label: starterStep,
                  accentColor: accentColor,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroTagPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;

  const _HeroTagPill({
    required this.icon,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accentColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectSectionCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final Widget child;
  final Widget? trailing;

  const _ProjectSectionCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ProjectPresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _ProjectPresetChip({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withValues(alpha: context.isDark ? 0.24 : 0.13)
                : c.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accentColor : c.border.withValues(alpha: 0.8),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? accentColor : c.textPrimary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

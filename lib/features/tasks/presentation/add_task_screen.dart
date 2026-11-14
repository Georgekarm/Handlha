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
import '../../notifications/alarm_reminder_store.dart';
import '../../notifications/presentation/notification_permission_sheet.dart';
import '../../projects/domain/project.dart';
import '../../projects/presentation/project_providers.dart';
import '../domain/task.dart';
import 'task_providers.dart';

/// شاشة إضافة وتعديل مهمة بتصميم حديث متناغم مع هوية «هندلها».
class AddTaskScreen extends ConsumerStatefulWidget {
  final Task? existingTask;
  final String? initialProjectId;

  const AddTaskScreen({
    super.key,
    this.existingTask,
    this.initialProjectId,
  });

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  late TaskPriority _priority;
  late EnergyLevel _energyLevel;
  late TaskRecurrence _recurrence;
  int _estimatedMinutes = 30;
  DateTime? _scheduledAt;
  String? _selectedProjectId;
  String _alertMode = 'notification';
  bool _saving = false;

  late final String _initialTitleSnapshot;
  late final String _initialNotesSnapshot;
  late final TaskPriority _initialPrioritySnapshot;
  late final EnergyLevel _initialEnergySnapshot;
  late final TaskRecurrence _initialRecurrenceSnapshot;
  late final int _initialMinutesSnapshot;
  late final DateTime? _initialScheduleSnapshot;
  late final String? _initialProjectSnapshot;
  late final String _initialAlertModeSnapshot;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTask;
    _titleController.text = t?.title ?? '';
    _notesController.text = t?.description ?? '';
    _priority = t?.priority ?? TaskPriority.medium;
    _energyLevel = t?.energyLevel ?? EnergyLevel.medium;
    _recurrence = t?.recurrence ?? TaskRecurrence.none;
    _estimatedMinutes = t?.estimatedDurationMinutes ?? 30;
    _scheduledAt = t?.scheduledStartAt ?? t?.dueAt;
    _selectedProjectId = t?.projectId ?? widget.initialProjectId;
    _alertMode = t != null
        ? AlarmReminderStore.current.alertModeForTask(t.id)
        : 'notification';

    _initialTitleSnapshot = _titleController.text;
    _initialNotesSnapshot = _notesController.text;
    _initialPrioritySnapshot = _priority;
    _initialEnergySnapshot = _energyLevel;
    _initialRecurrenceSnapshot = _recurrence;
    _initialMinutesSnapshot = _estimatedMinutes;
    _initialScheduleSnapshot = _scheduledAt;
    _initialProjectSnapshot = _selectedProjectId;
    _initialAlertModeSnapshot = _alertMode;

    _titleController.addListener(_onTextEdited);
    _notesController.addListener(_onTextEdited);
  }

  void _onTextEdited() {
    if (mounted) setState(() {});
  }

  bool get _hasUnsavedChanges {
    return _titleController.text != _initialTitleSnapshot ||
        _notesController.text != _initialNotesSnapshot ||
        _priority != _initialPrioritySnapshot ||
        _energyLevel != _initialEnergySnapshot ||
        _recurrence != _initialRecurrenceSnapshot ||
        _estimatedMinutes != _initialMinutesSnapshot ||
        _scheduledAt != _initialScheduleSnapshot ||
        _selectedProjectId != _initialProjectSnapshot ||
        _alertMode != _initialAlertModeSnapshot;
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextEdited);
    _notesController.removeListener(_onTextEdited);
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _popScreen({bool goHome = false}) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(goHome ? '/home' : '/tasks');
      }
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleBack() async {
    if (!_hasUnsavedChanges || _saving) {
      _popScreen();
      return;
    }
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final discard = await HandelhaDialog.confirm(
      context,
      icon: Icons.edit_off_rounded,
      title: isEn ? 'Discard Changes?' : 'تجاهل التعديلات؟',
      message: isEn
          ? 'You have unsaved details for this task. Leave without saving?'
          : 'في تفاصيل لسه ما اتحفظتش. تحب تخرج من غير ما تحفظها؟',
      confirmLabel: isEn ? 'Discard' : 'خروج بدون حفظ',
      cancelLabel: isEn ? 'Keep Editing' : 'كمّل تعديل',
      isDanger: true,
    );
    if (discard == true && mounted) {
      _popScreen();
    }
  }

  Future<void> _pickScheduleDateTime() async {
    final now = DateTime.now();
    final initial = _scheduledAt ??
        DateTime(now.year, now.month, now.day, (now.hour + 1).clamp(9, 21), 0);
    final picked = await HandelhaDateTimePicker.showDateTimeSheet(
      context,
      initialDateTime: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() => _scheduledAt = picked);
    }
  }

  void _applyQuickDatePreset(Duration offset, {int defaultHour = 10}) {
    final targetDay = DateTime.now().add(offset);
    final current = _scheduledAt;
    final hour = current?.hour ?? defaultHour;
    final minute = current?.minute ?? 0;
    setState(() {
      _scheduledAt = DateTime(
        targetDay.year,
        targetDay.month,
        targetDay.day,
        hour,
        minute,
      );
    });
  }

  Future<void> _openProjectPickerSheet(List<Project> projects) async {
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final picked = await showModalBottomSheet<String?>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProjectPickerSheet(
        projects: projects,
        selectedProjectId: _selectedProjectId,
        isEn: isEn,
      ),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _selectedProjectId = picked.isEmpty ? null : picked;
      });
    }
  }

  Future<void> _saveTask() async {
    if (_saving) return;
    final isEn = Directionality.of(context) == TextDirection.ltr;

    if (!(_formKey.currentState?.validate() ?? false)) {
      HandelhaFeedback.showWarning(
        context,
        isEn ? 'Please enter a task title first.' : 'اكتب عنوان المهمة الأول.',
      );
      return;
    }

    setState(() => _saving = true);

    final title = _titleController.text.trim();
    final rawNotes = _notesController.text.trim();
    final description = rawNotes.isEmpty ? null : rawNotes;

    late final Result<Task> result;
    if (_isEditing) {
      final existing = widget.existingTask!;
      final nextStatus = existing.isCompleted
          ? TaskStatus.completed
          : (_scheduledAt != null ? TaskStatus.planned : TaskStatus.inbox);
      final updated = Task(
        id: existing.id,
        userId: existing.userId,
        projectId: _selectedProjectId,
        parentTaskId: existing.parentTaskId,
        phaseId: existing.phaseId,
        dependsOnTaskIds: existing.dependsOnTaskIds,
        durationUncertainty: existing.durationUncertainty,
        title: title,
        description: description,
        status: nextStatus,
        priority: _priority,
        dueAt: _scheduledAt,
        scheduledStartAt: _scheduledAt,
        estimatedDurationMinutes: _estimatedMinutes,
        actualDurationMinutes: existing.actualDurationMinutes,
        energyLevel: _energyLevel,
        source: existing.source,
        aiConfidence: existing.aiConfidence,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        version: existing.version,
        syncStatus: existing.syncStatus,
        recurrence: _recurrence,
        deletedAt: existing.deletedAt,
      );
      result = await ref.read(allTasksProvider.notifier).updateTask(updated);
    } else {
      result = await ref.read(allTasksProvider.notifier).createTask(
            title: title,
            description: description,
            priority: _priority,
            energyLevel: _energyLevel,
            scheduledStartAt: _scheduledAt,
            estimatedDurationMinutes: _estimatedMinutes,
            status: _scheduledAt != null
                ? TaskStatus.planned
                : TaskStatus.inbox,
            projectId: _selectedProjectId,
            recurrence: _recurrence,
          );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case Failure<Task>(failure: final failure):
        HandelhaFeedback.showError(context, failure.message);
      case Success<Task>(data: final saved):
        if (_scheduledAt != null) {
          await ref.read(alarmReminderProvider.notifier).addOrUpdateAlarm(
                id: saved.id,
                title: saved.title,
                scheduledAt: _scheduledAt!,
                alertMode: _alertMode,
                taskId: saved.id,
              );
        } else {
          await ref.read(alarmReminderProvider.notifier).removeAlarm(saved.id);
        }
        if (!mounted) return;
        HandelhaFeedback.showSuccess(
          context,
          _isEditing
              ? (isEn ? 'Task changes saved!' : 'تم تحديث المهمة بنجاح!')
              : (isEn ? 'Task added to your plan!' : 'تم حفظ المهمة في جدولك!'),
        );
        _popScreen();
    }
  }

  Color _priorityColor(AppThemeExtension c, TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => c.primary,
      TaskPriority.medium => c.info,
      TaskPriority.high => c.warning,
      TaskPriority.urgent => c.danger,
    };
  }

  String _priorityLabel(TaskPriority priority, bool isEn) {
    return switch (priority) {
      TaskPriority.low => isEn ? 'Low' : 'هادئة',
      TaskPriority.medium => isEn ? 'Medium' : 'متوسطة',
      TaskPriority.high => isEn ? 'High' : 'مهمة',
      TaskPriority.urgent => isEn ? 'Urgent' : 'عاجلة',
    };
  }

  String _energyLabel(EnergyLevel energy, bool isEn) {
    return switch (energy) {
      EnergyLevel.low => isEn ? 'Light' : 'طاقة خفيفة',
      EnergyLevel.medium => isEn ? 'Balanced' : 'تركيز متوازن',
      EnergyLevel.high => isEn ? 'Deep Focus' : 'تركيز عميق',
    };
  }

  String _recurrenceLabel(TaskRecurrence recurrence, bool isEn) {
    return switch (recurrence) {
      TaskRecurrence.none => isEn ? 'Once' : 'مرة واحدة',
      TaskRecurrence.daily => isEn ? 'Daily' : 'يوميًا',
      TaskRecurrence.weekdays => isEn ? 'Weekdays' : 'أيام العمل',
      TaskRecurrence.weekly => isEn ? 'Weekly' : 'أسبوعيًا',
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final theme = Theme.of(context);
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final alarmState = ref.watch(alarmReminderProvider);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final activeProjects =
        projects.where((p) => p.status != ProjectStatus.archived).toList();
    final selectedProject = activeProjects
        .where((p) => p.id == _selectedProjectId)
        .firstOrNull;

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final tomorrowDate = todayDate.add(const Duration(days: 1));
    final nextWeekDate = todayDate.add(const Duration(days: 7));
    final selectedDateOnly = _scheduledAt == null
        ? null
        : DateTime(_scheduledAt!.year, _scheduledAt!.month, _scheduledAt!.day);

    final durationOptions = const [15, 25, 45, 60, 90];

    return PopScope(
      canPop: !_hasUnsavedChanges || _saving,
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
                  title: _isEditing
                      ? (isEn ? 'Edit Task' : 'تعديل المهمة')
                      : (isEn ? 'New Task' : 'مهمة جديدة'),
                  subtitle: _isEditing
                      ? (isEn
                          ? 'Update your task details smoothly'
                          : 'عدّل تفاصيل مهمتك بهدوء ووضوح')
                      : (isEn
                          ? 'Craft your task clearly in seconds'
                          : 'جهّز تفاصيل مهمتك بشكل منظم ومريح'),
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
                          // بطاقة المعاينة الحية لشكل المهمة
                          _TaskLivePreviewCard(
                            title: _titleController.text.trim(),
                            notes: _notesController.text.trim(),
                            priorityLabel: _priorityLabel(_priority, isEn),
                            priorityColor: _priorityColor(c, _priority),
                            energyLabel: _energyLabel(_energyLevel, isEn),
                            durationMinutes: _estimatedMinutes,
                            scheduledAt: _scheduledAt,
                            recurrence: _recurrence,
                            recurrenceLabel: _recurrenceLabel(
                              _recurrence,
                              isEn,
                            ),
                            project: selectedProject,
                            isEn: isEn,
                          ),
                          const SizedBox(height: 16),

                          // القسم ١: العنوان والملاحظات
                          _SectionCard(
                            icon: Icons.edit_note_rounded,
                            title: isEn ? 'Task Details' : 'عنوان المهمة والتفاصيل',
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
                                        ? 'What do you want to handle?'
                                        : 'مثال: مراجعة عرض العميل أو إنهاء الفصل الثالث',
                                    hintStyle: TextStyle(
                                      color: c.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.radio_button_unchecked_rounded,
                                      color: _priorityColor(c, _priority),
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
                                        color: c.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? (isEn
                                          ? 'Task title is required'
                                          : 'اكتب عنوان المهمة')
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _notesController,
                                  minLines: 2,
                                  maxLines: 4,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: c.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: isEn
                                        ? 'Optional notes, steps, or links...'
                                        : 'ملاحظات إضافية أو نقاط مساعدة (اختياري)...',
                                    hintStyle: TextStyle(color: c.textMuted),
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.only(bottom: 22),
                                      child: Icon(
                                        Icons.notes_rounded,
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
                                        color: c.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // القسم ٢: الموعد والمدة
                          _SectionCard(
                            icon: Icons.event_available_rounded,
                            title: isEn
                                ? 'Schedule & Duration'
                                : 'الموعد والمدة المقدرة',
                            trailing: _scheduledAt != null
                                ? TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _scheduledAt = null),
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
                                    _ModernOptionChip(
                                      icon: Icons.wb_sunny_outlined,
                                      label: isEn ? 'Today' : 'النهارده',
                                      selected: selectedDateOnly == todayDate,
                                      onTap: () => _applyQuickDatePreset(
                                        Duration.zero,
                                        defaultHour: (now.hour + 1).clamp(9, 21),
                                      ),
                                    ),
                                    _ModernOptionChip(
                                      icon: Icons.wb_twilight_rounded,
                                      label: isEn ? 'Tomorrow' : 'بكرة',
                                      selected:
                                          selectedDateOnly == tomorrowDate,
                                      onTap: () => _applyQuickDatePreset(
                                        const Duration(days: 1),
                                      ),
                                    ),
                                    _ModernOptionChip(
                                      icon: Icons.next_week_outlined,
                                      label: isEn
                                          ? 'Next week'
                                          : 'الأسبوع الجاي',
                                      selected:
                                          selectedDateOnly == nextWeekDate,
                                      onTap: () => _applyQuickDatePreset(
                                        const Duration(days: 7),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // زر فتح منتقي التاريخ والوقت المودرن
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _pickScheduleDateTime,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _scheduledAt != null
                                            ? c.primarySoft
                                            : c.surfaceSoft,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _scheduledAt != null
                                              ? c.primary.withValues(alpha: 0.35)
                                              : c.border,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: _scheduledAt != null
                                                  ? c.primary
                                                  : c.surface,
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                            ),
                                            child: Icon(
                                              Icons.calendar_month_rounded,
                                              size: 19,
                                              color: _scheduledAt != null
                                                  ? c.textOnPrimary
                                                  : c.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _scheduledAt != null
                                                      ? '${ArabicFormatters.weekdayShort(_scheduledAt!)}، ${ArabicFormatters.dateFull(_scheduledAt!)}'
                                                      : (isEn
                                                          ? 'Pick specific date & time'
                                                          : 'اختيار تاريخ ووقت مخصص'),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: c.textPrimary,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _scheduledAt != null
                                                      ? (isEn
                                                          ? 'At ${ArabicFormatters.timeOfDayAr(_scheduledAt!)} • Tap to adjust'
                                                          : 'الساعة ${ArabicFormatters.timeOfDayAr(_scheduledAt!)} • اضغط للتعديل')
                                                      : (isEn
                                                          ? 'Optional — leave empty for Inbox'
                                                          : 'اختياري — لو سيبته فاضي هتدخل صندوق الوارد'),
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: _scheduledAt !=
                                                                null
                                                            ? c.primary
                                                            : c.textSecondary,
                                                        fontWeight:
                                                            _scheduledAt != null
                                                                ? FontWeight.w700
                                                                : FontWeight.w500,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.tune_rounded,
                                            color: c.primary,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                if (_scheduledAt != null) ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          isEn
                                              ? 'Reminder Alert Type'
                                              : 'طريقة التنبيه عند الموعد',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            color: c.textSecondary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (!alarmState.permissionGranted)
                                        TextButton(
                                          onPressed: () =>
                                              ensureHandelhaNotificationPermission(
                                            context,
                                            ref,
                                            includeExactAlarm:
                                                _alertMode == 'alarm',
                                          ),
                                          style: TextButton.styleFrom(
                                            minimumSize: Size.zero,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Text(
                                            isEn
                                                ? 'Allow Notifications'
                                                : 'تفعيل الإذن',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: c.primary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _ModernOptionChip(
                                        icon: Icons.notifications_active_outlined,
                                        label: isEn
                                            ? 'Notification'
                                            : 'رسالة إشعار',
                                        selected:
                                            _alertMode == 'notification',
                                        onTap: () => setState(
                                          () => _alertMode = 'notification',
                                        ),
                                      ),
                                      _ModernOptionChip(
                                        icon: Icons.alarm_on_rounded,
                                        label: isEn
                                            ? 'Ringing Alarm'
                                            : 'منبه يرن',
                                        selected: _alertMode == 'alarm',
                                        accentColor: const Color(0xFFB45309),
                                        onTap: () async {
                                          setState(() => _alertMode = 'alarm');
                                          await ensureHandelhaNotificationPermission(
                                            context,
                                            ref,
                                            includeExactAlarm: true,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: 14),
                                Text(
                                  isEn
                                      ? 'Estimated Focus Duration'
                                      : 'المدة المتوقعة للإنجاز',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: c.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: durationOptions.map((mins) {
                                    final selected = _estimatedMinutes == mins;
                                    return _ModernOptionChip(
                                      icon: Icons.timer_outlined,
                                      label: ArabicFormatters.durationMinutes(
                                        mins,
                                      ),
                                      selected: selected,
                                      onTap: () => setState(
                                        () => _estimatedMinutes = mins,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // القسم ٣: الأولوية ومستوى الطاقة
                          _SectionCard(
                            icon: Icons.flag_outlined,
                            title: isEn
                                ? 'Priority & Energy'
                                : 'الأولوية ومستوى التركيز',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  isEn ? 'Priority Level' : 'درجة الأهمية',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: c.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: TaskPriority.values.map((p) {
                                    final pColor = _priorityColor(c, p);
                                    return _ModernOptionChip(
                                      label: _priorityLabel(p, isEn),
                                      selected: _priority == p,
                                      accentColor: pColor,
                                      leadingDotColor: pColor,
                                      onTap: () =>
                                          setState(() => _priority = p),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  isEn ? 'Energy Required' : 'الطاقة المطلوبة',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: c.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: EnergyLevel.values.map((energy) {
                                    final icon = switch (energy) {
                                      EnergyLevel.low => Icons.spa_outlined,
                                      EnergyLevel.medium => Icons.bolt_rounded,
                                      EnergyLevel.high =>
                                        Icons.local_fire_department_rounded,
                                    };
                                    final accent = switch (energy) {
                                      EnergyLevel.low => c.success,
                                      EnergyLevel.medium => c.info,
                                      EnergyLevel.high => c.accent,
                                    };
                                    return _ModernOptionChip(
                                      icon: icon,
                                      label: _energyLabel(energy, isEn),
                                      selected: _energyLevel == energy,
                                      accentColor: accent,
                                      onTap: () => setState(
                                        () => _energyLevel = energy,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // القسم ٤: المشروع والتكرار
                          _SectionCard(
                            icon: Icons.folder_copy_outlined,
                            title: isEn
                                ? 'Project & Repeat'
                                : 'الربط بمشروع والتكرار',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      isEn ? 'Project' : 'المشروع',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: c.textSecondary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const Spacer(),
                                    if (activeProjects.isNotEmpty)
                                      InkWell(
                                        onTap: () => _openProjectPickerSheet(
                                          activeProjects,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          child: Text(
                                            isEn ? 'Browse all' : 'عرض الكل',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: c.primary,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _ModernOptionChip(
                                      icon: Icons.inbox_rounded,
                                      label: isEn ? 'No project' : 'بدون مشروع',
                                      selected: _selectedProjectId == null,
                                      onTap: () => setState(
                                        () => _selectedProjectId = null,
                                      ),
                                    ),
                                    ...activeProjects.take(3).map((proj) {
                                      final projColor = Color(proj.colorValue);
                                      return _ModernOptionChip(
                                        leadingDotColor: projColor,
                                        label: ArabicFormatters.trData(
                                          proj.title,
                                        ),
                                        selected: _selectedProjectId == proj.id,
                                        accentColor: projColor,
                                        onTap: () => setState(
                                          () => _selectedProjectId = proj.id,
                                        ),
                                      );
                                    }),
                                    if (selectedProject != null &&
                                        !activeProjects
                                            .take(3)
                                            .any((p) => p.id == selectedProject.id))
                                      _ModernOptionChip(
                                        leadingDotColor: Color(
                                          selectedProject.colorValue,
                                        ),
                                        label: ArabicFormatters.trData(
                                          selectedProject.title,
                                        ),
                                        selected: true,
                                        accentColor: Color(
                                          selectedProject.colorValue,
                                        ),
                                        onTap: () => _openProjectPickerSheet(
                                          activeProjects,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  isEn ? 'Recurrence' : 'تكرار المهمة',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: c.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: TaskRecurrence.values.map((rec) {
                                    return _ModernOptionChip(
                                      icon: rec == TaskRecurrence.none
                                          ? Icons.looks_one_outlined
                                          : Icons.repeat_rounded,
                                      label: _recurrenceLabel(rec, isEn),
                                      selected: _recurrence == rec,
                                      onTap: () =>
                                          setState(() => _recurrence = rec),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // شريط الحفظ السفلي الحديث
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
                      onPressed: _saving ? null : _saveTask,
                      icon: _saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: c.textOnPrimary,
                              ),
                            )
                          : Icon(
                              _isEditing
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.add_task_rounded,
                              size: 20,
                            ),
                      label: Text(
                        _isEditing
                            ? (isEn ? 'Save Changes' : 'حفظ التعديلات')
                            : (isEn ? 'Save Task' : 'احفظ المهمة'),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.textOnPrimary,
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

class _TaskLivePreviewCard extends StatelessWidget {
  final String title;
  final String notes;
  final String priorityLabel;
  final Color priorityColor;
  final String energyLabel;
  final int durationMinutes;
  final DateTime? scheduledAt;
  final TaskRecurrence recurrence;
  final String recurrenceLabel;
  final Project? project;
  final bool isEn;

  const _TaskLivePreviewCard({
    required this.title,
    required this.notes,
    required this.priorityLabel,
    required this.priorityColor,
    required this.energyLabel,
    required this.durationMinutes,
    required this.scheduledAt,
    required this.recurrence,
    required this.recurrenceLabel,
    required this.project,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final theme = Theme.of(context);
    final isPlaceholder = title.isEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(
              priorityColor.withValues(alpha: context.isDark ? 0.14 : 0.06),
              c.surface,
            ),
            c.surface,
          ],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: priorityColor.withValues(alpha: context.isDark ? 0.38 : 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: const BorderRadiusDirectional.horizontal(
                  start: Radius.circular(22),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isEn ? 'Live Preview' : 'معاينة البطاقة',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: priorityColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (project != null)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Color(
                                  project!.colorValue,
                                ).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: Color(project!.colorValue),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      ArabicFormatters.trData(project!.title),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: c.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isPlaceholder
                          ? (isEn
                              ? 'Your task title appears here...'
                              : 'عنوان مهمتك هيظهر هنا بشكل فوري...')
                          : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isPlaceholder ? c.textMuted : c.textPrimary,
                      ),
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _PreviewPill(
                          icon: Icons.flag_rounded,
                          text: priorityLabel,
                          color: priorityColor,
                        ),
                        _PreviewPill(
                          icon: Icons.timer_outlined,
                          text: ArabicFormatters.durationMinutes(
                            durationMinutes,
                          ),
                          color: c.primary,
                        ),
                        _PreviewPill(
                          icon: Icons.bolt_rounded,
                          text: energyLabel,
                          color: c.info,
                        ),
                        if (scheduledAt != null)
                          _PreviewPill(
                            icon: Icons.schedule_rounded,
                            text:
                                '${ArabicFormatters.dateShort(scheduledAt!)} • ${ArabicFormatters.timeOfDayAr(scheduledAt!)}',
                            color: c.primary,
                          ),
                        if (recurrence != TaskRecurrence.none)
                          _PreviewPill(
                            icon: Icons.repeat_rounded,
                            text: recurrenceLabel,
                            color: c.secondary,
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
}

class _PreviewPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _PreviewPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.icon,
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
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: c.primary),
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

class _ModernOptionChip extends StatelessWidget {
  final IconData? icon;
  final Color? leadingDotColor;
  final String label;
  final bool selected;
  final Color? accentColor;
  final VoidCallback onTap;

  const _ModernOptionChip({
    this.icon,
    this.leadingDotColor,
    required this.label,
    required this.selected,
    this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final activeColor = accentColor ?? c.primary;

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
                ? activeColor.withValues(alpha: context.isDark ? 0.24 : 0.13)
                : c.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? activeColor : c.border.withValues(alpha: 0.8),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingDotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: leadingDotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ] else if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? activeColor : c.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? activeColor : c.textPrimary,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectPickerSheet extends StatelessWidget {
  final List<Project> projects;
  final String? selectedProjectId;
  final bool isEn;

  const _ProjectPickerSheet({
    required this.projects,
    required this.selectedProjectId,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.65;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: c.border.withValues(alpha: 0.7)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  children: [
                    Icon(Icons.folder_open_rounded, color: c.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEn ? 'Link to Project' : 'ربط المهمة بمشروع',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    _ProjectTile(
                      color: c.textMuted,
                      title: isEn ? 'No project (Standalone)' : 'بدون مشروع',
                      subtitle: isEn
                          ? 'Keep as a general task'
                          : 'مهمة مستقلة في جدولك',
                      selected: selectedProjectId == null,
                      onTap: () => Navigator.of(context).pop(''),
                    ),
                    const SizedBox(height: 8),
                    for (final project in projects) ...[
                      _ProjectTile(
                        color: Color(project.colorValue),
                        title: ArabicFormatters.trData(project.title),
                        subtitle: project.description?.trim().isNotEmpty == true
                            ? ArabicFormatters.trData(project.description!)
                            : (isEn ? 'Active project' : 'مشروع نشط'),
                        selected: selectedProjectId == project.id,
                        onTap: () => Navigator.of(context).pop(project.id),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ProjectTile({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? c.primary : c.border.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: c.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

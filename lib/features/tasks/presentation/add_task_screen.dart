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
import '../../notifications/alarm_reminder_store.dart';
import '../../notifications/presentation/notification_permission_sheet.dart';
import '../../projects/domain/project.dart';
import '../../projects/presentation/project_providers.dart';
import '../domain/task.dart';
import 'task_providers.dart';

enum _AddTaskMode { manual, assistant }

/// شاشة إضافة وتعديل مهمة بتصميم نظيف متطابق مع هوية «هندلها».
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

class _AddTaskScreenState extends ConsumerState<AddTaskScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _assistantController = TextEditingController();
  final _subtaskController = TextEditingController();

  _AddTaskMode _mode = _AddTaskMode.manual;
  late TaskPriority _priority;
  late EnergyLevel _energyLevel;
  late TaskRecurrence _recurrence;
  int _estimatedMinutes = 25;
  DateTime? _scheduledAt;
  String? _selectedProjectId;
  String _alertMode = 'notification';
  bool _saving = false;
  bool _showSubtaskInput = false;
  final List<String> _subtasks = [];
  String? _attachmentNote;

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
    _priority = t?.priority ?? TaskPriority.high;
    _energyLevel = t?.energyLevel ?? EnergyLevel.medium;
    _recurrence = t?.recurrence ?? TaskRecurrence.none;
    _estimatedMinutes = t?.estimatedDurationMinutes ?? 25;
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

    WidgetsBinding.instance.addObserver(this);
    _titleController.addListener(_onTextEdited);
    _notesController.addListener(_onTextEdited);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(alarmReminderProvider.notifier).refreshPermissions();
    }
  }

  Future<void> _ensureAlarmPermissionsFromTask() async {
    await ensureHandelhaNotificationPermission(
      context,
      ref,
      includeExactAlarm: true,
    );
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
        _alertMode != _initialAlertModeSnapshot ||
        _subtasks.isNotEmpty ||
        (_attachmentNote?.isNotEmpty ?? false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.removeListener(_onTextEdited);
    _notesController.removeListener(_onTextEdited);
    _titleController.dispose();
    _notesController.dispose();
    _assistantController.dispose();
    _subtaskController.dispose();
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

  void _applyQuickDatePreset(Duration offset, {int defaultHour = 10}) {
    final now = DateTime.now();
    final targetDay = now.add(offset);
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

  Future<void> _openScheduleSheet() async {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final now = DateTime.now();
          final todayDate = DateTime(now.year, now.month, now.day);
          final tomorrowDate = todayDate.add(const Duration(days: 1));
          final nextWeekDate = todayDate.add(const Duration(days: 7));
          final selectedOnly = _scheduledAt == null
              ? null
              : DateTime(
                  _scheduledAt!.year,
                  _scheduledAt!.month,
                  _scheduledAt!.day,
                );

          return SafeArea(
            child: SingleChildScrollView(
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
                          isEn ? 'Schedule & Duration' : 'الموعد والمدة',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      if (_scheduledAt != null)
                        TextButton(
                          onPressed: () {
                            setState(() => _scheduledAt = null);
                            setSheetState(() {});
                          },
                          child: Text(
                            isEn ? 'Clear' : 'مسح',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: c.danger,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SheetOptionChip(
                        label: isEn ? 'Today' : 'النهارده',
                        selected: selectedOnly == todayDate,
                        onTap: () {
                          _applyQuickDatePreset(
                            Duration.zero,
                            defaultHour: (now.hour + 1).clamp(9, 21),
                          );
                          setSheetState(() {});
                        },
                      ),
                      _SheetOptionChip(
                        label: isEn ? 'Tomorrow' : 'بكرة',
                        selected: selectedOnly == tomorrowDate,
                        onTap: () {
                          _applyQuickDatePreset(const Duration(days: 1));
                          setSheetState(() {});
                        },
                      ),
                      _SheetOptionChip(
                        label: isEn ? 'Next week' : 'الأسبوع الجاي',
                        selected: selectedOnly == nextWeekDate,
                        onTap: () {
                          _applyQuickDatePreset(const Duration(days: 7));
                          setSheetState(() {});
                        },
                      ),
                      _SheetOptionChip(
                        label: isEn ? 'Pick date & time' : 'تاريخ ووقت مخصص',
                        selected: false,
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _pickScheduleDateTime();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isEn ? 'Estimated Duration' : 'المدة المتوقعة',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [15, 25, 45, 60, 90].map((min) {
                      return _SheetOptionChip(
                        label: ArabicFormatters.durationMinutes(min),
                        selected: _estimatedMinutes == min,
                        onTap: () {
                          setState(() => _estimatedMinutes = min);
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isEn ? 'Repeat' : 'التكرار',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TaskRecurrence.values.map((r) {
                      return _SheetOptionChip(
                        label: _recurrenceLabel(r, isEn),
                        selected: _recurrence == r,
                        onTap: () {
                          setState(() => _recurrence = r);
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.ctaBackground,
                        foregroundColor: context.ctaForeground,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isEn ? 'Done' : 'تم',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.ctaForeground,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPrioritySheet() async {
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
              Text(
                isEn ? 'Select Priority' : 'اختيار الأولوية',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              for (final p in TaskPriority.values)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: _priorityColor(c, p),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(
                    _priorityLabel(p, isEn),
                    style: TextStyle(
                      fontWeight:
                          _priority == p ? FontWeight.w700 : FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                  trailing: _priority == p
                      ? Icon(Icons.check_rounded, color: c.primary)
                      : null,
                  onTap: () {
                    setState(() => _priority = p);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _openAttachmentDialog() async {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final ctrl = TextEditingController(text: _attachmentNote ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isEn ? 'Add Reference Note / Link' : 'إضافة مرفق أو رابط مرجعي',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 300,
          decoration: InputDecoration(
            counterText: '',
            hintText: isEn ? 'Link, file name, or reference...' : 'رابط أو اسم ملف مرجعي...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isEn ? 'Cancel' : 'إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.ctaBackground,
              foregroundColor: context.ctaForeground,
            ),
            child: Text(isEn ? 'Attach' : 'إرفاق'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (saved != null && mounted) {
      final cleanSaved =
          saved.length > 300 ? saved.substring(0, 300).trim() : saved;
      setState(() => _attachmentNote = cleanSaved.isEmpty ? null : cleanSaved);
    }
  }

  void _applyAssistantDraft() {
    final raw = _assistantController.text.trim();
    if (raw.isEmpty) {
      final isEn = Directionality.of(context) == TextDirection.ltr;
      HandelhaFeedback.showWarning(
        context,
        isEn
            ? 'Write a quick sentence about your task first.'
            : 'اكتب جملة سريعة عن المهمة الأول.',
      );
      return;
    }

    var cleaned = raw.length > 120 ? raw.substring(0, 120).trim() : raw;
    var nextPriority = _priority;
    var nextMinutes = _estimatedMinutes;
    DateTime? nextSchedule = _scheduledAt;
    final now = DateTime.now();

    if (cleaned.contains('عاجل') || cleaned.toLowerCase().contains('urgent')) {
      nextPriority = TaskPriority.urgent;
    } else if (cleaned.contains('عالية') ||
        cleaned.contains('مهم') ||
        cleaned.toLowerCase().contains('high')) {
      nextPriority = TaskPriority.high;
    }

    if (cleaned.contains('بكرة') ||
        cleaned.contains('غدا') ||
        cleaned.toLowerCase().contains('tomorrow')) {
      final tmr = now.add(const Duration(days: 1));
      nextSchedule = DateTime(tmr.year, tmr.month, tmr.day, 10, 0);
    } else if (cleaned.contains('النهارده') ||
        cleaned.contains('اليوم') ||
        cleaned.toLowerCase().contains('today')) {
      nextSchedule =
          DateTime(now.year, now.month, now.day, (now.hour + 1).clamp(9, 21), 0);
    }

    for (final min in [15, 25, 30, 45, 60, 90]) {
      if (cleaned.contains('$min')) {
        nextMinutes = min;
        break;
      }
    }

    setState(() {
      _titleController.text = cleaned;
      _priority = nextPriority;
      _estimatedMinutes = nextMinutes;
      _scheduledAt = nextSchedule;
      _mode = _AddTaskMode.manual;
    });
  }

  Future<void> _activateReminder() async {
    if (_scheduledAt == null) {
      _applyQuickDatePreset(Duration.zero, defaultHour: 10);
    }
    setState(() => _alertMode = 'alarm');
    await _ensureAlarmPermissionsFromTask();
    if (!mounted) return;
    await _openScheduleSheet();
  }

  String _composeDescription() {
    final parts = <String>[];
    final rawNotes = _notesController.text.trim();
    if (rawNotes.isNotEmpty) parts.add(rawNotes);
    if (_subtasks.isNotEmpty) {
      parts.add(_subtasks.map((s) => '- [ ] $s').join('\n'));
    }
    if (_attachmentNote != null && _attachmentNote!.trim().isNotEmpty) {
      parts.add('مرفق: ${_attachmentNote!.trim()}');
    }
    return parts.join('\n\n');
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
    final composed = _composeDescription();
    final description = composed.isEmpty ? null : composed;

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
            status:
                _scheduledAt != null ? TaskStatus.planned : TaskStatus.inbox,
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
      TaskPriority.medium => c.secondary,
      TaskPriority.high => const Color(0xFFC9735B),
      TaskPriority.urgent => c.danger,
    };
  }

  Color _priorityCardBg(
    AppThemeExtension c,
    TaskPriority priority,
    bool isDark,
  ) {
    return switch (priority) {
      TaskPriority.low =>
        isDark ? const Color(0xFF15342C) : const Color(0xFFEAF3F0),
      TaskPriority.medium =>
        isDark ? const Color(0xFF23223A) : const Color(0xFFEFEFF8),
      TaskPriority.high || TaskPriority.urgent =>
        isDark ? const Color(0xFF392721) : const Color(0xFFFBF0EC),
    };
  }

  String _priorityLabel(TaskPriority priority, bool isEn) {
    return switch (priority) {
      TaskPriority.low => isEn ? 'Low priority' : 'أولوية هادئة',
      TaskPriority.medium => isEn ? 'Medium' : 'متوسطة',
      TaskPriority.high => isEn ? 'High priority' : 'أولوية عالية',
      TaskPriority.urgent => isEn ? 'Urgent' : 'أولوية عاجلة',
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

  String _scheduleDisplayText(bool isEn) {
    if (_scheduledAt == null) {
      return isEn ? 'Choose time' : 'تحديد الموعد';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final picked = DateTime(
      _scheduledAt!.year,
      _scheduledAt!.month,
      _scheduledAt!.day,
    );
    final timeStr = ArabicFormatters.timeOfDayAr(_scheduledAt!);
    if (picked == today) {
      return isEn ? 'Today, $timeStr' : 'النهارده، $timeStr';
    }
    if (picked == tomorrow) {
      return isEn ? 'Tomorrow, $timeStr' : 'بكرة، $timeStr';
    }
    return '${ArabicFormatters.dateShort(_scheduledAt!)}، $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final alarmState = ref.watch(alarmReminderProvider);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final activeProjects =
        projects.where((p) => p.status != ProjectStatus.archived).toList();
    final selectedProject = activeProjects
        .where((p) => p.id == _selectedProjectId)
        .firstOrNull;
    final projectBarColor = selectedProject != null
        ? Color(selectedProject.colorValue)
        : c.primary;

    return PopScope(
      canPop: !_hasUnsavedChanges || _saving,
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
                      title: _isEditing
                          ? (isEn ? 'Edit Task' : 'تعديل المهمة')
                          : (isEn ? 'Add Task' : 'إضافة مهمة'),
                      subtitle: isEn ? 'Take it step by step' : 'خدها خطوة خطوة',
                      padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
                      onBack: _handleBack,
                    ),

                    // Segmented Switcher: يدوي | بمساعدة هندلها
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.segmentedTrackBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ModePill(
                              label: isEn ? 'Manual' : 'يدوي',
                              selected: _mode == _AddTaskMode.manual,
                              onTap: () =>
                                  setState(() => _mode = _AddTaskMode.manual),
                            ),
                          ),
                          Expanded(
                            child: _ModePill(
                              label: isEn
                                  ? 'With Handelha'
                                  : 'بمساعدة هندلها',
                              selected: _mode == _AddTaskMode.assistant,
                              onTap: () => setState(
                                () => _mode = _AddTaskMode.assistant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_mode == _AddTaskMode.assistant) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              isEn
                                  ? 'Describe your task naturally'
                                  : 'احكي لهندلها عن المهمة بجملة واحدة',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _assistantController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: isEn
                                    ? 'e.g. Review presentation tomorrow 5 PM urgent'
                                    : 'مثال: مراجعة التقرير بكرة الساعة ٥ لمدة ٤٥ دقيقة أولوية عالية',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _applyAssistantDraft,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: context.ctaBackground,
                                      foregroundColor: context.ctaForeground,
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      isEn
                                          ? 'Fill details'
                                          : 'تجهيز تفاصيل المهمة',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => context.go('/chat'),
                                  child: Text(
                                    isEn ? 'Open Chat' : 'افتح الشات',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Field 1: اسم المهمة
                    _FieldLabel(
                      label: isEn ? 'Task Name' : 'اسم المهمة',
                    ),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: isEn
                            ? 'Prepare campaign ideas'
                            : 'جهّز أفكار الحملة',
                        filled: true,
                        fillColor: c.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
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
                      validator: (v) {
                        final trimmed = v?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return isEn
                              ? 'Task title is required'
                              : 'اكتب عنوان المهمة';
                        }
                        if (trimmed.length > 120) {
                          return isEn
                              ? 'Task title is too long (max 120 characters)'
                              : 'عنوان المهمة طويل جدًا (الحد الأقصى ١٢٠ حرف)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Field 2: وصف بسيط (اختياري)
                    _FieldLabel(
                      label: isEn
                          ? 'Quick Note (optional)'
                          : 'وصف بسيط (اختياري)',
                    ),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _notesController,
                      minLines: 2,
                      maxLines: 3,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: isEn
                            ? 'Write what helps you start...'
                            : 'اكتب اللي هيساعدك تبدأ...',
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
                      validator: (v) {
                        final trimmed = v?.trim() ?? '';
                        if (trimmed.length > 1000) {
                          return isEn
                              ? 'Note is too long (max 1000 characters)'
                              : 'الوصف طويل جدًا (الحد الأقصى ١٠٠٠ حرف)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Section: الموعد والأولوية
                    Text(
                      isEn ? 'Schedule & Priority' : 'الموعد والأولوية',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: _PickerCard(
                            label: isEn ? 'Schedule' : 'الموعد',
                            value: _scheduleDisplayText(isEn),
                            trailing: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: c.textSecondary,
                            ),
                            onTap: _openScheduleSheet,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PickerCard(
                            label: isEn ? 'Priority' : 'الأولوية',
                            value: _priorityLabel(_priority, isEn),
                            backgroundColor:
                                _priorityCardBg(c, _priority, isDark),
                            borderColor: _priorityColor(c, _priority)
                                .withValues(alpha: isDark ? 0.45 : 0.18),
                            valueColor: _priority == TaskPriority.high ||
                                    _priority == TaskPriority.urgent
                                ? _priorityColor(c, _priority)
                                : c.textPrimary,
                            trailing: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: _priorityColor(c, _priority),
                                shape: BoxShape.circle,
                              ),
                            ),
                            onTap: _openPrioritySheet,
                          ),
                        ),
                      ],
                    ),

                    if (_scheduledAt != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isEn
                                        ? 'Reminder Alert Type'
                                        : 'طريقة التنبيه عند الموعد',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ),
                                if (_alertMode == 'notification' &&
                                    !alarmState.permissionGranted)
                                  TextButton(
                                    onPressed: () =>
                                        ensureHandelhaNotificationPermission(
                                      context,
                                      ref,
                                      includeExactAlarm: false,
                                    ),
                                    style: TextButton.styleFrom(
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      isEn ? 'Allow' : 'تفعيل الإذن',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: c.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _SheetOptionChip(
                                    label: isEn ? 'Notification' : 'رسالة إشعار',
                                    selected: _alertMode == 'notification',
                                    onTap: () => setState(
                                      () => _alertMode = 'notification',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _SheetOptionChip(
                                    label: isEn ? 'Ringing Alarm' : 'منبه يرن',
                                    selected: _alertMode == 'alarm',
                                    onTap: () async {
                                      setState(() => _alertMode = 'alarm');
                                      await _ensureAlarmPermissionsFromTask();
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (_alertMode == 'alarm') ...[
                              const SizedBox(height: 10),
                              (() {
                                final missingCore =
                                    !alarmState.permissionGranted;
                                if (!missingCore) {
                                  return Row(
                                    children: [
                                      Icon(
                                        Icons.verified_outlined,
                                        size: 15,
                                        color: c.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          isEn
                                              ? 'Alarm reminder ready — alerts you with sound & vibration on time'
                                              : 'منبه المواعيد مفعّل — ينبّهك بصوت واهتزاز في ميعاده',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: c.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return Material(
                                  color: c.warning.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: _ensureAlarmPermissionsFromTask,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              c.warning.withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.notifications_active_outlined,
                                            size: 17,
                                            color: c.warning,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              isEn
                                                  ? 'Allow notification & alarm permission'
                                                  : 'تفعيل إذن الإشعارات والمنبه',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: c.textPrimary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isEn ? 'Allow' : 'سماح',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: c.warning,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              })(),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Project Selector: المشروع
                    _FieldLabel(label: isEn ? 'Project' : 'المشروع'),
                    const SizedBox(height: 7),
                    Material(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openProjectPickerSheet(activeProjects),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: projectBarColor,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedProject != null
                                      ? ArabicFormatters.trData(
                                          selectedProject.title,
                                        )
                                      : (isEn ? 'No project' : 'بدون مشروع'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary,
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

                    // Action Pills: + خطوة فرعية | + مرفق
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionPill(
                            label: isEn ? '+ Substep' : '+ خطوة فرعية',
                            onTap: () => setState(
                              () => _showSubtaskInput = !_showSubtaskInput,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionPill(
                            label: isEn ? '+ Attachment' : '+ مرفق',
                            onTap: _openAttachmentDialog,
                          ),
                        ),
                      ],
                    ),

                    if (_showSubtaskInput || _subtasks.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_showSubtaskInput)
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _subtaskController,
                                      maxLength: 120,
                                      decoration: InputDecoration(
                                        counterText: '',
                                        hintText: isEn
                                            ? 'Add substep...'
                                            : 'أضف خطوة فرعية...',
                                        isDense: true,
                                      ),
                                      onSubmitted: (val) {
                                        final trimmed = val.trim();
                                        if (trimmed.isEmpty) return;
                                        if (_subtasks.contains(trimmed)) {
                                          _subtaskController.clear();
                                          return;
                                        }
                                        setState(() {
                                          _subtasks.add(trimmed);
                                          _subtaskController.clear();
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () {
                                      final trimmed =
                                          _subtaskController.text.trim();
                                      if (trimmed.isEmpty) return;
                                      if (_subtasks.contains(trimmed)) {
                                        _subtaskController.clear();
                                        return;
                                      }
                                      setState(() {
                                        _subtasks.add(trimmed);
                                        _subtaskController.clear();
                                      });
                                    },
                                    icon: Icon(
                                      Icons.add_circle_rounded,
                                      color: c.primary,
                                    ),
                                  ),
                                ],
                              ),
                            for (var i = 0; i < _subtasks.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_box_outline_blank_rounded,
                                      size: 16,
                                      color: c.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _subtasks[i],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: c.textPrimary,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () =>
                                          setState(() => _subtasks.removeAt(i)),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: c.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    if (_attachmentNote != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.attach_file_rounded,
                              size: 16,
                              color: c.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _attachmentNote!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () =>
                                  setState(() => _attachmentNote = null),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: InkWell(
                        onTap: _activateReminder,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Text(
                            _scheduledAt != null
                                ? (isEn
                                    ? 'Reminder: ${_scheduleDisplayText(true)}'
                                    : 'تذكير: ${_scheduleDisplayText(false)}')
                                : (isEn
                                    ? '+ Add reminder'
                                    : '+ إضافة تذكير'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _scheduledAt != null
                                  ? c.primary
                                  : c.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Save CTA
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveTask,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.ctaBackground,
                          foregroundColor: context.ctaForeground,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _saving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: context.ctaForeground,
                                ),
                              )
                            : Text(
                                _isEditing
                                    ? (isEn ? 'Save Changes' : 'حفظ التعديلات')
                                    : (isEn ? 'Save Task' : 'احفظ المهمة'),
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
        bottomNavigationBar: const HandelhaBottomNav(currentIndex: 1),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? context.heroBannerBackground
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark ? const Color(0xFF9EB5AE) : c.secondary),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: context.appColors.textSecondary,
      ),
    );
  }
}

class _PickerCard extends StatelessWidget {
  final String label;
  final String value;
  final Widget trailing;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? valueColor;
  final VoidCallback onTap;

  const _PickerCard({
    required this.label,
    required this.value,
    required this.trailing,
    required this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: backgroundColor ?? c.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor ?? c.border, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: valueColor ?? c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickActionPill({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: context.softControlSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetOptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SheetOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? context.ctaBackground : context.softControlSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? context.ctaForeground : c.textPrimary,
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
                      title: isEn ? 'No project' : 'بدون مشروع',
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
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

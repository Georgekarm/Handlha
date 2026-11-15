import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/mode/student_mode_controller.dart';
import '../../../app/theme/app_theme_extension.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loading_view.dart';
import '../../../shared/widgets/feature_empty_state.dart';
import '../../../shared/widgets/handelha_feedback.dart';
import '../../../shared/widgets/handelha_header.dart';
import '../../../shared/widgets/handelha_task_card.dart';
import '../../projects/domain/project.dart';
import '../../projects/presentation/project_providers.dart';
import '../domain/task.dart';
import 'task_providers.dart';

enum _TasksTab { open, completed }

/// شاشة المهام.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  _TasksTab _tab = _TasksTab.open;

  Future<void> _confirmDelete(Task task) async {
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final cleanTitle = ArabicFormatters.trData(task.title);
    final confirmed = await HandelhaDialog.confirm(
      context,
      icon: Icons.delete_outline_rounded,
      title: isEn ? 'Delete Task?' : 'حذف المهمة؟',
      message: isEn
          ? 'Permanently delete "$cleanTitle"?'
          : 'هل تريد حذف «${task.title}» نهائيًا؟',
      confirmLabel: isEn ? 'Delete' : 'حذف',
      cancelLabel: isEn ? 'Cancel' : 'إلغاء',
      isDanger: true,
    );
    if (confirmed == true) {
      await ref.read(allTasksProvider.notifier).deleteTask(task.id);
    }
  }

  Future<void> _showTaskActions(Task task) async {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: c.primary),
              title: Text(isEn ? 'Edit task' : 'تعديل المهمة'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: Icon(Icons.timer_outlined, color: c.primary),
              title: Text(isEn ? 'Start focus session' : 'ابدأ جلسة تركيز'),
              onTap: () => Navigator.pop(ctx, 'focus'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: c.danger),
              title: Text(
                isEn ? 'Delete task' : 'حذف المهمة',
                style: TextStyle(color: c.danger),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await context.push('/tasks/add', extra: task);
    } else if (action == 'focus') {
      await context.push(
        '/focus-session',
        extra: {'title': task.title, 'id': task.id},
      );
    } else if (action == 'delete') {
      await _confirmDelete(task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final tasksAsync = ref.watch(allTasksProvider);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final projectMap = {for (final p in projects) p.id: p};

    if (tasksAsync.isLoading && tasksAsync.value == null) {
      return Material(
        type: MaterialType.transparency,
        child: AppLoadingView(title: isEn ? 'Tasks' : 'المهام'),
      );
    }

    if (tasksAsync.hasError && tasksAsync.value == null) {
      return Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: AppErrorView(
            onRetry: () => ref.read(allTasksProvider.notifier).refresh(),
          ),
        ),
      );
    }

    final all = tasksAsync.value ?? const <Task>[];
    final openTasks =
        all.where((t) => !t.isCompleted && !t.isCancelled).toList();
    final completedTasks = all.where((t) => t.isCompleted).toList();
    final shown = _tab == _TasksTab.open ? openTasks : completedTasks;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final todayOpen = openTasks.where((t) {
      final dt = t.scheduledStartAt ?? t.dueAt;
      return dt == null || dt.isBefore(todayEnd);
    }).toList();
    final upcomingOpen = openTasks.where((t) {
      final dt = t.scheduledStartAt ?? t.dueAt;
      return dt != null && !dt.isBefore(todayEnd);
    }).toList();

    final totalCount = openTasks.length + completedTasks.length;
    final doneCount = completedTasks.length;
    final ratio =
        totalCount == 0 ? 0.0 : (doneCount / totalCount).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
        color: c.primary,
        onRefresh: () => ref.read(allTasksProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 114),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HandelhaHeader(
                title: _tab == _TasksTab.open
                    ? (isEn ? 'Tasks' : 'المهام')
                    : (isEn ? 'Completed Tasks' : 'المهام المكتملة'),
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
                actions: [
                  HandelhaHeaderIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: isEn ? 'Settings' : 'الإعدادات',
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),

              // Hero Summary Card
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEn ? 'Take it step by step' : 'خدها خطوة خطوة',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalCount == 0
                                    ? (isEn
                                        ? 'Ready for your first task'
                                        : 'جاهز لأول مهمة')
                                    : (isEn
                                        ? '$doneCount of $totalCount tasks done'
                                        : '${ArabicFormatters.toArabicDigits(doneCount)} من ${ArabicFormatters.toArabicDigits(totalCount)} مهام خلصت'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: context.limeAccent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            ArabicFormatters.percent(percent),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: context.limeAccentInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5.5,
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.limeAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Pill capsule tabs (المفتوحة N / المكتملة M)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.segmentedTrackBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabPill(
                        label: isEn
                            ? 'Open ${openTasks.length}'
                            : 'المفتوحة ${ArabicFormatters.toArabicDigits(openTasks.length)}',
                        selected: _tab == _TasksTab.open,
                        onTap: () => setState(() => _tab = _TasksTab.open),
                      ),
                    ),
                    Expanded(
                      child: _TabPill(
                        label: isEn
                            ? 'Completed ${completedTasks.length}'
                            : 'المكتملة ${ArabicFormatters.toArabicDigits(completedTasks.length)}',
                        selected: _tab == _TasksTab.completed,
                        onTap: () => setState(() => _tab = _TasksTab.completed),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (shown.isEmpty)
                FeatureEmptyState(
                  title: _tab == _TasksTab.open
                      ? (isEn ? 'Page still empty?' : 'لسه الصفحة فاضية؟')
                      : (isEn
                          ? 'No completed tasks yet'
                          : 'مفيش مهام مكتملة لسه'),
                  subtitle: _tab == _TasksTab.open
                      ? (isEn
                          ? "That's a great start. Pick one thing you want to finish, and take the rest step by step."
                          : 'دي بداية حلوة. اختار حاجة واحدة نفسك تخلّصها، وسيب الباقي خطوة خطوة.')
                      : (isEn
                          ? 'Once you finish a task, it will show up here so you can celebrate your progress.'
                          : 'أول ما تخلّص مهمة من مهامك هتظهر هنا عشان تفرح بإنجازك.'),
                  primaryCtaLabel:
                      isEn ? '+ Add First Task' : '+ أضف أول مهمة',
                  onPrimaryCta: () => context.push('/tasks/add'),
                  secondaryCtaLabel: isEn
                      ? 'Let the assistant help'
                      : 'خلّي المساعد يساعدك',
                  onSecondaryCta: () => context.go('/chat'),
                )
              else if (_tab == _TasksTab.open) ...[
                if (todayOpen.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEn ? 'Today' : 'النهارده',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        isEn
                            ? '${todayOpen.length} tasks'
                            : '${ArabicFormatters.toArabicDigits(todayOpen.length)} مهام',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < todayOpen.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _buildTaskItem(todayOpen[i], projectMap),
                  ],
                ],
                if (upcomingOpen.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEn ? 'Upcoming' : 'القادمة',
                          style: TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        isEn
                            ? '${upcomingOpen.length} tasks'
                            : '${ArabicFormatters.toArabicDigits(upcomingOpen.length)} مهام',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < upcomingOpen.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _buildTaskItem(upcomingOpen[i], projectMap),
                  ],
                ],
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    isEn
                        ? 'Prioritize what matters most, not what is most.'
                        : 'الأولوية للأهم، مش للأكثر.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.push('/tasks/add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.ctaBackground,
                      foregroundColor: context.ctaForeground,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      isEn ? '+ Add Task' : '+ إضافة مهمة',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: context.ctaForeground,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  isEn
                      ? '${completedTasks.length} steps worth celebrating.'
                      : '${ArabicFormatters.toArabicDigits(completedTasks.length)} خطوات تستاهل تفرح بيها.',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < completedTasks.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _buildTaskItem(completedTasks[i], projectMap),
                ],
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn
                            ? 'Great job! Small consistent steps make a difference.'
                            : 'عاش! القليل المستمر بيعمل فرق.',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: c.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEn
                            ? 'There is still time for yourself, not just work.'
                            : 'لسه في وقت لنفسك، مش للشغل بس.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: c.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildTaskItem(Task task, Map<String, Project> projectMap) {
    final project =
        task.projectId != null ? projectMap[task.projectId!] : null;
    return HandelhaTaskCard(
      task: task,
      projectName: project?.title,
      stripeColor: project != null ? Color(project.colorValue) : null,
      onToggleComplete: () {
        final notifier = ref.read(allTasksProvider.notifier);
        if (task.isCompleted) {
          notifier.reopenTask(task.id);
        } else {
          notifier.completeTask(task.id);
          final isEn = Directionality.of(context) == TextDirection.ltr;
          final isStudentMode = ref.read(isStudentModeActiveProvider);
          final isExam = isStudentMode &&
              (task.title.contains('امتحان') ||
                  task.title.contains('اختبار') ||
                  task.title.contains('كويز') ||
                  task.title.toLowerCase().contains('exam') ||
                  task.title.toLowerCase().contains('quiz'));
          final isHard = task.priority == TaskPriority.urgent ||
              task.priority == TaskPriority.high ||
              task.energyLevel == EnergyLevel.high ||
              (task.estimatedDurationMinutes != null &&
                  task.estimatedDurationMinutes! >= 45);
          final msg = isExam
              ? (isEn
                  ? 'Exam completed — open Progress whenever you want to save your grade.'
                  : 'عاش بجد! خلّصت «${task.title}» — تقدر تسجّل تقديرك في «إنجازك» أول ما النتيجة تطلع.')
              : isHard
                  ? (isEn
                      ? 'Big task done — solid focus today.'
                      : 'عاش عليك! خلّصت مهمة تقيلة النهارده بمجهود محترم.')
                  : (isEn
                      ? 'Nice progress — one more step done.'
                      : 'خطوة حلوة اتعملت النهارده.');
          HandelhaFeedback.showCelebration(context, msg);
        }
      },
      onTap: () => context.push('/tasks/add', extra: task),
      onMorePressed: () => _showTaskActions(task),
      onLongPress: () => _confirmDelete(task),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.segmentedActiveBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          boxShadow: selected && !context.isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (context.isDark ? Colors.white : c.primary)
                : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

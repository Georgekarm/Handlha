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
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
                actions: [
                  HandelhaHeaderIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: isEn ? 'Settings' : 'الإعدادات',
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),

              // Pill capsule tabs (المفتوحة N / المكتملة M)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? c.surfaceSoft : const Color(0xFFE1E8E4),
                  borderRadius: BorderRadius.circular(18),
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
              const SizedBox(height: 22),

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
                  Text(
                    isEn ? 'Today' : 'النهارده',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < todayOpen.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _buildTaskItem(todayOpen[i], projectMap),
                  ],
                ],
                if (upcomingOpen.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    isEn ? 'Upcoming' : 'القادمة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < upcomingOpen.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _buildTaskItem(upcomingOpen[i], projectMap),
                  ],
                ],
                const SizedBox(height: 18),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isEn
                          ? 'Prioritize what matters most, not what is most.'
                          : 'الأولوية للأهم، مش للأكثر.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => context.push('/tasks/add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: c.textOnPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      isEn ? '+ Add Task' : '+ إضافة مهمة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textOnPrimary,
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
          color: selected ? c.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
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
            color: selected ? c.primary : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

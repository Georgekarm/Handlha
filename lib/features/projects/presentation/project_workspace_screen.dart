import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_extension.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../../shared/widgets/handelha_ambient_background.dart';
import '../../../shared/widgets/handelha_bottom_nav.dart';
import '../../../shared/widgets/handelha_feedback.dart';
import '../../../shared/widgets/handelha_header.dart';
import '../../../shared/widgets/handelha_task_card.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_providers.dart';
import '../domain/project.dart';
import 'project_providers.dart';
import 'widgets/ai_breakdown_sheet.dart';

enum _WorkspaceTab { upcoming, overview }

/// شاشة تفاصيل المشروع بتصميم نظيف متطابق مع هوية «هندلها».
class ProjectWorkspaceScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String projectTitle;
  final String projectGoal;
  final Color? accentColor;

  const ProjectWorkspaceScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
    this.projectGoal = '',
    this.accentColor,
  });

  @override
  ConsumerState<ProjectWorkspaceScreen> createState() =>
      _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState
    extends ConsumerState<ProjectWorkspaceScreen> {
  _WorkspaceTab _tab = _WorkspaceTab.upcoming;

  Future<void> _openAiBreakdown(Project? project) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiBreakdownModal(
        projectTitle: project?.title ?? widget.projectTitle,
        projectGoal: project?.description ?? widget.projectGoal,
        onAccepted: () {
          ref.read(allTasksProvider.notifier).refresh();
          ref.read(projectsProvider.notifier).refresh();
        },
      ),
    );
    if (created == true) {
      await Future.wait([
        ref.read(allTasksProvider.notifier).refresh(),
        ref.read(projectsProvider.notifier).refresh(),
      ]);
    }
  }

  Future<void> _confirmDeleteProject(Project project) async {
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final cleanTitle = ArabicFormatters.trData(project.title);
    final confirmed = await HandelhaDialog.confirm(
      context,
      icon: Icons.folder_delete_outlined,
      title: isEn ? 'Delete Project?' : 'حذف المشروع؟',
      message: isEn
          ? '"$cleanTitle" will be removed from your projects.'
          : 'سيتم حذف «${project.title}» من قائمة مشروعاتك.',
      confirmLabel: isEn ? 'Delete' : 'حذف',
      cancelLabel: isEn ? 'Cancel' : 'إلغاء',
      isDanger: true,
    );
    if (confirmed == true && mounted) {
      await ref.read(projectsProvider.notifier).deleteProject(project.id);
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/projects');
        }
      }
    }
  }

  String _taskSubtitleConcise(Task task, bool isEn) {
    if (task.isCompleted) {
      return isEn ? 'Done' : 'خلصت';
    }
    final parts = <String>[];
    final when = task.scheduledStartAt ?? task.dueAt;
    if (when != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final day = DateTime(when.year, when.month, when.day);
      if (day == today) {
        parts.add(isEn ? 'Today' : 'النهارده');
      } else {
        parts.add(ArabicFormatters.timeOfDayAr(when));
      }
    } else {
      parts.add(isEn ? 'Today' : 'النهارده');
    }
    if ((task.estimatedDurationMinutes ?? 0) > 0) {
      parts.add(
        ArabicFormatters.durationMinutesFull(task.estimatedDurationMinutes!),
      );
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final project =
        projects.where((p) => p.id == widget.projectId).firstOrNull;
    final allTasks = ref.watch(allTasksProvider).value ?? const <Task>[];

    final projectTasks =
        allTasks.where((t) => t.projectId == widget.projectId).toList();
    final doneCount = projectTasks.where((t) => t.isCompleted).length;
    final totalCount = projectTasks.length;
    final openCount = totalCount - doneCount;
    final percent = totalCount == 0
        ? (project?.progressPercent ?? 0.0)
        : (doneCount / totalCount) * 100;
    final ratio = (percent / 100).clamp(0.0, 1.0);

    final themeAccent = project != null
        ? Color(project.colorValue)
        : (widget.accentColor ?? c.primary);
    final title =
        ArabicFormatters.trData(project?.title ?? widget.projectTitle);
    final goalText =
        (project?.description?.trim().isNotEmpty ?? false)
            ? project!.description!.trim()
            : widget.projectGoal.trim();

    final targetDate = project?.targetDate;
    final daysLeft =
        targetDate?.difference(DateTime.now()).inDays;
    String metaLine = ArabicFormatters.countOf(doneCount, totalCount);
    if (daysLeft != null && daysLeft >= 0) {
      metaLine = isEn
          ? '$metaLine • $daysLeft days left'
          : '$metaLine • فاضل ${ArabicFormatters.toArabicDigits(daysLeft)} يوم';
    }

    final statusLabel = totalCount > 0 && doneCount == totalCount
        ? (isEn ? 'Completed' : 'مكتمل')
        : (project?.status == ProjectStatus.paused
            ? (isEn ? 'Paused' : 'متوقف')
            : (isEn ? 'In Progress' : 'قيد التنفيذ'));

    final segmentCount = (totalCount >= 4 && totalCount <= 10) ? totalCount : 8;
    final filledSegments = (ratio * segmentCount).round().clamp(0, segmentCount);

    return Scaffold(
      extendBody: true,
      body: HandelhaAmbientBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 114),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HandelhaHeader(
                  title: isEn ? 'Project Details' : 'تفاصيل المشروع',
                  subtitle: isEn ? 'Take it step by step' : 'خدها خطوة خطوة',
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
                ),

                // Hero Summary Banner Card
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: context.limeAccent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: context.limeAccentInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        metaLine,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isEn ? 'Overall Progress' : 'التقدم الكلي',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.76),
                              ),
                            ),
                          ),
                          Text(
                            ArabicFormatters.percent(percent),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.limeAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: List.generate(segmentCount, (idx) {
                          final active = idx < filledSegments;
                          return Expanded(
                            child: Container(
                              height: 5.5,
                              margin: EdgeInsetsDirectional.only(
                                end: idx == segmentCount - 1 ? 0 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? context.limeAccent
                                    : Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3 KPI Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _KpiMetricCard(
                        value: isEn
                            ? '$doneCount'
                            : ArabicFormatters.toArabicDigits(doneCount),
                        label: isEn ? 'Completed' : 'مهام مكتملة',
                        valueColor:
                            isDark ? context.limeAccent : c.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _KpiMetricCard(
                        value: isEn
                            ? '$openCount'
                            : ArabicFormatters.toArabicDigits(openCount),
                        label: isEn ? 'Open' : 'مهام مفتوحة',
                        valueColor: isDark
                            ? const Color(0xFFAFA9F0)
                            : c.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _KpiMetricCard(
                        value: daysLeft != null && daysLeft >= 0
                            ? (isEn
                                ? '$daysLeft'
                                : ArabicFormatters.toArabicDigits(daysLeft))
                            : '—',
                        label: isEn ? 'Days Left' : 'يوم متبقي',
                        valueColor: c.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Segmented Switcher: الخطوات اللي جاية | نظرة عامة
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.segmentedTrackBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _WorkspaceTabPill(
                          label: isEn ? 'Upcoming Steps' : 'الخطوات اللي جاية',
                          selected: _tab == _WorkspaceTab.upcoming,
                          onTap: () =>
                              setState(() => _tab = _WorkspaceTab.upcoming),
                        ),
                      ),
                      Expanded(
                        child: _WorkspaceTabPill(
                          label: isEn ? 'Overview' : 'نظرة عامة',
                          selected: _tab == _WorkspaceTab.overview,
                          onTap: () =>
                              setState(() => _tab = _WorkspaceTab.overview),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                if (_tab == _WorkspaceTab.upcoming) ...[
                  if (projectTasks.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: c.border),
                      ),
                      child: Column(
                        children: [
                          Text(
                            isEn
                                ? 'No steps recorded for this project yet.'
                                : 'لسه مفيش خطوات متسجلة للمشروع ده.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () => _openAiBreakdown(project),
                            child: Text(
                              isEn
                                  ? 'Suggest steps for this project'
                                  : 'اقترح خطوات للمشروع',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: c.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (var i = 0; i < projectTasks.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          HandelhaTaskCard(
                            task: projectTasks[i],
                            projectName: isEn ? 'Work' : 'شغل',
                            stripeColor: themeAccent,
                            showEndStripe: false,
                            compactTag: true,
                            subtitleOverride: _taskSubtitleConcise(
                              projectTasks[i],
                              isEn,
                            ),
                            onToggleComplete: () {
                              final t = projectTasks[i];
                              final notifier =
                                  ref.read(allTasksProvider.notifier);
                              if (t.isCompleted) {
                                notifier.reopenTask(t.id);
                              } else {
                                notifier.completeTask(t.id);
                              }
                            },
                            onTap: () => context.push(
                              '/tasks/add',
                              extra: projectTasks[i],
                            ),
                          ),
                        ],
                      ],
                    ),
                ] else ...[
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
                          isEn ? 'Project Goal' : 'الهدف من المشروع',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          goalText.isNotEmpty
                              ? goalText
                              : (isEn
                                  ? 'No project description added yet.'
                                  : 'لم يُضف وصف للمشروع بعد.'),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: c.textPrimary,
                          ),
                        ),
                        if (targetDate != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            isEn ? 'Target Date' : 'الموعد المستهدف',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${ArabicFormatters.dateShort(targetDate)} ${isEn ? targetDate.year : ArabicFormatters.toArabicDigits(targetDate.year)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _openAiBreakdown(project),
                                child: Text(
                                  isEn
                                      ? 'Smart Breakdown'
                                      : 'تقسيم ذكي للمشروع',
                                ),
                              ),
                            ),
                            if (project != null) ...[
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: () =>
                                    _confirmDeleteProject(project),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: c.danger,
                                  side: BorderSide(
                                    color: c.danger.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Text(
                                  isEn ? 'Delete' : 'حذف المشروع',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.push(
                      '/tasks/add',
                      extra: {'projectId': widget.projectId},
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.ctaBackground,
                      foregroundColor: context.ctaForeground,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      isEn ? '+ Add Project Step' : '+ أضف خطوة للمشروع',
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
      bottomNavigationBar: const HandelhaBottomNav(currentIndex: 2),
    );
  }
}

class _KpiMetricCard extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _KpiMetricCard({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceTabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WorkspaceTabPill({
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
        duration: const Duration(milliseconds: 170),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              selected ? context.segmentedActiveBackground : Colors.transparent,
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (context.isDark ? Colors.white : c.textPrimary)
                : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

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

/// شاشة تفاصيل المشروع.
class ProjectWorkspaceScreen extends ConsumerWidget {
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

  Future<void> _openAiBreakdown(
    BuildContext context,
    WidgetRef ref,
    Project? project,
  ) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiBreakdownModal(
        projectTitle: project?.title ?? projectTitle,
        projectGoal: project?.description ?? projectGoal,
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

  Future<void> _confirmDeleteProject(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
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
    if (confirmed == true && context.mounted) {
      await ref.read(projectsProvider.notifier).deleteProject(project.id);
      if (context.mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/projects');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final project = projects.where((p) => p.id == projectId).firstOrNull;
    final allTasks = ref.watch(allTasksProvider).value ?? const <Task>[];

    final projectTasks =
        allTasks.where((t) => t.projectId == projectId).toList();
    final doneCount = projectTasks.where((t) => t.isCompleted).length;
    final totalCount = projectTasks.length;
    final percent = totalCount == 0
        ? (project?.progressPercent ?? 0.0)
        : (doneCount / totalCount) * 100;
    final ratio = (percent / 100).clamp(0.0, 1.0);

    final themeAccent =
        project != null ? Color(project.colorValue) : (accentColor ?? c.primary);
    final title = ArabicFormatters.trData(project?.title ?? projectTitle);

    String metaLine = ArabicFormatters.countOf(doneCount, totalCount);
    final targetDate = project?.targetDate;
    if (targetDate != null) {
      final days = targetDate.difference(DateTime.now()).inDays;
      if (days >= 0) {
        metaLine = isEn
            ? '$metaLine • $days days left'
            : '$metaLine • فاضل ${ArabicFormatters.toArabicDigits(days)} يوم';
      }
    }

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
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
                  actions: [
                    HandelhaHeaderIconButton(
                      icon: Icons.auto_awesome_outlined,
                      tooltip: isEn
                          ? 'Smart Project Breakdown'
                          : 'تقسيم ذكي للمشروع',
                      iconColor: c.primary,
                      onTap: () => _openAiBreakdown(context, ref, project),
                    ),
                    if (project != null) ...[
                      const SizedBox(width: 8),
                      HandelhaHeaderIconButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: isEn ? 'Delete Project' : 'حذف المشروع',
                        iconColor: c.danger,
                        onTap: () =>
                            _confirmDeleteProject(context, ref, project),
                      ),
                    ],
                  ],
                ),

                // Top project summary banner card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 26,
                            color: themeAccent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: c.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        metaLine,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: c.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 7,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.65),
                          color: themeAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                Text(
                  isEn ? 'Upcoming Steps' : 'الخطوات اللي جاية',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                if (projectTasks.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isEn
                              ? 'No steps recorded for this project yet.'
                              : 'لسه مفيش خطوات متسجلة للمشروع ده.',
                          style: TextStyle(
                            fontSize: 14,
                            color: c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () =>
                              _openAiBreakdown(context, ref, project),
                          icon: Icon(
                            Icons.auto_awesome_outlined,
                            size: 18,
                            color: c.primary,
                          ),
                          label: Text(
                            isEn
                                ? 'Suggest Steps with AI'
                                : 'اقترح خطوات بالذكاء الاصطناعي',
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
                          stripeColor: themeAccent,
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

                const SizedBox(height: 22),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => context.push(
                      '/tasks/add',
                      extra: {'projectId': projectId},
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: c.textOnPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      isEn ? '+ Add Project Step' : '+ أضف خطوة للمشروع',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textOnPrimary,
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

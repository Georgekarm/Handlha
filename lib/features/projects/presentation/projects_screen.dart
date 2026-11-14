import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_extension.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loading_view.dart';
import '../../../shared/widgets/feature_empty_state.dart';
import '../../../shared/widgets/handelha_header.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_providers.dart';
import '../domain/project.dart';
import 'project_providers.dart';

enum _ProjectFilter { active, completed }

/// شاشة المشروعات.
class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  _ProjectFilter _filter = _ProjectFilter.active;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final projectsAsync = ref.watch(projectsProvider);
    final allTasks = ref.watch(allTasksProvider).value ?? const <Task>[];

    if (projectsAsync.isLoading && projectsAsync.value == null) {
      return Material(
        type: MaterialType.transparency,
        child: AppLoadingView(title: isEn ? 'Projects' : 'المشروعات'),
      );
    }

    if (projectsAsync.hasError && projectsAsync.value == null) {
      return Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: AppErrorView(
            onRetry: () => ref.read(projectsProvider.notifier).refresh(),
          ),
        ),
      );
    }

    final allProjects = projectsAsync.value ?? const <Project>[];
    final activeProjects = allProjects
        .where(
          (p) =>
              p.status == ProjectStatus.active ||
              p.status == ProjectStatus.paused,
        )
        .toList();
    final completedProjects = allProjects
        .where((p) => p.status == ProjectStatus.completed)
        .toList();

    final shown =
        _filter == _ProjectFilter.active ? activeProjects : completedProjects;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
        color: c.primary,
        onRefresh: () => ref.read(projectsProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 114),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HandelhaHeader(
                title: isEn ? 'Projects' : 'المشروعات',
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
                actions: [
                  HandelhaHeaderIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: isEn ? 'Settings' : 'الإعدادات',
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
              Text(
                isEn
                    ? 'Your big ideas, turned into clear steps.'
                    : 'أفكارك الكبيرة، خطوات واضحة.',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Compact right-aligned filter pills
              Row(
                children: [
                  Flexible(
                    child: _FilterChipPill(
                      label: isEn
                          ? 'Active ${activeProjects.length}'
                          : 'نشطة ${ArabicFormatters.toArabicDigits(activeProjects.length)}',
                      selected: _filter == _ProjectFilter.active,
                      onTap: () =>
                          setState(() => _filter = _ProjectFilter.active),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: _FilterChipPill(
                      label: isEn ? 'Completed' : 'مكتملة',
                      selected: _filter == _ProjectFilter.completed,
                      onTap: () =>
                          setState(() => _filter = _ProjectFilter.completed),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (shown.isEmpty)
                FeatureEmptyState(
                  icon: Icons.folder_open_rounded,
                  title: _filter == _ProjectFilter.active
                      ? (isEn
                          ? 'No active projects yet?'
                          : 'لسه مفيش مشروعات نشطة؟')
                      : (isEn
                          ? 'No completed projects yet'
                          : 'مفيش مشروعات مكتملة لسه'),
                  subtitle: isEn
                      ? 'Break your big idea into small steps, and each step will calmly bring you closer to your goal.'
                      : 'قسم فكرتك الكبيرة لخطوات صغيرة، وكل خطوة هتقربك من هدفك بهدوء.',
                  primaryCtaLabel: isEn ? '+ New Project' : '+ مشروع جديد',
                  onPrimaryCta: () => context.push('/projects/new'),
                  secondaryCtaLabel: isEn
                      ? 'Let the assistant suggest a plan'
                      : 'خلّي المساعد يقترح خطة',
                  onSecondaryCta: () => context.go('/chat'),
                )
              else ...[
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _ProjectCard(
                    project: shown[i],
                    linkedTasks: allTasks
                        .where((t) => t.projectId == shown[i].id)
                        .toList(),
                    onTap: () => context.push(
                      '/project-workspace',
                      extra: {
                        'id': shown[i].id,
                        'title': shown[i].title,
                        'goal': shown[i].description ?? '',
                        'color': shown[i].colorValue.toString(),
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => context.push('/projects/new'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: c.textOnPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      isEn ? '+ New Project' : '+ مشروع جديد',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textOnPrimary,
                      ),
                    ),
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
}

class _FilterChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Material(
      color: selected ? c.primarySoft : c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: selected ? null : Border.all(color: c.border),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? c.primary : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final List<Task> linkedTasks;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.project,
    required this.linkedTasks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final projectColor = Color(project.colorValue);

    final totalTasks = linkedTasks.isNotEmpty
        ? linkedTasks.length
        : project.taskIds.length;
    final doneTasks = linkedTasks.isNotEmpty
        ? linkedTasks.where((t) => t.isCompleted).length
        : ((project.progressPercent / 100) * totalTasks).round();

    final percent = linkedTasks.isNotEmpty
        ? (totalTasks == 0 ? 0.0 : (doneTasks / totalTasks) * 100)
        : project.progressPercent;
    final ratio = (percent / 100).clamp(0.0, 1.0);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 18, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 24,
                          color: projectColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ArabicFormatters.trData(project.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${ArabicFormatters.countOf(doneTasks, totalTasks)} • ${ArabicFormatters.percent(percent)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: c.surfaceMuted,
                        color: projectColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: projectColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

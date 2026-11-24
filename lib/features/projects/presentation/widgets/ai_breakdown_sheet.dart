import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme_extension.dart';
import '../../../../core/database/local_project_database.dart';
import '../../../../core/result/result.dart';
import '../../../../shared/widgets/handelha_feedback.dart';
import '../../../assistant/planning/ai_planning_models.dart';
import '../../../assistant/planning/ai_planning_service.dart';
import '../../../assistant/presentation/assistant_providers.dart';
import '../../../authentication/presentation/auth_providers.dart';
import '../../../tasks/domain/task.dart';
import '../../../tasks/presentation/task_providers.dart';
import '../../domain/project.dart';
import '../project_providers.dart';

class AiBreakdownModal extends ConsumerStatefulWidget {
  final String? existingProjectId;
  final String projectTitle;
  final String projectGoal;
  final String? deadline;
  final String? constraints;
  final String? conversationContext;
  final VoidCallback? onAccepted;

  const AiBreakdownModal({
    super.key,
    this.existingProjectId,
    required this.projectTitle,
    required this.projectGoal,
    this.deadline,
    this.constraints,
    this.conversationContext,
    this.onAccepted,
  });

  static Future<void> show(
    BuildContext context, {
    String? existingProjectId,
    required String projectTitle,
    required String projectGoal,
    String? deadline,
    String? constraints,
    String? conversationContext,
    VoidCallback? onAccepted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiBreakdownModal(
        existingProjectId: existingProjectId,
        projectTitle: projectTitle,
        projectGoal: projectGoal,
        deadline: deadline,
        constraints: constraints,
        conversationContext: conversationContext,
        onAccepted: onAccepted,
      ),
    );
  }

  @override
  ConsumerState<AiBreakdownModal> createState() => _AiBreakdownModalState();
}

class _AiBreakdownModalState extends ConsumerState<AiBreakdownModal> {
  final _refinementController = TextEditingController();
  ProjectPlan? _plan;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() { super.initState(); _generate(); }

  @override
  void dispose() { _refinementController.dispose(); super.dispose(); }

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; });
    try {
      final planning = ref.read(aiPlanningServiceProvider);
      final user = await ref.read(authNotifierProvider.future);
      if (!mounted) return;
      final taskResult = user == null ? null : await ref.read(localTaskDbProvider).getTasksForUser(user.id);
      final existingTasks = taskResult is Success<List<Task>> ? taskResult.data : <Task>[];
      final plan = await planning.breakdownProject(
        title: widget.projectTitle, goal: widget.projectGoal, deadline: widget.deadline,
        constraints: widget.constraints, conversationContext: widget.conversationContext,
        refinement: _refinementController.text, currentDatetime: WallClock.deviceNowIso(),
        existingTasks: existingTasks, existingPhases: _plan?.phases ?? const []);
      if (mounted) setState(() => _plan = plan);
    } catch (e) {
      if (mounted) setState(() => _error = e is PlanningException ? e.message : 'الخطة ما وصلتش. جرّب تاني.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    final plan = _plan;
    final user = ref.read(authNotifierProvider).value;
    if (plan == null || user == null || _saving) return;
    setState(() => _saving = true);
    const uuid = Uuid();
    final projectId = widget.existingProjectId ?? uuid.v4();
    final taskIds = {for (final task in plan.phases.expand((p) => p.tasks)) task.id: uuid.v4()};
    final phaseIds = {for (final phase in plan.phases) phase.id: uuid.v4()};
    final now = DateTime.now();
    final tasks = <Task>[];
    for (final phase in plan.phases) {
      for (final task in phase.tasks) {
        tasks.add(Task(
          id: taskIds[task.id]!, userId: user.id, projectId: projectId, phaseId: phaseIds[phase.id],
          title: task.title, description: task.description, status: TaskStatus.planned,
          priority: task.priority ?? TaskPriority.medium, dueAt: task.suggestedDeadline,
          estimatedDurationMinutes: task.estimatedDurationMinutes, durationUncertainty: task.durationUncertainty,
          dependsOnTaskIds: task.dependsOn.map((id) => taskIds[id] ?? id).toList(), energyLevel: EnergyLevel.medium,
          source: TaskSource.ai, createdAt: now, updatedAt: now, version: 1, syncStatus: SyncStatus.pending));
      }
    }
    final taskResult = await ref.read(localTaskDbProvider).createApprovedTasks(tasks);
    if (taskResult is Failure<List<Task>>) {
      if (mounted) setState(() { _saving = false; _error = 'المهام ما اتحفظتش. مفيش خطة اتعتمدت.'; });
      return;
    }
    Project? existingProject;
    if (widget.existingProjectId != null) {
      final currentProjects = await LocalProjectDatabase.instance.forUser(user.id);
      if (currentProjects is Success<List<Project>>) {
        existingProject = currentProjects.data
            .where((p) => p.id == widget.existingProjectId)
            .firstOrNull;
      }
    }
    final mergedTaskIds = <String>[
      if (existingProject != null) ...existingProject.taskIds,
      ...taskIds.values,
    ];
    final project = existingProject != null
        ? existingProject.copyWith(
            nextStepTitle: existingProject.nextStepTitle ?? tasks.firstOrNull?.title,
            targetDate: existingProject.targetDate ??
                plan.phases.map((p) => p.suggestedDeadline).whereType<DateTime>().lastOrNull,
            taskIds: mergedTaskIds,
            updatedAt: now,
          )
        : Project(
            id: projectId, userId: user.id, title: plan.title, description: plan.goal, status: ProjectStatus.active,
            progressPercent: 0, nextStepTitle: tasks.firstOrNull?.title,
            targetDate: plan.phases.map((p) => p.suggestedDeadline).whereType<DateTime>().lastOrNull,
            taskIds: mergedTaskIds, createdAt: now, updatedAt: now);
    final phases = plan.phases.map((phase) => {
      'id': phaseIds[phase.id], 'title': phase.title, 'description': phase.description,
      'estimatedDurationMinutes': phase.estimatedDurationMinutes,
      'suggestedDeadline': phase.suggestedDeadline?.toIso8601String(),
      'taskIds': phase.tasks.map((task) => taskIds[task.id]).toList()}).toList();
    final projectResult = await LocalProjectDatabase.instance.save(project, phases: phases);
    if (!mounted) return;
    setState(() => _saving = false);
    if (projectResult is Failure<void>) {
      setState(() => _error = 'المهام اتحفظت، لكن بيانات المشروع محتاجة إعادة محاولة.');
      return;
    }
    ref.invalidate(todayTasksProvider);
    ref.invalidate(allTasksProvider);
    ref.invalidate(projectsProvider);
    widget.onAccepted?.call();
    HandelhaFeedback.showSuccess(
      context,
      'تم اعتماد ${plan.phases.length} مراحل و${tasks.length} مهمة.',
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final tasksCount = _plan?.phases.fold<int>(0, (sum, phase) => sum + phase.tasks.length) ?? 0;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(width: 44, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
        ListTile(leading: Icon(Icons.auto_fix_high_rounded, color: c.primary),
          title: Text(isEn ? 'Smart Project Breakdown' : 'تقسيم ذكي للمشروع', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
          subtitle: Text(_plan == null
              ? (isEn ? 'Reviewing goal and requirements' : 'بنراجع الهدف والمتطلبات')
              : (isEn ? '$tasksCount suggested tasks • Review before approving' : '$tasksCount مهمة مقترحة • راجعها قبل الاعتماد'),
              style: TextStyle(color: c.textSecondary)),
          trailing: IconButton(onPressed: _saving ? null : () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: c.textSecondary))),
        Divider(height: 1, color: c.border),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _plan == null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error ?? (isEn ? 'No plan available.' : 'مفيش خطة متاحة.'), textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary))))
          : ListView(padding: const EdgeInsets.all(20), children: [
              Text(_plan!.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              const SizedBox(height: 6),
              Text(_plan!.goal, style: TextStyle(color: c.textSecondary, height: 1.5)),
              if (_plan!.clarificationQuestion != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(isEn ? 'Clarification: ${_plan!.clarificationQuestion}' : 'سؤال للمراجعة: ${_plan!.clarificationQuestion}', style: TextStyle(color: c.warning))),
              const SizedBox(height: 18),
              for (final phase in _plan!.phases) ...[
                Text(phase.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary)),
                if (phase.description != null) Text(phase.description!, style: TextStyle(color: c.textSecondary)),
                if (phase.estimatedDurationMinutes != null) Text(isEn ? 'Phase estimate: ${phase.estimatedDurationMinutes} min' : 'تقدير المرحلة: ${phase.estimatedDurationMinutes} دقيقة', style: TextStyle(fontSize: 12, color: c.textMuted)),
                if (phase.suggestedDeadline != null) Text(isEn ? 'Suggested deadline: ${_date(phase.suggestedDeadline!)}' : 'ميعاد مقترح: ${_date(phase.suggestedDeadline!)}', style: TextStyle(fontSize: 12, color: c.textMuted)),
                const SizedBox(height: 8),
                for (final task in phase.tasks) Card(color: c.surfaceSoft, margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(task.title, style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary)),
                  if (task.description != null) Text(task.description!, style: TextStyle(color: c.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    if (task.estimatedDurationMinutes != null) Text(isEn ? 'Est: ${task.estimatedDurationMinutes} min' : 'تقدير: ${task.estimatedDurationMinutes} دقيقة', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    if (task.priority != null) Text(isEn ? 'Suggested priority: ${task.priority!.name}' : 'أولوية مقترحة: ${task.priority!.name}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    if (task.suggestedDeadline != null) Text(_date(task.suggestedDeadline!), style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    if (task.dependsOn.isNotEmpty) Text(isEn ? 'Depends on: ${task.dependsOn.join(', ')}' : 'يعتمد على: ${task.dependsOn.join('، ')}', style: TextStyle(fontSize: 12, color: c.textSecondary))]),
                  if (task.durationUncertainty != null) Text(isEn ? 'Uncertainty: ${task.durationUncertainty}' : 'دقة التقدير: ${task.durationUncertainty}', style: TextStyle(fontSize: 11, color: c.textMuted))]))),
                const SizedBox(height: 14)],
              TextField(controller: _refinementController, minLines: 1, maxLines: 3, decoration: InputDecoration(labelText: isEn ? 'Refine plan in your words' : 'عدّل الخطة بكلامك', hintText: isEn ? 'Example: fewer tasks, focus on MVP' : 'مثال: قلل عدد المهام وركّز على الـ MVP')),
              TextButton.icon(onPressed: _generate, icon: const Icon(Icons.refresh), label: Text(isEn ? 'Regenerate with changes' : 'إعادة توليد بالتعديلات')),
              if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.danger))])),
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), child: Row(children: [
          Expanded(child: OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(isEn ? 'Reject' : 'رفض'))),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: ElevatedButton(onPressed: _plan == null || _loading || _saving ? null : _accept, child: Text(_saving ? (isEn ? 'Saving...' : 'جارٍ الحفظ...') : (isEn ? 'Reviewed • Approve Plan' : 'مراجعة تمت • اعتماد الخطة'))))])),
      ]));
  }

  String _date(DateTime value) => '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

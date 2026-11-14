import '../../tasks/domain/task.dart';

class ProjectPlan {
  const ProjectPlan({required this.title, required this.goal, required this.phases, this.clarificationQuestion});
  final String title;
  final String goal;
  final List<PlanPhase> phases;
  final String? clarificationQuestion;
}

class PlanPhase {
  const PlanPhase({required this.id, required this.title, required this.tasks, this.description, this.estimatedDurationMinutes, this.suggestedDeadline});
  final String id;
  final String title;
  final String? description;
  final int? estimatedDurationMinutes;
  final DateTime? suggestedDeadline;
  final List<PlanTask> tasks;
}

class PlanTask {
  const PlanTask({
    required this.id,
    required this.title,
    this.description,
    this.estimatedDurationMinutes,
    this.durationUncertainty,
    this.priority,
    this.suggestedDeadline,
    this.dependsOn = const [],
  });
  final String id;
  final String title;
  final String? description;
  final int? estimatedDurationMinutes;
  final String? durationUncertainty;
  final TaskPriority? priority;
  final DateTime? suggestedDeadline;
  final List<String> dependsOn;
}

class TaskExtraction {
  const TaskExtraction({
    required this.title,
    this.description,
    this.estimatedDurationMinutes,
    this.dueAt,
    this.priority,
    this.dependsOn = const [],
    this.clarificationQuestion,
  });
  final String title;
  final String? description;
  final int? estimatedDurationMinutes;
  final DateTime? dueAt;
  final TaskPriority? priority;
  final List<String> dependsOn;
  final String? clarificationQuestion;
}

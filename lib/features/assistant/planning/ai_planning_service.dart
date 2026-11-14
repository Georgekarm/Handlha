import 'dart:convert';

import 'package:ai_assistant/ai_assistant.dart';

import '../../tasks/domain/task.dart';
import 'ai_planning_models.dart';

class PlanningException implements Exception {
  const PlanningException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AiPlanningService {
  AiPlanningService(this._llm);
  final LLMService _llm;

  Future<ProjectPlan> breakdownProject({
    required String title,
    required String goal,
    required String currentDatetime,
    String? deadline,
    String? constraints,
    String? conversationContext,
    String? refinement,
    List<Task> existingTasks = const [],
    List<PlanPhase> existingPhases = const [],
  }) async {
    final input = {
      'title': title,
      'goal': goal,
      if (deadline?.trim().isNotEmpty == true) 'deadline': deadline,
      if (constraints?.trim().isNotEmpty == true) 'constraints': constraints,
      if (conversationContext?.trim().isNotEmpty == true) 'conversation_context': conversationContext,
      if (refinement?.trim().isNotEmpty == true) 'refinement': refinement,
      'existing_tasks': existingTasks.map((t) => {
        'id': t.id,
        'title': t.title,
        'status': t.status.name,
        'estimated_duration_minutes': t.estimatedDurationMinutes,
        'due_at': t.dueAt?.toIso8601String(),
        'depends_on': t.dependsOnTaskIds,
      }).toList(),
      'existing_phases': existingPhases.map((p) => {
        'id': p.id,
        'title': p.title,
        'estimated_duration_minutes': p.estimatedDurationMinutes,
        'suggested_deadline': p.suggestedDeadline?.toIso8601String(),
        'task_ids': p.tasks.map((t) => t.id).toList(),
      }).toList(),
    };
    final reply = await _complete(
      conversationId: 'project-plan',
      currentDatetime: currentDatetime,
      instructions: '''
Return one JSON object only. Create a practical project plan from the supplied facts.
Schema: {"title":string,"goal":string,"clarification_question":string|null,"phases":[{"id":string,"title":string,"description":string|null,"estimated_duration_minutes":integer|null,"suggested_deadline":string|null,"tasks":[{"id":string,"title":string,"description":string|null,"estimated_duration_minutes":integer|null,"duration_uncertainty":string|null,"priority":"low"|"medium"|"high"|"urgent"|null,"suggested_deadline":string|null,"depends_on":[string]}]}]}.
Use unique new task IDs. depends_on may reference new task IDs or IDs supplied in existing_tasks, but no others. Dependencies must be acyclic and ordered. Use existing_tasks and existing_phases as context during refinement; do not recreate completed work. Balance estimated workload across phases and respect stated capacity and deadlines when enough information exists. Distinguish estimates from confirmed commitments: every deadline is only a suggestion and duration_uncertainty should explain uncertainty. Do not state that anything was saved or executed. Ask at most one clarification question only if essential; otherwise null. Do not invent user constraints or dates. Suggested task estimates and priorities are proposals, not confirmed facts.''',
      input: input,
    );
    return _parsePlan(_jsonObject(reply), existingTasks.map((t) => t.id).toSet());
  }

  Future<TaskExtraction> extractTask({
    required String text,
    required String currentDatetime,
    List<Task> existingTasks = const [],
  }) async {
    final input = {
      'text': text,
      'existing_tasks': existingTasks.map((t) => {'id': t.id, 'title': t.title}).toList(),
    };
    final reply = await _complete(
      conversationId: 'task-extraction',
      currentDatetime: currentDatetime,
      instructions: '''
Return one JSON object only. Extract only facts explicitly stated or unambiguously implied by the user's text.
Schema: {"title":string,"description":string|null,"estimated_duration_minutes":integer|null,"due_at":string|null,"priority":"low"|"medium"|"high"|"urgent"|null,"depends_on":[string],"clarification_question":string|null}.
depends_on may contain only IDs from existing_tasks when the user clearly states a dependency such as backend before frontend. Never invent a date, time, duration, priority, dependency, or commitment. If absent use null or []. Resolve relative dates using current_datetime. Ask at most one short clarification question only when essential.''',
      input: input,
    );
    return _parseExtraction(_jsonObject(reply), existingTasks);
  }

  Future<String> _complete({
    required String conversationId,
    required String currentDatetime,
    required String instructions,
    required Map<String, dynamic> input,
  }) async {
    final reply = await _llm.complete(LlmRequest(
      conversationId: conversationId,
      systemPrompt: 'You are Handelha planning engine. $instructions\ncurrent_datetime: $currentDatetime\nJSON must be valid UTF-8 with no markdown.',
      messages: [ConversationMessage.user(jsonEncode(input))],
      tools: const [],
    ));
    final text = reply.text?.trim();
    if (text == null || text.isEmpty) {
      throw const PlanningException('المساعد مرجعش بخطة صالحة. جرّب تاني.');
    }
    return text;
  }

  Map<String, dynamic> _jsonObject(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '').replaceFirst(RegExp(r'\s*```$'), '');
    }
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    throw const PlanningException('رد المساعد مش منظّم. جرّب تاني من غير ما نحفظ أي حاجة.');
  }

  ProjectPlan _parsePlan(Map<String, dynamic> json, [Set<String> existingTaskIds = const {}]) {
    final rawPhases = json['phases'];
    if (rawPhases is! List || rawPhases.isEmpty) {
      throw const PlanningException('الخطة ناقصة مراحل. راجع الهدف وجرّب تاني.');
    }
    final taskIds = <String>{};
    for (final phase in rawPhases) {
      if (phase is! Map || phase['tasks'] is! List) throw const PlanningException('صيغة الخطة غير صالحة.');
      for (final task in phase['tasks'] as List) {
        if (task is! Map || !taskIds.add(_requiredString(task['id'])) || existingTaskIds.contains(task['id'])) {
          throw const PlanningException('الخطة فيها مهمة ناقصة أو مكررة.');
        }
      }
    }
    final validDependencyIds = {...taskIds, ...existingTaskIds};
    final phases = rawPhases.map((raw) {
      final phase = raw as Map;
      final tasks = (phase['tasks'] as List).map((value) => _planTask(value as Map, validDependencyIds)).toList();
      return PlanPhase(
        id: _requiredString(phase['id']),
        title: _requiredString(phase['title']),
        description: _optionalString(phase['description']),
        estimatedDurationMinutes: _minutes(phase['estimated_duration_minutes']),
        suggestedDeadline: _date(phase['suggested_deadline']),
        tasks: tasks,
      );
    }).toList();
    _validateAcyclic(phases.expand((p) => p.tasks));
    return ProjectPlan(
      title: _requiredString(json['title']),
      goal: _requiredString(json['goal']),
      clarificationQuestion: _optionalString(json['clarification_question']),
      phases: phases,
    );
  }

  PlanTask _planTask(Map raw, Set<String> validIds) {
    final dependencies = _strings(raw['depends_on']);
    if (dependencies.any((id) => !validIds.contains(id))) {
      throw const PlanningException('الخطة فيها اعتماد على مهمة غير موجودة.');
    }
    return PlanTask(
      id: _requiredString(raw['id']),
      title: _requiredString(raw['title']),
      description: _optionalString(raw['description']),
      estimatedDurationMinutes: _minutes(raw['estimated_duration_minutes']),
      durationUncertainty: _optionalString(raw['duration_uncertainty']),
      priority: _priority(raw['priority']),
      suggestedDeadline: _date(raw['suggested_deadline']),
      dependsOn: dependencies,
    );
  }

  TaskExtraction _parseExtraction(Map<String, dynamic> json, List<Task> existing) {
    final ids = existing.map((t) => t.id).toSet();
    final dependencies = _strings(json['depends_on']);
    if (dependencies.any((id) => !ids.contains(id))) {
      throw const PlanningException('المساعد اقترح اعتماد غير موجود. راجع المهمة قبل الحفظ.');
    }
    return TaskExtraction(
      title: _requiredString(json['title']),
      description: _optionalString(json['description']),
      estimatedDurationMinutes: _minutes(json['estimated_duration_minutes']),
      dueAt: _date(json['due_at']),
      priority: _priority(json['priority']),
      dependsOn: dependencies,
      clarificationQuestion: _optionalString(json['clarification_question']),
    );
  }

  void _validateAcyclic(Iterable<PlanTask> tasks) {
    final byId = {for (final task in tasks) task.id: task};
    final visiting = <String>{};
    final visited = <String>{};
    bool visit(String id) {
      if (visited.contains(id) || !byId.containsKey(id)) return true;
      if (!visiting.add(id)) return false;
      for (final dependency in byId[id]!.dependsOn) {
        if (!visit(dependency)) return false;
      }
      visiting.remove(id);
      visited.add(id);
      return true;
    }
    if (byId.keys.any((id) => !visit(id))) {
      throw const PlanningException('الخطة فيها اعتماد دائري. عدّلها قبل الاعتماد.');
    }
  }

  String _requiredString(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) throw const PlanningException('رد المساعد ناقص بيانات أساسية.');
    return text;
  }

  String? _optionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  int? _minutes(Object? value) {
    if (value == null) return null;
    if (value is int && value > 0 && value <= 10080) return value;
    throw const PlanningException('مدة غير صالحة في رد المساعد.');
  }

  DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const PlanningException('تاريخ غير صالح في رد المساعد.');
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw const PlanningException('تاريخ غير صالح في رد المساعد.');
    return parsed;
  }

  TaskPriority? _priority(Object? value) {
    if (value == null) return null;
    for (final priority in TaskPriority.values) {
      if (priority.name == value) return priority;
    }
    throw const PlanningException('أولوية غير صالحة في رد المساعد.');
  }

  List<String> _strings(Object? value) {
    if (value == null) return const [];
    if (value is List && value.every((item) => item is String)) return value.cast<String>();
    throw const PlanningException('صيغة الاعتمادات غير صالحة.');
  }
}

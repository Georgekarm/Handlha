import 'package:equatable/equatable.dart';

enum TaskStatus { inbox, planned, inProgress, completed, cancelled }

enum TaskPriority { low, medium, high, urgent }

enum EnergyLevel { low, medium, high }

enum TaskSource { manual, chat, voice, ai, import }

enum SyncStatus { synced, pending, failed }

enum TaskRecurrence { none, daily, weekdays, weekly, monthly }

/// Core domain entity for a Task.
/// This is the canonical representation used throughout the app.
/// DTOs/DB objects must be mapped to/from this.
class Task extends Equatable {
  final String id;
  final String userId;
  final String? projectId;
  final String? parentTaskId;
  final String? phaseId;
  final List<String> dependsOnTaskIds;
  final String? durationUncertainty;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueAt;
  final DateTime? scheduledStartAt;
  final int? estimatedDurationMinutes;
  final int? actualDurationMinutes;
  final EnergyLevel energyLevel;
  final TaskSource source;
  final double? aiConfidence;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final SyncStatus syncStatus;
  final TaskRecurrence recurrence;
  final DateTime? deletedAt;

  const Task({
    required this.id,
    required this.userId,
    this.projectId,
    this.parentTaskId,
    this.phaseId,
    this.dependsOnTaskIds = const [],
    this.durationUncertainty,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.dueAt,
    this.scheduledStartAt,
    this.estimatedDurationMinutes,
    this.actualDurationMinutes,
    required this.energyLevel,
    required this.source,
    this.aiConfidence,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.syncStatus,
    this.recurrence = TaskRecurrence.none,
    this.deletedAt,
  });

  bool get isCompleted => status == TaskStatus.completed;
  bool get isCancelled => status == TaskStatus.cancelled;
  bool get isDeleted => deletedAt != null;

  Task copyWith({
    String? id,
    String? userId,
    String? projectId,
    String? parentTaskId,
    String? phaseId,
    List<String>? dependsOnTaskIds,
    String? durationUncertainty,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueAt,
    DateTime? scheduledStartAt,
    int? estimatedDurationMinutes,
    int? actualDurationMinutes,
    EnergyLevel? energyLevel,
    TaskSource? source,
    double? aiConfidence,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    SyncStatus? syncStatus,
    TaskRecurrence? recurrence,
    DateTime? deletedAt,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      phaseId: phaseId ?? this.phaseId,
      dependsOnTaskIds: dependsOnTaskIds ?? this.dependsOnTaskIds,
      durationUncertainty: durationUncertainty ?? this.durationUncertainty,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueAt: dueAt ?? this.dueAt,
      scheduledStartAt: scheduledStartAt ?? this.scheduledStartAt,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      actualDurationMinutes:
          actualDurationMinutes ?? this.actualDurationMinutes,
      energyLevel: energyLevel ?? this.energyLevel,
      source: source ?? this.source,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
      recurrence: recurrence ?? this.recurrence,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    projectId,
    parentTaskId,
    phaseId,
    dependsOnTaskIds,
    durationUncertainty,
    title,
    description,
    status,
    priority,
    dueAt,
    scheduledStartAt,
    estimatedDurationMinutes,
    actualDurationMinutes,
    energyLevel,
    source,
    aiConfidence,
    createdAt,
    updatedAt,
    version,
    syncStatus,
    recurrence,
    deletedAt,
  ];
}

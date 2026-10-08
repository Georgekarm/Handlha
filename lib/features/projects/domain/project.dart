import 'package:equatable/equatable.dart';

enum ProjectStatus { active, paused, completed, archived }

class Project extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final ProjectStatus status;
  final double progressPercent;
  final String? nextStepTitle;
  final DateTime? targetDate;
  final List<String> taskIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Project({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.status,
    required this.progressPercent,
    this.nextStepTitle,
    this.targetDate,
    required this.taskIds,
    required this.createdAt,
    required this.updatedAt,
  });

  Project copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    ProjectStatus? status,
    double? progressPercent,
    String? nextStepTitle,
    DateTime? targetDate,
    List<String>? taskIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      nextStepTitle: nextStepTitle ?? this.nextStepTitle,
      targetDate: targetDate ?? this.targetDate,
      taskIds: taskIds ?? this.taskIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    description,
    status,
    progressPercent,
    nextStepTitle,
    targetDate,
    taskIds,
    createdAt,
    updatedAt,
  ];
}

/// AI-generated proposal awaiting user confirmation.
/// No AI result becomes a domain command without going through this.
class AssistantProposal extends Equatable {
  final String id;
  final String type;
  final String? sourceMessageId;
  final double confidence;
  final List<String> missingInformation;
  final List<ProposedTaskChange> proposedChanges;
  final bool requiresConfirmation;
  final DateTime expiresAt;
  final ProposalStatus status;

  const AssistantProposal({
    required this.id,
    required this.type,
    this.sourceMessageId,
    required this.confidence,
    required this.missingInformation,
    required this.proposedChanges,
    required this.requiresConfirmation,
    required this.expiresAt,
    required this.status,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  List<Object?> get props => [
    id,
    type,
    sourceMessageId,
    confidence,
    missingInformation,
    proposedChanges,
    requiresConfirmation,
    expiresAt,
    status,
  ];
}

enum ProposalStatus { pending, confirmed, rejected, expired }

class ProposedTaskChange extends Equatable {
  final String field;
  final dynamic currentValue;
  final dynamic proposedValue;

  const ProposedTaskChange({
    required this.field,
    this.currentValue,
    required this.proposedValue,
  });

  @override
  List<Object?> get props => [field, currentValue, proposedValue];
}

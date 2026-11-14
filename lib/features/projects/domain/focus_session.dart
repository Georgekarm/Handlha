import 'package:equatable/equatable.dart';

/// A completed or abandoned focus interval persisted locally.
class FocusSession extends Equatable {
  final String id;
  final String userId;
  final String? taskId;
  final String taskTitle;
  final DateTime startedAt;
  final DateTime endedAt;
  final int elapsedMinutes;
  final bool completed;

  const FocusSession({
    required this.id,
    required this.userId,
    this.taskId,
    required this.taskTitle,
    required this.startedAt,
    required this.endedAt,
    required this.elapsedMinutes,
    required this.completed,
  });

  @override
  List<Object?> get props => [id, userId, taskId, taskTitle, startedAt, endedAt, elapsedMinutes, completed];
}

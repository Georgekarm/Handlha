import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/task.dart';
import '../../../core/database/local_task_database.dart';
import '../../../core/result/result.dart';
import '../../../core/logger/app_logger.dart';
import '../../authentication/presentation/auth_providers.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final localTaskDbProvider = Provider<LocalTaskDatabase>((ref) {
  return LocalTaskDatabase.instance;
});

/// Today's tasks for the current user
final todayTasksProvider =
    AsyncNotifierProvider<TodayTasksNotifier, List<Task>>(
      TodayTasksNotifier.new,
    );

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class TodayTasksNotifier extends AsyncNotifier<List<Task>> {
  static const _tag = 'TodayTasksNotifier';

  LocalTaskDatabase get _db => ref.read(localTaskDbProvider);

  String? get _userId => ref.read(authNotifierProvider).value?.id;

  @override
  Future<List<Task>> build() async {
    return _fetchTasks();
  }

  Future<List<Task>> _fetchTasks() async {
    final userId = _userId;
    if (userId == null) return [];

    final result = await _db.getTasksForToday(userId);
    return switch (result) {
      Success<List<Task>>(data: final tasks) => tasks,
      Failure<List<Task>>(failure: final f) => throw Exception(f.message),
    };
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchTasks);
  }

  /// Optimistic completion — marks task complete immediately, rolls back on fail
  Future<void> completeTask(String taskId) async {
    final previousState = state;

    // Optimistic update
    state = AsyncData(
      state.value?.map((t) {
            if (t.id == taskId) {
              return t.copyWith(status: TaskStatus.completed);
            }
            return t;
          }).toList() ??
          [],
    );

    final result = await _db.completeTask(taskId);
    if (result is Failure<Task>) {
      AppLogger.warning(
        'completeTask rollback: ${result.failure.message}',
        tag: _tag,
      );
      // Rollback to previous state
      state = previousState;
    }
  }

  Future<Result<Task>> createTask({
    required String title,
    TaskPriority priority = TaskPriority.medium,
    DateTime? scheduledStartAt,
    int? estimatedDurationMinutes,
    TaskStatus status = TaskStatus.inbox,
  }) async {
    final userId = _userId;
    if (userId == null) {
      return const Failure(AuthFailure('يجب تسجيل الدخول.'));
    }

    final result = await _db.createTask(
      userId: userId,
      title: title,
      priority: priority,
      scheduledStartAt: scheduledStartAt,
      estimatedDurationMinutes: estimatedDurationMinutes,
      status: status,
    );

    if (result is Success<Task>) {
      await refresh();
    }
    return result;
  }

  Future<void> deleteTask(String taskId) async {
    final previousState = state;
    state = AsyncData(state.value?.where((t) => t.id != taskId).toList() ?? []);

    final result = await _db.deleteTask(taskId);
    if (result is Failure<void>) {
      state = previousState;
    }
  }
}

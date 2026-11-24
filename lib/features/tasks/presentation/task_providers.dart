import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_task_database.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/result/result.dart';
import '../../../core/telemetry/local_core_loop_telemetry.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../../notifications/local_notification_service.dart';
import '../domain/task.dart';

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

/// All tasks for the current user
final allTasksProvider =
    AsyncNotifierProvider<AllTasksNotifier, List<Task>>(
      AllTasksNotifier.new,
    );

// ---------------------------------------------------------------------------
// Notifiers
// ---------------------------------------------------------------------------

class TodayTasksNotifier extends AsyncNotifier<List<Task>> {
  static const _tag = 'TodayTasksNotifier';

  LocalTaskDatabase get _db => ref.read(localTaskDbProvider);

  String? get _userId => ref.read(authNotifierProvider).value?.id;

  Future<String?> _resolveUserId() async {
    final immediate = _userId;
    if (immediate != null) return immediate;
    final user = await ref.read(authNotifierProvider.future);
    return user?.id;
  }

  @override
  Future<List<Task>> build() async {
    final userId = ref.watch(authNotifierProvider.select((s) => s.value?.id));
    if (userId == null) return [];
    return _fetchTasksFor(userId);
  }

  Future<List<Task>> _fetchTasksFor(String userId) async {
    final result = await _db.getTasksForToday(userId);
    return switch (result) {
      Success<List<Task>>(data: final tasks) => _restoreNotifications(tasks),
      Failure<List<Task>>(failure: final f) => throw Exception(f.message),
    };
  }

  Future<List<Task>> _restoreNotifications(List<Task> tasks) async {
    await LocalNotificationService.instance.rescheduleTasks(tasks);
    return tasks;
  }

  Future<List<Task>> _fetchTasks() async {
    final userId = await _resolveUserId();
    if (userId == null) return [];
    return _fetchTasksFor(userId);
  }

  void _invalidateSibling() {
    if (this is AllTasksNotifier) {
      ref.invalidate(todayTasksProvider);
    } else {
      ref.invalidate(allTasksProvider);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchTasks);
  }

  /// Optimistic completion — marks task complete immediately, rolls back on fail
  Future<void> completeTask(String taskId) async {
    final previousState = state;

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
      state = previousState;
    } else {
      await LocalNotificationService.instance.cancelTask(taskId);
      await LocalCoreLoopTelemetry.instance.recordEvent(
        _userId,
        'task_completed',
      );
      await refresh();
      _invalidateSibling();
    }
  }

  Future<void> reopenTask(String taskId) async {
    final previousState = state;
    final current = state.value ?? const <Task>[];
    final matches = current.where((t) => t.id == taskId).toList();
    if (matches.isEmpty) return;
    final existing = matches.first;
    final reopened = existing.copyWith(status: TaskStatus.planned);
    state = AsyncData(
      current.map((t) => t.id == taskId ? reopened : t).toList(),
    );
    final result = await _db.updateTask(reopened);
    if (result is Failure<Task>) {
      state = previousState;
    } else {
      await LocalNotificationService.instance.scheduleTask(reopened);
      _invalidateSibling();
    }
  }

  Future<void> rescheduleTask(String taskId, DateTime newDate) async {
    final previousState = state;
    final current = state.value ?? const <Task>[];
    final matches = current.where((t) => t.id == taskId).toList();
    if (matches.isEmpty) return;
    final task = matches.first.copyWith(
      dueAt: newDate,
      scheduledStartAt: newDate,
      status: TaskStatus.planned,
    );
    state = AsyncData(current.map((t) => t.id == taskId ? task : t).toList());
    final result = await _db.updateTask(task);
    if (result is Failure<Task>) {
      state = previousState;
    } else {
      await LocalNotificationService.instance.scheduleTask(task);
      _invalidateSibling();
    }
  }

  Future<Result<Task>> updateTask(Task updated) async {
    final result = await _db.updateTask(updated);
    if (result is Success<Task>) {
      await LocalNotificationService.instance.scheduleTask(result.data);
      await refresh();
      _invalidateSibling();
    }
    return result;
  }

  Future<Result<Task>> createTask({
    required String title,
    TaskPriority priority = TaskPriority.medium,
    EnergyLevel energyLevel = EnergyLevel.medium,
    DateTime? scheduledStartAt,
    int? estimatedDurationMinutes,
    TaskStatus status = TaskStatus.inbox,
    String? description,
    String? projectId,
    List<String> dependsOnTaskIds = const [],
    TaskSource source = TaskSource.manual,
    TaskRecurrence recurrence = TaskRecurrence.none,
  }) async {
    final userId = await _resolveUserId();
    if (userId == null) {
      return const Failure(AuthFailure('يجب تسجيل الدخول.'));
    }

    final result = await _db.createTask(
      userId: userId,
      title: title,
      priority: priority,
      energyLevel: energyLevel,
      scheduledStartAt: scheduledStartAt,
      estimatedDurationMinutes: estimatedDurationMinutes,
      status: status,
      description: description,
      projectId: projectId,
      dependsOnTaskIds: dependsOnTaskIds,
      source: source,
      recurrence: recurrence,
    );

    if (result is Success<Task>) {
      await LocalNotificationService.instance.scheduleTask(result.data);
      await refresh();
      _invalidateSibling();
    }
    return result;
  }

  Future<void> deleteTask(String taskId) async {
    final previousState = state;
    state = AsyncData(state.value?.where((t) => t.id != taskId).toList() ?? []);

    final result = await _db.deleteTask(taskId);
    if (result is Failure<void>) {
      state = previousState;
    } else {
      await LocalNotificationService.instance.cancelTask(taskId);
      _invalidateSibling();
    }
  }
}

class AllTasksNotifier extends TodayTasksNotifier {
  @override
  Future<List<Task>> _fetchTasksFor(String userId) async {
    final result = await _db.getTasksForUser(userId);
    return switch (result) {
      Success<List<Task>>(data: final tasks) => _restoreNotifications(tasks),
      Failure<List<Task>>(failure: final f) => throw Exception(f.message),
    };
  }

  @override
  Future<List<Task>> build() async {
    final userId = ref.watch(authNotifierProvider.select((s) => s.value?.id));
    if (userId == null) return [];
    return _fetchTasksFor(userId);
  }

  @override
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchTasks);
  }
}

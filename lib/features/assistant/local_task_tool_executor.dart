// ignore_for_file: prefer_initializing_formals
import 'package:ai_assistant/ai_assistant.dart';

import '../../core/database/local_task_database.dart';
import '../../core/result/result.dart';
import '../../core/telemetry/local_core_loop_telemetry.dart';
import '../notifications/alarm_reminder_store.dart';
import '../notifications/local_notification_service.dart';
import '../tasks/domain/task.dart';

/// Executes validated assistant actions against the user's local task &
/// alarm/reminder stores. No network access is performed here; ownership is
/// always scoped by userId.
class LocalTaskToolExecutor implements ToolExecutor {
  LocalTaskToolExecutor({
    required LocalTaskDatabase database,
    required String? Function() userId,
    void Function()? onChanged,
    DateTime Function()? nowProvider,
    String Function()? alertModeResolver,
  })  : _database = database,
        _userId = userId,
        _onChanged = onChanged,
        _nowProvider = nowProvider ?? DateTime.now,
        _alertModeResolver =
            alertModeResolver ?? (() => AlarmReminderStore.current.defaultAlertMode);

  final LocalTaskDatabase _database;
  final String? Function() _userId;
  final void Function()? _onChanged;
  final DateTime Function() _nowProvider;
  final String Function() _alertModeResolver;

  static const _tools = {
    'create_task',
    'update_task',
    'delete_task',
    'complete_task',
    'get_tasks',
    'search_tasks',
    'get_schedule',
    'get_daily_summary',
    'get_upcoming_tasks',
    'create_reminder',
    'update_reminder',
    'delete_reminder',
  };

  @override
  Set<String>? get supportedTools => _tools;

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final userId = _userId();
    if (userId == null || !_tools.contains(call.name)) {
      return ToolResult.permissionDenied();
    }
    final current = await _database.getTasksForUser(userId);
    if (current is Failure<List<Task>>) return ToolResult.failed();
    final tasks = (current as Success<List<Task>>).data;
    final args = call.arguments;

    switch (call.name) {
      case 'create_task':
        return _create(userId, args);
      case 'create_reminder':
        return _createReminder(userId, tasks, args);
      case 'update_reminder':
        return _updateReminder(userId, args);
      case 'delete_reminder':
        return _deleteReminder(userId, args);
      case 'get_tasks':
        return ToolResult.success({'tasks': _maps(_filter(tasks, args))});
      case 'search_tasks':
        return ToolResult.success({'tasks': _maps(_search(tasks, args))});
      case 'get_schedule':
        final day = _date(args['date']) ?? _day(_nowProvider());
        return ToolResult.success(
          {'date': _isoDate(day), 'tasks': _maps(_onDate(tasks, day))},
        );
      case 'get_daily_summary':
        final day = _date(args['date']) ?? _day(_nowProvider());
        final dayTasks = _onDate(tasks, day);
        final done = dayTasks.where((t) => t.isCompleted).length;
        return ToolResult.success({
          'date': _isoDate(day),
          'done': done,
          'pending': dayTasks.length - done,
          'overdue': tasks
              .where((t) =>
                  t.dueAt != null && t.dueAt!.isBefore(day) && !t.isCompleted)
              .length,
        });
      case 'get_upcoming_tasks':
        final now = _nowProvider();
        final end = now.add(Duration(days: (args['days_ahead'] as int?) ?? 7));
        final upcoming = tasks.where((t) {
          final date = t.dueAt ?? t.scheduledStartAt;
          return date != null &&
              !date.isBefore(now) &&
              date.isBefore(end) &&
              !t.isCompleted &&
              !t.isCancelled;
        }).toList()
          ..sort(
            (a, b) => (a.dueAt ?? a.scheduledStartAt)!
                .compareTo((b.dueAt ?? b.scheduledStartAt)!),
          );
        return ToolResult.success({
          'tasks': _maps(upcoming.take((args['limit'] as int?) ?? 10).toList()),
        });
      case 'complete_task':
        final match = _resolve(tasks, args);
        if (match is _Many) return ToolResult.ambiguous(_maps(match.tasks));
        if (match is! _One) return ToolResult.notFound();
        final completed = args['completed'] as bool? ?? true;
        final result = completed
            ? await _database.completeTask(match.task.id)
            : await _database.updateTask(
                match.task.copyWith(status: TaskStatus.planned),
              );
        if (result is Success<Task>) {
          if (completed) {
            await LocalNotificationService.instance.cancelTask(match.task.id);
            await _disableReminderForTask(userId, match.task.id);
            await LocalCoreLoopTelemetry.instance.recordEvent(
              userId,
              'task_completed',
            );
          } else {
            await LocalNotificationService.instance.scheduleTask(result.data);
          }
        }
        return _taskResult(result);
      case 'update_task':
        final match = _resolve(tasks, args);
        if (match is _Many) return ToolResult.ambiguous(_maps(match.tasks));
        if (match is! _One) return ToolResult.notFound();
        final nextDue = _dateTime(args['date'], args['time']);
        final updated = match.task.copyWith(
          title: args['title'] as String?,
          description: args['description'] as String?,
          priority: _priority(args['priority']) ?? match.task.priority,
          recurrence: _recurrence(args['recurrence']) ?? match.task.recurrence,
          dueAt: nextDue ?? match.task.dueAt,
          scheduledStartAt: nextDue ?? match.task.scheduledStartAt,
        );
        final result = await _database.updateTask(updated);
        if (result is Success<Task>) {
          await LocalNotificationService.instance.scheduleTask(result.data);
          if (nextDue != null) {
            await _updateLinkedAlarmTime(userId, result.data, nextDue);
          }
        }
        return _taskResult(result);
      case 'delete_task':
        final match = _resolve(tasks, args);
        if (match is _Many) return ToolResult.ambiguous(_maps(match.tasks));
        if (match is! _One) return ToolResult.notFound();
        final result = await _database.deleteTask(match.task.id);
        if (result is Failure<void>) return ToolResult.failed();
        await LocalNotificationService.instance.cancelTask(match.task.id);
        await _removeReminderForTask(userId, match.task.id);
        _onChanged?.call();
        return ToolResult.success(
          {'task_id': match.task.id, 'title': match.task.title},
        );
      default:
        return ToolResult.permissionDenied();
    }
  }

  Future<ToolResult> _create(String userId, Map<String, dynamic> args) async {
    final due = _dateTime(args['date'], args['time']);
    final result = await _database.createTask(
      userId: userId,
      title: args['title'] as String,
      description: args['description'] as String?,
      priority: _priority(args['priority']) ?? TaskPriority.medium,
      recurrence: _recurrence(args['recurrence']) ?? TaskRecurrence.none,
      dueAt: due,
      scheduledStartAt: due,
      estimatedDurationMinutes: args['estimated_duration_minutes'] as int?,
      status: due != null ? TaskStatus.planned : TaskStatus.inbox,
      source: TaskSource.chat,
    );
    String? scheduleStatus;
    if (result is Success<Task>) {
      await LocalCoreLoopTelemetry.instance.recordEvent(userId, 'task_created');
      final mode = _alertModeResolver();
      if (due != null) {
        final remindOffset = args['reminder_minutes_before'] as int?;
        final scheduledAt = remindOffset != null
            ? due.subtract(Duration(minutes: remindOffset))
            : due;
        final item = await _persistReminder(
          userId: userId,
          id: result.data.id,
          title: result.data.title,
          scheduledAt: scheduledAt,
          alertMode: mode,
          taskId: result.data.id,
        );
        scheduleStatus = item.scheduleStatus;
      } else {
        final outcome =
            await LocalNotificationService.instance.scheduleTask(result.data);
        scheduleStatus = outcome.status.name;
      }
    }
    return _taskResult(result, scheduleStatus: scheduleStatus);
  }

  Future<ToolResult> _createReminder(
    String userId,
    List<Task> tasks,
    Map<String, dynamic> args,
  ) async {
    final now = _nowProvider();
    final mode = _alertModeResolver();
    var title = (args['title'] ?? '').toString().trim();
    DateTime? scheduledAt;
    String? linkedTaskId;

    if (args['in_minutes'] != null) {
      final mins = (args['in_minutes'] as num).toInt().clamp(1, 10080);
      scheduledAt = now.add(Duration(minutes: mins));
    } else if (args['date'] != null && args['time'] != null) {
      scheduledAt = _dateTime(args['date'], args['time']);
    } else if (args['task_id'] != null || args['task_query'] != null) {
      final match = _resolve(tasks, {
        if (args['task_id'] != null) 'task_id': args['task_id'],
        if (args['task_query'] != null) 'query': args['task_query'],
      });
      if (match is _Many) return ToolResult.ambiguous(_maps(match.tasks));
      if (match is! _One) return ToolResult.notFound();
      linkedTaskId = match.task.id;
      if (title.isEmpty) title = match.task.title;
      final base = match.task.dueAt ?? match.task.scheduledStartAt ?? now;
      final minsBefore = (args['minutes_before'] as num?)?.toInt() ?? 0;
      scheduledAt = base.subtract(Duration(minutes: minsBefore));
    }

    if (scheduledAt == null) {
      return ToolResult.failed(message: 'Missing reminder time.');
    }
    if (title.isEmpty) title = 'تذكير مهمة';

    if (linkedTaskId == null) {
      final taskRes = await _database.createTask(
        userId: userId,
        title: title,
        priority: TaskPriority.high,
        dueAt: scheduledAt,
        scheduledStartAt: scheduledAt,
        status: TaskStatus.planned,
        source: TaskSource.chat,
      );
      if (taskRes is Success<Task>) {
        linkedTaskId = taskRes.data.id;
        await LocalCoreLoopTelemetry.instance.recordEvent(
          userId,
          'task_created',
        );
      }
    }

    final reminderId =
        linkedTaskId ?? 'alarm_${now.millisecondsSinceEpoch}';
    final item = await _persistReminder(
      userId: userId,
      id: reminderId,
      title: title,
      scheduledAt: scheduledAt,
      alertMode: mode,
      taskId: linkedTaskId,
    );

    _onChanged?.call();
    return ToolResult.success({
      'reminder_id': item.id,
      'task_id': ?linkedTaskId,
      'title': item.title,
      'date': _isoDate(scheduledAt),
      'time': _isoTime(scheduledAt),
      'alert_mode': mode,
      'schedule_status': item.scheduleStatus,
    });
  }

  Future<ToolResult> _updateReminder(
    String userId,
    Map<String, dynamic> args,
  ) async {
    final loaded = await AlarmReminderStore.load(userId);
    final match = _resolveReminder(loaded.items, args);
    if (match == null) return ToolResult.notFound();

    DateTime nextAt = match.scheduledAt;
    if (args['in_minutes'] != null) {
      nextAt = _nowProvider()
          .add(Duration(minutes: (args['in_minutes'] as num).toInt()));
    } else if (args['date'] != null || args['time'] != null) {
      final base = match.scheduledAt;
      final d = _date(args['date']) ?? DateTime(base.year, base.month, base.day);
      final timeStr = args['time']?.toString() ?? _isoTime(base);
      final parts = timeStr.split(':');
      nextAt = DateTime(
        d.year,
        d.month,
        d.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }
    final nextTitle = (args['title'] as String?)?.trim();
    final updated = await _persistReminder(
      userId: userId,
      id: match.id,
      title: (nextTitle == null || nextTitle.isEmpty) ? match.title : nextTitle,
      scheduledAt: nextAt,
      alertMode: match.alertMode,
      taskId: match.taskId,
    );
    _onChanged?.call();
    return ToolResult.success({
      'reminder_id': updated.id,
      'title': updated.title,
      'date': _isoDate(updated.scheduledAt),
      'time': _isoTime(updated.scheduledAt),
      'alert_mode': updated.alertMode,
      'schedule_status': updated.scheduleStatus,
    });
  }

  Future<ToolResult> _deleteReminder(
    String userId,
    Map<String, dynamic> args,
  ) async {
    final loaded = await AlarmReminderStore.load(userId);
    final match = _resolveReminder(loaded.items, args);
    if (match == null) return ToolResult.notFound();

    final remaining = loaded.items.where((e) => e.id != match.id).toList();
    await AlarmReminderStore.save(userId, loaded.copyWith(items: remaining));
    await LocalNotificationService.instance.cancelById(match.id);
    _onChanged?.call();
    return ToolResult.success({'reminder_id': match.id, 'title': match.title});
  }

  AlarmReminderItem? _resolveReminder(
    List<AlarmReminderItem> items,
    Map<String, dynamic> args,
  ) {
    final id = args['reminder_id']?.toString();
    if (id != null && id.isNotEmpty) {
      return items.where((e) => e.id == id).firstOrNull;
    }
    final query = (args['query'] ?? '').toString().trim().toLowerCase();
    if (query.isEmpty) return null;
    return items
        .where((e) => e.title.toLowerCase().contains(query))
        .firstOrNull;
  }

  Future<AlarmReminderItem> _persistReminder({
    required String userId,
    required String id,
    required String title,
    required DateTime scheduledAt,
    required String alertMode,
    String? taskId,
  }) async {
    final current = await AlarmReminderStore.load(userId);
    final outcome = await LocalNotificationService.instance.scheduleReminderItem(
      id: id,
      title: title,
      scheduledAt: scheduledAt,
      alertMode: alertMode,
      taskId: taskId,
      userId: userId,
      requestPermission: false,
    );
    await LocalCoreLoopTelemetry.instance.recordEvent(
      userId,
      'alarm_schedule_outcome',
      alarmStatus: outcome.status.name,
    );
    final item = AlarmReminderItem(
      id: id,
      title: title,
      scheduledAt: scheduledAt,
      alertMode: alertMode,
      isEnabled: true,
      taskId: taskId,
      scheduleStatus: outcome.status.name,
    );
    final nextModes = Map<String, String>.from(current.taskAlertModes);
    if (taskId != null) {
      nextModes[taskId] = alertMode;
    }
    final filtered = current.items.where((e) => e.id != item.id).toList();
    final updated = [item, ...filtered]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    await AlarmReminderStore.save(
      userId,
      current.copyWith(
        defaultAlertMode: alertMode,
        items: updated,
        taskAlertModes: nextModes,
      ),
    );
    return item;
  }

  Future<void> _updateLinkedAlarmTime(
    String userId,
    Task task,
    DateTime nextDue,
  ) async {
    final current = await AlarmReminderStore.load(userId);
    final idx =
        current.items.indexWhere((e) => e.taskId == task.id || e.id == task.id);
    if (idx < 0) return;
    final item = current.items[idx].copyWith(
      title: task.title,
      scheduledAt: nextDue,
    );
    final nextItems = List<AlarmReminderItem>.from(current.items);
    nextItems[idx] = item;
    await AlarmReminderStore.save(userId, current.copyWith(items: nextItems));
  }

  Future<void> _disableReminderForTask(String userId, String taskId) async {
    final current = await AlarmReminderStore.load(userId);
    if (!current.items.any((e) => e.taskId == taskId || e.id == taskId)) {
      return;
    }
    final updated = [
      for (final item in current.items)
        if (item.taskId == taskId || item.id == taskId)
          item.copyWith(isEnabled: false)
        else
          item,
    ];
    await AlarmReminderStore.save(userId, current.copyWith(items: updated));
  }

  Future<void> _removeReminderForTask(String userId, String taskId) async {
    final current = await AlarmReminderStore.load(userId);
    final updated = current.items
        .where((e) => e.taskId != taskId && e.id != taskId)
        .toList();
    final nextModes = Map<String, String>.from(current.taskAlertModes)
      ..remove(taskId);
    await AlarmReminderStore.save(
      userId,
      current.copyWith(items: updated, taskAlertModes: nextModes),
    );
  }

  ToolResult _taskResult(Result<Task> result, {String? scheduleStatus}) {
    if (result is Failure<Task>) {
      return ToolResult.failed(message: result.failure.message);
    }
    final task = (result as Success<Task>).data;
    _onChanged?.call();
    return ToolResult.success({
      ..._map(task),
      'schedule_status': ?scheduleStatus,
    });
  }

  _Match _resolve(List<Task> tasks, Map<String, dynamic> args) {
    final id = args['task_id']?.toString();
    if (id != null && id.isNotEmpty) {
      final found = tasks.where((t) => t.id == id).toList();
      return found.length == 1 ? _One(found.single) : const _None();
    }
    final query = (args['query'] ?? '').toString().trim().toLowerCase();
    final createdOn = _date(args['created_on']);
    final dueDate = _date(args['due_date']);
    final found = tasks.where((t) {
      final title = '${t.title} ${t.description ?? ''}'.toLowerCase();
      final created = _day(t.createdAt);
      final due = t.dueAt == null ? null : _day(t.dueAt!);
      return (query.isEmpty || title.contains(query)) &&
          (createdOn == null || created == createdOn) &&
          (dueDate == null || due == dueDate);
    }).toList();
    if (found.length == 1) return _One(found.single);
    if (found.length > 1) return _Many(found.take(5).toList());
    return const _None();
  }

  List<Task> _filter(List<Task> tasks, Map<String, dynamic> args) {
    Iterable<Task> result = tasks;
    final date = _date(args['date']);
    if (date != null) result = _onDate(result, date);
    final from = _date(args['date_from']);
    final to = _date(args['date_to']);
    if (from != null || to != null) {
      final end = (to ?? from!).add(const Duration(days: 1));
      result = result.where((t) {
        final value = t.scheduledStartAt ?? t.dueAt;
        return value != null &&
            (from == null || !value.isBefore(from)) &&
            value.isBefore(end);
      });
    }
    final status = args['status']?.toString() ?? 'pending';
    if (status == 'completed') result = result.where((t) => t.isCompleted);
    if (status != 'all' && status != 'completed') {
      result = result.where((t) => !t.isCompleted && !t.isCancelled);
    }
    final priority = _priority(args['priority']);
    if (priority != null) result = result.where((t) => t.priority == priority);
    return result.take((args['limit'] as int?) ?? 20).toList();
  }

  List<Task> _search(List<Task> tasks, Map<String, dynamic> args) {
    final q = args['query'].toString().toLowerCase();
    Iterable<Task> result = tasks.where(
      (t) => '${t.title} ${t.description ?? ''}'.toLowerCase().contains(q),
    );
    final status = args['status']?.toString() ?? 'all';
    if (status == 'completed') result = result.where((t) => t.isCompleted);
    if (status == 'pending') {
      result = result.where((t) => !t.isCompleted && !t.isCancelled);
    }
    return result.take((args['limit'] as int?) ?? 10).toList();
  }

  List<Task> _onDate(Iterable<Task> tasks, DateTime day) {
    final end = day.add(const Duration(days: 1));
    return tasks.where((t) {
      final value = t.scheduledStartAt ?? t.dueAt;
      return value != null && !value.isBefore(day) && value.isBefore(end);
    }).toList();
  }

  List<Map<String, dynamic>> _maps(Iterable<Task> tasks) =>
      tasks.map(_map).toList();
  Map<String, dynamic> _map(Task t) => {
        'task_id': t.id,
        'title': t.title,
        'description': t.description,
        'status': t.status.name,
        'priority': t.priority.name,
        'recurrence': t.recurrence.name,
        if (t.estimatedDurationMinutes != null)
          'estimated_minutes': t.estimatedDurationMinutes,
        if (t.dueAt != null) 'date': _isoDate(t.dueAt!),
        if (t.dueAt != null) 'time': _isoTime(t.dueAt!),
      };

  TaskPriority? _priority(Object? value) => value == null
      ? null
      : TaskPriority.values.where((p) => p.name == value.toString()).firstOrNull;

  TaskRecurrence? _recurrence(Object? value) => value == null
      ? null
      : TaskRecurrence.values
          .where((r) => r.name == value.toString())
          .firstOrNull;
  DateTime? _dateTime(Object? date, Object? time) {
    final d = _date(date);
    if (d == null) return null;
    final parts = (time?.toString() ?? '00:00').split(':');
    return DateTime(
      d.year,
      d.month,
      d.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  DateTime? _date(Object? value) => value is String
      ? DateTime.tryParse(value) == null
          ? null
          : _day(DateTime.parse(value))
      : null;
  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
  String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String _isoTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

sealed class _Match {
  const _Match();
}

class _One extends _Match {
  const _One(this.task);
  final Task task;
}

class _Many extends _Match {
  const _Many(this.tasks);
  final List<Task> tasks;
}

class _None extends _Match {
  const _None();
}

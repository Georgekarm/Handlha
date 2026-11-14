import '../domain/task.dart';

class TaskRecurrenceService {
  const TaskRecurrenceService._();

  static DateTime? nextOccurrence(Task task, {DateTime? from}) {
    if (task.recurrence == TaskRecurrence.none) return null;
    final base = from ?? task.scheduledStartAt ?? task.dueAt ?? DateTime.now();
    switch (task.recurrence) {
      case TaskRecurrence.daily:
        return base.add(const Duration(days: 1));
      case TaskRecurrence.weekly:
        return base.add(const Duration(days: 7));
      case TaskRecurrence.weekdays:
        var next = base.add(const Duration(days: 1));
        while (next.weekday == DateTime.friday || next.weekday == DateTime.saturday) {
          next = next.add(const Duration(days: 1));
        }
        return next;
      case TaskRecurrence.none:
        return null;
    }
  }
}

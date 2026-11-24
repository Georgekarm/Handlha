import '../domain/task.dart';

class TaskRecurrenceService {
  const TaskRecurrenceService._();

  static DateTime _addCalendarDays(DateTime dt, int days) {
    return DateTime(
      dt.year,
      dt.month,
      dt.day + days,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
      dt.microsecond,
    );
  }

  static DateTime _addCalendarMonths(DateTime dt, int months) {
    final totalMonths = (dt.year * 12 + (dt.month - 1)) + months;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = (totalMonths % 12) + 1;
    // Day 0 of the following month is the last valid calendar day of targetMonth.
    final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final clampedDay =
        dt.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : dt.day;
    return DateTime(
      targetYear,
      targetMonth,
      clampedDay,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
      dt.microsecond,
    );
  }

  static DateTime? nextOccurrence(Task task, {DateTime? from}) {
    if (task.recurrence == TaskRecurrence.none) return null;
    final base = from ?? task.scheduledStartAt ?? task.dueAt ?? DateTime.now();
    switch (task.recurrence) {
      case TaskRecurrence.daily:
        return _addCalendarDays(base, 1);
      case TaskRecurrence.weekly:
        return _addCalendarDays(base, 7);
      case TaskRecurrence.weekdays:
        var next = _addCalendarDays(base, 1);
        while (next.weekday == DateTime.friday ||
            next.weekday == DateTime.saturday) {
          next = _addCalendarDays(next, 1);
        }
        return next;
      case TaskRecurrence.monthly:
        return _addCalendarMonths(base, 1);
      case TaskRecurrence.none:
        return null;
    }
  }
}

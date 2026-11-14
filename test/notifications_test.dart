import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handelha/core/database/local_task_database.dart';
import 'package:handelha/features/assistant/local_task_tool_executor.dart';
import 'package:handelha/features/notifications/alarm_reminder_store.dart';
import 'package:handelha/features/notifications/local_notification_service.dart';
import 'package:handelha/features/notifications/notification_preferences.dart';
import 'package:handelha/features/tasks/domain/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Task task(String id, DateTime dueAt) => Task(
        id: id,
        userId: 'user-1',
        title: 'مراجعة المشروع',
        status: TaskStatus.planned,
        priority: TaskPriority.medium,
        dueAt: dueAt,
        energyLevel: EnergyLevel.medium,
        source: TaskSource.manual,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        version: 1,
        syncStatus: SyncStatus.pending,
      );

  group('ReminderMessageCatalog', () {
    final now = DateTime(2026, 11, 7, 14);

    test('classifies overdue tasks and speaks supportively without shaming', () {
      final message = ReminderMessageCatalog.forTask(
        task('overdue', DateTime(2026, 11, 6, 12)),
        now,
      );

      expect(message.urgency, ReminderUrgency.overdue);
      expect(message.title, contains('المعاد عدى'));
      expect(
        message.body,
        anyOf(
          contains('عادي'),
          contains('ولا يهمك'),
          contains('من غير ضغط'),
          contains('مش محتاج تلوم نفسك'),
        ),
      );
    });

    test('a date-only task due today is not immediately marked overdue', () {
      final message = ReminderMessageCatalog.forTask(
        task('today', DateTime(2026, 11, 7)),
        now,
      );

      expect(message.urgency, ReminderUrgency.today);
      expect(message.title, 'مهمة ليك النهارده');
    });

    test('classifies future tasks separately and direct tone provides a gentle nudge', () {
      final message = ReminderMessageCatalog.forTask(
        task('future', DateTime(2026, 11, 9, 9)),
        now,
        tone: ReminderTone.direct,
      );

      expect(message.urgency, ReminderUrgency.upcoming);
      expect(message.body, anyOf(contains('خطّط'), contains('حدّد'), contains('حضّر'), contains('راجع')));
    });

    test('daily encouragement is stable within a day and changes the next day', () {
      final first = ReminderMessageCatalog.dailyMessage(now, ReminderTone.supportive);
      final sameDay = ReminderMessageCatalog.dailyMessage(DateTime(2026, 11, 7, 23), ReminderTone.supportive);
      final nextDay = ReminderMessageCatalog.dailyMessage(DateTime(2026, 11, 8), ReminderTone.supportive);

      expect(first, sameDay);
      expect(nextDay, isNot(first));
    });

    test('message selection is stable for a task within a day and tone changes the copy', () {
      final item = task('stable-task-id', DateTime(2026, 11, 7, 22));
      final first = ReminderMessageCatalog.forTask(item, now);
      final second = ReminderMessageCatalog.forTask(item, DateTime(2026, 11, 7, 20));
      final direct = ReminderMessageCatalog.forTask(item, now, tone: ReminderTone.direct);

      expect(first.body, second.body);
      expect(direct.body, isNot(first.body));
    });
  });

  group('LocalNotificationPreferences', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('saves preferences per account and restores defaults for another account', () async {
      const saved = NotificationPreferences(
        enabled: false,
        tone: ReminderTone.direct,
        quietHoursStartMinutes: 21 * 60 + 30,
        quietHoursEndMinutes: 7 * 60 + 15,
      );
      await LocalNotificationPreferences.save('user-1', saved);

      expect(await LocalNotificationPreferences.load('user-1'), saved);
      expect(await LocalNotificationPreferences.load('user-2'), const NotificationPreferences());
    });

    test('clears saved preferences for a deleted local account', () async {
      await LocalNotificationPreferences.save(
        'user-1',
        const NotificationPreferences(enabled: false),
      );
      await LocalNotificationPreferences.clear('user-1');

      expect(await LocalNotificationPreferences.load('user-1'), const NotificationPreferences());
    });
  });

  group('NotificationPayload, AlarmReminderStore & LocalTaskToolExecutor', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('encodes and decodes structured alarm payloads with legacy taskId fallback', () {
      const payload = NotificationPayload(
        id: 'rem-1',
        title: 'امتحان الفيزياء',
        alertMode: 'alarm',
        taskId: 'task-1',
      );
      final decoded = NotificationPayload.tryDecode(payload.encode());
      expect(decoded?.id, 'rem-1');
      expect(decoded?.title, 'امتحان الفيزياء');
      expect(decoded?.isAlarm, isTrue);
      expect(decoded?.taskId, 'task-1');

      final legacy = NotificationPayload.tryDecode('task-legacy-42');
      expect(legacy?.id, 'task-legacy-42');
      expect(legacy?.isAlarm, isFalse);
      expect(legacy?.taskId, 'task-legacy-42');
    });

    test('LocalTaskToolExecutor supports create_reminder, update_reminder, and delete_reminder', () async {
      final db = LocalTaskDatabase.instance;
      await db.clearForUser('user-rem-1');

      var alertMode = 'alarm';
      final executor = LocalTaskToolExecutor(
        database: db,
        userId: () => 'user-rem-1',
        alertModeResolver: () => alertMode,
        nowProvider: () => DateTime(2026, 11, 15, 10, 0),
      );

      expect(executor.supportedTools, containsAll(['create_reminder', 'update_reminder', 'delete_reminder']));

      final createRes = await executor.execute(const ToolCall(
        id: 'c1',
        name: 'create_reminder',
        arguments: {
          'title': 'مراجعة امتحان العربي',
          'date': '2026-11-16',
          'time': '09:00',
        },
      ));
      expect(createRes.isSuccess, isTrue);
      expect(createRes.data['alert_mode'], 'alarm');
      final reminderId = createRes.data['reminder_id'] as String;

      final loaded = await AlarmReminderStore.load('user-rem-1');
      expect(loaded.items.length, 1);
      expect(loaded.items.first.isFullAlarm, isTrue);
      expect(loaded.items.first.title, 'مراجعة امتحان العربي');

      final updateRes = await executor.execute(ToolCall(
        id: 'c2',
        name: 'update_reminder',
        arguments: {
          'reminder_id': reminderId,
          'time': '11:30',
        },
      ));
      expect(updateRes.isSuccess, isTrue);
      expect(updateRes.data['time'], '11:30');

      final deleteRes = await executor.execute(ToolCall(
        id: 'c3',
        name: 'delete_reminder',
        arguments: {'reminder_id': reminderId},
      ));
      expect(deleteRes.isSuccess, isTrue);

      final afterDelete = await AlarmReminderStore.load('user-rem-1');
      expect(afterDelete.items, isEmpty);
    });
  });
}

import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter_test/flutter_test.dart';

ToolCall c(String n, Map<String, dynamic> a) => ToolCall(id: '1', name: n, arguments: a);

void main() {
  final v = ToolValidator(now: WallClock.tryParse('2026-10-04T18:00:00+03:00')!);

  test('valid create_task passes and is cleaned', () {
    final r = v.validate(c('create_task', {
      'title': '  مذاكرة Neural Networks ',
      'date': '2026-10-05',
      'time': '20:00',
      'priority': 'medium',
      'description': null,
    }));
    expect(r.ok, isTrue, reason: r.errors.join());
    expect(r.args['title'], 'مذاكرة Neural Networks');
    expect(r.args.containsKey('description'), isFalse);
  });

  test('unknown tool, unknown param, missing required', () {
    expect(v.validate(c('drop_database', {})).ok, isFalse);
    expect(v.validate(c('create_task', {'title': 'x', 'user_id': 'other'})).ok, isFalse);
    expect(v.validate(c('create_task', {'date': '2026-10-05'})).ok, isFalse);
  });

  test('bad types, enums, dates and times are rejected', () {
    expect(v.validate(c('create_task', {'title': 5})).ok, isFalse);
    expect(v.validate(c('create_task', {'title': 'x', 'priority': 'urgent'})).ok, isFalse);
    expect(v.validate(c('create_task', {'title': 'x', 'date': '2026-02-30'})).ok, isFalse);
    expect(v.validate(c('create_task', {'title': 'x', 'date': '5/10/2026'})).ok, isFalse);
    expect(v.validate(c('create_task', {'title': 'x', 'date': '2026-10-05', 'time': '8pm'})).ok, isFalse);
    expect(v.validate(c('create_task', {'title': 'x', 'date': '2026-10-05', 'time': '24:30'})).ok, isFalse);
    expect(v.validate(c('create_task', {'title': 'x', 'date': '2099-01-01'})).ok, isFalse);
  });

  test('time requires date', () {
    expect(v.validate(c('create_task', {'title': 'x', 'time': '20:00'})).ok, isFalse);
  });

  test('selectors: update/delete/complete need a selector and (update) a change', () {
    expect(v.validate(c('delete_task', {})).ok, isFalse);
    expect(v.validate(c('delete_task', {'created_on': '2026-10-03'})).ok, isTrue);
    expect(v.validate(c('complete_task', {'query': 'Machine Learning'})).ok, isTrue);
    expect(v.validate(c('update_task', {'task_id': 't1'})).ok, isFalse);
    expect(v.validate(c('update_task', {'task_id': 't1', 'time': '19:00'})).ok, isTrue);
  });

  test('reminder timing modes are mutually exclusive', () {
    expect(v.validate(c('create_reminder', {'title': 'x', 'in_minutes': 120})).ok, isTrue);
    expect(v.validate(c('create_reminder', {'title': 'x', 'date': '2026-10-05', 'time': '09:30'})).ok, isTrue);
    expect(v.validate(c('create_reminder', {'title': 'x', 'task_query': 'محاضرة', 'minutes_before': 30})).ok, isTrue);
    expect(v.validate(c('create_reminder', {'title': 'x'})).ok, isFalse);
    expect(v.validate(c('create_reminder', {'title': 'x', 'in_minutes': 5, 'date': '2026-10-05', 'time': '09:30'})).ok, isFalse);
    expect(v.validate(c('create_reminder', {'title': 'x', 'date': '2026-10-05'})).ok, isFalse);
  });

  test('integers: whole doubles ok, fractions and ranges rejected', () {
    expect(v.validate(c('create_reminder', {'title': 'x', 'in_minutes': 30.0})).ok, isTrue);
    expect(v.validate(c('create_reminder', {'title': 'x', 'in_minutes': 30.5})).ok, isFalse);
    expect(v.validate(c('create_reminder', {'title': 'x', 'in_minutes': 0})).ok, isFalse);
  });

  test('every tool definition is strict JSON schema', () {
    for (final d in AssistantTools.definitions()) {
      expect((d['parameters'] as Map)['additionalProperties'], false, reason: d['name'] as String);
    }
    expect(AssistantTools.all.length, 12);
  });

  test('ToolRegistry: handler exceptions become FAILED without leaking details', () async {
    final reg = ToolRegistry()
      ..register('create_task', (_) async => throw Exception('db password=hunter2'));
    final r = await reg.execute(c('create_task', {'title': 'x'}));
    expect(r.status, ToolStatus.failed);
    expect(r.toJson().toString(), isNot(contains('hunter2')));
    expect(reg.supportedTools, {'create_task'});
  });
}

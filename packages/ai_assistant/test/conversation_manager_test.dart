import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter_test/flutter_test.dart';

ToolCall tc(String id, String n) => ToolCall(id: id, name: n, arguments: const {});

void main() {
  test('pending action is consumed once and shows up in the context block', () {
    final m = ConversationManager();
    m.setPending('c', const PendingAction(
        action: 'create_task', knownFields: {'title': 'مذاكرة AI'}, question: 'تحبها إمتى؟'));
    final p = m.takePending('c');
    expect(p, isNotNull);
    expect(m.takePending('c'), isNull);
    final ctx = m.buildContext('c', p);
    expect(ctx, contains('create_task'));
    expect(ctx, contains('مذاكرة AI'));
  });

  test('last referenced task is remembered for "قبلها"', () {
    final m = ConversationManager();
    m.recordEntity('c', ToolCall(id: '1', name: 'create_task', arguments: const {'title': 'محاضرة'}),
        ToolResult.success({'task_id': 't9', 'title': 'محاضرة Neural Networks', 'date': '2026-10-11', 'time': '10:00'}));
    final ctx = m.buildContext('c', null);
    expect(ctx, contains('t9'));
    expect(ctx, contains('محاضرة Neural Networks'));
  });

  test('delete clears the last task reference', () {
    final m = ConversationManager();
    m.recordEntity('c', tc('1', 'create_task'), ToolResult.success({'task_id': 't1', 'title': 'x'}));
    m.recordEntity('c', tc('2', 'delete_task'), ToolResult.success({'task_id': 't1'}));
    expect(m.buildContext('c', null), isNot(contains('Last referenced task')));
  });

  test('dangling tool-call groups are never committed', () {
    final m = ConversationManager();
    m.commitTurn('c', [
      ConversationMessage.user('a'),
      ConversationMessage.assistant('', toolCalls: [tc('1', 'create_task'), tc('2', 'create_reminder')]),
      ConversationMessage.tool(tc('1', 'create_task'), ToolResult.success()),
      // result for call 2 is missing
    ]);
    final h = m.history('c');
    expect(h.length, 1);
    expect(h.single.role, MessageRole.user);
  });

  test('trimming keeps history starting at a user message', () {
    final m = ConversationManager(maxMessages: 4);
    for (var i = 0; i < 5; i++) {
      m.commitTurn('c', [ConversationMessage.user('u$i'), ConversationMessage.assistant('a$i')]);
    }
    final h = m.history('c');
    expect(h.first.role, MessageRole.user);
    expect(h.length <= 4, isTrue);
  });
}

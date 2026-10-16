import '../models/conversation_message.dart';
import '../models/tool_models.dart';

class EntityRef {
  const EntityRef({required this.kind, required this.id, required this.title, this.date, this.time});
  final String kind; // 'task' | 'reminder'
  final String id;
  final String title;
  final String? date;
  final String? time;
}

/// A question the assistant asked and the partial action it is waiting on.
class PendingAction {
  const PendingAction({required this.action, required this.knownFields, required this.question});
  final String action; // e.g. create_task
  final Map<String, dynamic> knownFields;
  final String question;
}

class ConversationState {
  final List<ConversationMessage> messages = [];
  PendingAction? pending;
  EntityRef? lastTask;
  EntityRef? lastReminder;
  final List<String> toolLog = []; // "create_task:SUCCESS"
}

/// Persistence hook: implement to survive app restarts.
abstract class ConversationStore {
  ConversationState load(String conversationId);
  void save(String conversationId, ConversationState state);
  void clear(String conversationId);
}

class InMemoryConversationStore implements ConversationStore {
  final Map<String, ConversationState> _m = {};
  @override
  ConversationState load(String id) => _m.putIfAbsent(id, ConversationState.new);
  @override
  void save(String id, ConversationState s) => _m[id] = s;
  @override
  void clear(String id) => _m.remove(id);
}

/// Keeps recent messages, the pending clarification, the last referenced
/// task/reminder (for "قبلها", "أجلها", "خليها") and a tool log.
class ConversationManager {
  ConversationManager({ConversationStore? store, this.maxMessages = 30})
      : _store = store ?? InMemoryConversationStore();

  final ConversationStore _store;
  final int maxMessages;

  List<ConversationMessage> history(String id) => List.unmodifiable(_store.load(id).messages);

  /// Returns and clears the pending clarification (consumed once per turn; the
  /// model re-registers it if it still needs more information).
  PendingAction? takePending(String id) {
    final s = _store.load(id);
    final p = s.pending;
    s.pending = null;
    _store.save(id, s);
    return p;
  }

  void setPending(String id, PendingAction p) {
    final s = _store.load(id);
    s.pending = p;
    _store.save(id, s);
  }

  /// Appends a finished turn. Drops any trailing tool-call group that lacks
  /// results so the history stays valid for every LLM provider.
  void commitTurn(String id, List<ConversationMessage> turn) {
    final s = _store.load(id);
    s.messages.addAll(_consistent(turn));
    while (s.messages.length > maxMessages) {
      s.messages.removeAt(0);
    }
    while (s.messages.isNotEmpty && s.messages.first.role != MessageRole.user) {
      s.messages.removeAt(0);
    }
    _store.save(id, s);
  }

  List<ConversationMessage> _consistent(List<ConversationMessage> turn) {
    final out = <ConversationMessage>[];
    for (var i = 0; i < turn.length; i++) {
      final m = turn[i];
      if (m.role == MessageRole.assistant && m.toolCalls.isNotEmpty) {
        final need = m.toolCalls.map((c) => c.id).toSet();
        final got = <String>{};
        var j = i + 1;
        while (j < turn.length && turn[j].role == MessageRole.tool) {
          got.add(turn[j].toolCallId ?? '');
          j++;
        }
        if (!got.containsAll(need)) break;
      }
      out.add(m);
    }
    return out;
  }

  void recordEntity(String id, ToolCall call, ToolResult result) {
    final s = _store.load(id);
    s.toolLog.add('${call.name}:${result.status.wire}');
    if (s.toolLog.length > 20) s.toolLog.removeAt(0);
    if (result.isSuccess) {
      final d = result.data;
      final title = (d['title'] ?? call.arguments['title'] ?? call.arguments['query'] ?? '').toString();
      final tid = d['task_id'];
      final rid = d['reminder_id'];
      if (call.name == 'delete_task') {
        s.lastTask = null;
      } else if (call.name == 'delete_reminder') {
        s.lastReminder = null;
      } else {
        if (tid != null) {
          s.lastTask = EntityRef(
              kind: 'task',
              id: tid.toString(),
              title: title,
              date: d['date']?.toString(),
              time: d['time']?.toString());
        }
        if (rid != null) {
          s.lastReminder = EntityRef(
              kind: 'reminder',
              id: rid.toString(),
              title: title,
              date: d['date']?.toString(),
              time: d['time']?.toString());
        }
      }
    }
    _store.save(id, s);
  }

  /// Text appended to the system prompt each round.
  String buildContext(String id, PendingAction? pending) {
    final s = _store.load(id);
    final b = StringBuffer();
    if (pending != null) {
      b.writeln('- Pending clarification from your previous turn: action=${pending.action}, '
          'known_fields=${_clip(pending.knownFields.toString(), 300)}, '
          'you asked: "${_clip(pending.question, 150)}". If the user\'s new message answers it, '
          'merge it with known_fields and complete the action now (do not ask again unless still missing).');
    }
    if (s.lastTask != null) b.writeln('- Last referenced task: ${_fmt(s.lastTask!)}. "قبلها/أجلها/خليها/خلصتها" refer to it unless the user names another.');
    if (s.lastReminder != null) b.writeln('- Last referenced reminder: ${_fmt(s.lastReminder!)}.');
    if (s.toolLog.isNotEmpty) b.writeln('- Recent tool results: ${s.toolLog.join(', ')}.');
    return b.isEmpty ? '- (none)' : b.toString().trimRight();
  }

  String _fmt(EntityRef e) =>
      '"${_clip(e.title, 80)}" (id=${e.id}${e.date != null ? ', date=${e.date}' : ''}${e.time != null ? ', time=${e.time}' : ''})';

  String _clip(String s, int n) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').replaceAll('"', "'");
    return t.length <= n ? t : '${t.substring(0, n)}…';
  }

  void reset(String id) => _store.clear(id);
}

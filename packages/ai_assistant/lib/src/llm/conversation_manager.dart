import '../models/conversation_message.dart';
import '../models/tool_models.dart';

class EntityRef {
  const EntityRef({
    required this.kind,
    required this.id,
    required this.title,
    this.date,
    this.time,
  });

  final String kind; // 'task' | 'reminder'
  final String id;
  final String title;
  final String? date;
  final String? time;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'id': id,
        'title': title,
        if (date != null) 'date': date,
        if (time != null) 'time': time,
      };

  factory EntityRef.fromJson(Map<String, dynamic> json) => EntityRef(
        kind: json['kind'] as String,
        id: json['id'] as String,
        title: json['title'] as String,
        date: json['date']?.toString(),
        time: json['time']?.toString(),
      );
}

/// A question the assistant asked and the partial action it is waiting on.
class PendingAction {
  const PendingAction({
    required this.action,
    required this.knownFields,
    required this.question,
    this.askedAt,
  });

  final String action; // e.g. create_task
  final Map<String, dynamic> knownFields;
  final String question;
  final DateTime? askedAt;

  Map<String, dynamic> toJson() => {
        'action': action,
        'known_fields': knownFields,
        'question': question,
        if (askedAt != null) 'asked_at': askedAt!.toIso8601String(),
      };

  factory PendingAction.fromJson(Map<String, dynamic> json) => PendingAction(
        action: json['action'] as String,
        knownFields: Map<String, dynamic>.from(json['known_fields'] as Map),
        question: json['question'] as String,
        askedAt: json['asked_at'] != null
            ? DateTime.parse(json['asked_at'] as String)
            : null,
      );
}

class ConversationMetadata {
  const ConversationMetadata({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  ConversationMetadata copyWith({
    String? title,
    DateTime? updatedAt,
  }) =>
      ConversationMetadata(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ConversationMetadata.fromJson(Map<String, dynamic> json) =>
      ConversationMetadata(
        id: json['id'] as String,
        title: (json['title'] ?? '').toString(),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class ConversationState {
  ConversationState({ConversationMetadata? metadata})
      : metadata = metadata ??
            ConversationMetadata(
              id: '',
              title: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

  ConversationMetadata metadata;
  final List<ConversationMessage> messages = [];
  PendingAction? pending;
  EntityRef? lastTask;
  EntityRef? lastReminder;
  final List<String> toolLog = []; // "create_task:SUCCESS"
  final Map<String, dynamic> planningDecisions = {};

  Map<String, dynamic> toJson() => {
        'metadata': metadata.toJson(),
        'messages': messages.map((m) => m.toJson()).toList(),
        if (pending != null) 'pending': pending!.toJson(),
        if (lastTask != null) 'last_task': lastTask!.toJson(),
        if (lastReminder != null) 'last_reminder': lastReminder!.toJson(),
        'tool_log': toolLog,
        'planning_decisions': planningDecisions,
      };

  factory ConversationState.fromJson(Map<String, dynamic> json) {
    final state = ConversationState(
      metadata: ConversationMetadata.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map),
      ),
    );
    state.messages.addAll(
      (json['messages'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => ConversationMessage.fromJson(Map<String, dynamic>.from(m))),
    );
    if (json['pending'] is Map) {
      state.pending = PendingAction.fromJson(
        Map<String, dynamic>.from(json['pending'] as Map),
      );
    }
    if (json['last_task'] is Map) {
      state.lastTask = EntityRef.fromJson(
        Map<String, dynamic>.from(json['last_task'] as Map),
      );
    }
    if (json['last_reminder'] is Map) {
      state.lastReminder = EntityRef.fromJson(
        Map<String, dynamic>.from(json['last_reminder'] as Map),
      );
    }
    state.toolLog.addAll((json['tool_log'] as List? ?? const []).map((e) => e.toString()));
    if (json['planning_decisions'] is Map) {
      state.planningDecisions.addAll(
        Map<String, dynamic>.from(json['planning_decisions'] as Map),
      );
    }
    return state;
  }
}

/// Persistence hook: implement to survive app restarts.
abstract class ConversationStore {
  Future<ConversationState> load(String conversationId);
  Future<List<ConversationMetadata>> list();
  Future<void> save(String conversationId, ConversationState state);
  Future<void> clear(String conversationId);
}

class InMemoryConversationStore implements ConversationStore {
  final Map<String, ConversationState> _m = {};

  @override
  Future<ConversationState> load(String id) async =>
      _m.putIfAbsent(id, () => ConversationState(metadata: _metadata(id)));

  @override
  Future<List<ConversationMetadata>> list() async {
    final values = _m.values.map((s) => s.metadata).toList();
    values.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return values;
  }

  @override
  Future<void> save(String id, ConversationState state) async {
    _m[id] = state;
  }

  @override
  Future<void> clear(String id) async {
    _m.remove(id);
  }

  static ConversationMetadata _metadata(String id) {
    final now = DateTime.now();
    return ConversationMetadata(id: id, title: '', createdAt: now, updatedAt: now);
  }
}

/// Keeps recent messages, pending clarification, entity references and planning
/// decisions isolated by conversation id.
class ConversationManager {
  ConversationManager({ConversationStore? store, this.maxMessages = 30})
      : _store = store ?? InMemoryConversationStore();

  final ConversationStore _store;
  final int maxMessages;

  Future<List<ConversationMessage>> history(String id) async =>
      List.unmodifiable((await _store.load(id)).messages);

  Future<ConversationState> state(String id) => _store.load(id);

  Future<List<ConversationMetadata>> listConversations() => _store.list();

  /// Returns and clears the pending clarification (consumed once per turn; the
  /// model re-registers it if it still needs more information).
  Future<PendingAction?> takePending(String id) async {
    final s = await _store.load(id);
    final p = s.pending;
    s.pending = null;
    await _store.save(id, s);
    return p;
  }

  Future<void> setPending(String id, PendingAction p) async {
    final s = await _store.load(id);
    s.pending = p;
    await _store.save(id, s);
  }

  /// Appends a finished or interrupted turn. Message ids make retries
  /// idempotent, including when the user message was already persisted.
  Future<void> commitTurn(String id, List<ConversationMessage> turn) async {
    final s = await _store.load(id);
    final existingIds = s.messages.map((m) => m.id).toSet();
    s.messages.addAll(_consistent(turn).where((m) => !existingIds.contains(m.id)));
    while (s.messages.length > maxMessages) {
      s.messages.removeAt(0);
    }
    while (s.messages.isNotEmpty && s.messages.first.role != MessageRole.user) {
      s.messages.removeAt(0);
    }
    final now = DateTime.now();
    final firstUser = s.messages.where((m) => m.role == MessageRole.user).firstOrNull;
    s.metadata = s.metadata.copyWith(
      title: s.metadata.title.isEmpty && firstUser != null
          ? _clip(firstUser.content, 60)
          : s.metadata.title,
      updatedAt: now,
    );
    await _store.save(id, s);
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

  Future<void> recordEntity(String id, ToolCall call, ToolResult result) async {
    final s = await _store.load(id);
    s.toolLog.add('${call.name}:${result.status.wire}');
    if (s.toolLog.length > 20) s.toolLog.removeAt(0);
    if (result.isSuccess) {
      final d = result.data;
      final title =
          (d['title'] ?? call.arguments['title'] ?? call.arguments['query'] ?? '').toString();
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
            time: d['time']?.toString(),
          );
        }
        if (rid != null) {
          s.lastReminder = EntityRef(
            kind: 'reminder',
            id: rid.toString(),
            title: title,
            date: d['date']?.toString(),
            time: d['time']?.toString(),
          );
        }
      }
    }
    await _store.save(id, s);
  }

  Future<void> recordPlanningDecision(
    String id,
    String key,
    dynamic value,
  ) async {
    final s = await _store.load(id);
    s.planningDecisions[key] = value;
    s.metadata = s.metadata.copyWith(updatedAt: DateTime.now());
    await _store.save(id, s);
  }

  /// Text appended to the system prompt each round.
  Future<String> buildContext(String id, PendingAction? pending) async {
    final s = await _store.load(id);
    final b = StringBuffer();
    if (pending != null) {
      b.writeln('- Pending clarification from your previous turn: action=${pending.action}, '
          'known_fields=${_clip(pending.knownFields.toString(), 300)}, '
          'you asked: "${_clip(pending.question, 150)}". If the user\'s new message answers it, '
          'merge it with known_fields and complete the action now (do not ask again unless still missing).');
    }
    if (s.lastTask != null) {
      b.writeln('- Last referenced task: ${_fmt(s.lastTask!)}. "قبلها/أجلها/خليها/خلصتها" refer to it unless the user names another.');
    }
    if (s.lastReminder != null) {
      b.writeln('- Last referenced reminder: ${_fmt(s.lastReminder!)}.');
    }
    if (s.toolLog.isNotEmpty) {
      b.writeln('- Recent tool results: ${s.toolLog.join(', ')}.');
    }
    if (s.planningDecisions.isNotEmpty) {
      b.writeln('- Confirmed planning decisions: ${_clip(s.planningDecisions.toString(), 500)}. Preserve them unless the user changes them.');
    }
    return b.isEmpty ? '- (none)' : b.toString().trimRight();
  }

  String _fmt(EntityRef e) =>
      '"${_clip(e.title, 80)}" (id=${e.id}${e.date != null ? ', date=${e.date}' : ''}${e.time != null ? ', time=${e.time}' : ''})';

  String _clip(String s, int n) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').replaceAll('"', "'");
    return t.length <= n ? t : '${t.substring(0, n)}…';
  }

  Future<void> reset(String id) => _store.clear(id);
}

import 'tool_schema.dart';

const _priorities = ['low', 'medium', 'high'];
const _recurrences = ['none', 'daily', 'weekly', 'monthly'];
const _statuses = ['pending', 'completed', 'all'];

ParamSpec _s(String n, String d,
        {bool req = false, List<String>? en, ParamFormat? f, int max = 200}) =>
    ParamSpec(n, ParamType.string, d,
        required: req, enumValues: en, format: f, maxLength: max);
ParamSpec _date(String n, String d, {bool req = false}) =>
    _s(n, '$d Format YYYY-MM-DD.', req: req, f: ParamFormat.date, max: 10);
ParamSpec _time(String n, String d, {bool req = false}) =>
    _s(n, '$d 24-hour HH:mm.', req: req, f: ParamFormat.time, max: 5);
ParamSpec _int(String n, String d, {bool req = false, num? min, num? max}) =>
    ParamSpec(n, ParamType.integer, d, required: req, min: min, max: max);
ParamSpec _bool(String n, String d) => ParamSpec(n, ParamType.boolean, d);

/// Ways to identify an existing task. At least one is required.
List<ParamSpec> _taskSelector() => [
      _s('task_id', 'Exact task id taken from an earlier tool result or the context block. Never invent.', max: 100),
      _s('query', 'Words from the task title as the user said them (no verbs).', max: 120),
      _date('created_on', 'Select tasks created on this date ("اللي ضفته امبارح").'),
      _date('due_date', 'Select tasks due on this date.'),
    ];

bool _has(Map<String, dynamic> a, List<String> keys) => keys.any(a.containsKey);

String? _needTaskSelector(Map<String, dynamic> a) =>
    _has(a, ['task_id', 'query', 'created_on', 'due_date'])
        ? null
        : 'Identify the task with at least one of task_id, query, created_on, due_date.';

String? _needReminderSelector(Map<String, dynamic> a) =>
    _has(a, ['reminder_id', 'query']) ? null : 'Identify the reminder with reminder_id or query.';

CrossRule _atLeastOneOf(List<String> keys, String msg) =>
    (a) => _has(a, keys) ? null : msg;

String? _reminderCreateRule(Map<String, dynamic> a) {
  final abs = _has(a, ['date', 'time']);
  final rel = a.containsKey('in_minutes');
  final task = _has(a, ['task_id', 'task_query', 'minutes_before']);
  if ([abs, rel, task].where((x) => x).length != 1) {
    return 'Use exactly one timing mode: (date+time) OR in_minutes OR (task_id|task_query + minutes_before).';
  }
  if (abs && !(a.containsKey('date') && a.containsKey('time'))) {
    return 'Absolute reminders need both date and time.';
  }
  if (task && !(_has(a, ['task_id', 'task_query']) && a.containsKey('minutes_before'))) {
    return 'Task-relative reminders need task_id or task_query, and minutes_before.';
  }
  return null;
}

String? _reminderUpdateRule(Map<String, dynamic> a) {
  final changes = ['title', 'date', 'time', 'in_minutes', 'minutes_before'];
  if (!_has(a, changes)) return 'Provide at least one field to change.';
  if (a.containsKey('in_minutes') && _has(a, ['date', 'time', 'minutes_before'])) {
    return 'in_minutes cannot be combined with date/time/minutes_before.';
  }
  return null;
}

String? _rangeRule(Map<String, dynamic> a) {
  final f = a['date_from'], t = a['date_to'];
  if (f is String && t is String && f.compareTo(t) > 0) return 'date_from must be <= date_to.';
  if (a.containsKey('date') && _has(a, ['date_from', 'date_to'])) {
    return 'Use either date or date_from/date_to, not both.';
  }
  return null;
}

class AssistantTools {
  AssistantTools._();

  static const clarificationName = 'request_clarification';

  /// The 12 application tools. The app executes these.
  static final List<ToolSchema> all = [
    ToolSchema(
      name: 'create_task',
      description:
          'Create a new task. Use when the user asks to add/record a task, study session, lecture or appointment.',
      params: [
        _s('title', 'Short task title in the user\'s language, without date/time words.', req: true, max: 120),
        _s('description', 'Optional extra details.', max: 500),
        _date('date', 'Due date.'),
        _time('time', 'Due time.'),
        _s('priority', 'Priority. Default medium.', en: _priorities, max: 10),
        _s('category', 'Short category label (e.g. مذاكرة, محاضرة, شغل).', max: 40),
        _int('reminder_minutes_before',
            'Attach a reminder this many minutes before the due time (needs date+time).',
            min: 0, max: 10080),
        _s('recurrence', 'Repeat rule. Default none.', en: _recurrences, max: 10),
      ],
      rules: [
        (a) => a.containsKey('time') && !a.containsKey('date')
            ? 'time requires date (resolve "today" to an actual date).'
            : null,
        (a) => a.containsKey('reminder_minutes_before') && !(a.containsKey('date') && a.containsKey('time'))
            ? 'reminder_minutes_before requires date and time.'
            : null,
      ],
    ),
    ToolSchema(
      name: 'update_task',
      description:
          'Change fields of an existing task. Send ONLY the fields the user asked to change.',
      params: [
        ..._taskSelector(),
        _s('title', 'New title.', max: 120),
        _s('description', 'New description.', max: 500),
        _date('date', 'New due date.'),
        _time('time', 'New due time.'),
        _s('priority', 'New priority.', en: _priorities, max: 10),
        _s('category', 'New category.', max: 40),
        _int('reminder_minutes_before', 'New reminder offset in minutes.', min: 0, max: 10080),
        _s('recurrence', 'New repeat rule.', en: _recurrences, max: 10),
      ],
      rules: [
        _needTaskSelector,
        _atLeastOneOf(
            ['title', 'description', 'date', 'time', 'priority', 'category', 'reminder_minutes_before', 'recurrence'],
            'Provide at least one field to change.'),
      ],
    ),
    ToolSchema(
      name: 'delete_task',
      description:
          'Delete a task. The app returns AMBIGUOUS if several match; never guess. Bulk delete needs explicit user intent and confirmation.',
      params: [
        ..._taskSelector(),
        _bool('all_matches', 'true ONLY if the user explicitly asked to delete all matching tasks and confirmed.'),
      ],
      rules: [_needTaskSelector],
    ),
    ToolSchema(
      name: 'complete_task',
      description:
          'Mark a task completed (or not completed). Only when the user says it is already done.',
      params: [
        ..._taskSelector(),
        _bool('completed', 'Default true. false to reopen a task.'),
      ],
      rules: [_needTaskSelector],
    ),
    ToolSchema(
      name: 'get_tasks',
      description: 'List the user\'s tasks with optional filters.',
      params: [
        _date('date', 'Only tasks due on this date.'),
        _date('date_from', 'Range start (inclusive).'),
        _date('date_to', 'Range end (inclusive).'),
        _s('status', 'Default pending.', en: _statuses, max: 10),
        _s('priority', 'Filter by priority.', en: _priorities, max: 10),
        _s('category', 'Filter by category.', max: 40),
        _int('limit', 'Max results (default 20).', min: 1, max: 50),
      ],
      rules: [_rangeRule],
    ),
    ToolSchema(
      name: 'search_tasks',
      description: 'Find tasks by words in title/description.',
      params: [
        _s('query', 'Search words.', req: true, max: 120),
        _s('status', 'Default all.', en: _statuses, max: 10),
        _int('limit', 'Max results (default 10).', min: 1, max: 50),
      ],
    ),
    ToolSchema(
      name: 'create_reminder',
      description:
          'Create a reminder. Choose exactly one timing mode: absolute (date+time), relative to now (in_minutes), or relative to an existing task (task_id|task_query + minutes_before).',
      params: [
        _s('title', 'What to remind about.', req: true, max: 120),
        _date('date', 'Absolute reminder date.'),
        _time('time', 'Absolute reminder time.'),
        _int('in_minutes', 'Minutes from now.', min: 1, max: 525600),
        _s('task_id', 'Existing task id (from earlier results/context).', max: 100),
        _s('task_query', 'Words from an existing task\'s title.', max: 120),
        _int('minutes_before', 'Minutes before the task\'s due time.', min: 0, max: 10080),
      ],
      rules: [_reminderCreateRule],
    ),
    ToolSchema(
      name: 'update_reminder',
      description: 'Change an existing reminder. Send only the fields to change.',
      params: [
        _s('reminder_id', 'Exact reminder id from earlier results/context.', max: 100),
        _s('query', 'Words from the reminder title.', max: 120),
        _s('title', 'New title.', max: 120),
        _date('date', 'New date.'),
        _time('time', 'New time.'),
        _int('in_minutes', 'Reschedule to N minutes from now.', min: 1, max: 525600),
        _int('minutes_before', 'New offset before the linked task.', min: 0, max: 10080),
      ],
      rules: [_needReminderSelector, _reminderUpdateRule],
    ),
    ToolSchema(
      name: 'delete_reminder',
      description: 'Delete a reminder.',
      params: [
        _s('reminder_id', 'Exact reminder id from earlier results/context.', max: 100),
        _s('query', 'Words from the reminder title.', max: 120),
      ],
      rules: [_needReminderSelector],
    ),
    ToolSchema(
      name: 'get_schedule',
      description:
          'Get the user\'s timeline (tasks + reminders) for a day. Use for "رتبلي يومي": fetch, then suggest an order in words (do not modify anything).',
      params: [
        _date('date', 'Day to fetch.', req: true),
        _bool('include_reminders', 'Default true.'),
      ],
    ),
    ToolSchema(
      name: 'get_daily_summary',
      description: 'Counts and highlights for a day (done, pending, overdue). Defaults to today.',
      params: [_date('date', 'Day to summarize.')],
    ),
    ToolSchema(
      name: 'get_upcoming_tasks',
      description: 'Next pending tasks from now.',
      params: [
        _int('days_ahead', 'Look-ahead window in days (default 7).', min: 1, max: 30),
        _int('limit', 'Max results (default 10).', min: 1, max: 50),
      ],
    ),
  ];

  static final Map<String, ToolSchema> byName = {for (final t in all) t.name: t};

  /// Internal meta-tool handled by the module itself (never reaches the app):
  /// lets the model ask a question while recording what it already knows, so
  /// the next user message can be merged into the pending action.
  static final ToolSchema clarification = ToolSchema(
    name: clarificationName,
    description:
        'Ask the user ONE short question in Egyptian Arabic when required information is missing or the reference is ambiguous. The question is spoken exactly as written.',
    params: [
      _s('question', 'The exact Egyptian Arabic question to ask the user.', req: true, max: 300),
      _s('pending_action', 'The action you will perform once answered.',
          req: true,
          en: [
            'create_task', 'update_task', 'delete_task', 'complete_task',
            'create_reminder', 'update_reminder', 'delete_reminder', 'other'
          ],
          max: 30),
      const ParamSpec('known_fields', ParamType.object,
          'Fields already known for the pending action (e.g. {"title":"مذاكرة AI"}).'),
    ],
  );

  /// Everything the validator accepts.
  static final Map<String, ToolSchema> validatable = {...byName, clarificationName: clarification};

  /// Tool definitions to send to the LLM. [only] restricts to tools the app
  /// actually implements (null = all).
  static List<Map<String, dynamic>> definitions({Set<String>? only}) => [
        for (final t in all)
          if (only == null || only.contains(t.name)) t.toDefinition(),
        clarification.toDefinition(),
      ];
}

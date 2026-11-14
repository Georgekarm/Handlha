import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../features/projects/domain/focus_session.dart';
import '../result/result.dart';
import '../secure_storage/secure_storage_service.dart';

class LocalFocusSessionDatabase {
  LocalFocusSessionDatabase._();
  static final instance = LocalFocusSessionDatabase._();
  static const _key = 'local_focus_sessions_v1';
  static const _schemaVersion = 1;
  static const _uuid = Uuid();
  Completer<void>? _activeLock;

  Future<Result<FocusSession>> record({
    required String userId,
    String? taskId,
    required String taskTitle,
    required DateTime startedAt,
    required DateTime endedAt,
    required int elapsedMinutes,
    required bool completed,
  }) => _serialized(() async {
    try {
      if (elapsedMinutes < 0 || endedAt.isBefore(startedAt)) {
        return const Failure(ValidationFailure('مدة جلسة التركيز غير صالحة.'));
      }
      final session = FocusSession(
        id: _uuid.v4(), userId: userId, taskId: taskId, taskTitle: taskTitle.trim(),
        startedAt: startedAt, endedAt: endedAt, elapsedMinutes: elapsedMinutes,
        completed: completed,
      );
      final all = await _readAll();
      all.add(session);
      await _writeAll(all);
      return Success(session);
    } catch (_) {
      return const Failure(LocalDatabaseFailure('تعذّر حفظ جلسة التركيز.'));
    }
  });

  Future<Result<List<FocusSession>>> forUser(String userId) async {
    try {
      final sessions = (await _readAll()).where((s) => s.userId == userId).toList()
        ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
      return Success(sessions);
    } catch (_) {
      return const Failure(LocalDatabaseFailure());
    }
  }

  Future<Result<void>> clearForUser(String userId) => _serialized(() async {
    try {
      final remaining = (await _readAll()).where((s) => s.userId != userId).toList();
      await _writeAll(remaining);
      return const Success(null);
    } catch (_) {
      return const Failure(LocalDatabaseFailure());
    }
  });

  Future<List<FocusSession>> _readAll() async {
    final raw = await SecureStorageService.instance.readOrThrow(_key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    if (decoded['schema'] != _schemaVersion) {
      throw const FormatException('Unsupported focus session schema');
    }
    return (decoded['items'] as List<dynamic>)
        .map((value) => _fromJson((value as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> _writeAll(List<FocusSession> sessions) async {
    await SecureStorageService.instance.writeOrThrow(_key, jsonEncode({
      'schema': _schemaVersion,
      'items': sessions.map(_toJson).toList(),
    }));
  }

  Future<T> _serialized<T>(Future<T> Function() operation) async {
    while (_activeLock != null) {
      try {
        await _activeLock!.future;
      } catch (_) {}
    }
    final lock = Completer<void>();
    _activeLock = lock;
    try {
      return await operation();
    } finally {
      _activeLock = null;
      lock.complete();
    }
  }

  Map<String, dynamic> _toJson(FocusSession s) => {
    'id': s.id, 'userId': s.userId, 'taskId': s.taskId, 'taskTitle': s.taskTitle,
    'startedAt': s.startedAt.toIso8601String(), 'endedAt': s.endedAt.toIso8601String(),
    'elapsedMinutes': s.elapsedMinutes, 'completed': s.completed,
  };

  FocusSession _fromJson(Map<String, dynamic> j) => FocusSession(
    id: j['id'] as String, userId: j['userId'] as String, taskId: j['taskId'] as String?,
    taskTitle: j['taskTitle'] as String,
    startedAt: DateTime.parse(j['startedAt'] as String),
    endedAt: DateTime.parse(j['endedAt'] as String),
    elapsedMinutes: (j['elapsedMinutes'] as num).toInt(), completed: j['completed'] as bool,
  );
}

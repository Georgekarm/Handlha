import 'dart:async';
import 'dart:convert';

import '../../features/projects/domain/project.dart';
import '../result/result.dart';
import '../secure_storage/secure_storage_service.dart';

class LocalProjectDatabase {
  LocalProjectDatabase._();
  static final instance = LocalProjectDatabase._();
  static const _key = 'local_projects_v1';
  Completer<void>? _activeLock;

  Future<Result<void>> save(Project project, {List<Map<String, dynamic>> phases = const []}) => _serialized(() async {
    try {
      final records = await _readRecords();
      final index = records.indexWhere((r) => ((r['project'] as Map?) ?? r)['id'] == project.id);
      final record = _toRecord(project, phases);
      if (index < 0) {
        records.add(record);
      } else {
        records[index] = record;
      }
      await SecureStorageService.instance.writeOrThrow(_key, jsonEncode(records));
      return const Success(null);
    } catch (_) {
      return const Failure(LocalDatabaseFailure());
    }
  });

  Future<Result<List<Project>>> forUser(String userId) async {
    try {
      return Success((await _readAll()).where((p) => p.userId == userId).toList());
    } catch (_) {
      return const Failure(LocalDatabaseFailure());
    }
  }

  Future<List<Project>> _readAll() async {
    final records = await _readRecords();
    return records.map((record) {
      return _fromJson((record['project'] as Map?)?.cast<String, dynamic>() ?? record);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _readRecords() async {
    final raw = await SecureStorageService.instance.readOrThrow(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((value) => (value as Map).cast<String, dynamic>()).toList();
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

  Future<Result<void>> clearForUser(String userId) => _serialized(() async {
        try {
          final records = await _readRecords();
          records.removeWhere((record) {
            final project = (record['project'] as Map?)?.cast<String, dynamic>() ?? record;
            return project['userId'] == userId;
          });
          await SecureStorageService.instance.writeOrThrow(_key, jsonEncode(records));
          return const Success(null);
        } catch (_) {
          return const Failure(LocalDatabaseFailure());
        }
      });

  Future<Result<void>> delete(String projectId) => _serialized(() async {
        try {
          final records = await _readRecords();
          records.removeWhere((record) {
            final project = (record['project'] as Map?)?.cast<String, dynamic>() ?? record;
            return project['id'] == projectId;
          });
          await SecureStorageService.instance.writeOrThrow(_key, jsonEncode(records));
          return const Success(null);
        } catch (_) {
          return const Failure(LocalDatabaseFailure());
        }
      });

  Future<List<Map<String, dynamic>>> phasesForProject(String projectId) async {
    try {
      final records = await _readRecords();
      for (final record in records) {
        final project = (record['project'] as Map?)?.cast<String, dynamic>() ?? record;
        if (project['id'] == projectId) {
          final rawPhases = record['phases'];
          if (rawPhases is List) {
            return rawPhases.map((e) => (e as Map).cast<String, dynamic>()).toList();
          }
        }
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic> _toRecord(Project p, List<Map<String, dynamic>> phases) => {
        'schema': 1,
        'phases': phases,
        'project': _toJson(p),
      };

  Map<String, dynamic> _toJson(Project p) => {
        'id': p.id,
        'userId': p.userId,
        'title': p.title,
        'description': p.description,
        'status': p.status.name,
        'progressPercent': p.progressPercent,
        'nextStepTitle': p.nextStepTitle,
        'targetDate': p.targetDate?.toIso8601String(),
        'taskIds': p.taskIds,
        'colorValue': p.colorValue,
        'createdAt': p.createdAt.toIso8601String(),
        'updatedAt': p.updatedAt.toIso8601String(),
      };

  Project _fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        userId: j['userId'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        status: ProjectStatus.values.byName(j['status'] as String),
        progressPercent: (j['progressPercent'] as num).toDouble(),
        nextStepTitle: j['nextStepTitle'] as String?,
        targetDate: j['targetDate'] == null ? null : DateTime.parse(j['targetDate'] as String),
        taskIds: (j['taskIds'] as List).cast<String>(),
        colorValue: (j['colorValue'] as num?)?.toInt() ?? 0xFF007067,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_focus_session_database.dart';
import '../../../core/database/local_project_database.dart';
import '../../../core/result/result.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../domain/focus_session.dart';
import '../domain/project.dart';

final projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<Project>>(
      ProjectsNotifier.new,
    );

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  static const _uuid = Uuid();

  LocalProjectDatabase get _db => LocalProjectDatabase.instance;

  String? get _userId => ref.read(authNotifierProvider).value?.id;

  Future<String?> _resolveUserId() async {
    final immediate = _userId;
    if (immediate != null) return immediate;
    final user = await ref.read(authNotifierProvider.future);
    return user?.id;
  }

  @override
  Future<List<Project>> build() async {
    final userId = ref.watch(authNotifierProvider.select((s) => s.value?.id));
    if (userId == null) return [];
    return _fetch(userId);
  }

  Future<List<Project>> _fetch(String userId) async {
    final result = await _db.forUser(userId);
    return switch (result) {
      Success<List<Project>>(data: final projects) => projects,
      Failure<List<Project>>(failure: final f) => throw Exception(f.message),
    };
  }

  Future<void> refresh() async {
    final userId = await _resolveUserId();
    if (userId == null) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(userId));
  }

  Future<Result<Project>> createProject({
    required String title,
    String? description,
    int colorValue = 0xFF007067,
    DateTime? targetDate,
    String? nextStepTitle,
    List<Map<String, dynamic>> phases = const [],
  }) async {
    final userId = await _resolveUserId();
    if (userId == null) {
      return const Failure(AuthFailure('يجب تسجيل الدخول.'));
    }
    final now = DateTime.now();
    final project = Project(
      id: _uuid.v4(),
      userId: userId,
      title: title.trim(),
      description: description?.trim().isEmpty == true
          ? null
          : description?.trim(),
      status: ProjectStatus.active,
      progressPercent: 0,
      nextStepTitle: nextStepTitle?.trim().isEmpty == true
          ? null
          : nextStepTitle?.trim(),
      targetDate: targetDate,
      taskIds: const [],
      colorValue: colorValue,
      createdAt: now,
      updatedAt: now,
    );
    final saveRes = await _db.save(project, phases: phases);
    if (saveRes is Failure<void>) {
      return Failure(saveRes.failure);
    }
    await refresh();
    return Success(project);
  }

  Future<Result<void>> updateProject(
    Project project, {
    List<Map<String, dynamic>>? phases,
  }) async {
    final currentPhases = phases ?? await _db.phasesForProject(project.id);
    final updated = project.copyWith(updatedAt: DateTime.now());
    final res = await _db.save(updated, phases: currentPhases);
    if (res is Success<void>) {
      await refresh();
    }
    return res;
  }

  Future<Result<void>> deleteProject(String projectId) async {
    final res = await _db.delete(projectId);
    if (res is Success<void>) {
      await refresh();
    }
    return res;
  }
}

final focusSessionsProvider =
    AsyncNotifierProvider<FocusSessionsNotifier, List<FocusSession>>(
      FocusSessionsNotifier.new,
    );

class FocusSessionsNotifier extends AsyncNotifier<List<FocusSession>> {
  LocalFocusSessionDatabase get _db => LocalFocusSessionDatabase.instance;

  String? get _userId => ref.read(authNotifierProvider).value?.id;

  Future<String?> _resolveUserId() async {
    final immediate = _userId;
    if (immediate != null) return immediate;
    final user = await ref.read(authNotifierProvider.future);
    return user?.id;
  }

  @override
  Future<List<FocusSession>> build() async {
    final userId = ref.watch(authNotifierProvider.select((s) => s.value?.id));
    if (userId == null) return [];
    return _fetch(userId);
  }

  Future<List<FocusSession>> _fetch(String userId) async {
    final result = await _db.forUser(userId);
    return switch (result) {
      Success<List<FocusSession>>(data: final sessions) => sessions,
      Failure<List<FocusSession>>(failure: final f) => throw Exception(f.message),
    };
  }

  Future<void> refresh() async {
    final userId = await _resolveUserId();
    if (userId == null) {
      state = const AsyncData([]);
      return;
    }
    state = await AsyncValue.guard(() => _fetch(userId));
  }

  Future<Result<FocusSession>> recordSession({
    String? taskId,
    required String taskTitle,
    required DateTime startedAt,
    required DateTime endedAt,
    required int elapsedMinutes,
    required bool completed,
  }) async {
    final userId = await _resolveUserId();
    if (userId == null) {
      return const Failure(AuthFailure('يجب تسجيل الدخول.'));
    }
    final res = await _db.record(
      userId: userId,
      taskId: taskId,
      taskTitle: taskTitle,
      startedAt: startedAt,
      endedAt: endedAt,
      elapsedMinutes: elapsedMinutes,
      completed: completed,
    );
    if (res is Success<FocusSession>) {
      await refresh();
    }
    return res;
  }
}



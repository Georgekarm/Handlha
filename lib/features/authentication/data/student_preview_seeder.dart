import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/environment/environment.dart';
import '../../../app/mode/student_mode_controller.dart';
import '../../../core/database/local_focus_session_database.dart';
import '../../../core/database/local_project_database.dart';
import '../../../core/database/local_task_database.dart';
import '../../notifications/alarm_reminder_store.dart';
import '../../projects/data/exam_grades_store.dart';
import '../../projects/domain/project.dart';
import '../../subscriptions/data/local_subscription_store.dart';
import '../../subscriptions/domain/subscription_models.dart';
import '../../tasks/domain/task.dart';

/// Dedicated Student QA/Preview account for isolated debug/QA builds only.
///
/// Always disabled in release builds and in default builds. Enable only in QA
/// debug builds via:
/// `--dart-define=APP_ENV=development --dart-define=ENABLE_QA_PREVIEW=true`.
class StudentPreviewAccount {
  const StudentPreviewAccount._();

  static bool? _testOverrideEnabled;

  /// Strictly `false` in release builds and whenever `ENABLE_QA_PREVIEW` is not
  /// explicitly supplied alongside `APP_ENV=development` in debug mode.
  static bool get enabled {
    if (kReleaseMode) return false;
    if (_testOverrideEnabled != null) return _testOverrideEnabled!;
    return Environment.enableQaPreviewAccount;
  }

  @visibleForTesting
  static void setTestOverrideEnabled(bool? value) {
    assert(
      !kReleaseMode,
      'StudentPreviewAccount override is forbidden in release builds.',
    );
    _testOverrideEnabled = value;
  }

  static const String userId = 'handelha_student_qa_v1';
  static const String email = 'student@handelha.app';
  static const String password = 'Student2026!';
  static const String displayName = 'أحمد — طالب هندلها';

  static const String _seededKey = 'handelha_student_qa_seeded_v1';

  static bool matchesCredentials(String normalizedEmail, String rawPassword) {
    if (!enabled) return false;
    return normalizedEmail == email && rawPassword == password;
  }

  /// Ensures the QA preview Student Mode flag and sample academic workspace
  /// data exist for [userId]. Never marks itself as a verified store purchase.
  static Future<StoredSubscriptionRecord> ensureProvisioned() async {
    if (!enabled) {
      throw StateError(
        'StudentPreviewAccount provisioning is disabled in this build.',
      );
    }
    final sub = await LocalSubscriptionStore.activatePlanForUser(
      userId: userId,
      track: SubscriptionPlanTrack.student,
      planId: 'student_yearly',
      planTitle: 'باقة الطلاب السنوية (معاينة QA)',
      planPrice: '٣٩٩ ج.م',
      isAnnual: true,
      isLocalActivation: true,
    );

    StudentModeStore.setSync(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('handelha_student_mode', true);
      if (prefs.getBool(_seededKey) == true) {
        return sub;
      }

      await _seedWorkspaceData();
      await prefs.setBool(_seededKey, true);
    } catch (_) {
      // Keep sign-in resilient even if optional seed data encounters an error.
    }
    return sub;
  }

  static Future<void> _seedWorkspaceData() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const projectId = 'student-qa-proj-exams';

    final project = Project(
      id: projectId,
      userId: userId,
      title: 'استعداد امتحانات الترم',
      description: 'خطة مراجعة منظمة لمواد الترم مع جلسات تركيز وتدريب على الامتحانات.',
      status: ProjectStatus.active,
      progressPercent: 50.0,
      nextStepTitle: 'حل نموذج امتحان فيزياء حديثة',
      targetDate: today.add(const Duration(days: 5)),
      taskIds: const [
        'student-qa-t1',
        'student-qa-t2',
        'student-qa-t3',
        'student-qa-t4',
      ],
      colorValue: 0xFF4F46E5,
      createdAt: today.subtract(const Duration(days: 6)),
      updatedAt: now,
    );
    await LocalProjectDatabase.instance.save(project);

    final tasks = <Task>[
      Task(
        id: 'student-qa-t1',
        userId: userId,
        projectId: projectId,
        title: 'حل نموذج امتحان فيزياء حديثة',
        description: 'مراجعة الفصل الثالث والرابع وحل أسئلة السنين السابقة.',
        status: TaskStatus.planned,
        priority: TaskPriority.high,
        dueAt: DateTime(today.year, today.month, today.day, 18, 0),
        scheduledStartAt: DateTime(today.year, today.month, today.day, 18, 0),
        estimatedDurationMinutes: 45,
        energyLevel: EnergyLevel.high,
        source: TaskSource.manual,
        createdAt: today.subtract(const Duration(days: 2)),
        updatedAt: now,
        version: 1,
        syncStatus: SyncStatus.synced,
      ),
      Task(
        id: 'student-qa-t2',
        userId: userId,
        projectId: projectId,
        title: 'مراجعة ملخص التفاضل والتكامل',
        description: 'التركيز على مسائل التكامل بالتجزئة والقوانين الأساسية.',
        status: TaskStatus.planned,
        priority: TaskPriority.urgent,
        dueAt: today.add(const Duration(days: 1, hours: 10)),
        scheduledStartAt: today.add(const Duration(days: 1, hours: 10)),
        estimatedDurationMinutes: 35,
        energyLevel: EnergyLevel.high,
        source: TaskSource.manual,
        createdAt: today.subtract(const Duration(days: 1)),
        updatedAt: now,
        version: 1,
        syncStatus: SyncStatus.synced,
      ),
      Task(
        id: 'student-qa-t3',
        userId: userId,
        projectId: projectId,
        title: 'تلخيص محاضرة هياكل البيانات',
        status: TaskStatus.completed,
        priority: TaskPriority.medium,
        dueAt: today,
        scheduledStartAt: DateTime(today.year, today.month, today.day, 11, 0),
        estimatedDurationMinutes: 30,
        actualDurationMinutes: 30,
        energyLevel: EnergyLevel.medium,
        source: TaskSource.manual,
        createdAt: today.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        version: 1,
        syncStatus: SyncStatus.synced,
      ),
      Task(
        id: 'student-qa-t4',
        userId: userId,
        projectId: projectId,
        title: 'تسليم شيت البرمجة العملي',
        status: TaskStatus.completed,
        priority: TaskPriority.high,
        dueAt: today.subtract(const Duration(days: 1)),
        scheduledStartAt: today.subtract(const Duration(days: 1)).add(const Duration(hours: 14)),
        estimatedDurationMinutes: 40,
        actualDurationMinutes: 40,
        energyLevel: EnergyLevel.medium,
        source: TaskSource.manual,
        createdAt: today.subtract(const Duration(days: 4)),
        updatedAt: today.subtract(const Duration(days: 1)).add(const Duration(hours: 15)),
        version: 1,
        syncStatus: SyncStatus.synced,
      ),
    ];
    await LocalTaskDatabase.instance.createApprovedTasks(tasks);

    // 6-day focus streak so charts, badges, and focus tree flourish immediately.
    const sessionMins = [35, 30, 45, 25, 40, 30];
    const sessionTitles = [
      'مراجعة فيزياء حديثة',
      'تلخيص هياكل البيانات',
      'حل مسائل تفاضل وتكامل',
      'مراجعة الإنجليزي الأكاديمي',
      'شيت البرمجة العملي',
      'تحضير ملخصات الميدتيرم',
    ];
    for (var i = 0; i < sessionMins.length; i++) {
      final start = today
          .subtract(Duration(days: i))
          .add(const Duration(hours: 10));
      await LocalFocusSessionDatabase.instance.record(
        userId: userId,
        taskId: i == 0 ? 'student-qa-t1' : 'student-qa-t3',
        taskTitle: sessionTitles[i],
        elapsedMinutes: sessionMins[i],
        completed: true,
        startedAt: start,
        endedAt: start.add(Duration(minutes: sessionMins[i])),
      );
    }

    // Exam Grades showcase for Student Mode in TrackingScreen.
    await ExamGradesStore.addGrade(
      userId: userId,
      examTitle: 'برمجة متقدمة',
      gradeTier: 'excellent',
      scoreLabel: '٩٤٪ • امتياز',
    );
    await ExamGradesStore.addGrade(
      userId: userId,
      examTitle: 'فيزياء حديثة',
      gradeTier: 'very_good',
      scoreLabel: '٨٨٪ • جيد جدًا',
    );
    await ExamGradesStore.addGrade(
      userId: userId,
      examTitle: 'تفاضل وتكامل',
      gradeTier: 'excellent',
      scoreLabel: '٩٦٪ • امتياز',
    );

    // Scheduled alarm item for testing Alarms in Notifications screen.
    final alarmAt = today.add(const Duration(days: 1, hours: 9));
    await AlarmReminderStore.save(
      userId,
      AlarmReminderState(
        permissionGranted: false,
        exactAlarmGranted: false,
        defaultAlertMode: 'alarm',
        items: [
          AlarmReminderItem(
            id: 'student-qa-alarm-1',
            title: 'مراجعة ملخص التفاضل والتكامل',
            scheduledAt: alarmAt,
            alertMode: 'alarm',
            isEnabled: true,
            taskId: 'student-qa-t2',
          ),
        ],
        taskAlertModes: const {
          'student-qa-t2': 'alarm',
          'student-qa-t1': 'notification',
        },
      ),
    );
  }
}

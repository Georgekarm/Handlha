import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/subscriptions/presentation/subscription_providers.dart';

/// مخزن متزامن لحالة وضع الطالب بحيث تتمكن الطبقات غير المرتبطة بالواجهة من قراءتها بسهولة.
class StudentModeStore {
  StudentModeStore._();

  static bool isActive = false;

  static void setSync(bool value) {
    isActive = value;
  }
}

/// يدير تفعيل أو إيقاف «وضع الطالب» مع حفظ الإعداد محليًا.
final studentModeControllerProvider =
    NotifierProvider<StudentModeController, bool>(StudentModeController.new);

/// يحدد ما إذا كان وضع الطالب مفعّل حاليًا (يدويًا أو عبر اشتراك باقة الطلاب).
final isStudentModeActiveProvider = Provider<bool>((ref) {
  final manualStudentMode = ref.watch(studentModeControllerProvider);
  final subState = ref.watch(subscriptionProvider).value;
  final active = manualStudentMode || (subState?.isStudent ?? false);
  StudentModeStore.setSync(active);
  return active;
});

class StudentModeController extends Notifier<bool> {
  static const _key = 'handelha_student_mode';

  @override
  bool build() {
    _loadSaved();
    return StudentModeStore.isActive;
  }

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_key);
      if (saved != null && ref.mounted && saved != state) {
        StudentModeStore.setSync(saved);
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> setStudentMode(bool enabled) async {
    StudentModeStore.setSync(enabled);
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } catch (_) {}
  }

  Future<void> toggle() => setStudentMode(!state);

  static Future<void> clearSaved() async {
    StudentModeStore.setSync(false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

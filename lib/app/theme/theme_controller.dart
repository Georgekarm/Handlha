import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode provider — يدير الوضع (Light/Dark/System) مع حفظ محلي.
///
/// يدعم:
/// - تبديل سريع من الشاشة الرئيسية
/// - حفظ الاختيار في SharedPreferences
/// - استعادة الاختيار عند إعادة فتح التطبيق
/// - ثلاثة أوضاع: Light, Dark, System
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'sekretairak_theme_mode';

  @override
  ThemeMode build() {
    _loadSaved();
    return ThemeMode.system;
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      state = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> _persist(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// تبديل بين Light و Dark (يتجاهل System)
  void toggle() {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    _persist(next);
  }

  /// تعيين وضع محدد
  void setMode(ThemeMode mode) {
    state = mode;
    _persist(mode);
  }

  /// هل الوضع الحالي داكن فعلًا؟ (يأخذ System في الاعتبار)
  bool isDark(BuildContext context) {
    if (state == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return state == ThemeMode.dark;
  }
}

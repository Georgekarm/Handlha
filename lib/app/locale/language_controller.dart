import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported app & AI assistant languages: Egyptian Arabic (default) or English.
enum AppLanguage {
  arEg,
  en,
}

extension AppLanguageX on AppLanguage {
  bool get isEnglish => this == AppLanguage.en;
  bool get isArabic => this == AppLanguage.arEg;

  Locale get locale => isEnglish
      ? const Locale('en', 'US')
      : const Locale('ar', 'EG');

  TextDirection get textDirection =>
      isEnglish ? TextDirection.ltr : TextDirection.rtl;

  String get wireCode => isEnglish ? 'en' : 'ar-EG';

  String get sttLocaleId => isEnglish ? 'en_US' : 'ar_EG';

  List<String> get ttsCandidates => isEnglish
      ? const ['en-US', 'en_US', 'en-GB', 'en']
      : const ['ar-EG', 'ar_EG', 'ar-SA', 'ar_SA', 'ar'];

  String get displayLabel => isEnglish ? 'English' : 'عربي مصري';

  /// Simple bilingual helper keeping UI components concise without codegen.
  String tr(String ar, String en) => isEnglish ? en : ar;
}

final appLanguageProvider =
    NotifierProvider<AppLanguageNotifier, AppLanguage>(AppLanguageNotifier.new);

class AppLanguageNotifier extends Notifier<AppLanguage> {
  static const _key = 'handelha_app_language';
  bool _hasExplicitSelection = false;
  bool _disposed = false;

  @override
  AppLanguage build() {
    _hasExplicitSelection = false;
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _loadSaved();
    return AppLanguage.arEg;
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed || _hasExplicitSelection) return;
    final saved = prefs.getString(_key);
    if (saved == AppLanguage.en.name) {
      state = AppLanguage.en;
    } else if (saved == AppLanguage.arEg.name) {
      state = AppLanguage.arEg;
    }
  }

  Future<void> _persist(AppLanguage lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang.name);
  }

  Future<void> setLanguage(AppLanguage language) async {
    _hasExplicitSelection = true;
    if (state == language) return;
    state = language;
    await _persist(language);
  }
}

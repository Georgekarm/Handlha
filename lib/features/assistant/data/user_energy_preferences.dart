import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../authentication/presentation/auth_providers.dart';

/// Represents the user's personal productivity, peak energy hours, and
/// task/project breakdown preferences used by the AI Assistant & Planner.
class UserEnergyPreferences {
  const UserEnergyPreferences({
    this.peakEnergyPeriod = 'morning', // 'morning' | 'afternoon' | 'evening'
    this.preferredSessionMinutes = 45, // 25 | 45 | 60
    this.hardTaskStrategy = 'peak_first', // 'peak_first' | 'warmup_first'
    this.projectBreakdownStyle = 'micro_steps', // 'micro_steps' | 'milestone_blocks'
    this.completedWizard = false,
  });

  final String peakEnergyPeriod;
  final int preferredSessionMinutes;
  final String hardTaskStrategy;
  final String projectBreakdownStyle;
  final bool completedWizard;

  /// Start of the user's preferred productive window (minutes from midnight).
  int get workStartMinute => switch (peakEnergyPeriod) {
        'afternoon' => 12 * 60, // 12:00 PM
        'evening' => 17 * 60, // 5:00 PM
        _ => 8 * 60, // 8:00 AM
      };

  /// End of the user's preferred productive window (minutes from midnight).
  int get workEndMinute => switch (peakEnergyPeriod) {
        'afternoon' => 19 * 60, // 7:00 PM
        'evening' => 23 * 60, // 11:00 PM
        _ => 15 * 60, // 3:00 PM
      };

  String get peakLabelAr => switch (peakEnergyPeriod) {
        'afternoon' => 'بعد الظهر 🌤️ (١٢ م – ٧ م)',
        'evening' => 'مسائي 🌙 (٥ م – ١١ م)',
        _ => 'صباحي ☀️ (٨ ص – ٣ م)',
      };

  String get peakShortAr => switch (peakEnergyPeriod) {
        'afternoon' => 'بعد الظهر 🌤️',
        'evening' => 'مسائي 🌙',
        _ => 'صباحي ☀️',
      };

  String get peakLabelEn => switch (peakEnergyPeriod) {
        'afternoon' => 'Afternoon 🌤️ (12 PM – 7 PM)',
        'evening' => 'Evening 🌙 (5 PM – 11 PM)',
        _ => 'Morning ☀️ (8 AM – 3 PM)',
      };

  String get peakShortEn => switch (peakEnergyPeriod) {
        'afternoon' => 'Afternoon 🌤️',
        'evening' => 'Evening 🌙',
        _ => 'Morning ☀️',
      };

  String get strategyLabelAr => hardTaskStrategy == 'warmup_first'
      ? 'تسخين بمهمة خفيفة أولًا 🌱'
      : 'الأصعب في قمة طاقتي 🔥';

  String get strategyLabelEn => hardTaskStrategy == 'warmup_first'
      ? 'Easy Warm-up First 🌱'
      : 'Hardest at Peak Energy 🔥';

  UserEnergyPreferences copyWith({
    String? peakEnergyPeriod,
    int? preferredSessionMinutes,
    String? hardTaskStrategy,
    String? projectBreakdownStyle,
    bool? completedWizard,
  }) {
    return UserEnergyPreferences(
      peakEnergyPeriod: peakEnergyPeriod ?? this.peakEnergyPeriod,
      preferredSessionMinutes:
          preferredSessionMinutes ?? this.preferredSessionMinutes,
      hardTaskStrategy: hardTaskStrategy ?? this.hardTaskStrategy,
      projectBreakdownStyle:
          projectBreakdownStyle ?? this.projectBreakdownStyle,
      completedWizard: completedWizard ?? this.completedWizard,
    );
  }

  Map<String, dynamic> toJson() => {
        'peakEnergyPeriod': peakEnergyPeriod,
        'preferredSessionMinutes': preferredSessionMinutes,
        'hardTaskStrategy': hardTaskStrategy,
        'projectBreakdownStyle': projectBreakdownStyle,
        'completedWizard': completedWizard,
      };

  factory UserEnergyPreferences.fromJson(Map<String, dynamic> json) {
    return UserEnergyPreferences(
      peakEnergyPeriod: (json['peakEnergyPeriod'] ?? 'morning').toString(),
      preferredSessionMinutes:
          (json['preferredSessionMinutes'] as num?)?.toInt() ?? 45,
      hardTaskStrategy: (json['hardTaskStrategy'] ?? 'peak_first').toString(),
      projectBreakdownStyle:
          (json['projectBreakdownStyle'] ?? 'micro_steps').toString(),
      completedWizard: json['completedWizard'] == true,
    );
  }
}

/// Synchronous in-memory cache + SharedPreferences persistence so both UI widgets
/// and the synchronous deterministic planner / NLU service can read preferences.
class UserEnergyPreferencesStore {
  static UserEnergyPreferences _current = const UserEnergyPreferences();

  static UserEnergyPreferences get current => _current;

  static void setCurrent(UserEnergyPreferences prefs) {
    _current = prefs;
  }

  static String _key(String userId) => 'handelha_energy_prefs_$userId';

  static Future<UserEnergyPreferences> load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) {
        return _current;
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _current = UserEnergyPreferences.fromJson(decoded);
      return _current;
    } catch (_) {
      return _current;
    }
  }

  static Future<void> save(String userId, UserEnergyPreferences value) async {
    _current = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(userId), jsonEncode(value.toJson()));
    } catch (_) {}
  }

  static Future<void> clearForUser(String userId) async {
    _current = const UserEnergyPreferences();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (_) {}
  }
}

class UserEnergyPreferencesNotifier
    extends StateNotifier<UserEnergyPreferences> {
  UserEnergyPreferencesNotifier(this._userId)
      : super(UserEnergyPreferencesStore.current) {
    _load();
  }

  final String _userId;

  Future<void> _load() async {
    final loaded = await UserEnergyPreferencesStore.load(_userId);
    if (mounted) {
      state = loaded;
    }
  }

  Future<void> updatePreferences(UserEnergyPreferences next) async {
    state = next;
    await UserEnergyPreferencesStore.save(_userId, next);
  }
}

final userEnergyPreferencesProvider = StateNotifierProvider<
    UserEnergyPreferencesNotifier, UserEnergyPreferences>((ref) {
  final user = ref.watch(authNotifierProvider).value;
  final userId = user?.id ?? 'guest';
  return UserEnergyPreferencesNotifier(userId);
});

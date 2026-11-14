import 'package:shared_preferences/shared_preferences.dart';

/// متجر محلي لحالة قراءة الإشعارات وآخر مزامنة لكل مستخدم.
class NotificationInboxStore {
  NotificationInboxStore._();

  static String _readKey(String userId) => 'handelha_notif_read_$userId';
  static String _lastSyncKey(String userId) => 'handelha_last_sync_$userId';

  static Future<Set<String>> loadReadIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_readKey(userId)) ?? const [];
    return list.toSet();
  }

  static Future<void> markAsRead(String userId, String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_readKey(userId)) ?? const []).toSet();
    if (current.add(notificationId)) {
      await prefs.setStringList(_readKey(userId), current.toList());
    }
  }

  static Future<void> markAllAsRead(
    String userId,
    Iterable<String> notificationIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_readKey(userId)) ?? const []).toSet();
    current.addAll(notificationIds);
    await prefs.setStringList(_readKey(userId), current.toList());
  }

  static Future<DateTime?> loadLastSync(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSyncKey(userId));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static Future<void> touchLastSync(String userId, [DateTime? at]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastSyncKey(userId),
      (at ?? DateTime.now()).toIso8601String(),
    );
  }

  static Future<void> clearForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_readKey(userId));
    await prefs.remove(_lastSyncKey(userId));
  }
}


import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/secure_storage/secure_storage_service.dart';
import '../domain/subscription_models.dart';

/// سجل الاشتراك والتصنيف المخزّن محليًا للمستخدم (`free` | `student` | `regularPro`).
class StoredSubscriptionRecord {
  const StoredSubscriptionRecord({
    required this.userId,
    this.category = UserSubscriptionCategory.free,
    this.tier = SubscriptionTier.free,
    this.activePlanId,
    this.activePlanTitle,
    this.activePlanPrice,
    this.subscribedAt,
    this.expirationDate,
    this.isLocalActivation = false,
  });

  final String userId;
  final UserSubscriptionCategory category;
  final SubscriptionTier tier;
  final String? activePlanId;
  final String? activePlanTitle;
  final String? activePlanPrice;
  final DateTime? subscribedAt;
  final DateTime? expirationDate;
  final bool isLocalActivation;

  bool get isSubscribed =>
      category != UserSubscriptionCategory.free && tier != SubscriptionTier.free;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'category': category.name,
        'categoryLabelAr': category.label(isEnglish: false),
        'tier': tier.name,
        if (activePlanId != null) 'activePlanId': activePlanId,
        if (activePlanTitle != null) 'activePlanTitle': activePlanTitle,
        if (activePlanPrice != null) 'activePlanPrice': activePlanPrice,
        if (subscribedAt != null)
          'subscribedAt': subscribedAt!.toUtc().toIso8601String(),
        if (expirationDate != null)
          'expirationDate': expirationDate!.toUtc().toIso8601String(),
        'isLocalActivation': isLocalActivation,
      };

  factory StoredSubscriptionRecord.fromJson(
    Map<String, dynamic> json, {
    String? fallbackUserId,
  }) {
    final category =
        UserSubscriptionCategory.fromName(json['category']?.toString());
    final rawTier = (json['tier'] ?? '').toString().trim().toLowerCase();
    final tier = switch (category) {
      UserSubscriptionCategory.student => SubscriptionTier.student,
      UserSubscriptionCategory.regularPro => SubscriptionTier.pro,
      UserSubscriptionCategory.free => rawTier == 'student'
          ? SubscriptionTier.student
          : rawTier == 'pro'
              ? SubscriptionTier.pro
              : SubscriptionTier.free,
    };

    return StoredSubscriptionRecord(
      userId: (json['userId'] ?? fallbackUserId ?? 'guest').toString(),
      category: category,
      tier: tier,
      activePlanId: json['activePlanId']?.toString(),
      activePlanTitle: json['activePlanTitle']?.toString(),
      activePlanPrice: json['activePlanPrice']?.toString(),
      subscribedAt: DateTime.tryParse(json['subscribedAt']?.toString() ?? ''),
      expirationDate:
          DateTime.tryParse(json['expirationDate']?.toString() ?? ''),
      isLocalActivation: json['isLocalActivation'] == true,
    );
  }

  SubscriptionState toSubscriptionState({
    List<SubscriptionOffer> offers = const [],
    String? message,
  }) {
    if (!isSubscribed) {
      return SubscriptionState(
        status: SubscriptionStatus.free,
        tier: SubscriptionTier.free,
        offers: offers,
        message: message,
      );
    }
    return SubscriptionState(
      status: SubscriptionStatus.active,
      tier: tier,
      offers: offers,
      subscribedAt: subscribedAt,
      expirationDate: expirationDate,
      activePlanId: activePlanId,
      activePlanTitle: activePlanTitle,
      activePlanPrice: activePlanPrice,
      isLocalActivation: isLocalActivation,
      message: message,
    );
  }
}

/// مستودع التخزين المحلي لتصنيف المستخدم (`طلاب` / `مشترك عادي` / `مجاني`) والخطة الفعّالة.
class LocalSubscriptionStore {
  LocalSubscriptionStore._();

  static const String _keyPrefix = 'handelha_user_subscription_v1_';

  static String _normalizeUserId(String? userId) {
    final trimmed = (userId ?? '').trim();
    return trimmed.isEmpty ? 'guest' : trimmed;
  }

  static String _storageKey(String? userId) =>
      '$_keyPrefix${_normalizeUserId(userId)}';

  static Future<StoredSubscriptionRecord> loadForUser(String? userId) async {
    final uid = _normalizeUserId(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey(uid));
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return StoredSubscriptionRecord.fromJson(decoded, fallbackUserId: uid);
        }
        if (decoded is Map) {
          return StoredSubscriptionRecord.fromJson(
            decoded.cast<String, dynamic>(),
            fallbackUserId: uid,
          );
        }
      }
    } catch (_) {}

    // Fallback to session-scoped secure storage keys if prefs entry wasn't written yet.
    try {
      final categoryRaw = await SecureStorageService.instance.read(
        SecureStorageKeys.subscriptionCategory,
      );
      if (categoryRaw != null && categoryRaw.trim().isNotEmpty) {
        final category = UserSubscriptionCategory.fromName(categoryRaw);
        if (category != UserSubscriptionCategory.free) {
          final planId = await SecureStorageService.instance.read(
            SecureStorageKeys.activePlanId,
          );
          final planTitle = await SecureStorageService.instance.read(
            SecureStorageKeys.activePlanTitle,
          );
          return StoredSubscriptionRecord(
            userId: uid,
            category: category,
            tier: category == UserSubscriptionCategory.student
                ? SubscriptionTier.student
                : SubscriptionTier.pro,
            activePlanId: planId,
            activePlanTitle: planTitle,
            isLocalActivation: true,
          );
        }
      }
    } catch (_) {}

    return StoredSubscriptionRecord(userId: uid);
  }

  static Future<StoredSubscriptionRecord> saveForUser(
    String? userId,
    StoredSubscriptionRecord record,
  ) async {
    final uid = _normalizeUserId(userId);
    final normalized = StoredSubscriptionRecord(
      userId: uid,
      category: record.category,
      tier: record.tier,
      activePlanId: record.activePlanId,
      activePlanTitle: record.activePlanTitle,
      activePlanPrice: record.activePlanPrice,
      subscribedAt: record.subscribedAt,
      expirationDate: record.expirationDate,
      isLocalActivation: record.isLocalActivation,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey(uid), jsonEncode(normalized.toJson()));
    } catch (_) {}

    await SecureStorageService.instance.write(
      SecureStorageKeys.subscriptionCategory,
      normalized.category.name,
    );
    if (normalized.activePlanId != null &&
        normalized.activePlanId!.trim().isNotEmpty) {
      await SecureStorageService.instance.write(
        SecureStorageKeys.activePlanId,
        normalized.activePlanId!,
      );
    } else {
      await SecureStorageService.instance.delete(SecureStorageKeys.activePlanId);
    }
    if (normalized.activePlanTitle != null &&
        normalized.activePlanTitle!.trim().isNotEmpty) {
      await SecureStorageService.instance.write(
        SecureStorageKeys.activePlanTitle,
        normalized.activePlanTitle!,
      );
    } else {
      await SecureStorageService.instance
          .delete(SecureStorageKeys.activePlanTitle);
    }

    return normalized;
  }

  static Future<StoredSubscriptionRecord> activatePlanForUser({
    required String? userId,
    required SubscriptionPlanTrack track,
    required String planId,
    required String planTitle,
    required String planPrice,
    required bool isAnnual,
    DateTime? expirationDate,
    bool isLocalActivation = true,
  }) async {
    final now = DateTime.now();
    final isStudent = track == SubscriptionPlanTrack.student;
    final expiry = expirationDate ??
        now.add(Duration(days: isAnnual ? 365 : 30));

    final record = StoredSubscriptionRecord(
      userId: _normalizeUserId(userId),
      category: isStudent
          ? UserSubscriptionCategory.student
          : UserSubscriptionCategory.regularPro,
      tier: isStudent ? SubscriptionTier.student : SubscriptionTier.pro,
      activePlanId: planId,
      activePlanTitle: planTitle,
      activePlanPrice: planPrice,
      subscribedAt: now,
      expirationDate: expiry,
      isLocalActivation: isLocalActivation,
    );
    return saveForUser(userId, record);
  }

  static Future<void> clearForUser(String? userId) async {
    final uid = _normalizeUserId(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey(uid));
    } catch (_) {}
    await SecureStorageService.instance.write(
      SecureStorageKeys.subscriptionCategory,
      UserSubscriptionCategory.free.name,
    );
    await SecureStorageService.instance.delete(SecureStorageKeys.activePlanId);
    await SecureStorageService.instance
        .delete(SecureStorageKeys.activePlanTitle);
  }
}

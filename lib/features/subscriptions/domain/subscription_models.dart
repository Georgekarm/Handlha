import 'package:equatable/equatable.dart';

/// التصنيف المخزّن للمستخدم في بيانات التطبيق والنسخ الاحتياطي.
enum UserSubscriptionCategory {
  free,
  student,
  regularPro;

  String label({bool isEnglish = false}) {
    return switch (this) {
      UserSubscriptionCategory.free =>
        isEnglish ? 'Free Account' : 'حساب مجاني',
      UserSubscriptionCategory.student =>
        isEnglish ? 'Student Category' : 'تصنيف الطلاب',
      UserSubscriptionCategory.regularPro =>
        isEnglish ? 'Regular Pro Subscriber' : 'تصنيف المشتركين العاديين (Pro)',
    };
  }

  String shortBadge({bool isEnglish = false}) {
    return switch (this) {
      UserSubscriptionCategory.free => isEnglish ? 'Free' : 'مجاني',
      UserSubscriptionCategory.student => isEnglish ? 'Student' : 'تصنيف الطلاب',
      UserSubscriptionCategory.regularPro => isEnglish ? 'Pro' : 'مشترك Pro',
    };
  }

  static UserSubscriptionCategory fromName(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized == 'student') return UserSubscriptionCategory.student;
    if (normalized == 'regularpro' ||
        normalized == 'regular_pro' ||
        normalized == 'pro') {
      return UserSubscriptionCategory.regularPro;
    }
    return UserSubscriptionCategory.free;
  }
}

/// مستويات الاشتراك المتاحة في «هندلها»: مجاني، باقة الطلاب، أو Pro العادية.
enum SubscriptionTier { free, student, pro }

/// مسارا خطط الاشتراك المعروضان فقط في شاشة الاشتراكات: الطلاب أو Pro العادية.
enum SubscriptionPlanTrack { student, pro }

enum SubscriptionStatus { unknown, unavailable, free, active, expired }

enum PremiumFeature {
  advancedPlanning,
  productivityInsights,
  premiumAssistant,
  studentExamTracking,
}

class SubscriptionOffer extends Equatable {
  const SubscriptionOffer({
    required this.identifier,
    required this.title,
    required this.description,
    required this.price,
    required this.periodLabel,
    required this.isAnnual,
    this.track = SubscriptionPlanTrack.pro,
  });

  final String identifier;
  final String title;
  final String description;
  final String price;
  final String periodLabel;
  final bool isAnnual;
  final SubscriptionPlanTrack track;

  @override
  List<Object?> get props => [
        identifier,
        title,
        description,
        price,
        periodLabel,
        isAnnual,
        track,
      ];
}

class SubscriptionState extends Equatable {
  const SubscriptionState({
    this.status = SubscriptionStatus.unknown,
    this.tier = SubscriptionTier.free,
    this.offers = const [],
    this.expirationDate,
    this.subscribedAt,
    this.activePlanId,
    this.activePlanTitle,
    this.activePlanPrice,
    this.isLocalActivation = false,
    this.message,
  });

  final SubscriptionStatus status;
  final SubscriptionTier tier;
  final List<SubscriptionOffer> offers;
  final DateTime? expirationDate;
  final DateTime? subscribedAt;
  final String? activePlanId;
  final String? activePlanTitle;
  final String? activePlanPrice;
  final bool isLocalActivation;
  final String? message;

  bool get isStudent =>
      tier == SubscriptionTier.student && status == SubscriptionStatus.active;
  bool get isRegularPro =>
      tier == SubscriptionTier.pro && status == SubscriptionStatus.active;
  bool get isPro => isRegularPro || isStudent;
  bool get isLoadingData => status == SubscriptionStatus.unknown;

  UserSubscriptionCategory get category {
    if (isStudent) return UserSubscriptionCategory.student;
    if (isRegularPro) return UserSubscriptionCategory.regularPro;
    return UserSubscriptionCategory.free;
  }

  String categoryLabel({bool isEnglish = false}) =>
      category.label(isEnglish: isEnglish);

  String resolvedPlanTitle({bool isEnglish = false}) {
    final planId = (activePlanId ?? '').toLowerCase();
    if (planId == 'student_yearly' ||
        (planId.contains('student') &&
            (planId.contains('year') || planId.contains('annual')))) {
      return isEnglish ? 'Student Yearly' : 'باقة الطلاب السنوية';
    }
    if (planId == 'student_monthly' || planId.contains('student')) {
      return isEnglish ? 'Student Monthly' : 'باقة الطلاب الشهرية';
    }
    if (planId == 'pro_yearly' ||
        planId.contains('year') ||
        planId.contains('annual')) {
      return isEnglish ? 'Pro Yearly' : 'باقة Pro السنوية';
    }
    if (planId == 'pro_monthly' || planId.contains('month')) {
      return isEnglish ? 'Pro Monthly' : 'باقة Pro الشهرية';
    }
    if (activePlanTitle != null && activePlanTitle!.trim().isNotEmpty) {
      return activePlanTitle!.trim();
    }
    if (isStudent) {
      return isEnglish ? 'Student Plan' : 'باقة الطلاب';
    }
    if (isRegularPro) {
      return isEnglish ? 'Handelha Pro' : 'باقة Pro العادية';
    }
    return isEnglish ? 'Free Plan' : 'الباقة المجانية';
  }

  bool isPlanActive(String planId) {
    if (!isPro) return false;
    final active = (activePlanId ?? '').trim();
    if (active.isNotEmpty) {
      return active == planId;
    }
    return false;
  }

  bool canUse(PremiumFeature feature) {
    if (feature == PremiumFeature.studentExamTracking) {
      return isStudent;
    }
    if (isPro) return true;
    return switch (feature) {
      PremiumFeature.advancedPlanning => false,
      PremiumFeature.productivityInsights => false,
      PremiumFeature.premiumAssistant => false,
      PremiumFeature.studentExamTracking => false,
    };
  }

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    SubscriptionTier? tier,
    List<SubscriptionOffer>? offers,
    DateTime? expirationDate,
    DateTime? subscribedAt,
    String? activePlanId,
    String? activePlanTitle,
    String? activePlanPrice,
    bool? isLocalActivation,
    String? message,
    bool clearActivePlan = false,
  }) => SubscriptionState(
        status: status ?? this.status,
        tier: tier ?? this.tier,
        offers: offers ?? this.offers,
        expirationDate:
            clearActivePlan ? null : (expirationDate ?? this.expirationDate),
        subscribedAt:
            clearActivePlan ? null : (subscribedAt ?? this.subscribedAt),
        activePlanId:
            clearActivePlan ? null : (activePlanId ?? this.activePlanId),
        activePlanTitle:
            clearActivePlan ? null : (activePlanTitle ?? this.activePlanTitle),
        activePlanPrice:
            clearActivePlan ? null : (activePlanPrice ?? this.activePlanPrice),
        isLocalActivation: isLocalActivation ?? this.isLocalActivation,
        message: message ?? this.message,
      );

  @override
  List<Object?> get props => [
        status,
        tier,
        offers,
        expirationDate,
        subscribedAt,
        activePlanId,
        activePlanTitle,
        activePlanPrice,
        isLocalActivation,
        message,
      ];
}

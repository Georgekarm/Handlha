import '../domain/subscription_models.dart';

abstract interface class SubscriptionRepository {
  Future<SubscriptionState> load(String? appUserId);
  Future<SubscriptionState> purchase(String productIdentifier);
  Future<SubscriptionState> selectPlan({
    required String? appUserId,
    required SubscriptionPlanTrack track,
    required String planId,
    required String planTitle,
    required String planPrice,
    required bool isAnnual,
  });
  Future<SubscriptionState> cancelLocalPlan(String? appUserId);
  Future<SubscriptionState> restore(String? appUserId);
  Future<void> dispose();
}

class SubscriptionConfig {
  const SubscriptionConfig._();

  static const androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: '',
  );
  static const entitlementId = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_ID',
    defaultValue: 'handelha_pro',
  );
  static const studentEntitlementId = String.fromEnvironment(
    'REVENUECAT_STUDENT_ENTITLEMENT_ID',
    defaultValue: 'handelha_student',
  );
  static const monthlyProductId = String.fromEnvironment(
    'REVENUECAT_MONTHLY_PRODUCT_ID',
    defaultValue: 'handelha_pro_monthly',
  );
  static const yearlyProductId = String.fromEnvironment(
    'REVENUECAT_YEARLY_PRODUCT_ID',
    defaultValue: 'handelha_pro_yearly',
  );
  static const studentMonthlyProductId = String.fromEnvironment(
    'REVENUECAT_STUDENT_MONTHLY_PRODUCT_ID',
    defaultValue: 'handelha_student_monthly',
  );
  static const studentYearlyProductId = String.fromEnvironment(
    'REVENUECAT_STUDENT_YEARLY_PRODUCT_ID',
    defaultValue: 'handelha_student_yearly',
  );
}

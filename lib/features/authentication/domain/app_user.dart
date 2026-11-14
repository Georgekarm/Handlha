import 'package:equatable/equatable.dart';

import '../../subscriptions/domain/subscription_models.dart';

enum OnboardingUsageType { study, work, personal, mixed }

enum AssistantTone { friendly, formal, brief, custom }

/// How the user signed in.
enum AuthProviderType { email, google, facebook }

class AppUser extends Equatable {
  final String id;
  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final AuthProviderType authProvider;
  final OnboardingUsageType usageType;
  final AssistantTone tone;
  final List<int> focusHours; // 0–23
  final bool onboardingComplete;
  final UserSubscriptionCategory subscriptionCategory;
  final String? activePlanId;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    this.displayName,
    this.email,
    this.avatarUrl,
    this.authProvider = AuthProviderType.email,
    required this.usageType,
    required this.tone,
    required this.focusHours,
    required this.onboardingComplete,
    this.subscriptionCategory = UserSubscriptionCategory.free,
    this.activePlanId,
    required this.createdAt,
  });

  bool get isStudentSubscriber =>
      subscriptionCategory == UserSubscriptionCategory.student;

  bool get isRegularProSubscriber =>
      subscriptionCategory == UserSubscriptionCategory.regularPro;

  String get firstName {
    if (displayName == null || displayName!.isEmpty) return 'صديقي';
    return displayName!.split(' ').first;
  }

  AppUser copyWith({
    String? id,
    String? displayName,
    String? email,
    String? avatarUrl,
    AuthProviderType? authProvider,
    OnboardingUsageType? usageType,
    AssistantTone? tone,
    List<int>? focusHours,
    bool? onboardingComplete,
    UserSubscriptionCategory? subscriptionCategory,
    String? activePlanId,
    bool clearActivePlan = false,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      authProvider: authProvider ?? this.authProvider,
      usageType: usageType ?? this.usageType,
      tone: tone ?? this.tone,
      focusHours: focusHours ?? this.focusHours,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      subscriptionCategory: subscriptionCategory ?? this.subscriptionCategory,
      activePlanId:
          clearActivePlan ? null : (activePlanId ?? this.activePlanId),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    displayName,
    email,
    avatarUrl,
    authProvider,
    usageType,
    tone,
    focusHours,
    onboardingComplete,
    subscriptionCategory,
    activePlanId,
    createdAt,
  ];
}

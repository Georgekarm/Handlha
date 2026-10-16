import 'package:equatable/equatable.dart';

enum OnboardingUsageType { study, work, personal, mixed }

enum AssistantTone { friendly, formal, brief, custom }

class AppUser extends Equatable {
  final String id;
  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final OnboardingUsageType usageType;
  final AssistantTone tone;
  final List<int> focusHours; // 0–23
  final bool onboardingComplete;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    this.displayName,
    this.email,
    this.avatarUrl,
    required this.usageType,
    required this.tone,
    required this.focusHours,
    required this.onboardingComplete,
    required this.createdAt,
  });

  String get firstName {
    if (displayName == null || displayName!.isEmpty) return 'صديقي';
    return displayName!.split(' ').first;
  }

  AppUser copyWith({
    String? id,
    String? displayName,
    String? email,
    String? avatarUrl,
    OnboardingUsageType? usageType,
    AssistantTone? tone,
    List<int>? focusHours,
    bool? onboardingComplete,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      usageType: usageType ?? this.usageType,
      tone: tone ?? this.tone,
      focusHours: focusHours ?? this.focusHours,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    displayName,
    email,
    avatarUrl,
    usageType,
    tone,
    focusHours,
    onboardingComplete,
    createdAt,
  ];
}

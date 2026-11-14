import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_extension.dart';
import '../domain/subscription_models.dart';
import 'subscription_providers.dart';

class PremiumFeatureGate extends ConsumerWidget {
  const PremiumFeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.lockedChild,
  });

  final PremiumFeature feature;
  final Widget child;
  final Widget? lockedChild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionProvider);
    final isAllowed = state.value?.canUseFeature(feature) ?? false;
    if (isAllowed) return child;
    return lockedChild ?? _LockedPremiumFeature(feature: feature);
  }
}

class _LockedPremiumFeature extends StatelessWidget {
  const _LockedPremiumFeature({required this.feature});

  final PremiumFeature feature;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final isStudentOnly = feature == PremiumFeature.studentExamTracking;
    final accent = isStudentOnly ? const Color(0xFF5B52D6) : colors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isStudentOnly ? Icons.school_rounded : Icons.lock_outline_rounded,
            color: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isStudentOnly
                  ? (isEn
                      ? 'Available in Student Mode & Student Plans.'
                      : 'الميزة دي ضمن باقات ووضع الطلاب فقط.')
                  : (isEn
                      ? 'Available in Student or Handelha Pro plans.'
                      : 'الميزة دي متاحة في باقات الطلاب و Handelha Pro.'),
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/subscription'),
            child: Text(isEn ? 'View Plans' : 'شوف الباقات'),
          ),
        ],
      ),
    );
  }
}

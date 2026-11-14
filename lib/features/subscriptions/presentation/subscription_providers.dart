import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/mode/student_mode_controller.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../data/revenuecat_subscription_repository.dart';
import '../data/subscription_repository.dart';
import '../domain/subscription_models.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final repository = RevenueCatSubscriptionRepository();
  ref.onDispose(() {
    repository.dispose();
  });
  return repository;
});

final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);

class SubscriptionNotifier extends AsyncNotifier<SubscriptionState> {
  SubscriptionRepository get _repository =>
      ref.read(subscriptionRepositoryProvider);

  @override
  Future<SubscriptionState> build() async {
    final userId = await ref.watch(
      authNotifierProvider.selectAsync((user) => user?.id),
    );
    return _repository.load(userId);
  }

  Future<void> _syncAuthClassification(SubscriptionState next) async {
    await ref
        .read(authNotifierProvider.notifier)
        .updateSubscriptionClassification(
          category: next.category,
          activePlanId: next.activePlanId,
        );
  }

  Future<void> refreshSubscription() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = ref.read(authNotifierProvider).value?.id;
      final next = await _repository.load(userId);
      await _syncAuthClassification(next);
      return next;
    });
  }

  Future<void> purchase(String productIdentifier) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final next = await _repository.purchase(productIdentifier);
      await _syncAuthClassification(next);
      return next;
    });
  }

  Future<void> selectPlan({
    required SubscriptionPlanTrack track,
    required String planId,
    required String planTitle,
    required String planPrice,
    required bool isAnnual,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = ref.read(authNotifierProvider).value?.id;
      final next = await _repository.selectPlan(
        appUserId: userId,
        track: track,
        planId: planId,
        planTitle: planTitle,
        planPrice: planPrice,
        isAnnual: isAnnual,
      );
      if (track == SubscriptionPlanTrack.pro) {
        await ref
            .read(studentModeControllerProvider.notifier)
            .setStudentMode(false);
      }
      await _syncAuthClassification(next);
      return next;
    });
  }

  Future<void> cancelLocalPlan() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = ref.read(authNotifierProvider).value?.id;
      final next = await _repository.cancelLocalPlan(userId);
      await _syncAuthClassification(next);
      return next;
    });
  }

  Future<void> restorePurchases() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = ref.read(authNotifierProvider).value?.id;
      final next = await _repository.restore(userId);
      await _syncAuthClassification(next);
      return next;
    });
  }
}

extension SubscriptionFeatureReader on SubscriptionState {
  bool canUseFeature(PremiumFeature feature) => canUse(feature);
}

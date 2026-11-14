import 'dart:io';

import 'package:purchases_flutter/purchases_flutter.dart';

import '../domain/subscription_models.dart';
import 'local_subscription_store.dart';
import 'subscription_repository.dart';

class RevenueCatSubscriptionRepository implements SubscriptionRepository {
  RevenueCatSubscriptionRepository({this.onCustomerInfoChanged});

  final void Function(SubscriptionState state)? onCustomerInfoChanged;
  bool _configured = false;
  String? _appUserId;

  bool get _hasStoreBilling =>
      Platform.isAndroid && SubscriptionConfig.androidApiKey.isNotEmpty;

  @override
  Future<SubscriptionState> load(String? appUserId) async {
    _appUserId = appUserId;
    final local = await LocalSubscriptionStore.loadForUser(appUserId);
    if (!_hasStoreBilling) {
      return local.toSubscriptionState();
    }

    try {
      await _configure(appUserId);
      final customerInfo = await Purchases.getCustomerInfo();
      final offerings = await Purchases.getOfferings();
      return await _stateFrom(
        customerInfo,
        offerings,
        appUserId: appUserId,
        localFallback: local,
      );
    } catch (_) {
      // Never lock out local subscription selection/display if store billing is offline.
      return local.toSubscriptionState();
    }
  }

  @override
  Future<SubscriptionState> purchase(String productIdentifier) async {
    if (!_hasStoreBilling) {
      final isStudent = productIdentifier.toLowerCase().contains('student');
      final isAnnual = productIdentifier.toLowerCase().contains('year') ||
          productIdentifier.toLowerCase().contains('annual');
      return selectPlan(
        appUserId: _appUserId,
        track: isStudent ? SubscriptionPlanTrack.student : SubscriptionPlanTrack.pro,
        planId: productIdentifier,
        planTitle: isStudent
            ? (isAnnual ? 'باقة الطلاب السنوية' : 'باقة الطلاب الشهرية')
            : (isAnnual ? 'باقة Pro السنوية' : 'باقة Pro الشهرية'),
        planPrice: isStudent
            ? (isAnnual ? '٣٩٩ ج.م' : '٤٩ ج.م')
            : (isAnnual ? '٦٩٩ ج.م' : '٨٩ ج.م'),
        isAnnual: isAnnual,
      );
    }

    if (!_configured) await _configure(_appUserId);
    final offerings = await Purchases.getOfferings();
    final package = _findPackage(offerings, productIdentifier);
    if (package == null) {
      return SubscriptionState(
        status: SubscriptionStatus.free,
        offers: _offersFrom(offerings),
        message: 'الخطة غير متاحة في المتجر حاليًا.',
      );
    }
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return _stateFrom(
      result.customerInfo,
      offerings,
      appUserId: _appUserId,
    );
  }

  @override
  Future<SubscriptionState> selectPlan({
    required String? appUserId,
    required SubscriptionPlanTrack track,
    required String planId,
    required String planTitle,
    required String planPrice,
    required bool isAnnual,
  }) async {
    _appUserId = appUserId;

    if (_hasStoreBilling) {
      try {
        if (!_configured) await _configure(appUserId);
        final offerings = await Purchases.getOfferings();
        final storeId = _resolveStoreIdentifier(track: track, planId: planId, isAnnual: isAnnual);
        final package = _findPackage(offerings, planId) ?? _findPackage(offerings, storeId);
        if (package != null) {
          final result = await Purchases.purchase(PurchaseParams.package(package));
          return await _stateFrom(
            result.customerInfo,
            offerings,
            appUserId: appUserId,
          );
        }
      } catch (_) {
        // Fall through to local persisted classification if store package isn't linked yet.
      }
    }

    final saved = await LocalSubscriptionStore.activatePlanForUser(
      userId: appUserId,
      track: track,
      planId: planId,
      planTitle: planTitle,
      planPrice: planPrice,
      isAnnual: isAnnual,
      isLocalActivation: true,
    );
    final state = saved.toSubscriptionState();
    onCustomerInfoChanged?.call(state);
    return state;
  }

  @override
  Future<SubscriptionState> cancelLocalPlan(String? appUserId) async {
    _appUserId = appUserId;
    await LocalSubscriptionStore.clearForUser(appUserId);
    const freeState = SubscriptionState(
      status: SubscriptionStatus.free,
      tier: SubscriptionTier.free,
    );
    onCustomerInfoChanged?.call(freeState);
    return freeState;
  }

  @override
  Future<SubscriptionState> restore(String? appUserId) async {
    _appUserId = appUserId;
    final local = await LocalSubscriptionStore.loadForUser(appUserId);
    if (!_hasStoreBilling) {
      return local.toSubscriptionState(
        message: local.isSubscribed
            ? 'تمت استعادة اشتراكك المحفوظ: ${local.toSubscriptionState().resolvedPlanTitle()}.'
            : 'لا توجد مشتريات سابقة محفوظة على هذا الحساب.',
      );
    }

    try {
      await _configure(appUserId);
      final customerInfo = await Purchases.restorePurchases();
      final offerings = await Purchases.getOfferings();
      return await _stateFrom(
        customerInfo,
        offerings,
        appUserId: appUserId,
        localFallback: local,
      );
    } catch (_) {
      return local.toSubscriptionState();
    }
  }

  String _resolveStoreIdentifier({
    required SubscriptionPlanTrack track,
    required String planId,
    required bool isAnnual,
  }) {
    if (track == SubscriptionPlanTrack.student) {
      return isAnnual
          ? SubscriptionConfig.studentYearlyProductId
          : SubscriptionConfig.studentMonthlyProductId;
    }
    return isAnnual
        ? SubscriptionConfig.yearlyProductId
        : SubscriptionConfig.monthlyProductId;
  }

  Future<void> _configure(String? appUserId) async {
    if (!_hasStoreBilling) return;
    if (!_configured) {
      await Purchases.setLogLevel(LogLevel.warn);
      await Purchases.configure(
        PurchasesConfiguration(SubscriptionConfig.androidApiKey),
      );
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
      _configured = true;
    }
    if (appUserId != null && appUserId.isNotEmpty && appUserId != _appUserId) {
      await Purchases.logIn(appUserId);
      _appUserId = appUserId;
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    _stateFrom(info, null, appUserId: _appUserId).then((_) {});
  }

  Future<SubscriptionState> _stateFrom(
    CustomerInfo info,
    Offerings? offerings, {
    String? appUserId,
    StoredSubscriptionRecord? localFallback,
  }) async {
    final studentEntitlement =
        info.entitlements.active[SubscriptionConfig.studentEntitlementId];
    final proEntitlement =
        info.entitlements.active[SubscriptionConfig.entitlementId];
    final hasStudent = studentEntitlement != null && studentEntitlement.isActive;
    final hasPro = proEntitlement != null && proEntitlement.isActive;

    final liveOffers = offerings == null ? const <SubscriptionOffer>[] : _offersFrom(offerings);

    if (hasStudent || hasPro) {
      final activeEnt = hasStudent ? studentEntitlement : proEntitlement;
      final tier = hasStudent ? SubscriptionTier.student : SubscriptionTier.pro;
      final category = hasStudent
          ? UserSubscriptionCategory.student
          : UserSubscriptionCategory.regularPro;
      final planId = activeEnt?.productIdentifier;
      final exp = DateTime.tryParse(activeEnt?.expirationDate ?? '');

      final saved = await LocalSubscriptionStore.saveForUser(
        appUserId,
        StoredSubscriptionRecord(
          userId: appUserId ?? 'guest',
          category: category,
          tier: tier,
          activePlanId: planId,
          subscribedAt: localFallback?.subscribedAt ?? DateTime.now(),
          expirationDate: exp,
          isLocalActivation: false,
        ),
      );
      final state = saved.toSubscriptionState(offers: liveOffers);
      onCustomerInfoChanged?.call(state);
      return state;
    }

    if (localFallback != null &&
        localFallback.isLocalActivation &&
        localFallback.isSubscribed) {
      final state = localFallback.toSubscriptionState(offers: liveOffers);
      onCustomerInfoChanged?.call(state);
      return state;
    }

    final freeState = SubscriptionState(
      status: SubscriptionStatus.free,
      tier: SubscriptionTier.free,
      offers: liveOffers,
    );
    onCustomerInfoChanged?.call(freeState);
    return freeState;
  }

  List<SubscriptionOffer> _offersFrom(Offerings offerings) {
    final current = offerings.current;
    if (current == null) return const [];
    return current.availablePackages.map((package) {
      final idLower = package.identifier.toLowerCase();
      final productLower = package.storeProduct.identifier.toLowerCase();
      final isStudent =
          package.identifier == SubscriptionConfig.studentMonthlyProductId ||
          package.identifier == SubscriptionConfig.studentYearlyProductId ||
          idLower.contains('student') ||
          productLower.contains('student');
      final isAnnual =
          package.identifier == SubscriptionConfig.yearlyProductId ||
          package.identifier == SubscriptionConfig.studentYearlyProductId ||
          package.packageType == PackageType.annual ||
          idLower.contains('year') ||
          idLower.contains('annual');

      final title = isStudent
          ? (isAnnual ? 'باقة الطلاب السنوية' : 'باقة الطلاب الشهرية')
          : (isAnnual ? 'Handelha Pro سنوي' : 'Handelha Pro شهري');
      final description = isStudent
          ? (isAnnual
              ? 'تغطية دراسية كاملة طول السنة بخصم خاص للطلاب.'
              : 'مزايا الطلاب كاملة وسجل الامتحانات بسعر مخفّض.')
          : (isAnnual
              ? 'أفضل قيمة لتنظيم السنة كلها.'
              : 'مرونة شهرية بدون التزام طويل.');

      return SubscriptionOffer(
        identifier: package.identifier,
        title: title,
        description: description,
        price: package.storeProduct.priceString,
        periodLabel: isAnnual ? 'سنوي' : 'شهري',
        isAnnual: isAnnual,
        track: isStudent
            ? SubscriptionPlanTrack.student
            : SubscriptionPlanTrack.pro,
      );
    }).toList();
  }

  Package? _findPackage(Offerings offerings, String identifier) {
    final current = offerings.current;
    if (current == null) return null;
    for (final package in current.availablePackages) {
      if (package.identifier == identifier ||
          package.storeProduct.identifier == identifier) {
        return package;
      }
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    if (_configured) {
      Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    }
  }
}

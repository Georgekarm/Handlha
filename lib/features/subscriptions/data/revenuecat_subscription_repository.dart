import 'dart:io';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../domain/subscription_models.dart';
import 'local_subscription_store.dart';
import 'subscription_repository.dart';

/// Platform-agnostic entitlement snapshot returned by [BillingGateway].
class BillingEntitlementSnapshot {
  const BillingEntitlementSnapshot({
    required this.entitlementId,
    required this.isActive,
    this.productIdentifier,
    this.expirationDate,
  });

  final String entitlementId;
  final bool isActive;
  final String? productIdentifier;
  final DateTime? expirationDate;
}

/// Platform-agnostic customer billing snapshot returned by [BillingGateway].
class BillingCustomerSnapshot {
  const BillingCustomerSnapshot({
    this.activeEntitlements = const {},
    this.allEntitlements = const {},
  });

  final Map<String, BillingEntitlementSnapshot> activeEntitlements;
  final Map<String, BillingEntitlementSnapshot> allEntitlements;
}

/// Explicit purchase attempt result distinguishing cancellation from failure.
class BillingPurchaseResult {
  const BillingPurchaseResult({
    this.customer,
    this.userCancelled = false,
    this.errorMessage,
  });

  final BillingCustomerSnapshot? customer;
  final bool userCancelled;
  final String? errorMessage;

  bool get isSuccess => customer != null && !userCancelled && errorMessage == null;
}

/// Injectable adapter around RevenueCat / Google Play Billing so purchase,
/// cancellation, expiration, revocation, and restore flows are deterministically
/// unit-tested without hitting live Play Store servers.
abstract interface class BillingGateway {
  Future<void> configure({
    required String apiKey,
    String? appUserId,
    required void Function(BillingCustomerSnapshot snapshot) onCustomerUpdated,
  });
  Future<void> logIn(String appUserId);
  Future<void> logOut();
  Future<BillingCustomerSnapshot> getCustomerSnapshot();
  Future<List<SubscriptionOffer>> getOffers();
  Future<BillingPurchaseResult> purchaseIdentifier(String identifier);
  Future<BillingCustomerSnapshot> restorePurchases();
  Future<void> dispose();
}

class _RevenueCatSdkGateway implements BillingGateway {
  void Function(CustomerInfo)? _listener;
  Offerings? _lastOfferings;

  @override
  Future<void> configure({
    required String apiKey,
    String? appUserId,
    required void Function(BillingCustomerSnapshot snapshot) onCustomerUpdated,
  }) async {
    await Purchases.setLogLevel(LogLevel.warn);
    final config = PurchasesConfiguration(apiKey)..appUserID = appUserId;
    await Purchases.configure(config);
    _listener = (info) => onCustomerUpdated(_mapCustomerInfo(info));
    Purchases.addCustomerInfoUpdateListener(_listener!);
  }

  @override
  Future<void> logIn(String appUserId) async {
    await Purchases.logIn(appUserId);
  }

  @override
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } catch (_) {}
  }

  @override
  Future<BillingCustomerSnapshot> getCustomerSnapshot() async {
    final info = await Purchases.getCustomerInfo();
    return _mapCustomerInfo(info);
  }

  @override
  Future<List<SubscriptionOffer>> getOffers() async {
    final offerings = await Purchases.getOfferings();
    _lastOfferings = offerings;
    return _mapOfferings(offerings);
  }

  @override
  Future<BillingPurchaseResult> purchaseIdentifier(String identifier) async {
    final offerings = _lastOfferings ?? await Purchases.getOfferings();
    _lastOfferings = offerings;
    final package = _findPackage(offerings, identifier);
    if (package == null) {
      return const BillingPurchaseResult(
        errorMessage: 'الخطة المختارة غير متاحة في متجر Google Play حاليًا.',
      );
    }
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return BillingPurchaseResult(
        customer: _mapCustomerInfo(result.customerInfo),
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const BillingPurchaseResult(userCancelled: true);
      }
      return const BillingPurchaseResult(
        errorMessage: 'لم تكتمل عملية الشراء عبر Google Play.',
      );
    } catch (_) {
      return const BillingPurchaseResult(
        errorMessage: 'لم تكتمل عملية الشراء عبر Google Play.',
      );
    }
  }

  @override
  Future<BillingCustomerSnapshot> restorePurchases() async {
    final info = await Purchases.restorePurchases();
    return _mapCustomerInfo(info);
  }

  @override
  Future<void> dispose() async {
    if (_listener != null) {
      Purchases.removeCustomerInfoUpdateListener(_listener!);
      _listener = null;
    }
  }

  BillingCustomerSnapshot _mapCustomerInfo(CustomerInfo info) {
    Map<String, BillingEntitlementSnapshot> mapMap(
      Map<String, EntitlementInfo> src,
    ) =>
        {
          for (final entry in src.entries)
            entry.key: BillingEntitlementSnapshot(
              entitlementId: entry.key,
              isActive: entry.value.isActive,
              productIdentifier: entry.value.productIdentifier,
              expirationDate: DateTime.tryParse(entry.value.expirationDate ?? ''),
            ),
        };
    return BillingCustomerSnapshot(
      activeEntitlements: mapMap(info.entitlements.active),
      allEntitlements: mapMap(info.entitlements.all),
    );
  }

  List<SubscriptionOffer> _mapOfferings(Offerings offerings) {
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
}

class RevenueCatSubscriptionRepository implements SubscriptionRepository {
  RevenueCatSubscriptionRepository({
    this.onCustomerInfoChanged,
    BillingGateway? gateway,
    this._storeBillingOverride,
    this._studentVerificationOverride,
    this._apiKeyOverride,
  }) : _gateway = gateway ?? _RevenueCatSdkGateway();

  final void Function(SubscriptionState state)? onCustomerInfoChanged;
  final BillingGateway _gateway;
  final bool? _storeBillingOverride;
  final bool? _studentVerificationOverride;
  final String? _apiKeyOverride;

  bool _configured = false;
  String? _appUserId;

  String get _resolvedApiKey => _apiKeyOverride ?? SubscriptionConfig.androidApiKey;

  bool get _hasStoreBilling =>
      _storeBillingOverride ??
      (Platform.isAndroid && _resolvedApiKey.trim().isNotEmpty);

  bool get _studentVerificationEnabled =>
      _studentVerificationOverride ??
      SubscriptionConfig.studentAcademicVerificationEnabled;

  @override
  Future<SubscriptionState> load(String? appUserId) async {
    final local = await LocalSubscriptionStore.loadForUser(appUserId);
    if (!_hasStoreBilling) {
      _appUserId = appUserId;
      if (local.isLocalActivation) {
        return const SubscriptionState(
          status: SubscriptionStatus.free,
          tier: SubscriptionTier.free,
        );
      }
      return local.toSubscriptionState();
    }

    try {
      await _configure(appUserId);
      final customer = await _gateway.getCustomerSnapshot();
      final offers = await _gateway.getOffers();
      return await _stateFrom(
        customer,
        offers,
        appUserId: appUserId,
        localFallback: local,
      );
    } catch (_) {
      if (local.isLocalActivation) {
        return const SubscriptionState(
          status: SubscriptionStatus.free,
          tier: SubscriptionTier.free,
        );
      }
      return local.toSubscriptionState();
    }
  }

  @override
  Future<SubscriptionState> purchase(String productIdentifier) async {
    if (!_hasStoreBilling) {
      return const SubscriptionState(
        status: SubscriptionStatus.free,
        tier: SubscriptionTier.free,
        message: 'خدمة الدفع عبر Google Play غير مهيّأة في هذه النسخة حاليًا.',
      );
    }

    await _configure(_appUserId);
    final offers = await _gateway.getOffers();
    final res = await _gateway.purchaseIdentifier(productIdentifier);
    if (res.isSuccess && res.customer != null) {
      return _stateFrom(
        res.customer!,
        offers,
        appUserId: _appUserId,
      );
    }

    final current = await LocalSubscriptionStore.loadForUser(_appUserId);
    final msg = res.userCancelled
        ? 'تم إلغاء عملية الشراء — لم يتم خصم أي مبلغ.'
        : (res.errorMessage ?? 'لم تكتمل عملية الشراء عبر Google Play.');
    return current.isLocalActivation
        ? SubscriptionState(
            status: SubscriptionStatus.free,
            tier: SubscriptionTier.free,
            offers: offers,
            message: msg,
          )
        : current.toSubscriptionState(offers: offers, message: msg);
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
    final current = await LocalSubscriptionStore.loadForUser(appUserId);
    SubscriptionState failClosed(
      String message, [
      List<SubscriptionOffer> offers = const [],
    ]) {
      final base = current.isLocalActivation
          ? SubscriptionState(
              status: SubscriptionStatus.free,
              tier: SubscriptionTier.free,
              offers: offers,
              message: message,
            )
          : current.toSubscriptionState(offers: offers, message: message);
      onCustomerInfoChanged?.call(base);
      return base;
    }

    if (track == SubscriptionPlanTrack.student && !_studentVerificationEnabled) {
      return failClosed(
        'خصم باقة الطلاب معلّق لحين تفعيل التحقق الأكاديمي من البريد الجامعي. يمكنك الاشتراك في باقات Handelha Pro.',
      );
    }

    if (!_hasStoreBilling) {
      _appUserId = appUserId;
      return failClosed(
        'خدمة الدفع عبر Google Play غير مفعّلة في هذه البيئة. لم يتم تفعيل أي اشتراك.',
      );
    }

    try {
      await _configure(appUserId);
      final offers = await _gateway.getOffers();
      final storeId = _resolveStoreIdentifier(
        track: track,
        planId: planId,
        isAnnual: isAnnual,
      );
      final hasExact = offers.any((o) => o.identifier == planId);
      final targetId = hasExact ? planId : storeId;
      final res = await _gateway.purchaseIdentifier(targetId);
      if (res.isSuccess && res.customer != null) {
        return await _stateFrom(
          res.customer!,
          offers,
          appUserId: appUserId,
        );
      }
      if (res.userCancelled) {
        return failClosed('تم إلغاء عملية الشراء — لم يتم خصم أي مبلغ.', offers);
      }
      return failClosed(
        res.errorMessage ?? 'تم إلغاء أو تعذّر إتمام عملية الشراء عبر Google Play.',
        offers,
      );
    } catch (_) {
      return failClosed('تم إلغاء أو تعذّر إتمام عملية الشراء عبر Google Play.');
    }
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
    final local = await LocalSubscriptionStore.loadForUser(appUserId);
    if (!_hasStoreBilling) {
      _appUserId = appUserId;
      return const SubscriptionState(
        status: SubscriptionStatus.free,
        tier: SubscriptionTier.free,
        message: 'لا توجد مشتريات سابقة مرتبطة بمتجر Google Play على هذا الحساب.',
      );
    }

    try {
      await _configure(appUserId);
      final customer = await _gateway.restorePurchases();
      final offers = await _gateway.getOffers();
      final next = await _stateFrom(
        customer,
        offers,
        appUserId: appUserId,
        localFallback: local,
      );
      if (next.isPro) {
        return next.copyWith(
          message: 'تمت استعادة اشتراكك النشط من Google Play بنجاح.',
        );
      }
      if (next.status == SubscriptionStatus.expired) {
        return next.copyWith(
          message:
              'تم العثور على اشتراك سابق لكنه منتهي الصلاحية على Google Play.',
        );
      }
      return next.copyWith(
        message:
            'لم يتم العثور على اشتراك نشط سابق مرتبط بحساب Google Play هذا.',
      );
    } catch (_) {
      return local.isLocalActivation
          ? const SubscriptionState(
              status: SubscriptionStatus.free,
              tier: SubscriptionTier.free,
              message: 'تعذّر الاتصال بمتجر Google Play لاستعادة المشتريات.',
            )
          : local.toSubscriptionState();
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
    final cleanId = (appUserId != null && appUserId.trim().isNotEmpty)
        ? appUserId.trim()
        : null;
    if (!_configured) {
      await _gateway.configure(
        apiKey: _resolvedApiKey,
        appUserId: cleanId,
        onCustomerUpdated: (snapshot) {
          _stateFrom(snapshot, const [], appUserId: _appUserId).then((_) {});
        },
      );
      _configured = true;
      _appUserId = cleanId;
      return;
    }
    if (cleanId != null && cleanId != _appUserId) {
      await _gateway.logIn(cleanId);
      _appUserId = cleanId;
    } else if (cleanId == null && _appUserId != null) {
      await _gateway.logOut();
      _appUserId = null;
    }
  }

  Future<SubscriptionState> _stateFrom(
    BillingCustomerSnapshot customer,
    List<SubscriptionOffer> liveOffers, {
    String? appUserId,
    StoredSubscriptionRecord? localFallback,
  }) async {
    final studentEntitlement =
        customer.activeEntitlements[SubscriptionConfig.studentEntitlementId];
    final proEntitlement =
        customer.activeEntitlements[SubscriptionConfig.entitlementId];
    final hasStudent = studentEntitlement != null && studentEntitlement.isActive;
    final hasPro = proEntitlement != null && proEntitlement.isActive;

    if (hasStudent || hasPro) {
      final activeEnt = hasStudent ? studentEntitlement : proEntitlement;
      final tier = hasStudent ? SubscriptionTier.student : SubscriptionTier.pro;
      final category = hasStudent
          ? UserSubscriptionCategory.student
          : UserSubscriptionCategory.regularPro;
      final planId = activeEnt?.productIdentifier;
      final exp = activeEnt?.expirationDate;

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

    // Check whether an entitlement existed previously and expired/was revoked.
    final prevPro = customer.allEntitlements[SubscriptionConfig.entitlementId];
    final prevStudent =
        customer.allEntitlements[SubscriptionConfig.studentEntitlementId];
    final expiredEnt = (prevPro != null && !prevPro.isActive)
        ? prevPro
        : ((prevStudent != null && !prevStudent.isActive) ? prevStudent : null);

    await LocalSubscriptionStore.clearForUser(appUserId);
    final inactiveState = expiredEnt != null
        ? SubscriptionState(
            status: SubscriptionStatus.expired,
            tier: SubscriptionTier.free,
            offers: liveOffers,
            expirationDate: expiredEnt.expirationDate,
            message: 'انتهت صلاحية اشتراكك السابق وعاد الحساب للباقة المجانية.',
          )
        : SubscriptionState(
            status: SubscriptionStatus.free,
            tier: SubscriptionTier.free,
            offers: liveOffers,
          );
    onCustomerInfoChanged?.call(inactiveState);
    return inactiveState;
  }

  @override
  Future<void> dispose() async {
    if (_configured) {
      await _gateway.dispose();
    }
  }
}

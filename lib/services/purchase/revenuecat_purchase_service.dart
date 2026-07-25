import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'purchase_service.dart';

class RevenueCatPurchaseService implements PurchaseService {
  static const _kOfferingId = 'boxed_premium';
  final _premiumController = StreamController<bool>.broadcast();
  void Function(CustomerInfo)? _listener;

  @override
  Future<void> initialize() async {
    final apiKey = Platform.isIOS
        ? const String.fromEnvironment('REVENUECAT_IOS_KEY')
        : const String.fromEnvironment('REVENUECAT_ANDROID_KEY');

    final configuration = PurchasesConfiguration(apiKey);
    await Purchases.configure(configuration);

    _listener = (info) {
      final isPremium = info.entitlements.active.containsKey('premium');
      _premiumController.add(isPremium);
    };
    Purchases.addCustomerInfoUpdateListener(_listener!);
  }

  @override
  Future<void> identify(String uid) async {
    await Purchases.logIn(uid);
  }

  @override
  Future<bool> isPremium() async {
    final info = await Purchases.getCustomerInfo();
    return info.entitlements.active.containsKey('premium');
  }

  @override
  Stream<bool> premiumUpdates() => _premiumController.stream;

  @override
  Future<PurchaseProduct?> premiumProduct() async {
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.all[_kOfferingId]?.getPackage('premium');
      if (package == null) return null;
      final storeProduct = package.storeProduct;
      return PurchaseProduct(
        id: storeProduct.identifier,
        priceString: storeProduct.priceString,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PurchaseOutcome> purchasePremium() async {
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.all[_kOfferingId]?.getPackage('premium');
      if (package == null) {
        return const PurchaseError('Product not available');
      }
      final info = await Purchases.purchasePackage(package);
      final isPremium = info.entitlements.active.containsKey('premium');
      return isPremium ? const PurchaseSuccess() : const PurchaseError('Premium not activated');
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseCancelled();
      }
      return PurchaseError(e.message ?? 'Purchase failed');
    } catch (e) {
      return PurchaseError(e.toString());
    }
  }

  @override
  Future<PurchaseOutcome> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      final isPremium = info.entitlements.active.containsKey('premium');
      return isPremium
          ? const PurchaseSuccess()
          : const PurchaseError('No purchases to restore');
    } catch (e) {
      return PurchaseError(e.toString());
    }
  }
}

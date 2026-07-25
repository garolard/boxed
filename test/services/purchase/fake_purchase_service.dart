import 'dart:async';

import 'package:vgcollection/services/purchase/purchase_service.dart';

class FakePurchaseService implements PurchaseService {
  bool _isPremium = false;
  final _premiumController = StreamController<bool>.broadcast();
  PurchaseOutcome? _purchaseOutcome;
  PurchaseOutcome? _restoreOutcome;
  PurchaseProduct? _product;

  int identifyCallCount = 0;
  String? lastIdentifyUid;
  int purchaseCallCount = 0;
  int restoreCallCount = 0;

  set purchaseOutcome(PurchaseOutcome? value) => _purchaseOutcome = value;
  set restoreOutcome(PurchaseOutcome? value) => _restoreOutcome = value;
  set product(PurchaseProduct? value) => _product = value;

  void emitPremium(bool value) {
    _isPremium = value;
    _premiumController.add(value);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> identify(String uid) async {
    identifyCallCount++;
    lastIdentifyUid = uid;
  }

  @override
  Future<bool> isPremium() async => _isPremium;

  @override
  Stream<bool> premiumUpdates() => _premiumController.stream;

  @override
  Future<PurchaseProduct?> premiumProduct() async => _product;

  @override
  Future<PurchaseOutcome> purchasePremium() async {
    purchaseCallCount++;
    return _purchaseOutcome ?? const PurchaseError('Not configured');
  }

  @override
  Future<PurchaseOutcome> restore() async {
    restoreCallCount++;
    return _restoreOutcome ?? const PurchaseError('Not configured');
  }
}

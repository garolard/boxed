import 'dart:async';

import '../scan_quota_service.dart';
import 'purchase_service.dart';

class PremiumBridge {
  final PurchaseService _purchaseService;
  final ScanQuotaService _scanQuotaService;
  StreamSubscription<bool>? _premiumSub;
  bool _restoreAttempted = false;

  PremiumBridge({
    required PurchaseService purchaseService,
    required ScanQuotaService scanQuotaService,
  })  : _purchaseService = purchaseService,
        _scanQuotaService = scanQuotaService;

  void start() {
    _premiumSub = _purchaseService.premiumUpdates().listen((isPremium) {
      if (isPremium) {
        _scanQuotaService.markPremium();
      }
    });
    _maybeRestore();
  }

  Future<void> _maybeRestore() async {
    if (_restoreAttempted) return;
    _restoreAttempted = true;
    try {
      final alreadyPremium = await _purchaseService.isPremium();
      if (alreadyPremium) return;
      await _purchaseService.restore();
    } catch (_) {
    }
  }

  void dispose() {
    _premiumSub?.cancel();
  }
}

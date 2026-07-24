class PurchaseProduct {
  final String id;
  final String priceString;

  const PurchaseProduct({
    required this.id,
    required this.priceString,
  });
}

sealed class PurchaseOutcome {
  const PurchaseOutcome();
}

final class PurchaseSuccess extends PurchaseOutcome {
  const PurchaseSuccess();
}

final class PurchaseCancelled extends PurchaseOutcome {
  const PurchaseCancelled();
}

final class PurchaseError extends PurchaseOutcome {
  final String message;
  const PurchaseError(this.message);
}

abstract class PurchaseService {
  Future<void> initialize();

  Future<void> identify(String uid);

  Future<bool> isPremium();

  Stream<bool> premiumUpdates();

  Future<PurchaseProduct?> premiumProduct();

  Future<PurchaseOutcome> purchasePremium();

  Future<PurchaseOutcome> restore();
}

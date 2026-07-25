import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgcollection/services/purchase/revenuecat_purchase_service.dart';

/// Tests drive the *real* [RevenueCatPurchaseService.premiumProduct] end-to-end
/// by mocking the `purchases_flutter` method channel that
/// `Purchases.getOfferings()` calls under the hood. This exercises the actual
/// offering -> package -> product resolution — the layer where the earlier bug
/// (`getPackage('premium')`, an entitlement id, resolving to null) lived.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('purchases_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// A single store product wrapping the Play SKU `premium_unlimited_scans`.
  Map<String, Object?> productJson({
    String identifier = 'premium_unlimited_scans',
    String priceString = r'$4.99',
  }) =>
      {
        'identifier': identifier,
        'description': 'Unlimited AI cover scans',
        'title': 'Premium',
        'price': 4990000,
        'priceString': priceString,
        'currencyCode': 'USD',
        'introPrice': null,
        'discounts': null,
        'productCategory': null,
        'defaultOption': null,
        'subscriptionOptions': null,
        'presentedOfferingIdentifier': null,
        'subscriptionPeriod': null,
      };

  /// A package inside an offering. Mirrors how the native SDK reports a
  /// "Lifetime" package: identifier `$rc_lifetime`, not the entitlement id.
  Map<String, Object?> packageJson({
    String identifier = r'$rc_lifetime',
    String packageType = 'LIFETIME',
    Map<String, Object?>? product,
  }) =>
      {
        'identifier': identifier,
        'packageType': packageType,
        'product': product ?? productJson(),
        'presentedOfferingContext': {'offeringIdentifier': 'boxed_premium'},
      };

  /// An offering keyed under an id, with its typed package slots. The native
  /// side fills both `availablePackages` and the matching typed slot
  /// (e.g. `lifetime`); [lifetime] toggles whether the typed slot is present.
  Map<String, Object?> offeringJson({
    String identifier = 'boxed_premium',
    required Map<String, Object?> package,
    bool lifetime = true,
  }) =>
      {
        'identifier': identifier,
        'serverDescription': '',
        'metadata': <String, Object?>{},
        'availablePackages': [package],
        'lifetime': lifetime ? package : null,
        'annual': null,
        'sixMonth': null,
        'threeMonth': null,
        'twoMonth': null,
        'monthly': null,
        'weekly': null,
      };

  Map<String, Object?> offeringsJson(
    Map<String, Map<String, Object?>> all,
  ) =>
      {'all': all, 'current': null};

  /// Registers a `getOfferings` handler returning [offerings]; other channel
  /// methods return null. Pass [throwOnGetOfferings] to simulate a store error.
  void mockOfferings(
    Map<String, Object?>? offerings, {
    bool throwOnGetOfferings = false,
  }) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getOfferings') {
        if (throwOnGetOfferings) {
          throw PlatformException(code: '23', message: 'store unreachable');
        }
        return offerings;
      }
      return null;
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('resolves the premium product from the boxed_premium lifetime package',
      () async {
    mockOfferings(offeringsJson({
      'boxed_premium': offeringJson(package: packageJson()),
    }));

    final product = await RevenueCatPurchaseService().premiumProduct();

    expect(product, isNotNull);
    expect(product!.id, 'premium_unlimited_scans');
    expect(product.priceString, r'$4.99');
  });

  test('resolves via availablePackages when the typed lifetime slot is null',
      () async {
    // Guards the fallback: even if RC reports the package only in
    // availablePackages (custom type, no typed slot), resolution still works.
    mockOfferings(offeringsJson({
      'boxed_premium': offeringJson(
        package: packageJson(identifier: 'custom_pkg', packageType: 'CUSTOM'),
        lifetime: false,
      ),
    }));

    final product = await RevenueCatPurchaseService().premiumProduct();

    expect(product?.id, 'premium_unlimited_scans');
  });

  test('returns null when the boxed_premium offering is absent', () async {
    mockOfferings(offeringsJson({
      'some_other_offering': offeringJson(
        identifier: 'some_other_offering',
        package: packageJson(),
      ),
    }));

    final product = await RevenueCatPurchaseService().premiumProduct();

    expect(product, isNull);
  });

  test('returns null (never throws) when fetching offerings fails', () async {
    mockOfferings(null, throwOnGetOfferings: true);

    final product = await RevenueCatPurchaseService().premiumProduct();

    expect(product, isNull);
  });
}

# revenuecat-one-time-premium

## Goal

Add a store-agnostic one-time premium purchase path via RevenueCat, wiring the paywall to real purchase/restore/price display and lighting up the existing quota gate through a promote-only bridge.

## Prerequisites

- Detect the current git branch with `git rev-parse --abbrev-ref HEAD` (or equivalent). If the command returns empty (detached HEAD), use the literal text `detached HEAD` for option 2.
- Present exactly three options in the user's input language (English fallback), in this fixed order. Canonical English labels — translate to match the user's input language, preserving meaning and order:
  1. `Suggest branch "revenuecat-one-time-premium"` — the change-name-derived branch (default).
  2. `Stay on current branch "{current-branch}"` — the detected current branch, or `detached HEAD`.
  3. `Enter branch name manually` — free text for a custom branch name.
- No option is prohibited. The user bears full responsibility for the choice.
- If the selected branch does not exist, create it from `main` before implementing.

### Step-by-Step Instructions

#### Step 1: Purchase seam — dependency, interface, models
*(already applied)*
#### Step 2: RevenueCat implementation
*(already applied)*
#### Step 3: ScanQuotaService.markPremium()
*(already applied)*
#### Step 4: PremiumBridge
*(already applied)*
#### Step 5: Provider + main + bootstrap wiring
*(already applied)*
#### Step 6: Paywall wiring + localization
*(already applied)*
#### Step 7: Tests
*(already applied)*

#### Step 8: Use explicit RC offering ID instead of `current`

- [x] In `lib/services/purchase/revenuecat_purchase_service.dart`, add a private constant `_kOfferingId = 'boxed_premium'`.
- [x] In both `premiumProduct()` and `purchasePremium()`, replace `offerings.current?.getPackage('premium')` with `offerings.all[_kOfferingId]?.getPackage('premium')`.

Diff:

```dart
+ const _kOfferingId = 'boxed_premium';

  // in premiumProduct:
- final package = offerings.current?.getPackage('premium');
+ final package = offerings.all[_kOfferingId]?.getPackage('premium');

  // in purchasePremium:
- final package = offerings.current?.getPackage('premium');
+ final package = offerings.all[_kOfferingId]?.getPackage('premium');
```

##### Step 8 Verification Checklist

**Automated:**
- [x] `flutter analyze lib/services/purchase/revenuecat_purchase_service.dart` — zero issues
- [x] `flutter test test/services/purchase/premium_bridge_test.dart` — still passes
- [x] `flutter test test/screens/paywall_screen_test.dart` — still passes

#### Step 9: Graceful degradation when product unavailable

- [x] Add `"paywallCtaUnavailable": "Temporarily unavailable"` (and translations) to the three `.arb` files.
- [x] Run `flutter gen-l10n` to regenerate the `AppLocalizations` class.
- [x] In `lib/screens/paywall_screen.dart`, disable the `FilledButton` when `product == null`:
  - Set `onPressed: null` when no product is available
  - Show `Text(l10n.paywallCtaUnavailable)` instead of `Text(l10n.paywallCtaFallback)` when product is null
- [x] Verify the disabled state renders correctly: the button is gray and untappable, Restore button is still functional.

```dart
// Before (lines 63-82):
FilledButton(
  onPressed: () => _handlePurchase(context),
  child: FutureBuilder<PurchaseProduct?>(
    future: _productFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }
      final product = snapshot.data;
      if (product != null) {
        return Text(l10n.paywallCtaPrice(product.priceString));
      }
      return Text(l10n.paywallCtaFallback);
    },
  ),
),

// After:
FilledButton(
  onPressed: _product == null ? null : () => _handlePurchase(context),
  child: FutureBuilder<PurchaseProduct?>(
    future: _productFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }
      final product = snapshot.data;
      if (product != null) {
        return Text(l10n.paywallCtaPrice(product.priceString));
      }
      return Text(l10n.paywallCtaUnavailable);
    },
  ),
),
```

##### Step 9 Verification Checklist

**Automated:**
- [x] `flutter gen-l10n` succeeds
- [x] `flutter analyze lib/screens/paywall_screen.dart` — zero issues
- [x] `flutter test test/screens/paywall_screen_test.dart` — still passes

**Human:**
- [x] Open the paywall in dev mode (no RevenueCat offering configured), verify the CTA is disabled and shows "Temporarily unavailable", and the Restore button is still tappable.

---

## Design Decisions Qualifying as ADR/DDR

The following decisions from `design.md` meet all three ADR/DDR criteria (hard to reverse, surprising without context, real trade-off):

- **D1** — Store-agnostic `PurchaseService` interface + separate RevenueCat impl
- **D2** — Promote-only bridge writing through a new `ScanQuotaService.markPremium()`
- **D4** — Identity anchored via `Purchases.logIn(uid)`, idempotent
- **D5** — Exactly one gated silent restore during bootstrap
- **D6** — Per-platform API keys via `String.fromEnvironment` dart-defines

The project does not currently maintain an `docs/adr/` or `docs/ddr/` directory. If you want these decisions preserved, run `/sai-3-implement` again after creating the directory and approving ADR creation.

### Step 9 — FutureBuilder wrapping for reactive `onPressed`

**Plan:** Use a plain `_product` field set via `.then()` on the future, referenced directly in `FilledButton.onPressed`.

**Final:** Both the `FilledButton` and `TextButton` are wrapped inside the `FutureBuilder`, using `snapshot.data` directly for both `onPressed` and the child text.

**Reason:** A plain field doesn't trigger widget rebuilds. The `FutureBuilder` rebuilds its child on snapshot change, but `onPressed` is a property of the `FilledButton` (the outer widget), not of the `FutureBuilder`'s child — so the closure captured the initial `null`. Wrapping everything inside the `FutureBuilder` builder ensures `onPressed` is re-evaluated with the correct `product` value on every snapshot change.

## Appendix: Plan vs Final Implementation

### Step 7 — Fake infrastructure compilation fixes

**Plan:** Shared `FakeUser` uses `final String uid` field + `String get uid` getter.

**Final:** Field renamed to `_uid` to avoid declaration conflict with the overriding getter.

**Reason:** Dart doesn't allow a field and getter with the same name in the same class when both are declared in the class.

**Plan:** `_FakeTransaction.update` parameter typed `Map<String, dynamic>`.

**Final:** Changed to `Map<Object, Object?>` to match the overridden `Transaction.update` signature, with explicit `data.cast<String, dynamic>()` for the internal map.

**Reason:** Parent interface (`cloud_firestore` 6.7.1) declares the parameter with `Map<Object, Object?>`.

**Plan:** `set` with merge does a simple spread (`...data`) — no FieldValue resolution.

**Final:** `set` with merge iterates entries and resolves `FieldValue.increment` the same way `update` does.

**Reason:** `recordScan` calls `doc.set({'scansUsed': FieldValue.increment(1)}, SetOptions(merge: true))`. Without FieldValue resolution, the Firestore fake stores the `FieldValue` object itself, which crashes when `quotaStream` casts `data['scansUsed'] as num?`.

**Plan:** `_FakeTransaction.commit` has `@override` annotation.

**Final:** Removed `@override`.

**Reason:** `Transaction` (cloud_firestore 6.7.1) does not define a `commit()` method. It's an internal method of the fake.

**Plan:** Paywall test uses `find.text(r'$4.99')`.

**Final:** Uses `find.textContaining(r'$4.99')`.

**Reason:** The rendered CTA text is `"Unlock for $4.99"` (localized prefix), not just the price string.

**Plan:** `FakeFirestore.doc`, `FakeFirestore.collection`, `FakeFirestore.runTransaction` lack `@override` annotations.

**Final:** Added `@override` to all three methods.

**Reason:** `flutter analyze` emitted `info`-level `annotate_overrides` warnings on these methods. Adding `@override` silences them.

**Plan:** Bridge test relies on transitive import of `PurchaseSuccess` from `fake_purchase_service.dart`.

**Final:** Added explicit `import 'package:vgcollection/services/purchase/purchase_service.dart'`.

**Reason:** Dart does not transitively expose imports from other files. `fake_purchase_service.dart` imports `purchase_service.dart` but doesn't re-export it, so `PurchaseSuccess` is not visible in the bridge test without a direct import.

### Step 2 — API differences in purchases_flutter 8.11.0

**Plan:** `addCustomerInfoUpdateListener` returns a `void Function()` removal handle stored as `_removeListener`.

**Final:** `addCustomerInfoUpdateListener` returns `void`. The listener function reference is stored directly and passed to `removeCustomerInfoUpdateListener` (visible in the companion dispose path).

**Reason:** The plan was written against an older SDK convention. In purchases_flutter 8.11.0, listeners are registered via `addCustomerInfoUpdateListener(callback)` which returns void, and removal is done via `removeCustomerInfoUpdateListener(callback)`.

**Plan:** `Purchases.purchasePackage(package)` returns a result with `result.customerInfo`.

**Final:** `Purchases.purchasePackage(package)` returns `Future<CustomerInfo>` directly — the CustomerInfo is the return value, not a field on a result wrapper.

**Reason:** SDK 8.x simplified the return type. No wrapper object.

**Plan:** `PlatformException` imported implicitly.

**Final:** Added `import 'package:flutter/services.dart'` for `PlatformException`.

**Reason:** `PlatformException` is not exported by `purchases_flutter`'s public API; it must be imported from `package:flutter/services.dart`.

## Why

The scan gate (`ScanQuotaService`) and `PaywallScreen` already ship, but the paywall's purchase and restore buttons are "coming soon" stubs — there is no way for a user to actually pay to unlock unlimited AI cover scans. We need a real, one-time (non-consumable) payment path that preserves the app's "no login required" stance and keeps the payment provider swappable and testable, rather than hard-coupling the UI to RevenueCat.

## What Changes

- Introduce a store-agnostic `PurchaseService` interface (plain `PurchaseProduct` / `PurchaseOutcome` models) so no RevenueCat type leaks into the app; add a `RevenueCatPurchaseService` implementation wrapping `purchases_flutter`.
- Sell a single non-consumable `premium` entitlement (one product) that maps to a `bool`. Identity is anchored to the Firebase Anonymous Auth uid via `Purchases.logIn(uid)`.
- Resolve the offering by an explicit id (`boxed_premium`, a single named constant) via `getOfferings().all['boxed_premium']` — do NOT rely on a "current" offering being set in the RevenueCat dashboard.
- Treat an unresolved offering/product as a first-class state, not a crash: when nothing resolves (offering id absent, store unreachable, Play not yet propagated), `premiumProduct()` returns `null`, `purchasePremium()` returns the error outcome, and the paywall renders a disabled CTA + "temporarily unavailable" copy while Restore stays functional.
- Add a bootstrap **bridge**: a listener on `premiumUpdates()` that performs a one-shot `ScanQuotaService.markPremium()` write of `isPremium: true` into `users/{uid}`, so the existing quota gate and reactive stream light up with near-zero rewiring.
- Self-heal on Android (uninstall rotates the uid): when a fresh/rotated uid is not premium, run **one** silent `restore()` — never on every launch.
- Wire `PaywallScreen`: CTA → `purchasePremium()`, Restore → `restore()`, and render the real localized price from `premiumProduct()`, replacing both "coming soon" SnackBars. Copy shifts from subscription wording to one-time-purchase wording.
- Add `purchaseServiceProvider` in `lib/providers/services.dart`, overridden in `main.dart`; call `initialize()` in `main()` and `identify(uid)` + start the bridge in `_AppBootstrap._bootstrap`.
- Add tests: a hand-rolled `FakePurchaseService` (no mocktail), paywall widget tests, and a bridge test reusing the existing in-memory fake Firestore.

## Capabilities

### New Capabilities
- `purchase-service`: store-agnostic `PurchaseService` abstraction and plain `PurchaseProduct` / `PurchaseOutcome` models — the seam every consumer talks to; no store SDK types leak out.
- `revenuecat-impl`: `RevenueCatPurchaseService` wrapping `purchases_flutter`, mapping the single non-consumable `premium` entitlement to a `bool`, anchoring identity via `Purchases.logIn(uid)`, and resolving the offering by the explicit id `boxed_premium` (named constant) rather than the RC "current" offering.
- `graceful-unavailable`: unresolved offering/product is a first-class null/error state — `premiumProduct()` returns `null`, `purchasePremium()` returns error, nothing throws to the UI, and the paywall degrades to a disabled CTA + "temporarily unavailable" copy with Restore still functional.
- `premium-bridge`: bootstrap listener that translates an active entitlement into a `users/{uid}.isPremium: true` write via a new `ScanQuotaService.markPremium()`, plus the gated one-shot silent restore for a fresh/rotated non-premium uid.
- `paywall-purchase`: wiring `PaywallScreen`'s CTA, Restore button, and price display to the real purchase flow and localized product price, replacing the "coming soon" stubs.
- `wiring`: provider registration and app-bootstrap sequencing (`purchaseServiceProvider`, `initialize()` in `main()`, `identify()` + bridge in `_AppBootstrap`).
- `tests`: hand-rolled `FakePurchaseService`, paywall widget tests, and the bridge test against the existing fake Firestore.

### Modified Capabilities
<!-- None. No baseline specs exist under openspec/specs/; all behavior here is additive. The existing ScanQuotaService gate, _effectivePremium seam, and IS_PREMIUM override are preserved unchanged. -->

## Impact

- **New dependency**: `purchases_flutter` (RevenueCat) in `pubspec.yaml`, plus per-platform RevenueCat API keys.
- **New code**: `PurchaseService` interface + models, `RevenueCatPurchaseService`, `purchaseServiceProvider`, the bridge in `_AppBootstrap._bootstrap`, and `ScanQuotaService.markPremium()`.
- **Modified code**: `lib/main.dart` (init + provider override), `lib/providers/services.dart` (new provider), `lib/screens/paywall_screen.dart` (real CTA/Restore/price), l10n `.arb` files (price placeholder + one-time-purchase copy).
- **Preserved seams (unchanged)**: `users/{uid}.isPremium` remains the gate; `ScanQuotaService._effectivePremium` and the `IS_PREMIUM` dev override stay as-is. The `PurchaseService` impl MUST NOT import Firestore; `ScanQuotaService` MUST NOT import RevenueCat — the bridge is the only coupling.
- **Non-goals**: cross-store transfer (buy on Android → switch to iOS = repurchase, accepted); hardening against jailbreak/root direct-Firestore writes (relax the planned rule to "user may write their own doc" — accepted low-value threat); Cloud Functions / webhooks / recurring subscriptions.
- **Platform behavior**: iOS keeps an explicit Restore button (App Store review requirement); Android restore runs silently.

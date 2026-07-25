# Design: revenuecat-one-time-premium

## Context

The scan gate (`ScanQuotaService`) and `PaywallScreen` already ship. The gate reads `users/{uid}.isPremium` from Firestore and exposes a reactive `quotaStream()`; `_effectivePremium` is a documented seam (`_isPremiumOverride || _cachedQuota?.isPremium == true`) explicitly left for a store integration. The paywall is a `ConsumerWidget` whose CTA and Restore buttons both show an identical "coming soon" SnackBar. No purchase SDK exists in the tree.

Established conventions this design must honor (from codebase research):
- Providers are plain `Provider<T>` / `StreamProvider<T>`, no `autoDispose`, no `riverpod_annotation` codegen. Services follow a throw-until-overridden pattern (`UnsupportedError`) and are overridden with real instances in `main.dart`'s root `ProviderScope`.
- `AnalyticsService` sets the precedent for an async-initialized service (`static Future<…> create()`) constructed in `main()` before `runApp`, then injected via override.
- `ScanQuotaService` is constructor-injected with `FirebaseFirestore` + `FirebaseAuth` + a `bool isPremiumOverride`; tests inject a hand-rolled `FakeFirestore`/`FakeFirebaseAuth` via `implements` + `noSuchMethod` — no mocktail.
- l10n: flat lowerCamelCase keys in `lib/l10n/app_{en,es,fr}.arb`, parameterized via `@key: {"placeholders": {...}}`, accessed through `context.l10n`.
- Compile-time config is delivered via `String.fromEnvironment` dart-defines (`IS_PREMIUM`); the repo recently dropped `.env`-as-asset in favor of `fromEnvironment`.

## Goals / Non-Goals

**Goals**
- Real one-time (non-consumable) `premium` purchase + restore path, no login required.
- Keep the payment provider swappable and testable behind a store-agnostic seam — no `purchases_flutter` type leaks past one file.
- Light up the existing quota gate with near-zero rewiring via a promote-only bridge to `users/{uid}.isPremium`.
- Self-heal Android uid rotation with exactly one gated silent restore.

**Non-Goals**
- Cross-store transfer (Android→iOS repurchase accepted).
- Hardening against rooted-device direct Firestore writes.
- Cloud Functions / webhooks / recurring subscriptions.
- Writing `isPremium: false` from any store signal (gate is promote-only).

## Decisions

### D1: Store-agnostic `PurchaseService` interface + separate RevenueCat impl
Introduce an abstract `PurchaseService` (interface) and a `RevenueCatPurchaseService` (impl) — the first interface/impl split in the repo. Only the impl imports `purchases_flutter`; the impl imports no Firestore symbol.
- **ADR criteria**: Hard to reverse ✅ (every consumer binds to the seam) · Surprising without context ✅ (repo has no other interface/impl split; `AnalyticsService` is a single concrete class) · Real trade-off ✅.
- **Alternatives considered**: (a) Use `purchases_flutter` types directly in the paywall + bridge — rejected: couples UI and gate to the SDK, blocks the hand-rolled fake, contradicts the "swappable/testable" goal. (b) Interface with RevenueCat models re-exported — rejected: still leaks SDK types.
- **Chosen**: Plain-Dart interface + `PurchaseProduct` / `PurchaseOutcome` models, RevenueCat isolated in one file. Matches the existing "override a plain-typed provider in main" pattern.

### D2: Promote-only bridge writing through a new `ScanQuotaService.markPremium()`
The bridge subscribes to `premiumUpdates()` and calls `markPremium()` (a `set({isPremium:true}, merge:true)` write) only on `true`; it never writes `false`. `ScanQuotaService` gains `markPremium()` as the ONLY new coupling point and imports no RevenueCat symbol.
- **ADR criteria**: Hard to reverse ✅ (defines the single coupling contract) · Surprising ✅ (one-way write is deliberate) · Real trade-off ✅.
- **Alternatives considered**: Two-way sync (mirror entitlement→flag including revocation) — rejected: a non-consumable never legitimately revokes here, and a false-write would fight the `IS_PREMIUM` dev override and risk fland-closed flapping. Keep `_effectivePremium` seam untouched.
- **Chosen**: `markPremium()` merge-write, no-op when no uid; bridge promotes only. Preserves the existing gate/override seam verbatim.

### D3: Extract the bridge into a testable `PremiumBridge` class
Bridge logic (subscribe→markPremium + gated one-shot silent restore) lives in a `PremiumBridge` taking `PurchaseService` + `ScanQuotaService`, not inline in `_AppBootstrap`. Rationale: the `tests` spec requires a bridge test using the existing `FakeFirestore`; an inlined listener in a private `State` is not unit-testable. Not an ADR-level decision (easily reversible) but recorded for the WHY.

### D4: Identity anchored via `Purchases.logIn(uid)`, idempotent
`identify(uid)` calls `Purchases.logIn(uid)` so the RevenueCat app-user id equals the Firebase Anonymous uid the quota doc uses. Called once after sign-in in bootstrap; tolerant of the same uid already logged in.
- **ADR criteria**: Hard to reverse ✅ (ties purchase identity to the anon uid model) · Surprising ✅ (Android uid rotation is why the silent restore exists) · Real trade-off ✅ (vs. anonymous RevenueCat ids or a separate stable id).
- **Alternatives considered**: Let RevenueCat mint its own anonymous id — rejected: decouples purchase identity from the quota doc identity and complicates restore reasoning. A separately persisted stable id — rejected: reintroduces a "login-like" concept the app deliberately avoids.
- **Chosen**: Bind to Firebase uid; accept that Android reinstall rotates it and self-heal via D5.

### D5: Exactly one gated silent restore during bootstrap
Because Android uninstall rotates the anon uid, run a single silent `restore()` at bootstrap only when the current uid is not already premium. Never on every launch; never for an already-premium uid. iOS keeps the explicit Restore button regardless (App Store review requirement).
- **ADR criteria**: Hard to reverse ⚠️ moderate · Surprising ✅ (a background store call during splash) · Real trade-off ✅.
- **Chosen**: Gate on `!isPremium`, one shot, failures swallowed (fire-and-forget like `AnalyticsService._safe`), MUST NOT block the splash-to-home transition or exceed the existing auth timeout behavior.

### D6: Per-platform API keys via `String.fromEnvironment` dart-defines
`initialize()` calls `Purchases.configure` once with the platform-appropriate key selected via `Platform.isIOS`/`isAndroid`, keys supplied as compile-time `String.fromEnvironment('REVENUECAT_IOS_KEY' / 'REVENUECAT_ANDROID_KEY')`. Matches the repo's `IS_PREMIUM`/`fromEnvironment` convention and the deliberate move away from bundling `.env`.

### D7: Resolve the offering by an explicit `boxed_premium` id, not the "current" offering
`premiumProduct()` reads the premium package from `getOfferings().all['boxed_premium']`, where `boxed_premium` is a single named constant, independent of any dashboard-configured "current" offering.
- **ADR criteria**: Hard to reverse ⚠️ moderate (changing the id/source touches product resolution + graceful-unavailable behavior) · Surprising ✅ (most RC samples reach for `offerings.current`) · Real trade-off ✅.
- **Alternatives considered**: Rely on `offerings.current` — fewer keystrokes, but couples runtime behavior to a mutable dashboard toggle that can silently null out the paywall; not reviewable in code.
- **Chosen**: Explicit id via a named constant → deterministic, code-reviewable resolution; a missing `boxed_premium` degrades through the graceful-unavailable path (D-level guarantee below) rather than surprising failure. See `specs/revenuecat-impl/spec.md`.

## Risks / Trade-offs

- **[SDK slow/offline during bootstrap blocks splash]** → Mitigation: `initialize()`/`identify()`/silent `restore()` are fire-and-forget with swallowed errors; bootstrap keeps the existing `Future.wait([...auth..., Future.delayed(_minSplash)])` timing and never awaits store calls on the splash-to-home path.
- **[Android uid rotation loses entitlement]** → Mitigation: D5 gated silent restore reactivates it against the still-owned store account.
- **[Promote-only bridge can't revoke]** → Mitigation: accepted by design; a non-consumable does not legitimately revoke here, and revocation would fight the dev override.
- **[Store type leakage regressions]** → Mitigation: `tests`/`revenuecat-impl` specs assert the interface imports no `purchases_flutter` and the impl imports no Firestore; the hand-rolled fake keeps consumers SDK-free.
- **[`purchases_flutter` version drift]** → Mitigation: pin the current latest stable at implementation time; the SDK surface used is small (`configure`, `logIn`, `getOfferings`, `purchase`, `restorePurchases`, customer-info listener).

## Migration Plan

Additive; no data migration. Deploy = ship the app with the new dependency and per-platform RevenueCat keys configured in the build. Rollback = revert the change set; the preserved `users/{uid}.isPremium` gate and `IS_PREMIUM` override continue to function with the paywall reverting to its "coming soon" stubs. No Firestore schema change (only an additive `isPremium` merge-write that already exists in the doc shape).

## Open Questions

None outstanding. Resolved during design: API-key delivery mechanism (D6, via repo `fromEnvironment` convention); bridge testability (D3, extracted class); entitlement/product identity fixed by specs (`premium` entitlement, single non-consumable product).

## File Change Checklist

Each row maps to the capability spec that governs it. `C` = created, `M` = modified.

| # | File | C/M | Change | Spec |
|---|------|-----|--------|------|
| 1 | `pubspec.yaml` | M | Add `purchases_flutter` dependency (latest stable). | revenuecat-impl |
| 2 | `lib/services/purchase/purchase_service.dart` | C | Abstract `PurchaseService` (`initialize`, `identify`, `isPremium`, `premiumUpdates`, `premiumProduct`, `purchasePremium`, `restore`) + plain `PurchaseProduct` (`id`, `priceString`) and `PurchaseOutcome` (success/cancelled/error) models. No store types. | purchase-service |
| 3 | `lib/services/purchase/revenuecat_purchase_service.dart` | C | `RevenueCatPurchaseService implements PurchaseService` over `purchases_flutter`; `configure` with platform key; `premium` entitlement→`bool`; customer-info listener→`Stream<bool>`; `logIn(uid)`; map results/user-cancelled to `PurchaseOutcome`; resolve offering via `getOfferings().all['boxed_premium']` (single named constant, D7)→`PurchaseProduct`, `null` when unresolved. Only file importing `purchases_flutter`; imports no Firestore. | revenuecat-impl |
| 4 | `lib/services/scan_quota_service.dart` | M | Add `markPremium()` → `set({isPremium:true}, merge:true)` on `users/{uid}`; no-op when no uid; no RevenueCat import; `_effectivePremium` seam untouched. | premium-bridge |
| 5 | `lib/services/purchase/premium_bridge.dart` | C | `PremiumBridge(PurchaseService, ScanQuotaService)`; `start()` subscribes `premiumUpdates()`→`markPremium()` on `true` only, plus the one gated silent restore (skip if already premium). | premium-bridge |
| 6 | `lib/providers/services.dart` | M | Add `purchaseServiceProvider` (plain `Provider<PurchaseService>`, throw `UnsupportedError` until overridden). | wiring |
| 7 | `lib/main.dart` | M | Construct + `initialize()` `RevenueCatPurchaseService` in `main()` before `runApp`; override `purchaseServiceProvider`; in `_AppBootstrap._bootstrap` call `identify(uid)` then start `PremiumBridge` (non-blocking, preserves splash timing). | wiring, premium-bridge |
| 8 | `lib/screens/paywall_screen.dart` | M | CTA→`purchasePremium()` (dismiss on success, silent on cancel, localized error); Restore→`restore()` (dismiss/nothing-to-restore/error); render `premiumProduct().priceString` with generic fallback on `null`; one-time-purchase copy; keep explicit Restore control (iOS). | paywall-purchase |
| 9 | `lib/l10n/app_en.arb` | M | Add price-parameterized CTA key + one-time-purchase copy + restore/error/nothing-to-restore keys; replace subscription wording. Template file. | paywall-purchase |
| 10 | `lib/l10n/app_es.arb` | M | Mirror new/changed keys in Spanish. | paywall-purchase |
| 11 | `lib/l10n/app_fr.arb` | M | Mirror new/changed keys in French. | paywall-purchase |
| 12 | `lib/l10n/app_localizations*.dart` | M | Regenerated from `.arb` (via `flutter gen-l10n`); not hand-edited. | paywall-purchase |
| 13 | `test/services/purchase/fake_purchase_service.dart` | C | Hand-rolled `FakePurchaseService implements PurchaseService` (no mocktail); scriptable outcomes, product, and `premiumUpdates()` emissions. | tests |
| 14 | `test/screens/paywall_screen_test.dart` | C | Widget tests via Riverpod override: price renders, CTA calls `purchasePremium()`+dismisses, Restore calls `restore()`, cancel leaves paywall open. | tests |
| 15 | `test/services/purchase/premium_bridge_test.dart` | C | Emission `true`→`markPremium()` write asserted against the existing in-memory `FakeFirestore`; silent restore gated (runs non-premium, skipped already-premium). | tests |

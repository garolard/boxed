# Tasks: revenuecat-one-time-premium

Ordered by dependency. Each `## Step` is one commit and MUST leave the repo buildable on its own.

## Step 1: Purchase seam — dependency, interface, models

**Files Affected**: pubspec.yaml, lib/services/purchase/purchase_service.dart

**What Will Be Done**: Add the `purchases_flutter` dependency (latest stable) to `pubspec.yaml`. Create the abstract `PurchaseService` plus plain `PurchaseProduct` and `PurchaseOutcome` models per `specs/purchase-service/spec.md`. No `purchases_flutter` import here. Buildable alone (abstract type + value models, no consumers yet). Model the outcome as an enum/sealed value that distinguishes success/cancelled/error per spec; `priceString` is a plain display string. Follow the repo's plain-Dart, no-codegen style.

**Testing Strategy**: `flutter analyze` clean; types compile. Behavioral coverage arrives in Step 7 (the interface is exercised via `FakePurchaseService`).

## Step 2: RevenueCat implementation

**Files Affected**: lib/services/purchase/revenuecat_purchase_service.dart

**What Will Be Done**: Implement `RevenueCatPurchaseService implements PurchaseService` wrapping `purchases_flutter` per `specs/revenuecat-impl/spec.md`. This is the ONLY file importing `purchases_flutter` and imports no Firestore symbol. `initialize()` selects the platform key via `Platform.isIOS`/`isAndroid` from `String.fromEnvironment` dart-defines (see design D6) and calls `Purchases.configure` once. Map the `premium` entitlement to `bool`; bridge the customer-info listener to a broadcast `Stream<bool>`; `identify` → idempotent `Purchases.logIn(uid)`; translate user-cancelled into the cancellation outcome; `premiumProduct()` resolves the offering explicitly via `getOfferings().all['boxed_premium']` held in a single named constant (design D7) — NOT `offerings.current` — and returns `null` when the offering/product cannot be resolved. Depends on Step 1's interface + the Step 1 dependency; buildable alone.

**Testing Strategy**: `flutter analyze` clean. Not unit-tested directly (wraps the live SDK); the interface contract is verified via the fake in Step 7. Manual/device verification of a real purchase is out of scope for the plan.

## Step 3: ScanQuotaService.markPremium()

**Files Affected**: lib/services/scan_quota_service.dart

**What Will Be Done**: Add `markPremium()` per `specs/premium-bridge/spec.md` — a `set({isPremium:true}, merge:true)` write on the existing `_doc` (`users/{uid}`), no-op when `_uid` is null. Reuse the existing `_doc`/`_uid` accessors; leave `_effectivePremium`, `quotaStream()`, and the `IS_PREMIUM` override untouched. No RevenueCat import. Buildable alone.

**Testing Strategy**: Covered by the existing test file's fake in Step 7's bridge test; assert the merge write preserves sibling fields (e.g. `scansUsed`).

## Step 4: PremiumBridge

**Files Affected**: lib/services/purchase/premium_bridge.dart

**What Will Be Done**: Create `PremiumBridge` taking `PurchaseService` + `ScanQuotaService` (design D3). `start()` subscribes to `premiumUpdates()` and calls `markPremium()` only on `true` (never on `false`), and runs the single gated silent `restore()` when the current uid is not already premium — per `specs/premium-bridge/spec.md`. Errors swallowed (fire-and-forget). Depends on Steps 1–3; buildable alone.

**Testing Strategy**: Unit-tested in Step 7 against `FakePurchaseService` + the existing `FakeFirestore`: emission writes the flag; restore gating runs for non-premium and is skipped for already-premium.

## Step 5: Provider + main + bootstrap wiring

**Files Affected**: lib/providers/services.dart, lib/main.dart

**What Will Be Done**: Add `purchaseServiceProvider` (plain `Provider<PurchaseService>`, throw-until-overridden) mirroring `scanQuotaServiceProvider`/`analyticsServiceProvider`, per `specs/wiring/spec.md`. In `main()` construct + `initialize()` the `RevenueCatPurchaseService` before `runApp` (alongside analytics/quota) and add its `overrideWithValue` to the root `ProviderScope`. In `_AppBootstrap._bootstrap`, after sign-in + quota provisioning, call `identify(uid)` then start `PremiumBridge`, keeping the existing `Future.wait([...])`/`_minSplash` timing and never awaiting store calls on the splash path (design D5, wiring spec's bootstrap scenarios). Both files change together because the provider and its override are one contract; depends on Steps 1–4; buildable.

**Testing Strategy**: `flutter analyze` clean; app boots. Bootstrap non-blocking behavior verified by reasoning (no `await` on store calls in the splash path) and the bridge unit test in Step 7.

## Step 6: Paywall wiring + localization

**Files Affected**: lib/screens/paywall_screen.dart, lib/l10n/app_en.arb, lib/l10n/app_es.arb, lib/l10n/app_fr.arb, lib/l10n/app_localizations.dart, lib/l10n/app_localizations_en.dart, lib/l10n/app_localizations_es.dart, lib/l10n/app_localizations_fr.dart

**What Will Be Done**: Per `specs/paywall-purchase/spec.md`, wire the CTA to `ref.read(purchaseServiceProvider).purchasePremium()` (dismiss on success, silent on cancel, localized error on error), the Restore control to `restore()` (dismiss / localized nothing-to-restore / error), and render `premiumProduct().priceString` in the CTA with a generic localized fallback when `null`. Replace both "coming soon" SnackBars and shift copy to one-time-purchase wording; keep the explicit Restore control (iOS). Add the price-parameterized CTA key and new copy/error keys to `app_en.arb` following the `@key: {"placeholders": {...}}` convention, mirror them in `app_es.arb`/`app_fr.arb`, and regenerate `app_localizations*.dart` via `flutter gen-l10n` (do not hand-edit generated files). Depends on Steps 1 + 5; buildable (provider exists, generated l10n updated in the same commit).

**Testing Strategy**: Widget tests in Step 7 (price render, CTA/Restore wiring, cancel path). `flutter gen-l10n` succeeds; `flutter analyze` clean.

## Step 7: Tests

**Files Affected**: test/services/purchase/fake_purchase_service.dart, test/screens/paywall_screen_test.dart, test/services/purchase/premium_bridge_test.dart

**What Will Be Done**: Per `specs/tests/spec.md`: hand-roll `FakePurchaseService implements PurchaseService` (no mocktail) with scriptable outcomes/product/stream emissions, mirroring the `implements` + `noSuchMethod` style in `test/services/scan_quota_service_test.dart`. Add `PaywallScreen` widget tests via Riverpod `overrideWithValue`. Add the `PremiumBridge` test reusing the in-memory `FakeFirestore`/`FakeFirebaseAuth` from the existing scan-quota test (extract or duplicate per that file's convention). Depends on all prior steps.

**Testing Strategy**: `flutter test` green across the three files, covering every scenario in `specs/tests/spec.md`.

## Required Documentation

### Local files
- lib/main.dart
- lib/providers/services.dart
- lib/providers/scan_quota_provider.dart
- lib/services/scan_quota_service.dart
- lib/services/analytics_service.dart
- lib/screens/paywall_screen.dart
- lib/l10n/l10n.dart
- lib/l10n/app_en.arb
- l10n.yaml
- test/services/scan_quota_service_test.dart
- pubspec.yaml

### Spec files
- openspec/changes/revenuecat-one-time-premium/specs/purchase-service/spec.md
- openspec/changes/revenuecat-one-time-premium/specs/revenuecat-impl/spec.md
- openspec/changes/revenuecat-one-time-premium/specs/premium-bridge/spec.md
- openspec/changes/revenuecat-one-time-premium/specs/paywall-purchase/spec.md
- openspec/changes/revenuecat-one-time-premium/specs/wiring/spec.md
- openspec/changes/revenuecat-one-time-premium/specs/tests/spec.md

### External URLs
None

## Implementation Context

**Stack**: Flutter / Dart (SDK `^3.12.2`), `flutter_riverpod ^3.3.2`, `cloud_firestore ^6.7.1`, `firebase_auth ^6.5.6`, `intl ^0.20.2`; new: `purchases_flutter` (RevenueCat).

**Conventions**:
- Providers are plain `Provider`/`StreamProvider` — no `autoDispose`, no `riverpod_annotation`/`.g.dart` codegen. Services throw `UnsupportedError` until overridden in `main.dart`'s root `ProviderScope`.
- Async-initialized services follow `AnalyticsService.create()`: build in `main()` before `runApp`, inject via override. Fire-and-forget calls swallow errors in a private `_safe`-style helper.
- Tests hand-roll fakes via `implements` + `noSuchMethod` (see `FakeFirestore`); no mocktail. `ScanQuotaService` is constructor-injected with `firestore`/`auth`.
- l10n keys are flat lowerCamelCase in `lib/l10n/app_{en,es,fr}.arb`, parameterized with `@key: {"placeholders": {...}}`, accessed via `context.l10n`; generated `app_localizations*.dart` is produced by `flutter gen-l10n`, never hand-edited.
- Compile-time config via `String.fromEnvironment` dart-defines (`IS_PREMIUM` precedent); no `.env` asset.

**Avoid**:
- Leaking any `purchases_flutter` type past `RevenueCatPurchaseService`; importing Firestore into any purchase file; importing RevenueCat into `ScanQuotaService`.
- Adding `riverpod` codegen or `mocktail` (both absent by convention).
- Awaiting store calls on the splash-to-home path or writing `isPremium:false` from the bridge.
- Hand-editing generated `app_localizations*.dart` instead of regenerating.

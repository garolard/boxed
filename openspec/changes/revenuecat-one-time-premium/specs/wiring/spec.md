## ADDED Requirements

### Requirement: purchaseServiceProvider is registered and overridden in main
The system SHALL add a `purchaseServiceProvider` to `lib/providers/services.dart` following the existing throw-until-overridden pattern used by `scanQuotaServiceProvider` and `analyticsServiceProvider`. `main.dart` SHALL override it with a concrete `RevenueCatPurchaseService` instance in the root `ProviderScope`.

#### Scenario: Provider throws until overridden
- **WHEN** `purchaseServiceProvider` is read without an override
- **THEN** it throws `UnsupportedError`, matching the sibling service providers

#### Scenario: main overrides with the RevenueCat implementation
- **WHEN** the app boots
- **THEN** `purchaseServiceProvider` resolves to the `RevenueCatPurchaseService` instance created in `main.dart`

### Requirement: PurchaseService is initialized in main before runApp
The system SHALL call `PurchaseService.initialize()` in `main()` before `runApp`, alongside the existing Firebase and analytics initialization, so the SDK is configured before any screen can request a product or purchase.

#### Scenario: initialize runs during startup
- **WHEN** `main()` executes
- **THEN** `PurchaseService.initialize()` completes before `runApp` is called

### Requirement: Bootstrap identifies the uid and starts the bridge
`_AppBootstrap._bootstrap` SHALL, after anonymous sign-in and quota provisioning, call `PurchaseService.identify(uid)` and start the premium bridge (subscribe to `premiumUpdates()` → `markPremium()`, plus the gated one-shot silent restore). The additions MUST preserve the existing minimum-splash timing and MUST NOT block the splash-to-home transition beyond the current auth timeout behavior.

#### Scenario: Identify happens after sign-in
- **WHEN** anonymous sign-in yields a uid during bootstrap
- **THEN** `identify(uid)` is called before the bridge subscribes

#### Scenario: Bootstrap still transitions to home
- **WHEN** the purchase SDK is slow or offline during bootstrap
- **THEN** the splash still transitions to home under the existing timing and no unhandled exception escapes bootstrap

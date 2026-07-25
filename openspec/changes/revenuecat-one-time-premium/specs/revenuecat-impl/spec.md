## ADDED Requirements

### Requirement: RevenueCatPurchaseService implements PurchaseService over purchases_flutter
The system SHALL provide `RevenueCatPurchaseService` implementing `PurchaseService` by wrapping the `purchases_flutter` SDK. It is the ONLY file permitted to import `purchases_flutter`. `initialize()` SHALL configure `Purchases` with the platform-appropriate API key. The implementation MUST NOT import Firestore or any app persistence layer.

#### Scenario: Initialization configures the SDK
- **WHEN** `initialize()` is called during app startup
- **THEN** `Purchases.configure` runs with the platform's RevenueCat API key exactly once

#### Scenario: RevenueCat import is isolated
- **WHEN** the codebase is analyzed
- **THEN** `purchases_flutter` is imported only by `RevenueCatPurchaseService`, and that file imports no Firestore symbol

### Requirement: The premium entitlement maps to a bool
The system SHALL treat the RevenueCat entitlement named `premium` as the single source of truth for premium state. `isPremium()` SHALL return `true` when `CustomerInfo.entitlements.active` contains `premium`, otherwise `false`. `premiumUpdates()` SHALL bridge RevenueCat's customer-info listener to a `Stream<bool>` reflecting that entitlement.

#### Scenario: Active entitlement reads as premium
- **WHEN** `CustomerInfo` reports `premium` in active entitlements
- **THEN** `isPremium()` returns `true`

#### Scenario: Listener updates propagate as bool
- **WHEN** RevenueCat fires a customer-info update in which `premium` becomes active
- **THEN** `premiumUpdates()` emits `true`

### Requirement: Identity is anchored to the Firebase uid
`identify(uid)` SHALL call `Purchases.logIn(uid)` so the RevenueCat app-user id equals the Firebase Anonymous Auth uid, keeping the purchase tied to the same identity the quota doc uses. It MUST tolerate being called with the current uid already logged in (idempotent, no crash).

#### Scenario: Login binds RevenueCat to the Firebase uid
- **WHEN** `identify(uid)` is called with the current Firebase Anonymous uid
- **THEN** `Purchases.logIn(uid)` runs and subsequent entitlement state is scoped to that app-user id

#### Scenario: Repeated identify with the same uid
- **WHEN** `identify(uid)` is called again with an unchanged uid
- **THEN** the call completes without error and premium state is unchanged

### Requirement: The premium offering is resolved by explicit id
The system SHALL resolve the premium offering by an explicit offering id held in a single named constant `boxed_premium` — via `getOfferings().all['boxed_premium']` (equivalently `getOffering('boxed_premium')`). The implementation MUST NOT rely on a "current" offering being configured in the RevenueCat dashboard. The premium `PurchaseProduct` SHALL be read from that resolved offering's package.

#### Scenario: Offering resolved by its explicit id
- **WHEN** `premiumProduct()` runs and `getOfferings().all` contains `boxed_premium`
- **THEN** the premium product is read from the `boxed_premium` offering, independent of whether any "current" offering is set

#### Scenario: Offering id is a single named constant
- **WHEN** the codebase is analyzed
- **THEN** the `boxed_premium` offering id appears as one named constant, not duplicated string literals

### Requirement: Purchase and restore map RevenueCat results to plain outcomes
`purchasePremium()` SHALL purchase the single non-consumable premium product and map the SDK result to a `PurchaseOutcome`, translating RevenueCat's user-cancelled error into the cancellation outcome rather than an error. `restore()` SHALL call `Purchases.restorePurchases()` and return an outcome reflecting whether `premium` is active afterward. `premiumProduct()` SHALL read the premium product from the `boxed_premium` offering and return a `PurchaseProduct` with its localized `priceString`, or `null` when the offering or product cannot be resolved.

#### Scenario: Purchase completes
- **WHEN** the native purchase succeeds for the premium product
- **THEN** `purchasePremium()` returns a success `PurchaseOutcome` and `isPremium()` is `true`

#### Scenario: User-cancelled purchase is not an error
- **WHEN** RevenueCat throws with the user-cancelled reason
- **THEN** `purchasePremium()` returns the cancellation outcome, not the error outcome

#### Scenario: Restore finds a prior purchase
- **WHEN** `restore()` runs on a device that previously bought premium
- **THEN** `premium` becomes active and `restore()` returns a success outcome

## ADDED Requirements

### Requirement: Store-agnostic PurchaseService interface
The system SHALL define an abstract `PurchaseService` interface that is the single seam every consumer talks to. It SHALL expose exactly these members: `initialize()`, `identify(String uid)`, `isPremium()`, `premiumUpdates()`, `premiumProduct()`, `purchasePremium()`, and `restore()`. No type from `purchases_flutter` (RevenueCat) SHALL appear in the interface's signatures — inputs and outputs use plain Dart types and the models defined below.

#### Scenario: Interface exposes the full contract
- **WHEN** a consumer holds a `PurchaseService` reference
- **THEN** it can call `initialize`, `identify`, `isPremium`, `premiumUpdates`, `premiumProduct`, `purchasePremium`, and `restore` without importing any RevenueCat symbol

#### Scenario: No store SDK types leak through the interface
- **WHEN** the interface file is analyzed
- **THEN** it imports no `purchases_flutter` symbol and every method signature uses plain Dart types or the `PurchaseProduct` / `PurchaseOutcome` models

### Requirement: Premium state is exposed as a bool and a stream
`isPremium()` SHALL return the current entitlement state as a `bool` (or `Future<bool>`), and `premiumUpdates()` SHALL return a `Stream<bool>` that emits whenever the `premium` entitlement becomes active or inactive. The stream is the source the bridge listens to.

#### Scenario: Query current premium state
- **WHEN** a consumer calls `isPremium()` after `initialize()`
- **THEN** it receives `true` if the `premium` entitlement is active, otherwise `false`

#### Scenario: Entitlement change emits on the stream
- **WHEN** the `premium` entitlement transitions from inactive to active
- **THEN** `premiumUpdates()` emits `true`

### Requirement: PurchaseProduct model carries a display-ready localized price
The system SHALL define a plain `PurchaseProduct` model exposing at minimum an identifier and a `priceString` that is the store-localized, ready-to-display price (e.g. `"$4.99"`). `premiumProduct()` SHALL return the `PurchaseProduct` for the single non-consumable premium product, or `null` when it cannot be loaded.

#### Scenario: Product resolves with a localized price
- **WHEN** `premiumProduct()` succeeds
- **THEN** it returns a `PurchaseProduct` whose `priceString` is the store-formatted localized price

#### Scenario: Product cannot be loaded
- **WHEN** the store offering is unavailable (offline, misconfigured)
- **THEN** `premiumProduct()` returns `null` and no exception propagates to the caller

### Requirement: PurchaseOutcome model reports the result of a purchase or restore
The system SHALL define a plain `PurchaseOutcome` model that distinguishes at least: success (premium now active), user cancellation, and error. `purchasePremium()` and `restore()` SHALL return a `PurchaseOutcome` and MUST NOT throw store-specific exceptions to the caller.

#### Scenario: Successful purchase
- **WHEN** the user completes payment for the premium product
- **THEN** `purchasePremium()` returns a `PurchaseOutcome` indicating success and premium is active

#### Scenario: User cancels the purchase
- **WHEN** the user dismisses the native purchase sheet
- **THEN** `purchasePremium()` returns a `PurchaseOutcome` indicating cancellation, distinguishable from an error

#### Scenario: Purchase fails
- **WHEN** the store returns a payment error
- **THEN** `purchasePremium()` returns a `PurchaseOutcome` indicating error rather than throwing

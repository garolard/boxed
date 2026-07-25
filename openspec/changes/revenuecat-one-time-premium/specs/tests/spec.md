## ADDED Requirements

### Requirement: Hand-rolled FakePurchaseService exists (no mocktail)
The system SHALL provide a hand-written `FakePurchaseService` implementing `PurchaseService` for tests, with no dependency on `mocktail` or any mocking package. It SHALL let a test script the outcomes of `purchasePremium()` / `restore()`, the value of `premiumProduct()`, and the emissions of `premiumUpdates()`.

#### Scenario: Fake is scriptable
- **WHEN** a test configures the fake to return a success outcome and emit `true` on `premiumUpdates()`
- **THEN** consumers under test observe those values without any real store SDK or network

### Requirement: Paywall widget tests cover CTA, restore, and price
The system SHALL add widget tests for `PaywallScreen` that, using `FakePurchaseService` via Riverpod override, assert: the localized price renders from `premiumProduct()`; tapping the CTA calls `purchasePremium()` and dismisses on success; tapping Restore calls `restore()`; and cancellation leaves the paywall open with no error.

#### Scenario: Price renders in the CTA
- **WHEN** the fake returns a product with a known `priceString`
- **THEN** the widget test finds that price on screen

#### Scenario: CTA success dismisses the paywall
- **WHEN** the fake returns a success outcome for `purchasePremium()`
- **THEN** the test asserts `purchasePremium()` was called and the paywall is dismissed

#### Scenario: Restore is wired
- **WHEN** the user taps Restore
- **THEN** the test asserts `restore()` was called

### Requirement: Bridge test uses the existing fake Firestore
The system SHALL add a test proving that a `premiumUpdates()` emission of `true` results in a `users/{uid}.isPremium: true` write, reusing the in-memory `FakeFirestore` already present in `test/services/scan_quota_service_test.dart`. It SHALL also assert that the silent restore is gated: it runs for a non-premium uid and is skipped for an already-premium uid.

#### Scenario: Emission writes the flag through markPremium
- **WHEN** the bridge is started with the fake and `premiumUpdates()` emits `true`
- **THEN** the fake Firestore doc `users/{uid}` reads `isPremium: true`

#### Scenario: Silent restore is gated by premium state
- **WHEN** bootstrap runs for an already-premium uid
- **THEN** the test asserts `restore()` is not called

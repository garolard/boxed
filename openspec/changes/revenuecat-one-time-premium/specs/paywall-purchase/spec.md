## ADDED Requirements

### Requirement: Paywall CTA triggers a real purchase
The system SHALL wire `PaywallScreen`'s primary CTA to `PurchaseService.purchasePremium()`, replacing the "coming soon" SnackBar. On a success outcome the paywall SHALL dismiss (the bridge unlocks the gate). On cancellation the paywall SHALL remain with no error shown. On error the paywall SHALL surface a localized failure message.

#### Scenario: Successful purchase from the paywall
- **WHEN** the user taps the CTA and `purchasePremium()` returns success
- **THEN** the paywall closes and the scan gate is unlocked via the premium bridge

#### Scenario: User cancels at the native sheet
- **WHEN** `purchasePremium()` returns the cancellation outcome
- **THEN** the paywall stays open and no error SnackBar is shown

#### Scenario: Purchase error
- **WHEN** `purchasePremium()` returns the error outcome
- **THEN** a localized error message is shown and the paywall stays open

### Requirement: Paywall shows the real localized price
The system SHALL render the price from `PurchaseService.premiumProduct()` in the CTA (or nearby), replacing hard-coded copy. When `premiumProduct()` returns `null`, the CTA SHALL be disabled and show localized "temporarily unavailable" copy in place of a price, and MUST remain non-crashing (see the `graceful-unavailable` capability). Paywall copy SHALL reflect a one-time purchase, not a recurring subscription.

#### Scenario: Price is displayed
- **WHEN** `premiumProduct()` returns a product with `priceString == "$4.99"`
- **THEN** the paywall CTA displays that localized price

#### Scenario: Price unavailable
- **WHEN** `premiumProduct()` returns `null`
- **THEN** the paywall disables the primary CTA, shows localized "temporarily unavailable" copy instead of a price, and does not crash

#### Scenario: Copy reflects one-time purchase
- **WHEN** the paywall renders its title/subtitle/CTA
- **THEN** the wording describes a one-time unlock rather than a subscription

### Requirement: Restore button invokes restore and reports the result
The system SHALL wire the Restore control to `PurchaseService.restore()`, replacing the "coming soon" SnackBar. On success (premium active) the paywall SHALL dismiss; otherwise it SHALL show a localized "nothing to restore" or error message. The explicit Restore button SHALL remain present on iOS for App Store review compliance.

#### Scenario: Restore reactivates premium
- **WHEN** the user taps Restore and `restore()` returns success
- **THEN** the paywall closes and the gate unlocks via the bridge

#### Scenario: Nothing to restore
- **WHEN** `restore()` finds no prior purchase
- **THEN** a localized "nothing to restore" message is shown and the paywall stays open

#### Scenario: Restore button present on iOS
- **WHEN** the paywall is shown on iOS
- **THEN** an explicit Restore control is visible

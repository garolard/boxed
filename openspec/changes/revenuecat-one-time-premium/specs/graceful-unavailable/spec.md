## ADDED Requirements

### Requirement: Unresolved offering or product is a first-class null/error state
When the premium offering or product cannot be resolved — the `boxed_premium` offering id is absent, the store is unreachable, or a freshly published product has not yet propagated — the purchase layer SHALL treat it as a defined state, never a crash. `premiumProduct()` SHALL return `null` and `purchasePremium()` SHALL return the error `PurchaseOutcome`. No store-specific exception SHALL propagate to the UI from either call.

#### Scenario: Offering id absent
- **WHEN** `getOfferings().all` does not contain `boxed_premium`
- **THEN** `premiumProduct()` returns `null` and no exception propagates to the caller

#### Scenario: Purchase attempted with no resolvable product
- **WHEN** `purchasePremium()` is called while the premium product cannot be resolved
- **THEN** it returns the error outcome rather than throwing

#### Scenario: Store unreachable during load
- **WHEN** fetching offerings fails (offline, store outage, not yet propagated)
- **THEN** `premiumProduct()` returns `null` and `purchasePremium()` returns the error outcome

### Requirement: Paywall degrades gracefully when premium is unavailable
When `premiumProduct()` returns `null`, `PaywallScreen` SHALL render a disabled primary CTA together with localized "temporarily unavailable" copy in place of a price, and MUST NOT crash. The Restore control SHALL remain enabled and functional in this state, so a prior purchaser can still recover their entitlement.

#### Scenario: Disabled CTA and unavailable copy
- **WHEN** the paywall renders while `premiumProduct()` is `null`
- **THEN** the primary CTA is disabled and localized "temporarily unavailable" copy is shown instead of a price

#### Scenario: Restore stays functional while unavailable
- **WHEN** premium is unavailable and the user taps Restore
- **THEN** `restore()` is still invoked and its outcome is reported normally

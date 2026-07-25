## ADDED Requirements

### Requirement: ScanQuotaService exposes a one-shot markPremium write
The system SHALL add `ScanQuotaService.markPremium()` that writes `isPremium: true` to `users/{uid}` using `set({...}, merge: true)`. This is the ONLY new coupling point; `ScanQuotaService` MUST NOT import RevenueCat. The write is a no-op when there is no current uid.

#### Scenario: markPremium writes the flag
- **WHEN** `markPremium()` is called with an authenticated uid
- **THEN** `users/{uid}` is merged with `isPremium: true` and other fields (e.g. `scansUsed`) are preserved

#### Scenario: markPremium with no uid
- **WHEN** `markPremium()` is called while no user is signed in
- **THEN** it performs no write and does not throw

### Requirement: Bridge translates entitlement updates into the Firestore flag
The system SHALL, during app bootstrap, subscribe to `PurchaseService.premiumUpdates()` and call `ScanQuotaService.markPremium()` whenever it emits `true`. This is the sole mechanism that turns a store entitlement into the `users/{uid}.isPremium` gate the app already reads. The bridge MUST NOT write `isPremium: false` — it only promotes to premium.

#### Scenario: Entitlement becomes active
- **WHEN** `premiumUpdates()` emits `true` after a purchase or restore
- **THEN** the bridge calls `markPremium()` once for that emission and the quota stream re-emits `isPremium: true`

#### Scenario: Non-premium emission does not clear the flag
- **WHEN** `premiumUpdates()` emits `false`
- **THEN** the bridge does not write to Firestore

### Requirement: Silent restore is gated to a fresh or rotated non-premium uid
Because uninstalling on Android rotates the anonymous uid, the system SHALL run exactly ONE silent `restore()` during bootstrap only when the current uid is not already premium (self-heal). The system MUST NOT call `restore()` on every launch. On iOS the silent restore MAY run too, but the explicit Restore button remains (see `paywall-purchase`).

#### Scenario: Fresh uid that never purchased
- **WHEN** bootstrap sees a uid whose `isPremium` is not `true` and there is no store entitlement
- **THEN** a single silent `restore()` runs, finds nothing, and premium stays `false`

#### Scenario: Rotated uid that previously purchased on the same store account
- **WHEN** an Android reinstall yields a new uid with `isPremium: false` but the store account still owns premium
- **THEN** the single silent `restore()` reactivates the entitlement, the bridge calls `markPremium()`, and the gate unlocks without user action

#### Scenario: Already-premium uid skips restore
- **WHEN** bootstrap sees a uid whose `isPremium` is already `true`
- **THEN** no silent `restore()` is called

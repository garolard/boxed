## ADDED Requirements

### Requirement: PaywallScreen is a full-screen modal route
The system SHALL provide a `PaywallScreen` that is pushed as a full-screen modal route (`Navigator.push` with a `MaterialPageRoute` that uses `FullscreenDialog: true`) when a scan is denied for quota reasons. The screen SHALL have a back button that dismisses the modal and returns the user to the scan tab.

#### Scenario: Denied scan pushes the paywall
- **WHEN** the user taps the Camera or Gallery button with `scansUsed >= 5` and `isPremium == false`
- **THEN** `ScanScreen` calls `Navigator.push` to `PaywallScreen` and returns from `_scan` without opening the picker
- **AND** the scan tab remains visible behind the modal

#### Scenario: User dismisses the paywall
- **WHEN** the user taps the close / back affordance on `PaywallScreen`
- **THEN** the modal is popped and the scan tab is fully interactive again
- **AND** no scan counter change has occurred

### Requirement: Paywall renders the required copy and structure
The `PaywallScreen` body SHALL contain: a title, a subtitle, a list of three feature bullets, a primary "Subscribe" button, and a secondary "Restore purchases" affordance. All copy SHALL come from `AppLocalizations` (no hard-coded strings).

#### Scenario: Paywall renders for English locale
- **WHEN** the device locale is `en` and the paywall is shown
- **THEN** the screen displays the values of `paywallTitle`, `paywallSubtitle`, `paywallFeature1`, `paywallFeature2`, `paywallFeature3`, `paywallCta`, and `paywallRestore`

#### Scenario: Paywall renders for Spanish locale
- **WHEN** the device locale is `es`
- **THEN** the screen displays the `es` translations of the same keys

#### Scenario: Paywall renders for French locale
- **WHEN** the device locale is `fr`
- **THEN** the screen displays the `fr` translations of the same keys

### Requirement: Subscribe button shows a "coming soon" SnackBar
Tapping the primary "Subscribe" button SHALL NOT initiate a purchase flow in this change. It SHALL display a SnackBar containing the `paywallComingSoon` string, then leave the user on the paywall. Real purchase integration is explicitly out of scope.

#### Scenario: User taps Subscribe
- **WHEN** the user taps the primary CTA on `PaywallScreen`
- **THEN** a SnackBar with the `paywallComingSoon` message is shown
- **AND** no StoreKit / Play Billing / RevenueCat call is made
- **AND** the user remains on the paywall

### Requirement: Restore purchases is a non-functional stub
Tapping the "Restore purchases" affordance SHALL NOT trigger a network call in this change. It MAY show the same "coming soon" SnackBar as Subscribe, or a dedicated "restore coming soon" message — but MUST NOT pretend to restore anything or alter `isPremium`.

#### Scenario: User taps Restore
- **WHEN** the user taps the Restore affordance
- **THEN** a SnackBar is shown and `users/{uid}.isPremium` is unchanged

### Requirement: IS_PREMIUM env flag bypasses the paywall
The system SHALL read the `IS_PREMIUM` key from `.env` at app startup. When `IS_PREMIUM` is the string `"true"` (case-insensitive), `ScanQuotaService` SHALL treat the user as premium for the lifetime of the app process: the quota is never read from Firestore, `recordScan()` is never called, and `ScanScreen` SHALL NOT push `PaywallScreen` even when `scansUsed >= 5`.

#### Scenario: Developer build with IS_PREMIUM=true
- **WHEN** `.env` contains `IS_PREMIUM=true` and the user has `scansUsed >= 5`
- **THEN** the user can scan without seeing the paywall
- **AND** no Firestore read or write occurs for the quota on that scan

#### Scenario: Production build without IS_PREMIUM
- **WHEN** `.env` does not contain `IS_PREMIUM`, or its value is not `"true"`
- **THEN** the env flag has no effect and the normal Firestore-backed quota applies

### Requirement: Env flag is dev-only, Firestore remains authoritative
The system SHALL treat `IS_PREMIUM` strictly as a developer escape hatch. When a real premium source is wired in (e.g. RevenueCat), the Firestore `isPremium` field SHALL be the authoritative source and the env flag SHALL remain only as a dev override. The implementation SHALL centralize the "is premium" check in a single helper so the swap is a one-line change.

#### Scenario: Future RevenueCat integration
- **WHEN** a future change adds a `revenueCatService` and writes `isPremium` to Firestore
- **THEN** the existing `IS_PREMIUM` env path is unchanged
- **AND** a production user is treated as premium iff `users/{uid}.isPremium == true`

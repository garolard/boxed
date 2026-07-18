## ADDED Requirements

### Requirement: ScanScreen gates scans on quota before opening the picker
At the top of `ScanScreen._scan` (`lib/screens/scan_screen.dart:37`), the system SHALL read the current `ScanQuota` and short-circuit before calling `_scanner.scan(...)`. If the user is not premium AND `scansUsed >= kFreeScanLimit`, the system SHALL `Navigator.push` `PaywallScreen` (full-screen modal) and return without opening the image picker.

#### Scenario: Quota exhausted, user taps Camera
- **WHEN** `scansUsed == 5` and `isPremium == false` and the user taps the Camera button
- **THEN** the paywall modal is shown
- **AND** the image picker is never opened
- **AND** `_scanning` is not set to `true`

#### Scenario: Quota exhausted, user taps Gallery
- **WHEN** `scansUsed == 5` and `isPremium == false` and the user taps the Gallery button
- **THEN** the same paywall modal is shown, regardless of `fromCamera`

#### Scenario: Quota available, user taps Camera
- **WHEN** `scansUsed < 5` and `isPremium == false`
- **THEN** the existing scan flow runs unchanged

#### Scenario: Premium user, user taps Camera
- **WHEN** `isPremium == true`
- **THEN** the scan runs even if `scansUsed >= 5` and the paywall is never shown

#### Scenario: Quota read failed
- **WHEN** the stream has emitted a quota with `readFailed == true`
- **THEN** the system treats the user as exhausted and pushes the paywall (fail-closed)

### Requirement: Successful scan records one use
When `_scanner.scan(...)` returns a `List<TitleCandidate>` with one or more entries, the system SHALL call `ScanQuotaService.recordScan()` exactly once. The call MUST happen after the candidate list is set on state and the success analytics event is logged, so the failure path can still roll back if the OpenAI call later turns out to be a paid error.

#### Scenario: Scan with at least one candidate
- **WHEN** `_recognize` returns a non-empty list
- **THEN** `recordScan()` is called once
- **AND** the candidate UI renders normally

#### Scenario: Scan with zero candidates
- **WHEN** `_recognize` returns an empty list
- **THEN** `recordScan()` is NOT called
- **AND** the existing "No readable text" UI is shown

#### Scenario: Picker cancelled
- **WHEN** `ImagePicker.pickImage` returns `null`
- **THEN** `recordScan()` is NOT called
- **AND** the scan UI returns to its idle state

### Requirement: _ScanIntro shows the free-scans-remaining pill
`_ScanIntro` (`lib/screens/scan_screen.dart:227`) SHALL render a pill that reads `freeScansRemaining(left, total)` where `left = kFreeScanLimit - scansUsed` (clamped at `0`) and `total = kFreeScanLimit`. The pill SHALL be hidden when the user is premium or when the quota read has failed (in the failed case the paywall is already the user-facing surface).

#### Scenario: Fresh user with full quota
- **WHEN** `scansUsed == 0` and `isPremium == false`
- **THEN** the pill displays "5 of 5 free scans left" (localized)

#### Scenario: User has used 2 scans
- **WHEN** `scansUsed == 2` and `isPremium == false`
- **THEN** the pill displays "3 of 5 free scans left" (localized)

#### Scenario: User has hit the limit
- **WHEN** `scansUsed == 5` and `isPremium == false`
- **THEN** the pill displays "0 of 5 free scans left" (localized)

#### Scenario: Premium user
- **WHEN** `isPremium == true`
- **THEN** the pill is not rendered

#### Scenario: Quota read failed
- **WHEN** the stream emitted a quota with `readFailed == true`
- **THEN** the pill is not rendered and the paywall is the only signal

### Requirement: Decrement on OpenAI failure flows back through the gate
If `recordScan()` is called optimistically and a later OpenAI error is detected (non-200 status or thrown exception from `_recognize`), the system SHALL call `ScanQuotaService.decrementScan()` to undo the increment. The existing `scanFailed` SnackBar / error card remains the user-facing signal.

#### Scenario: OpenAI returns 500 after the scan was recorded
- **WHEN** `recordScan()` succeeded and the response status is `>= 400`
- **THEN** `decrementScan()` is called
- **AND** the user sees the existing `scanFailed` message

#### Scenario: Network exception during the OpenAI call
- **WHEN** `http.Client.post` throws after `recordScan()` succeeded
- **THEN** `decrementScan()` is called in the catch block
- **AND** the existing error path surfaces the message

### Requirement: Analytics events are unchanged
The system MUST continue to call `AnalyticsService.logScanPerformed` exactly as today. The gate does not introduce a new analytics event in this change; the existing `source`, `candidateCount`, and `hasError` fields carry the same semantics. The `IS_PREMIUM` flag MAY be added as a property of a future event, but no new event is required by this change.

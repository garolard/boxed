## ADDED Requirements

### Requirement: Scan quota is persisted server-side under an anonymous uid
The system SHALL persist the user's scan counter in a Firestore document at path `users/{uid}` where `{uid}` is the Firebase Anonymous Auth uid of the current device. The document SHALL contain the fields `scansUsed` (int), `isPremium` (bool, default `false`), and `createdAt` (Firestore `ServerTimestamp`). The system SHALL create the document with `set({...}, merge: true)` if it does not exist when the app first reads the quota.

#### Scenario: First read on a fresh install
- **WHEN** the app starts on a device with no prior quota doc
- **THEN** the system upserts a new document at `users/{uid}` with `scansUsed: 0`, `isPremium: false`, and `createdAt` set to the server timestamp
- **AND** the in-memory `ScanQuota` reflects `scansUsed == 0` and `isPremium == false`

#### Scenario: Subsequent read after scans
- **WHEN** the app starts on a device whose doc already has `scansUsed: 2`
- **THEN** the in-memory `ScanQuota` reflects `scansUsed == 2` and the doc is left unchanged

### Requirement: ScanQuota is exposed as a live stream
The system SHALL expose the current quota as a `StreamProvider<ScanQuota>` in Riverpod. The stream SHALL emit a new `ScanQuota` every time the underlying Firestore document changes, so the UI reacts without manual refresh.

#### Scenario: UI subscribes and receives initial value
- **WHEN** a widget reads the provider and the doc exists with `scansUsed: 3`
- **THEN** the widget receives a `ScanQuota` with `scansUsed == 3` on first build

#### Scenario: Doc update propagates without a manual refresh
- **WHEN** another tab on the same device decrements `scansUsed` to `2`
- **THEN** every subscriber receives a new `ScanQuota` with `scansUsed == 2` within one stream tick

### Requirement: Quota reads fail closed
If reading the quota doc throws (no network, Firestore unavailable, permission denied, timeout), the system SHALL treat the user as **exhausted and not premium** — the read is a hard fail and MUST NOT be bypassed. No new scans are allowed in that state.

#### Scenario: No network on quota read
- **WHEN** `users/{uid}` cannot be fetched because the device is offline
- **THEN** the stream emits a `ScanQuota` with `scansUsed >= freeLimit`, `isPremium == false`, and `readFailed == true`
- **AND** any caller asking "may this user scan?" receives `false`

#### Scenario: Firestore returns a permission error
- **WHEN** the read fails with `permission-denied` or any other Firestore error
- **THEN** the system behaves identically to the offline case — denied, not bypassed

### Requirement: Successful scan increments the counter
The system SHALL increment `scansUsed` by exactly `1` only after `CoverScanService._recognize` returns a non-empty `List<TitleCandidate>`. The increment MUST use an atomic Firestore operation (`FieldValue.increment(1)`) so concurrent devices cannot lose updates.

#### Scenario: Scan returns at least one candidate
- **WHEN** `_recognize` returns `[TitleCandidate(...), ...]` with one or more entries
- **THEN** the system calls `recordScan()` and the doc's `scansUsed` increases by `1`

#### Scenario: Picker cancelled by the user
- **WHEN** `ImagePicker.pickImage` returns `null` (user dismissed the picker)
- **THEN** the system does NOT call `recordScan()` and `scansUsed` is unchanged

#### Scenario: OpenAI returns 200 with zero candidates
- **WHEN** `_recognize` returns an empty list (parser found nothing)
- **THEN** the system does NOT call `recordScan()` and `scansUsed` is unchanged

### Requirement: OpenAI error decrements the counter
If `recordScan()` was called optimistically and the OpenAI call subsequently returns a non-200 status or throws, the system SHALL decrement `scansUsed` by `1` so a paid but failed call never counts against the user. The decrement MUST also be atomic (`FieldValue.increment(-1)`).

#### Scenario: OpenAI 5xx after a scan is recorded
- **WHEN** the user has `scansUsed: 2` and a scan that incremented to `3` then fails server-side
- **THEN** the system decrements `scansUsed` back to `2` and the user keeps that free scan

#### Scenario: Network timeout on OpenAI call
- **WHEN** `http.Client.post` throws a `TimeoutException` after `recordScan()` was called
- **THEN** the system decrements `scansUsed` by `1` and the failure surfaces as the existing `scanFailed` SnackBar

### Requirement: Premium bypass is honored
The system SHALL treat a user as exempt from the quota when `users/{uid}.isPremium == true`. While premium, the system MUST NOT call `recordScan()`, MUST NOT decrement on error, and MUST emit `isPremium: true` in the stream so the UI can hide the "X of 5 free scans left" pill.

#### Scenario: Premium user attempts a scan
- **WHEN** the doc's `isPremium` is `true`
- **THEN** the scan is allowed regardless of `scansUsed`
- **AND** the counter is not changed by the attempt

### Requirement: Free limit and counter bounds are explicit
The free limit SHALL be `5` scans per device. The system SHALL expose this as a named constant (e.g., `kFreeScanLimit`) used by both the service and the UI pill. `scansUsed` MUST NOT be allowed to go below `0`; the decrement-on-error path MUST clamp at `0` if the atomic op would otherwise produce a negative value.

#### Scenario: Decrement clamped at zero
- **WHEN** `scansUsed == 0` and a stale decrement is requested
- **THEN** the doc remains at `scansUsed == 0` and no error is raised

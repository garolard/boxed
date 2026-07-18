## ADDED Requirements

### Requirement: test/services/scan_quota_service_test.dart exists and uses a fake Firestore
The system SHALL add a test file at `test/services/scan_quota_service_test.dart` that exercises `ScanQuotaService` against an in-memory fake of the Firestore API. The fake SHALL be substituted for `FirebaseFirestore` via constructor injection or Riverpod override — the test MUST NOT initialize the real `firebase_core` plugin or hit the network. The fake SHALL expose at minimum: `get`, `set` (with merge), `update` (with `FieldValue.increment`), and a `snapshots()` stream for the `users/{uid}` doc.

#### Scenario: Test file is present
- **WHEN** the change is applied
- **THEN** `test/services/scan_quota_service_test.dart` exists
- **AND** `flutter test test/services/scan_quota_service_test.dart` runs without network access

### Requirement: Increment test
The test file SHALL contain a test that, starting from a doc with `scansUsed: 0`, calls `recordScan()` exactly once and asserts the doc now reads `scansUsed: 1`. The test SHALL also assert the `StreamProvider<ScanQuota>` emitted `scansUsed: 1` after the write.

#### Scenario: recordScan increments by 1
- **WHEN** the doc starts at `scansUsed: 0`
- **THEN** after one `recordScan()` call the doc reads `scansUsed: 1` and the stream emits the new value

### Requirement: Fail-closed test
The test file SHALL contain a test that primes the fake to throw on `get()` and asserts the resulting `ScanQuota` has `readFailed == true` and the "may this user scan?" check returns `false`. The test SHALL also assert that `recordScan()` is NOT called in this state.

#### Scenario: Read throws
- **WHEN** the fake's `get()` throws `FirebaseException` (any code)
- **THEN** the stream emits a quota with `readFailed == true`
- **AND** the service answers "may scan" with `false`
- **AND** no `set` or `update` call has been issued

### Requirement: Premium bypass test
The test file SHALL contain a test that primes the doc with `isPremium: true` and asserts that `recordScan()` is a no-op and that the "may scan" check returns `true` regardless of `scansUsed`.

#### Scenario: Premium user attempts to scan at limit
- **WHEN** the doc has `isPremium: true` and `scansUsed: 5`
- **THEN** `mayScan` is `true` and `recordScan()` does not modify the doc

### Requirement: No-increment-on-failure test
The test file SHALL contain a test that simulates a `CoverScanService.scan` flow returning an empty list (zero candidates) and asserts `recordScan()` is NOT called and `scansUsed` is unchanged. A second case SHALL simulate `ImagePicker.pickImage` returning `null` and assert the same. A third case SHALL simulate `_recognize` throwing (OpenAI 5xx) and assert that `recordScan()` was NOT called before the throw.

#### Scenario: Zero candidates
- **WHEN** the simulated scan returns `[]`
- **THEN** `scansUsed` is unchanged and no `update` call is made

#### Scenario: Picker cancelled
- **WHEN** the simulated scan returns before `_recognize` (picker returned `null`)
- **THEN** `scansUsed` is unchanged and no `update` call is made

#### Scenario: OpenAI error before any recordScan
- **WHEN** the simulated `_recognize` throws before any counter write
- **THEN** `scansUsed` is unchanged

### Requirement: Decrement-on-OpenAI-error test
The test file SHALL contain a test that:
1. Sets the doc to `scansUsed: 2`.
2. Calls `recordScan()` so the doc becomes `scansUsed: 3`.
3. Simulates the OpenAI call failing with a non-200 status (or a thrown exception) AFTER the increment.
4. Calls `decrementScan()`.
5. Asserts the doc now reads `scansUsed: 2` and the stream emitted that value.

#### Scenario: Decrement restores prior count
- **WHEN** `scansUsed: 2` → `recordScan()` → failure → `decrementScan()`
- **THEN** the doc reads `scansUsed: 2` and the stream emits `2`

### Requirement: Decrement clamps at zero
The test file SHALL contain a test that calls `decrementScan()` on a doc at `scansUsed: 0` and asserts the doc remains at `scansUsed: 0` and no exception is raised.

#### Scenario: Decrement at zero is a no-op
- **WHEN** `scansUsed: 0` and `decrementScan()` is called
- **THEN** the doc reads `scansUsed: 0` and no error is thrown

### Requirement: Test isolation
Each test SHALL create its own fake Firestore and `ScanQuotaService` instance. Tests MUST NOT share state between cases (no static singletons, no module-level `late final` Firestore in the test file). The fake SHALL be re-creatable per test in O(1).

#### Scenario: Tests run in any order
- **WHEN** the suite is run with `--reporter expanded` and tests are reordered
- **THEN** every test passes regardless of execution order

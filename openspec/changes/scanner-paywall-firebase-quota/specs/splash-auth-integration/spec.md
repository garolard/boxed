## ADDED Requirements

### Requirement: Anonymous sign-in runs during app bootstrap
The system SHALL call `FirebaseAuth.instance.signInAnonymously()` inside `_AppBootstrap._bootstrap` (`lib/main.dart:106`). The auth state SHALL be ready before any scan attempt — the `ScanQuotaService` reads the uid of the currently signed-in anonymous user.

#### Scenario: Cold start, network available
- **WHEN** the user opens the app for the first time and has connectivity
- **THEN** `_bootstrap` triggers `signInAnonymously()` in parallel with the existing 1500ms minimum
- **AND** `FirebaseAuth.instance.currentUser` is non-null by the time the home screen builds

#### Scenario: Cold start, slow or no network
- **WHEN** `signInAnonymously()` is slow or fails
- **THEN** the splash remains on screen (the existing `_LoadingPulse` at `splash_screen.dart:243` already covers this) until the auth call resolves or fails
- **AND** the home screen does not build before auth has resolved

### Requirement: Quota doc is upserted on first sign-in
On the first successful sign-in for a given install, the system SHALL upsert the quota doc at `users/{uid}` with `scansUsed: 0`, `isPremium: false`, and `createdAt` set to the server timestamp, using `set({...}, merge: true)` so re-running the upsert is safe.

#### Scenario: First-ever sign-in on a device
- **WHEN** the anonymous user has no existing `users/{uid}` doc
- **THEN** the system writes the initial doc with the defaults above
- **AND** no exception is raised if the doc was created concurrently by another tab

#### Scenario: Re-bootstrap on an existing user
- **WHEN** the anonymous user already has a `users/{uid}` doc from a prior session
- **THEN** the upsert with `merge: true` is a no-op for existing fields and does not reset `scansUsed`

### Requirement: Bootstrap order is unchanged from the user perspective
The existing 1500ms minimum splash duration MUST be preserved. The auth call MUST run concurrently with that timer (or behind it) and MUST NOT extend the visible splash. The `_AppBootstrap` build method (`main.dart:114`) is unchanged — it still crossfades from `SplashScreen` to `HomeScreen` based on `_ready`.

#### Scenario: Auth resolves before 1500ms
- **WHEN** `signInAnonymously()` completes in 400ms
- **THEN** the home screen still appears no earlier than the 1500ms mark

#### Scenario: Auth resolves after 1500ms
- **WHEN** `signInAnonymously()` takes 3000ms
- **THEN** the splash stays on screen until auth resolves, then the home screen crossfades in
- **AND** `scan_screen.dart` is never reached with a null `currentUser`

### Requirement: No sign-in UI is introduced
The system MUST NOT present any sign-in screen, consent dialog, or "Continue as guest" button to the user. The anonymous sign-in is invisible. The `currentUser` is read by `ScanQuotaService`; it is never displayed.

#### Scenario: First-time user opens the app
- **WHEN** the user launches the app for the first time
- **THEN** the only UI shown before home is `SplashScreen`; no auth dialog or button is rendered

### Requirement: Android-uninstall quota reset is documented
The system SHALL carry a code comment near the anonymous sign-in call explaining that on Android, uninstalling the app rotates SSAID and the next install gets a fresh anonymous uid and a fresh counter, so the quota can be reset. iOS is unaffected because the Firebase Anonymous Auth uid is stored in the iOS Keychain, which survives uninstall. This is the accepted tradeoff for the "no login required" stance.

#### Scenario: Developer reads the code near the sign-in call
- **WHEN** a developer opens the file containing the anonymous sign-in
- **THEN** a comment is present that explicitly states: (a) Android uninstall resets the quota, (b) iOS does not, and (c) this is the documented no-login tradeoff

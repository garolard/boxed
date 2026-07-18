## Why

Every tap on the Scan tab triggers a paid OpenAI call (`gpt-5-nano` vision in `lib/services/cover_scan_service.dart:25`). Today nothing stops a user from running the bill up indefinitely, and nothing exists to convert that traffic into revenue later. The app must stay "no login required", so the gate needs to work without a sign-in screen: a server-side counter keyed by an invisible anonymous uid, with an `IS_PREMIUM=true` developer escape hatch for local builds.

## What Changes

- Add `firebase_auth` and `cloud_firestore` to `pubspec.yaml`; the project is already wired for `firebase_core` + `firebase_options.dart`, so no new platform config is required.
- Sign in anonymously inside `_AppBootstrap._bootstrap` (`lib/main.dart:106`) in parallel with the existing 1500ms minimum; the existing `_LoadingPulse` already covers the splash, so no UI change there.
- Introduce `ScanQuotaService` backed by a Firestore doc at `users/{uid}` with `{scansUsed, isPremium, createdAt}`, exposed as a `StreamProvider<ScanQuota>` so the UI reacts live. Increment is gated on `CoverScanService._recognize` returning ≥1 candidate; failures and picker cancellations do not count.
- Add a full-screen `PaywallScreen` (feature list, "Subscribe" → "coming soon" SnackBar, "Restore purchases" stub). `IS_PREMIUM=true` in `.env` short-circuits the check.
- In `ScanScreen._scan` (`lib/screens/scan_screen.dart:37`), check quota before opening the picker; when exhausted and not premium, push `PaywallScreen` and return. After a successful scan, call `recordScan()`. Show a "X of 5 free scans left" pill in `_ScanIntro` (`lib/screens/scan_screen.dart:227`).
- Add new l10n strings in `en`, `es`, `fr` (paywall copy + free-scans-remaining pill).
- Add `test/services/scan_quota_service_test.dart` with a fake Firestore covering increment, fail-closed reads, premium bypass, no-increment-on-failure, and decrement on OpenAI errors.

## Capabilities

### New Capabilities

- `scan-quota`: Server-side scan counter (`users/{uid}` doc) with stream-based provider, fail-closed reads, premium bypass, increment only on successful OpenAI response, decrement on parser failure. This is the data layer.
- `splash-auth-integration`: `signInAnonymously()` plus initial `set({...}, merge: true)` run inside `_AppBootstrap._bootstrap` alongside the existing 1500ms minimum. No splash UI change.
- `paywall-screen`: Full-screen modal with feature list, Subscribe button (coming-soon SnackBar), Restore purchases stub. `IS_PREMIUM=true` short-circuits the gate.
- `scan-gating`: Pre-picker quota check in `ScanScreen._scan`; route to `PaywallScreen` when exhausted and not premium; `recordScan()` after a successful scan; "X of 5 free scans left" pill in `_ScanIntro`.
- `l10n`: New ARB strings (`paywallTitle`, `paywallSubtitle`, `paywallFeature1/2/3`, `paywallCta`, `paywallRestore`, `freeScansRemaining(int left, int total)`, `paywallComingSoon`) added to `en`, `es`, `fr`.
- `tests`: `test/services/scan_quota_service_test.dart` covering increment, fail-closed, premium bypass, no-increment-on-failure, decrement on OpenAI error — using a fake Firestore, not the real client.

### Modified Capabilities

_None._ `openspec/specs/` is empty, so this change introduces only new capabilities; no existing requirement set is being edited.

## Impact

- **Dependencies (new):** `firebase_auth`, `cloud_firestore`. `firebase_core` and `firebase_options.dart` are already in place; no new Firebase project config.
- **Files touched:**
  - `pubspec.yaml` — add two deps.
  - `lib/main.dart` — extend `_AppBootstrap._bootstrap` (`main.dart:106`).
  - `lib/services/scan_quota_service.dart` — new service.
  - `lib/providers/services.dart` (or a new `lib/providers/scan_quota_provider.dart`) — `StreamProvider<ScanQuota>` and a `scanQuotaServiceProvider`.
  - `lib/screens/paywall_screen.dart` — new screen.
  - `lib/screens/scan_screen.dart` — gate `_scan` (`scan_screen.dart:37`), add pill in `_ScanIntro` (`scan_screen.dart:227`), push `PaywallScreen`.
  - `lib/services/cover_scan_service.dart` — no behavior change; gate sits in `ScanScreen` and only calls `recordScan()` after `_recognize` returns ≥1 candidate.
  - `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`, `lib/l10n/app_fr.arb` — new keys.
  - `.env` — add optional `IS_PREMIUM=true` (defaults to unset/absent).
  - `test/services/scan_quota_service_test.dart` — new file.
- **Cost:** Counter doc is 1 read + 1 write per scan; anonymous auth is 1 sign-in at app start. Negligible against the OpenAI spend this prevents.
- **Security / privacy:** Anonymous uid only — no PII. Firestore rules must restrict each user to their own doc (`request.auth.uid == userId`) and forbid clients from flipping `isPremium`. Out of scope for this change but flagged in `tests` and called out as a design-time decision.
- **Known limitation (accepted):** On Android, uninstalling the app rotates SSAID and the new install gets a fresh anonymous uid and a fresh counter — the quota can be reset. iOS is bulletproof (Keychain survives uninstall). This is the documented tradeoff for "no login required" and will live in a code comment near the anonymous-sign-in call.

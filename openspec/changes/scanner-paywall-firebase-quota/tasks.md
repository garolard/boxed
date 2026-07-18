# Tasks: scanner-paywall-firebase-quota

Steps are ordered by dependency. Each `## Step N` is one commit boundary and MUST leave the repository compiling + typechecking + building on its own.

## Step 1: Dependencies and l10n strings (additive only)

**Files Affected**: `pubspec.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`, `lib/l10n/app_fr.arb`

**What Will Be Done**: Add `firebase_auth` and `cloud_firestore` under `dependencies:` in `pubspec.yaml`, pinning to versions compatible with the existing `firebase_core: ^3.13.0` (use the matching major line from FlutterFire). Run `flutter pub get` mentally as the build gate. Add eight new ARB keys to each of `app_en.arb`, `app_es.arb`, `app_fr.arb`: `paywallTitle`, `paywallSubtitle`, `paywallFeature1`, `paywallFeature2`, `paywallFeature3`, `paywallCta`, `paywallRestore`, `paywallComingSoon`, and `freeScansRemaining` (taking `int left, int total`). The `@freeScansRemaining` metadata block goes ONLY in `app_en.arb` (template locale), mirroring the existing `@candidatesFound` / `@sharedDetailCount` placeholder pattern; `app_es.arb` and `app_fr.arb` carry only the translated string values, no `@key` metadata blocks, exactly as today. Verify by `flutter gen-l10n` (succeeds) and `flutter build apk --debug` or `flutter analyze` passing. No source code references the new keys yet — unused ARB keys are not a defect, so this snapshot builds. Reference: `openspec/changes/scanner-paywall-firebase-quota/specs/l10n/spec.md`.

**Testing Strategy**: `flutter gen-l10n` produces `AppLocalizations` with all eight keys across `en`/`es`/`fr`; `flutter analyze` clean.

## Step 2: ScanQuota data layer (model, service, providers) — not yet wired

**Files Affected**: `lib/services/scan_quota_service.dart` (new), `lib/providers/scan_quota_provider.dart` (new), `lib/providers/services.dart`

**What Will Be Done**: Create `lib/services/scan_quota_service.dart` exporting `const int kFreeScanLimit = 5;`, a `ScanQuota` immutable model with `scansUsed` (int), `isPremium` (bool), `readFailed` (bool, default false) and a `toString`/equality; and the `ScanQuotaService` class, constructed with `ScanQuotaService({required FirebaseFirestore firestore, required FirebaseAuth auth, required bool isPremiumOverride})` (mirroring `CoverScanService`'s constructor-injection pattern). Build `ScanQuotaService`'s contract per `openspec/changes/scanner-paywall-firebase-quota/specs/scan-quota/spec.md`: `Stream<ScanQuota> quotaStream()` (wraps `snapshots()` on `users/{uid}`, upserts on first emit via `set({scansUsed: 0, isPremium: false, createdAt: FieldValue.serverTimestamp()}, merge: true)`, catches read errors → emits `ScanQuota(scansUsed: kFreeScanLimit, isPremium: false, readFailed: true)`), `Future<bool> mayScan()` (true iff `!readFailed && (isPremium || scansUsed < kFreeScanLimit)`), `Future<void> recordScan()` (no-op if `isPremium`; else `update({scansUsed: FieldValue.increment(1)})`), `Future<void> decrementScan()` (no-op if `isPremium`; else `runTransaction` reading `scansUsed` and writing `max(0, scansUsed - 1)`). Centralize "is premium" in a single private getter `bool get _effectivePremium => isPremiumOverride || _quota?.isPremium == true`. Add the `scanQuotaServiceProvider` (`Provider<ScanQuotaService>((ref) => throw UnimplementedError())`, peer to `analyticsServiceProvider`'s override-required pattern) to `lib/providers/services.dart`. Create `lib/providers/scan_quota_provider.dart` declaring `scanQuotaProvider = StreamProvider<ScanQuota>((ref) => ref.read(scanQuotaServiceProvider).quotaStream()),` peer to the stateful notifiers in `collection_provider.dart` / `shared_collections_provider.dart`. Import `scan_quota_service.dart` from both provider files. No code yet calls these providers or instantiates the service, so the snapshot compiles and typechecks as additive-only code.

**Testing Strategy**: Plain `flutter analyze`; no test in this step (test lands in Step 6). Confirm `ProviderScope` default-throw behavior inherited from `analyticsServiceProvider` idiom.

## Step 3: Splash bootstrap wires anonymous auth + quota doc upsert

**Files Affected**: `lib/main.dart`

**What Will Be Done**: Inside `_AppBootstrap._bootstrap` (`lib/main.dart:106`), replace the current `await Future.delayed(_minSplash)` with `await Future.wait([FirebaseAuth.instance.signInAnonymously(), Future.delayed(_minSplash)])`. Immediately after, read the now-non-null `FirebaseAuth.instance.currentUser!.uid` and call `FirebaseFirestore.instance.collection('users').doc(uid).set({'scansUsed': 0, 'isPremium': false, 'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true))`. Instantiate `ScanQuotaService` with the resolved `isPremiumOverride` (read once from `dotenv.env['IS_PREMIUM']`, trimmed, case-insensitive compared to `"true"`, consistent with `cover_scan_service.dart`'s `dotenv.env['OPENAI_API_KEY'] ?? ''` style but resolved at startup) and a corresponding `scanQuotaServiceProvider.overrideWithValue(scanQuotaService)` entry in the `ProviderScope(overrides: [...])` list at `lib/main.dart:46–51` alongside the existing `analyticsServiceProvider.overrideWithValue(...)`. Add a multi-line code comment near the `signInAnonymously()` call stating: (a) Android uninstall rotates SSAID → new anonymous uid → fresh counter, (b) iOS unaffected because the Firebase Anonymous Auth uid is stored in the Keychain, (c) this is the documented no-login-required tradeoff — see `openspec/changes/scanner-paywall-firebase-quota/specs/splash-auth-integration/spec.md`. The `_AppBootstrap.build` crossfade stays purely driven by `_ready`; no UI change. After `_ready` flips true, `FirebaseAuth.instance.currentUser` is guaranteed non-null before any scan attempt.

**Testing Strategy**: `flutter analyze`; manual cold-start verification that the splash still shows for at least 1500ms and that the home screen never builds before auth resolves. No automated test added for this step (the UI orchestration is exercised via the existing app behavior).

## Step 4: PaywallScreen widget (definition only, not yet pushed)

**Files Affected**: `lib/screens/paywall_screen.dart` (new)

**What Will Be Done**: Create `lib/screens/paywall_screen.dart` defining a `ConsumerWidget` `PaywallScreen` that renders via `Scaffold` with an optional back arrow (it is pushed with `MaterialPageRoute(fullscreenDialog: true)` in Step 5). Body contains, in order: `Text(context.l10n.paywallTitle)`, `Text(context.l10n.paywallSubtitle)`, a `Column` of three `Row`s each with a checkmark icon and `Text(context.l10n.paywallFeature1/2/3)`, an elevated `TextButton`/`FilledButton` reading `context.l10n.paywallCta` whose `onPressed` shows a `SnackBar(content: Text(context.l10n.paywallComingSoon))` and stays on-screen, and a `TextButton` reading `context.l10n.paywallRestore` whose `onPressed` shows the same `paywallComingSoon` `SnackBar`. All text comes from `AppLocalizations` via the existing `context.l10n` extension from `lib/l10n/l10n.dart` — no hard-coded strings. No StoreKit/Play Billing/RevenueCat import or call. No analytics events. Nothing pushes this route yet, so the widget is unreferenced-but-buildable (matches Flutter's tolerance for unused widgets). Reference: `openspec/changes/scanner-paywall-firebase-quota/specs/paywall-screen/spec.md`.

**Testing Strategy**: `flutter analyze`; widget existence verified by `flutter build` of an app shell that imports the file. (No widget test in this change — spec scope is the data layer.)

## Step 5: ScanScreen gate + record/decrement + free-scans-remaining pill

**Files Affected**: `lib/screens/scan_screen.dart`

**What Will Be Done**: In `_ScanScreenState._scan` (`lib/screens/scan_screen.dart:37`), before any call to `_scanner.scan(...))`, read the current `ScanQuota` via `ref.read(scanQuotaProvider)`; if `readFailed || (!isPremium && scansUsed >= kFreeScanLimit)`, `Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen()))` and `return` without setting `_scanning = true` and without opening the picker (satisfying the spec's "the image picker is never opened" and "`_scanning` is not set to `true`"). On the existing success branch (after `_recognize` returns a non-empty `List<TitleCandidate>` and the candidate UI is on state and `analyticsService.logScanPerformed(...)` has fired — preserving the existing ordering), call `ref.read(scanQuotaServiceProvider).recordScan()` exactly once for the non-empty case. In the existing `catch` block (the path that surfaces `scanFailed` today), if `recordScan()` had been called earlier in this `_scan` invocation (track via a local `bool recorded`), call `ref.read(scanQuotaServiceProvider).decrementScan()` before the existing error UI surfaces. The zero-candidate and picker-cancel branches do NOT call `recordScan()` (no increment). Update `_ScanIntro` (`lib/screens/scan_screen.dart:227`) to render a pill widget reading `context.l10n.freeScansRemaining(left: (kFreeScanLimit - quota.scansUsed).clamp(0, kFreeScanLimit), total: kFreeScanLimit)` — only when `!quota.isPremium && !quota.readFailed`; hide the pill entirely when premium or on a failed read (the paywall is the user-facing surface in the failed case). `_ScanIntro` becomes a `ConsumerWidget` (or uses `ref.watch` via the parent `ConsumerStatefulWidget`) so the pill updates live as the stream emits. Import `scan_quota_provider.dart`, `scan_quota_service.dart`, `paywall_screen.dart`. The existing `analyticsServiceProvider` consumption is unchanged. Reference: `openspec/changes/scanner-paywall-firebase-quota/specs/scan-gating/spec.md` and `specs/scan-quota/spec.md`.

**Testing Strategy**: `flutter analyze`; manual flow on a device with `IS_PREMIUM` unset (confirm paywall at 5/5, decrement visible on an OpenAI 500, no increment on cancel/empty). Automated coverage of the gate logic comes via the `ScanQuotaService` unit tests in Step 6 (the data contract), not a widget test in this change.

## Step 6: ScanQuotaService unit tests with a hand-rolled fake Firestore

**Files Affected**: `test/services/scan_quota_service_test.dart` (new)

**What Will Be Done**: Create `test/services/scan_quota_service_test.dart` (creating the `test/services/` directory). Define a private `FakeFirestore` class inside the test file (no `mocktail`, no `fake_cloud_firestore`) that exposes, for a single configurable doc path `users/{uid}`: an in-memory `Map<String, Map<String, dynamic>>` store, a `get()` method that either returns the stored data or throws `FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')` when a `shouldThrowOnGet` flag is set, a `set(data, SetOptions)` that honors `merge: true`, an `update(deltas)` method that interprets `FieldValue.increment(n)` by adding `n` to the current int and **clamps via the transaction path below**, a `snapshots()` `Stream` whose controller re-emits current doc state on each mutation, and a `runTransaction(handler)` that invokes `handler` against the live in-memory map and commits the returned writes (this is the surface the decrement-clamp test exercises). Each test constructs a **fresh** `FakeFirestore` and a fresh `ScanQuotaService(firestore: fake, auth: fakeAuthAlwaysSignedIn, isPremiumOverride: false)` in its own body — NO shared `setUp` state, NO module-level `late final` — per `openspec/changes/scanner-paywall-firebase-quota/specs/tests/spec.md` "Test isolation". Implement the following test groups: (a) increment — start `scansUsed: 0`, `recordScan()` once, assert doc reads `scansUsed: 1` and the stream emits `1`. (b) fail-closed — set `shouldThrowOnGet = true`, read stream, assert `ScanQuota.readFailed == true`, `mayScan() == false`, and `recordScan()` issues no `set`/`update`. (c) premium bypass — set `isPremium: true` and `scansUsed: 5`, assert `mayScan() == true` and `recordScan()` doesn't touch the doc. (d) no-increment-on-failure — three sub-cases: zero candidates (simulate `scan` returning `[]`), picker-cancelled (simulate `scan` returning before `_recognize` ran), and `_recognize` throwing; assert no `update` issued. (e) decrement-on-OpenAI-error — `scansUsed: 2` → `recordScan()` → `3` → simulate non-200 → `decrementScan()` → assert doc reads `2` and stream emits `2`. (f) decrement-clamp-at-zero — `scansUsed: 0`, `decrementScan()`, assert doc remains at `0` and no exception. Reference: `openspec/changes/scanner-paywall-firebase-quota/specs/tests/spec.md`. The fake avoids any call into the real `firebase_core` plugin so the suite runs offline.

**Testing Strategy**: `flutter test test/services/scan_quota_service_test.dart` passes offline; `flutter test --reporter expanded` passes with the test cases reordered (no inter-test state).

## Required Documentation

### Local files
- openspec/changes/scanner-paywall-firebase-quota/proposal.md
- openspec/changes/scanner-paywall-firebase-quota/specs/scan-quota/spec.md
- openspec/changes/scanner-paywall-firebase-quota/specs/splash-auth-integration/spec.md
- openspec/changes/scanner-paywall-firebase-quota/specs/paywall-screen/spec.md
- openspec/changes/scanner-paywall-firebase-quota/specs/scan-gating/spec.md
- openspec/changes/scanner-paywall-firebase-quota/specs/l10n/spec.md
- openspec/changes/scanner-paywall-firebase-quota/specs/tests/spec.md
- pubspec.yaml
- lib/main.dart
- lib/services/cover_scan_service.dart
- lib/providers/services.dart
- lib/providers/collection_provider.dart
- lib/providers/shared_collections_provider.dart
- lib/screens/scan_screen.dart
- lib/screens/splash_screen.dart
- lib/l10n/app_en.arb
- lib/l10n/app_es.arb
- lib/l10n/app_fr.arb
- lib/l10n/l10n.dart
- lib/firebase_options.dart
- lib/services/analytics_service.dart
- .env
- test/qr_payload_codec_test.dart
- test/game_model_test.dart

### Spec files
- openspec/changes/scanner-paywall-firebase-quota/specs/scan-quota/spec.md
- openspec/changes/scanner-paywall-firebase-quota/specs/splash-auth-integration/spec.md
- openspec/changes/scanner-paywall-firebase-quota/specs/paywall-screen/spec.md
- openspec/changes/scanner-paywall-firebase-quota/specs/scan-gating/spec.md
- openspec/changes/scanner-paywall-firebase-quota/specs/l10n/spec.md
- openspec/changes/scanner-paywall-firebase-quota/specs/tests/spec.md

### External URLs
- None

## Implementation Context

**Stack**: Dart 3 / Flutter 3.x (Riverpod 3.x manual providers, no codegen), FlutterFire `firebase_core: ^3.13.0` + FlutterFire-generated `firebase_options.dart` (`projectId: boxed-bc996`), `flutter_dotenv` for `.env` access, `flutter_test` for tests. New deps this change: `firebase_auth`, `cloud_firestore` (matching majors from FlutterFire).

**Conventions**
- **Providers are manual Riverpod** — `Provider<T>((ref) => ...)`, `NotifierProvider<N, State>(N.new)`, `StreamProvider<T>`. NO `@riverpod` annotation, NO `riverpod_generator`, NO build_runner. Stateful providers live in their own `lib/providers/<thing>_provider.dart`; stateless service-object providers live together in `lib/providers/services.dart`.
- **Services are constructor-injected** — `CoverScanService({ImagePicker? picker, http.Client? client})`, `AnalyticsService._(...)` with optional analytics/crashlytics params. Tests fake by direct construction, not by container override (verify by `test/qr_payload_codec_test.dart`, `test/game_model_test.dart`).
- **`ProviderScope` is in `lib/main.dart:46–51`** and already uses `overrides: [analyticsServiceProvider.overrideWithValue(analytics)]`. New service providers follow the same override-with-real-instance-in-prod / override-with-fake-in-test pattern.
- **ARB placeholder metadata lives only in the template locale (`app_en.arb`)** as a sibling `@key` JSON block (`"@candidatesFound": {"placeholders": {"count": {"type": "int"}}}`). `app_es.arb` / `app_fr.arb` carry string values only, no `@key` metadata blocks. `flutter gen-l10n` derives metadata from `en`.
- **`.env` is loaded once in `main()` via `dotenv.load(fileName: '.env')`** and read at point-of-use with `dotenv.env['KEY'] ?? ''` (see `cover_scan_service.dart`). `.env` is declared under `flutter: assets:` in `pubspec.yaml`.
- **`context.l10n`** (`lib/l10n/l10n.dart`) is the universal `AppLocalizations` access extension; new copy MUST come through it (no hard-coded strings).

**Avoid**
- Do NOT reach for `mocktail`, `mockito`, or `fake_cloud_firestore` for the quota service test — the existing `test/` suite is plain `flutter_test` + direct construction, and `fake_cloud_firestore` would initialize the real `firebase_core` plugin (forbidden by the spec).
- Do NOT introduce a sign-in screen, consent dialog, "Continue as guest" button, or any pre-home UI other than `SplashScreen`.
- Do NOT mark progress with `- [ ]` / `- [x]` in this file — this is a planning scaffold. Execution progress is tracked in `implementation.md`.
- Do NOT add a new analytics event for the paywall or the gate — `logScanPerformed`'s existing fields (`source`, `candidateCount`, `hasError`, `errorMessage`) stay as the only scan-event surface, per `specs/scan-gating/spec.md`.
- Do NOT call `dotenv.env['IS_PREMIUM']` per-scan — resolve once in `main()` and inject as a constructor bool so the Firestore read path stays inactive on dev-premium builds.
- Do NOT deploy Firestore security rules in code — they are a deploy-time prerequisite, not a file in this repo's `lib/` tree.
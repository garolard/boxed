# Design: scanner-paywall-firebase-quota

## Context

The Scan tab triggers a paid OpenAI vision call (`gpt-5-nano` in `lib/services/cover_scan_service.dart:25`) on every tap. The app today has no gate and no path to monetization, so a determined user can run the bill up indefinitely. The app also commits to "no login required", so the counter must work without a sign-in UI.

The project is already wired for Firebase:
- `firebase_core: ^3.13.0` + FlutterFire-generated `lib/firebase_options.dart` (`projectId: boxed-bc996`), initialized in `main()`.
- `firebase_crashlytics`, `firebase_analytics` already in pubspec and used.
- `flutter_riverpod: ^3.3.2` with **manual** providers (`Provider`, `NotifierProvider`, `StreamProvider`) — no codegen, no `@riverpod` annotations. `ProviderScope` in `lib/main.dart:46–51` already overrides `analyticsServiceProvider`, establishing the override idiom tests will reuse.
- `.env` is loaded once in `main()` via `flutter_dotenv`; read at point-of-use with `dotenv.env['KEY'] ?? ''` (see `cover_scan_service.dart` reading `OPENAI_API_KEY`).
- Existing `test/` suite is pure `flutter_test` with **plain `test()` blocks, constructor injection, no mocktail/mockito**.

Constraints:
- No sign-in UI of any kind — anonymous uid only, invisible to the user.
- Splash visibility already has a 1500ms minimum (`_AppBootstrap._bootstrap` at `lib/main.dart:106`); auth must run **in parallel** and may extend the splash if it resolves after 1500ms, but never shorten it.
- Android uninstall rotates SSAID → fresh anonymous uid → quota reset; iOS unaffected (Keychain survives). This is the documented, accepted tradeoff for "no login required".
- Real purchase integration (StoreKit/Play Billing/RevenueCat) is **explicitly out of scope**; `PaywallScreen` only renders a "coming soon" SnackBar.
- Firestore security rules restricting each user to their own doc are **out of scope** for this change but must be flagged as a deploy-time prerequisite.

## Goals / Non-Goals

**Goals**
- Persist a per-device scan counter at `users/{uid}` (Firestore) with `scansUsed` (int), `isPremium` (bool, default false), `createdAt` (server timestamp).
- Expose the counter as a Riverpod `StreamProvider<ScanQuota>` that re-emits on any Firestore doc change.
- Fail closed on read errors (offline / permission-denied → treat as exhausted, not premium).
- Increment by 1 only after `CoverScanService._recognize` yields ≥1 candidate; decrement on a later OpenAI error; clamp at 0.
- `IS_PREMIUM=true` in `.env` short-circuits the whole gate for dev builds via a single centralized helper.
- Add a `PaywallScreen` modal pushed from `ScanScreen._scan` when quota is exhausted, plus a "X of 5 free scans left" pill in `_ScanIntro`.
- Add ARB strings in `en`/`es`/`fr` for all new copy.
- Add `test/services/scan_quota_service_test.dart` validating the data layer against a constructor-injected fake Firestore.

**Non-Goals**
- Real purchase flows (StoreKit/Play Billing/RevenueCat) and `isPremium` writes from a real backend.
- Firestore security rules deployment.
- Cross-device quota sync correctness beyond what Firestore already gives us.
- Any new UI before `SplashScreen` (no sign-in screen, consent dialog, or "Continue as guest" button).
- New analytics events beyond the existing `logScanPerformed`.
- A login wall; the anonymous uid is never displayed.

## Decisions

### D1: Provider file placement follows the project's dedicated-file pattern

- `scanQuotaServiceProvider` — `Provider<ScanQuotaService>` declared in `lib/providers/services.dart` alongside `collectionRepositoryProvider`, `igdbServiceProvider`, and `analyticsServiceProvider`, since it is the service-object peer of those three.
- `scanQuotaProvider` — `StreamProvider<ScanQuota>` plus the `ScanQuota` freezed-like model + `kFreeScanLimit` constant declared in a new `lib/providers/scan_quota_provider.dart`, mirroring the existing stateful-provider pattern (`collection_provider.dart`, `shared_collections_provider.dart` each own their state class + Notifier in a dedicated file).

**ADR/DDR criteria**
1. *Hard to reverse* — low; relocating a Riverpod provider is a mechanical rename once introduced.
2. *Surprising without context* — yes; a reader seeing service providers split across two files would ask why. The split mirrors the existing split between `services.dart` (stateless service objects) and the `*_provider.dart` family (stateful notifiers/streams). Placing it inline-without-explanation would invite reverse-factoring later.
3. *Real trade-off* — yes; an alternative was the proposal's parenthetical ("or a new `lib/providers/scan_quota_provider.dart`") which suggests lumping everything in one new file. The project precedent favors the split above.

**Alternatives considered**: (a) lump `scanQuotaServiceProvider` + `scanQuotaProvider` + `ScanQuota` model all in `scan_quota_provider.dart` — breaks the parity with `services.dart`. (b) Put both in `services.dart` — `services.dart` would start accumulating StreamProvider + domain models, blurring its role as the stateless-service-objects file.

**Chosen**: split per the project's existing two-tier convention.

### D2: ScanQuotaService is constructed via dependency injection for Firestore/Auth, mirrors CoverScanService

`ScanQuotaService` takes `FirebaseFirestore`, `FirebaseAuth`, and an `isPremiumOverride` bool (resolved once in `main()` from `dotenv.env['IS_PREMIUM']`) via its constructor. Methods: `Stream<ScanQuota> quotaStream()`, `Future<bool> mayScan()`, `Future<void> recordScan()`, `Future<void> decrementScan()`. This mirrors `CoverScanService({ImagePicker? picker, http.Client? client})` — constructor injection lets the test pass a fake Firestore without touching the real `firebase_core` plugin, matching the spec's "fake SHALL be substituted via constructor injection or Riverpod override".

**ADR/DDR criteria**
1. *Hard to reverse* — moderate; once `ScanScreen` calls `recordScan()`, the public method shape becomes interface contracts.
2. *Surprising without context* — yes; an injectable service in a project where `AnalyticsService` was originally constructed at app start and overridden into `ProviderScope` carries a specific seam decision worth recording.
3. *Real trade-off* — yes; an alternative was making `ScanQuotaService` read globals directly (`FirebaseFirestore.instance`, `FirebaseAuth.instance.currentUser!`), which is what the existing Firebase call sites do. The DI version is essential only because tests need a fake.

**Alternatives considered**: (a) staticSingleton via `FirebaseFirestore.instance` mirrored from how `main()` initializes everything; tests would have to use a Riverpod `ProviderContainer` override. Rejected — the spec mandates the fake's "O(1) re-creatable per test" via constructor injection, not via container overrides, and the existing test idiom (`game_model_test`, `qr_payload_codec_test`) is plain `test()` + direct construction, **not** `ProviderContainer`.

**Chosen**: constructor-injected `FirebaseFirestore`/`FirebaseAuth` on `ScanQuotaService`.

### D3: Fail-closed is encoded as an explicit `readFailed` flag rather than a synthetic quota

The stream emits a `ScanQuota` with `scansUsed >= kFreeScanLimit`, `isPremium == false`, and a `readFailed: true` boolean. `mayScan()` returns false when `readFailed` is true, and the UI gate (`ScanScreen._scan`) and the pill (`_ScanIntro`) branch on `readFailed` directly. This distinguishes "genuinely exhausted" from "we don't know" for future auditing and for the pill's hide-or-paywall decision, while keeping the gate logic uniform.

**ADR/DDR criteria**
1. *Hard to reverse* — moderate; adding or removing a boolean on the public `ScanQuota` model touches every consumer.
2. *Surprising without context* — yes; encoding fail-closed as `scansUsed >= kFreeScanLimit` alone would look like a real exhausted user, hiding the failure from analytics and from a future recovery heuristic.
3. *Real trade-off* — yes; alternative was to merge fail-closed into "exhausted" with no flag and let the gate use `scansUsed >= kFreeScanLimit` uniformly. Simpler, but loses information the spec explicitly preserves (`readFailed == true` is called out in scan-quota and scan-gating scenarios).

**Alternatives considered**: (a) single fail-closed sentinel — rejected by the spec's explicit `readFailed == true` field.

**Chosen**: carry an explicit `readFailed` flag.

### D4: `recordScan()` uses `FieldValue.increment(1)`; `decrementScan()` uses a Firestore Transaction, not `FieldValue.increment(-1)`

`recordScan()` increments unconditionally on success and is safe as a blind atomic add — concurrent devices cannot lose updates. `decrementScan()` cannot be implemented the same way because the spec requires clamping at `0`. A blind `FieldValue.increment(-1)` could drive the counter negative on a stale or racing decrement (the spec explicitly calls out "stale decrement" as a scenario). A `FirebaseFirestore.runTransaction` that reads `scansUsed`, applies `max(0, scansUsed - 1)`, and writes the result is the only atomic primitive that satisfies both "no lost updates" and "clamp at 0".

**ADR/DDR criteria**
1. *Hard to reverse* — low; the transaction is internal to the service.
2. *Surprising without context* — yes; a reader seeing two different atomic primitives for symmetric ±1 operations needs to know why the decrement path needed a read.
3. *Real trade-off* — yes; simpler alternative `FieldValue.increment(-1)` is what the spec text references in passing, but it cannot satisfy the clamp-at-zero scenario.

**Alternatives considered**: (a) `FieldValue.increment(-1)` and accept "rare negative won't hurt because the UI clamps" — rejected; spec mandates doc-remains-at-0, not UI clamping.

**Chosen**: `runTransaction` for `decrementScan()`; `FieldValue.increment(1)` for `recordScan()`.

### D5: `IS_PREMIUM` env flag is resolved once in `main()` and passed into `ScanQuotaService` as a constructor bool

`main()` reads `dotenv.env['IS_PREMIUM']`, normalizes it (trim + case-insensitive `== "true"`), and passes an `isPremiumOverride` boolean into `ScanQuotaService`. The service's "is this user premium?" check centralizes into one helper — `bool get _isPremium => isPremiumOverride || _cachedFirestoreIsPremium`. This satisfies the spec's "centralize the premium check in a single helper so the swap is a one-line change" requirement: when RevenueCat wires in and writes `isPremium` to Firestore, the check remains this single helper. Reading dotenv per-call would be wasteful and risk inconsistency; reading once at start mirrors how `OPENAI_API_KEY` is already consumed lazily per call but here the lifetime is "the app process".

**ADR/DDR criteria**
1. *Hard to reverse* — low; the boolean is a constructor arg.
2. *Surprising without context* — yes; dotenv normally being read at point-of-use makes a startup-resolution seem non-idiomatic until the helper is the only consumer across the codebase.
3. *Real trade-off* — yes; alternative was `dotenv.env['IS_PREMIUM']` inline in the helper (matches `cover_scan_service.dart` quirks). Rejected because the spec requires centralization around a single seam for the future RevenueCat swap, and resolving once keeps the Firestore read path inactive when the override is on.

**Alternatives considered**: (a) resolve at point-of-use in `ScanQuotaService` — duplicates `dotenv` reads and breaks the "no Firestore read on dev-premium scan" scenario's cleanliness.

**Chosen**: startup-resolved `isPremiumOverride` bool passed via constructor.

### D6: Bootstrap concurrency via `Future.wait` over `[signInAnonymously(), Future.delayed(1500ms)]`

`_AppBootstrap._bootstrap` currently only `await Future.delayed(_minSplash)`. The change wraps it in `Future.wait([FirebaseAuth.instance.signInAnonymously(), Future.delayed(_minSplash)])`, then upserts the quota doc with `set({scansUsed: 0, isPremium: false, createdAt: FieldValue.serverTimestamp}, merge: true)`, then `setState(_ready = true)`. The 1500ms minimum is preserved when auth is fast (the wait can't return before both complete); when auth is slow, the splash naturally extends past 1500ms until both resolve. The `_AppBootstrap.build` crossfade is unchanged — it is still purely driven by `_ready`.

**ADR/DDR criteria**
1. *Hard to reverse* — moderate; `_AppBootstrap` is a small but load-bearing startup sequence.
2. *Surprising without context* — yes; a `Future.wait` exactly parallel-daized auth + the existing timer is an intentional synchronization choice, not a coincidence.
3. *Real trade-off* — yes; alternatives were (a) await `signInAnonymously()` *before* the timer (extends splash by full auth duration always — violates the "fast network → no extension" intent) and (b) await auth after the timer with no coupling (allows a `null currentUser` window if the home screen renders before auth resolves).

**Alternatives considered**: (a) sequential `await auth; await delay` — always slow; (b) fire-and-forget auth, rely on `currentUser` being non-null by the time scan runs — risks a transient null-uid on first scan.

**Chosen**: `Future.wait` over auth + the minimum splash delay.

### D7: `PaywallScreen` is a `MaterialPageRoute(fullscreenDialog: true)` with no new analytics and no purchase calls

`PaywallScreen` renders the seven l10n strings (title, subtitle, three feature bullets, Subscribe CTA, Restore affordance). The Subscribe CTA shows the `paywallComingSoon` SnackBar and remains on screen. The Restore affordance shares the same SnackBar. No StoreKit/Play Billing/RevenueCat call is made. `FullscreenDialog: true` makes `Navigator.push` from `ScanScreen._scan` render the modal above the scan tab with a back affordance — exactly the spec's "scan tab remains visible behind the modal" contract once the modal has a transparent or scrollable Scaffold body.

**ADR/DDR criteria**
1. *Hard to reverse* — low; an addition-only screen.
2. *Surprising without context* — no — straightforward creation spec; readers will not be surprised.
3. *Real trade-off* — qualifies; routing choice (`Push` vs `showModalBottomSheet` vs `PageRouteBuilder`) had genuine alternatives.

This is borderline ADR; documenting only the routing choice.

**Alternatives considered**: (a) `showModalBottomSheet` — wrong affordance for an apprentice-modal; the spec says full-screen modal with a back button.

**Chosen**: `MaterialPageRoute(fullscreenDialog: true)`.

### D8: Test isolation via per-test fake Firestore created in the test body

Each test constructs its own fake `FirebaseFirestore` substitute and a fresh `ScanQuotaService`, satisfying the spec's "each test creates its own fake Firestore and `ScanQuotaService` instance; tests MUST NOT share state between cases; the fake SHALL be O(1) re-creatable per test". No `setUp`/`tearDown` shared state. The fake exposes `get`, `set` (with merge), `update` (interpreting `FieldValue.increment`), a `snapshots()` stream over the `users/{uid}` doc, and a "throw on `get`" mode for the fail-closed test. The fake is implemented in the test file itself (no mocktail/no external fake framework), matching the existing `qr_payload_codec_test` and `game_model_test` pattern of "plain `test()` + direct construction".

**ADR/DDR criteria**
1. *Hard to reverse* — low; an internal test helper.
2. *Surprising without context* — yes; a hand-rolled fake in a 2026 codebase invites "why not mocktail?". The existing `test/` files settle it: the project does not use mocking frameworks, and the spec explicitly forbids real-client initialization.
3. *Real trade-off* — yes; could pull in `mocktail` or `fake_cloud_firestore`. Both add a dependency beyond what existing suites use.

**Alternatives considered**: (a) `mocktail` — adds a dep unused elsewhere in `test/`; (b) `fake_cloud_firestore` — heavier than needed and would require the real `firebase_core` to initialize (which the spec forbids).

**Chosen**: hand-rolled fake via constructor injection.

## Risks / Trade-offs

- **[Android uninstall resets the quota]** → Mitigation: a code comment next to the anonymous sign-in call states (a) Android rotates SSAID on uninstall, (b) iOS is unaffected because the Firebase Anonymous Auth uid sits in the Keychain, (c) this is the documented tradeoff for "no login required". Live in-lieu of a migration plan until/unless a real accounts surface arrives.
- **[Firestore security rules are not part of this change]** → Mitigation: a deploy-time prerequisite is called out in the Migration Plan; the rule is `match /users/{userId} { allow read, write: if request.auth.uid == userId; }` with no client write path for `isPremium`. Reviewer must deploy this rule before enabling traffic.
- **[Counter reads cost 1 read + 1 write per scan]** → Accepted; negligible relative to the OpenAI spend this gate prevents. No mitigation.
- **[Slow network at cold start extends the splash visibly]** → Mitigation: existing `_LoadingPulse` is the loading surface; the spec accepts this. No abort/timeout is added in this change.
- **[Decrement transaction can block briefly if a write is in flight]** → Mitigation: Firestore transactions retry automatically; the user-facing error path is unchanged (the existing `scanFailed` SnackBar fires regardless of decrement outcome).
- **[Empty ARB placeholders block the release]** → Mitigation: the `freeScansRemaining` `@key` metadata block is added only in `app_en.arb` (the template locale), mirroring the existing `candidatesFound` / `sharedDetailCount` pattern — `gen-l10n` derives metadata from `en`. The `es`/`fr` files omit `@key` blocks (matching today's convention).
- **[`IS_PREMIUM=true` admitted into a shipped build]** → Mitigation: the flag defaults to absent/empty; if a release carries `IS_PREMIUM=true` inits `.env`, every user of that build bypasses the gate. Document that `.env` is a build-time asset and `IS_PREMIUM` must be unset for production builds; no code-level prevention in this change.

## Migration Plan

1. **Pre-deploy**: Add the Firestore security rule restricting each user's doc to their own uid and forbidding client writes to `isPremium`. Out of scope for code; reviewer/operator must apply this rule via the Firebase Console or `firebase/firestore.rules`.
2. **Dependency add**: bump `pubspec.yaml` with `firebase_auth` and `cloud_firestore`; `flutter pub get`.
3. **Code deploy**: ship the implementation commit-by-commit per `tasks.md`.
4. **Rollback**: revert the merge commit — the counter doc persists harmlessly in Firestore; the old scan flow resumes without quota gating. No data migration step required on rollback because the doc is additive.
5. **Post-deploy monitoring**: `logScanPerformed` continues to fire as before; there is no new analytics event. Compare scan counts before/after to confirm the gate is enforcing the limit. (No alert wiring in this change.)

## Open Questions

None remain after codebase research. The `budget-explorer` subagent confirmed:
- `firebase_core` + `lib/firebase_options.dart` are already in place; no new platform config.
- `ProviderScope` in `lib/main.dart:46–51` already uses the override idiom that tests will mirror.
- The existing ARB placeholder pattern (`candidatesFound`, `sharedDetailCount`) is the template for `freeScansRemaining`.
- The existing test idiom (plain `flutter_test` + direct constructor injection, no mocktail) drives the new test file's shape.
- The existing `.env`/`flutter_dotenv` access pattern (`dotenv.env['KEY'] ?? ''`) drives the `IS_PREMIUM` read.
- The existing `_recognize`/`scan()` success-vs-error branching drives where `recordScan()` and `decrementScan()` plug into `ScanScreen._scan`.
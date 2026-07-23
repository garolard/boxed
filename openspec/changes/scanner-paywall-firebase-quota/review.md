# Code Review — Scanner Paywall Firebase Quota

**Change:** `openspec/changes/scanner-paywall-firebase-quota/`  
**Branch reviewed:** `scanner-paywall-firebase-quota`  
**Parent branch:** `main`  
**Commits in scope:** 6 (251e381..98af44c)  
**Files changed:** 12  
**Date:** 2025-07-18

## Summary

The change implements a server-side scan quota system backed by Firebase Anonymous Auth and Firestore, with a paywall screen and scan gating. The architecture follows the design decisions (DI, fail-closed, StreamProvider, fullscreenDialog modal). However, a critical bug in the bootstrap resets the scan counter to 0 on every cold start, completely defeating the quota system. Several other correctness issues in the service layer and test fakes undermine the reliability of the implementation.

**Verdict:** Needs rework

**Findings count:** 2 Blockers · 10 Major · 2 Minor · 1 Questions
*(Mutation Analysis severities are folded into these counts: each surviving / pre-check-failed mutation is a Major, each revert-failed mutation is a Blocker.)*

---

## Domain Alignment Check

- **Goal coverage:** Partially met — the core quota system is implemented but the bootstrap resets `scansUsed` to 0 on every cold start (`main.dart:149`), defeating the primary goal of a persistent server-side counter.
- **Decisions respected:** Mostly — D1 (provider file placement), D2 (DI), D3 (fail-closed flag), D4 (transaction for decrement), D5 (IS_PREMIUM resolution), D6 (Future.wait), D7 (fullscreenDialog), D8 (fake Firestore) are all followed. However, the bootstrap upsert violates the spec's "re-bootstrap is a no-op for existing fields" scenario.
- **Scope creep:** None detected.

---

## Security Surface Triage

- **Surface touched:** Yes
- **Areas affected:** auth (`lib/main.dart:130-134` — anonymous sign-in), dynamic queries / data layer (`lib/services/scan_quota_service.dart` — Firestore reads/writes to `users/{uid}`), logging (`lib/main.dart:134` — auth errors silently swallowed)
- **Recommendation:** Run `/sai-6-security scanner-paywall-firebase-quota`

---

## Performance Surface Triage

- **Surface touched:** Yes
- **Tiers affected:** backend (Firestore reads/writes per scan), frontend (new StreamProvider with live Firestore listener)
- **Areas affected:** new queries (`scan_quota_service.dart` — 1 read + 1 write per scan), new deps (`firebase_auth`, `cloud_firestore` in `pubspec.yaml`), caching changes (broadcast StreamController with no cleanup)
- **Recommendation:** Run `/sai-7-performance scanner-paywall-firebase-quota`

---

## Accessibility Surface Triage

- **Surface touched:** Yes
- **Areas affected:** interactive widgets (`lib/screens/paywall_screen.dart` — buttons, navigation), navigation (`lib/screens/scan_screen.dart:45-51` — new fullscreenDialog modal route), dynamic-SPA (Flutter widget tree changes with new pill and paywall)
- **Recommendation:** Run `/sai-8-accessibility scanner-paywall-firebase-quota`

---

## Findings

### Blockers

#### B1 — Bootstrap resets scansUsed to 0 on every cold start
- **Location:** `lib/main.dart:149-153`
- **Category:** Correctness / Domain Alignment
- **Problem:** The `set({scansUsed: 0, isPremium: false, createdAt: serverTimestamp}, SetOptions(merge: true))` unconditionally overwrites `scansUsed` to 0 on every app launch. With `merge: true`, Firestore merges the provided fields into the existing document, so `scansUsed: 0` resets the counter every cold start. This completely defeats the persistent server-side quota — a user regains their full scan allowance each time they reopen the app.
- **Evidence:**
  ```dart
  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .set({
    'scansUsed': 0,  // ← resets on every boot
    'isPremium': false,
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  ```
- **Suggested fix:** Only write the initial doc if it doesn't exist. Use a get-then-set pattern or a Firestore transaction:
  ```dart
  final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  final snap = await docRef.get();
  if (!snap.exists) {
    await docRef.set({
      'scansUsed': 0,
      'isPremium': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  ```
- **Spec reference:** `specs/splash-auth-integration/spec.md` — "Re-bootstrap on an existing user" scenario: "the upsert with merge: true is a no-op for existing fields and does not reset scansUsed"

#### B2 — recordScan() uses update() which throws if doc doesn't exist
- **Location:** `lib/services/scan_quota_service.dart:126`
- **Category:** Correctness
- **Problem:** `doc.update({'scansUsed': FieldValue.increment(1)})` throws a `FirebaseException` if the document does not exist. The bootstrap is supposed to create the doc, but if bootstrap fails (auth timeout at `main.dart:134` swallows the error), the doc won't exist. The quota stream emits `scansUsed: 0` for a non-existent doc (`scan_quota_service.dart:89-91`), so `mayScan()` returns true, the user attempts a scan, and `recordScan()` crashes. The catch block in `scan_screen.dart:80-81` then calls `decrementScan()` which also throws (same root cause — `tx.update` on non-existent doc at line 138), and that throw is unhandled.
- **Evidence:**
  ```dart
  Future<void> recordScan() async {
    if (_effectivePremium) return;
    final doc = _doc;
    if (doc == null) return;
    await doc.update({'scansUsed': FieldValue.increment(1)});  // throws if doc missing
  }
  ```
- **Suggested fix:** Use `set({'scansUsed': FieldValue.increment(1)}, SetOptions(merge: true))` instead of `update()`. This creates the doc if it doesn't exist, or increments if it does. Alternatively, add a guard that creates the doc first.
- **Spec reference:** `specs/scan-quota/spec.md` — "Successful scan increments the counter"

### Major

#### M1 — StreamController and Firestore listener never cancelled (resource leak)
- **Location:** `lib/services/scan_quota_service.dart:86-110`
- **Category:** Maintainability / Performance
- **Problem:** The broadcast `StreamController` and its `doc.snapshots().listen()` subscription are never closed or cancelled. No `dispose()` method or `onCancel` hook is wired up. When the `StreamProvider` consumer unsubscribes, the underlying Firestore listener keeps running, leaking resources. Additionally, `scan_screen.dart:41` calls `quotaStream().first` on every `_scan()` invocation, creating a new StreamController and Firestore listener each time that are never cleaned up.
- **Suggested fix:** Store the `StreamSubscription` from `doc.snapshots().listen()` and cancel it in a `dispose()` method or via `ctrl.onCancel`. For the `scan_screen.dart:41` case, use `ref.read(scanQuotaProvider.future)` instead of creating a new stream.

#### M2 — _cachedQuota stale between recordScan and next Firestore snapshot
- **Location:** `lib/services/scan_quota_service.dart:53,98,114-118`
- **Category:** Correctness
- **Problem:** `_cachedQuota` is only refreshed by the stream listener (line 98). After `recordScan()` mutates the remote doc (line 126), the cache remains stale until the next Firestore snapshot arrives. During that window, `mayScan()` reads from `_cachedQuota` (line 116) and can return an over-permissive result, potentially allowing one scan past the limit.
- **Suggested fix:** Update `_cachedQuota` immediately after a successful `recordScan()` or `decrementScan()` call, e.g., `_cachedQuota = _cachedQuota?.copyWith(scansUsed: (_cachedQuota?.scansUsed ?? 0) + 1)`.

#### M3 — createdAt overwritten on every boot
- **Location:** `lib/main.dart:152`
- **Category:** Correctness
- **Problem:** `createdAt: FieldValue.serverTimestamp()` is written on every launch because `merge: true` overwrites existing fields. The field records "last boot" rather than true account-creation time. This is the same root cause as B1 — the upsert should be conditional.
- **Suggested fix:** Same fix as B1 — only write the doc if it doesn't exist.

#### M4 — Auth error silently swallowed with no logging
- **Location:** `lib/main.dart:134`
- **Category:** Maintainability / Security
- **Problem:** `catch (_) {}` swallows all auth errors with no logging. If `signInAnonymously()` fails or times out, `currentUser` is null, the quota-doc upsert is silently skipped, and the app navigates to `HomeScreen` without a uid. Downstream `ScanQuotaService` calls that depend on an authenticated user will fail at runtime with no diagnostic signal.
- **Suggested fix:** At minimum, log the error via `widget.analytics.logEvent(...)` or `FirebaseCrashlytics.instance.recordError(...)`. Consider also surfacing a user-visible error or retrying.

#### M5 — decrementScan transaction uses tx.update which throws if doc doesn't exist
- **Location:** `lib/services/scan_quota_service.dart:134-138`
- **Category:** Correctness
- **Problem:** The transaction calls `tx.update(doc, {'scansUsed': next})` which throws if the document does not exist (e.g., if invoked before any `recordScan` has succeeded and the bootstrap failed to create the doc). A `tx.set` with merge or an `if (snap.exists)` guard would prevent a crash on the rollback path.
- **Suggested fix:** Check `snap.exists` before calling `tx.update`. If the doc doesn't exist, the decrement is a no-op (scansUsed is already 0).

#### M6 — Test fake _FakeDocumentRef.update treats all FieldValue as increment(+1)
- **Location:** `test/services/scan_quota_service_test.dart:112-114`
- **Category:** Correctness / Testing
- **Problem:** The fake unconditionally does `current + 1` for any `FieldValue`, ignoring the actual increment amount. When `decrementScan()` uses `FieldValue.increment(-1)` (if the implementation were to use that instead of a transaction), the fake would incorrectly add 1 instead of subtracting. The fake doesn't introspect the `FieldValue` to determine the increment amount.
- **Evidence:**
  ```dart
  if (value is FieldValue) {
    final current = (doc.data[key] as num?)?.toInt() ?? 0;
    doc.data[key] = current + 1;  // ← always +1, ignores actual increment
  }
  ```
- **Suggested fix:** The `FieldValue` API doesn't expose the increment amount directly, so the fake needs a different approach. One option: intercept the `FieldValue` and apply it based on the known operations (increment by 1 or -1). Alternatively, since `decrementScan` uses a transaction (not `FieldValue.increment(-1)` directly), this may not affect current tests — but the fake is still incorrect for any future `FieldValue.increment(-1)` usage.

#### M7 — Test fake _FakeTransaction.update doesn't handle FieldValue
- **Location:** `test/services/scan_quota_service_test.dart:172-183`
- **Category:** Correctness / Testing
- **Problem:** The transaction fake stores raw `FieldValue` objects in the pending map via spread (`...data`), so on `commit` the document's field becomes a `FieldValue` instance rather than a computed integer. However, looking at the actual `decrementScan()` implementation, it passes `{'scansUsed': next}` where `next` is a plain `int` (not a `FieldValue`). So this finding is actually not triggered by the current implementation. The transaction fake works correctly for the current code because `decrementScan` computes the new value client-side and passes a plain int. **Retracted — not a real finding given the current implementation.**
- **Suggested fix:** N/A for current code, but the fake should handle `FieldValue` in transaction updates for robustness.

#### M8 — Missing test scenarios: picker cancelled, OpenAI error before recordScan
- **Location:** `test/services/scan_quota_service_test.dart:291-305`
- **Category:** Testing / Domain Alignment
- **Problem:** The spec requires three "no-increment-on-failure" scenarios: zero candidates, picker cancelled, and OpenAI error before recordScan. Only the empty-candidates case is attempted, and it's a tautology — it seeds `scansUsed: 2` and immediately asserts it's still `2` without invoking any service method. The "picker cancelled" and "OpenAI error before recordScan" scenarios have no test coverage.
- **Evidence:**
  ```dart
  test('no-increment on empty candidates', () async {
    ...
    await fake.doc('users/user-4').set({'scansUsed': 2, 'isPremium': false});
    // Simulating a scan that returns zero candidates: recordScan is never called.
    // We assert the doc is untouched.
    expect(fake._docs['users/user-4']!.data['scansUsed'], 2);  // ← tautology
  });
  ```
- **Suggested fix:** The "no-increment-on-failure" scenarios are really integration tests that exercise the `ScanScreen._scan` flow, not the `ScanQuotaService` in isolation. The service itself doesn't know about picker cancellations or OpenAI errors — those are handled by the caller. Consider whether these tests belong in a widget test for `ScanScreen` instead, or remove the tautological test and document that these scenarios are covered by integration tests.

#### M9 — Tests rely on Future.delayed for synchronization (flaky)
- **Location:** `test/services/scan_quota_service_test.dart:235,238,258,280`
- **Category:** Testing
- **Problem:** All tests use `Future.delayed(Duration(milliseconds: 50))` to synchronize with stream emissions. This is inherently flaky under CI load or slow machines. The 50ms delay is a race condition waiting to happen.
- **Suggested fix:** Use `expectLater(stream, emits(...))` or a `Completer`-based gate to make assertions deterministic. For example:
  ```dart
  final future = service.quotaStream().first;
  await service.recordScan();
  final quota = await future;
  expect(quota.scansUsed, 1);
  ```

#### M10 — isPremium hardcoded to false in Firestore even when IS_PREMIUM override is true
- **Location:** `lib/main.dart:151`
- **Category:** Correctness / Domain Alignment
- **Problem:** The Firestore doc always gets `isPremium: false` even when the dotenv `IS_PREMIUM` override is `true`. The local `ScanQuotaService` treats the user as premium (via `_isPremiumOverride`), but the server document disagrees. This will confuse security rules, admin tools, or any future server-side premium check.
- **Suggested fix:** Either write `isPremium: isPremiumOverride` to Firestore, or document that the Firestore `isPremium` field is only for server-side premium (RevenueCat) and the env flag is purely local. The design doc (D5) says the env flag is a "developer escape hatch" — clarify whether it should be reflected in Firestore.

### Minor

#### m1 — Stale TDD comments in test file
- **Location:** `test/services/scan_quota_service_test.dart:323,339`
- **Suggestion:** Comments say "RED expectation: this will fail because runTransaction is not yet wired" but `FakeFirestore.runTransaction` IS implemented (line 40-46). Remove or update these comments to avoid confusing future readers.

#### m2 — ScanQuota model doesn't include createdAt field
- **Location:** `lib/services/scan_quota_service.dart:9-42`
- **Suggestion:** The spec requires persisting `createdAt` as a server timestamp, and the bootstrap writes it to Firestore, but the `ScanQuota` model doesn't expose it. Not a bug (the field is persisted), but the model is incomplete. Consider adding `createdAt` to `ScanQuota` for future auditing or UI display.

### Questions

#### Q1 — scan_screen.dart:41 creates a new quotaStream() per _scan() call
- **Location:** `lib/screens/scan_screen.dart:41`
- **Question:** The `_scan` method calls `ref.read(scanQuotaServiceProvider).quotaStream().first` which creates a new broadcast StreamController and Firestore listener each time. The `_ScanIntro` widget already watches `scanQuotaProvider` (the StreamProvider). Should `_scan` read the current value from the existing provider (e.g., `ref.read(scanQuotaProvider).valueOrNull` or `ref.read(scanQuotaProvider.future)`) instead of creating a new stream? This would avoid the resource leak identified in M1.

---

## Mutation Analysis (Pass 11)

*Mutation Analysis (Pass 11): skipped — no test command could be detected from project manifests (pubspec.yaml does not declare an explicit test script). No mutation findings.*

---

## Coverage Notes

- **Files reviewed:** 10 / 12 (excluded `openspec/changes/scanner-paywall-firebase-quota/implementation.md` as it's a planning artifact, and `pubspec.yaml` as it only adds two dependencies)
- **Files skipped:** `openspec/changes/scanner-paywall-firebase-quota/implementation.md` (planning artifact), `pubspec.yaml` (dependency additions only)
- **Tests inspected:** Yes — coverage assessment: the test file covers increment, fail-closed, premium bypass, decrement-restores, and decrement-clamps. Missing: picker-cancelled and OpenAI-error-before-recordScan scenarios (which are arguably integration tests, not unit tests for the service).

---

## Next Steps

1. Fix B1 (bootstrap resets scansUsed) and B2 (recordScan throws on missing doc) — these are critical correctness bugs that defeat the quota system.
2. Fix M1 (StreamController leak) and M4 (silent auth error) — resource leak and observability gap.
3. Fix M6 (test fake FieldValue handling) and M8 (missing test scenarios) — test reliability.
4. Re-run review after fixes.

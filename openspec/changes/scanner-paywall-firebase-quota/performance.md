# Performance Report — Scanner Paywall Firebase Quota

**Change:** `openspec/changes/scanner-paywall-firebase-quota/`  
**Scope:** diff vs `main`  
**Tiers audited:** frontend, db  
**Branch:** `scanner-paywall-firebase-quota`  
**Baseline reference:** absolute thresholds — no baseline  
**Date:** 2025-07-18

## Executive Summary

| Severity | Backend | Frontend | DB | Queue | Total |
|----------|---------|----------|----|----|-------|
| Critical | 0 | 1 | 0 | 0 | 1 |
| High | 0 | 0 | 2 | 0 | 2 |
| Medium | 0 | 3 | 2 | 0 | 5 |
| Low | 0 | 4 | 0 | 0 | 4 |
| Informational | 0 | 1 | 0 | 0 | 1 |
| **Total** | 0 | 9 | 4 | 0 | 13 |

**Verdict:** Release after Critical/High fixed

**Risk posture:** The critical resource leak in the Firestore listener will cause unbounded memory growth and billing overflows in production. The high-severity N+1 listener pattern compounds this by creating multiple listeners per user session. Cold-start latency is acceptable but could be improved by parallelizing Firestore operations.

---

## Hot Paths in Scope

| Path | Tier | Why it matters |
|------|------|----------------|
| `ScanQuotaService.quotaStream()` | db | Creates Firestore real-time listener; called on every scan attempt |
| `_AppBootstrap._bootstrap()` | frontend | Blocks splash-to-home transition; includes auth + Firestore provisioning |
| `ScanScreen._scan()` | frontend | User-facing scan flow; reads quota before opening camera |
| `_ScanIntro` widget | frontend | Rebuilds on every quota stream emission |

---

## Findings

### [Critical] Frontend: Firestore listener never cancelled

- **Location:** `lib/services/scan_quota_service.dart:86-109`
- **Category:** Resource Management
- **Symptom:** Each `quotaStream()` call opens a new Firestore listener and `StreamController` that are never closed or cancelled, leaking memory and billing reads indefinitely.
- **Evidence:**
  ```dart
  final ctrl = StreamController<ScanQuota>.broadcast();
  doc.snapshots().listen(
    (snap) { … },
    onError: (_) { … },
    cancelOnError: false,
  );
  return ctrl.stream;
  ```
- **Root cause:** The `StreamSubscription` from `listen()` is discarded; `ctrl` is never closed on cancel.
- **Expected impact if unfixed:** Unbounded Firestore listener count; continuous read billing; memory growth proportional to call count. App will degrade after ~50-100 scan attempts.
- **Remediation:** Store the subscription; use `ctrl.onCancel` to call `sub.cancel()` and `ctrl.close()`, or return `doc.snapshots().map(…)` directly.
- **Expected gain:** Eliminates leaked listeners; ~100% reduction in background Firestore reads per stale call.
- **Validation method:** Call `quotaStream()` twice, verify via Firestore console that only one active listener exists after the first is cancelled.
- **Spec note:** —

### [High] DB: N+1 Firestore listeners — quotaStream() not singleton

- **Location:** `lib/services/scan_quota_service.dart:78-111`
- **Category:** N+1
- **Symptom:** Every widget rebuild or call spawns a fresh `doc.snapshots()` subscription.
- **Evidence:**
  ```dart
  Stream<ScanQuota> quotaStream() {
    final doc = _doc;
    …
    final ctrl = StreamController<ScanQuota>.broadcast();
    doc.snapshots().listen(…);
  ```
- **Root cause:** No memoization; broadcast stream is recreated per invocation.
- **Expected impact if unfixed:** N simultaneous Firestore real-time listeners for the same document; linear cost growth.
- **Remediation:** Cache the broadcast `StreamController` lazily (`_quotaStream ??= …`); share one underlying `snapshots()` subscription.
- **Expected gain:** Reduces listener count from N to 1; ~90% fewer Firestore reads.
- **Validation method:** Instrument `snapshots()` calls; confirm single invocation across multiple subscribers.
- **Spec note:** —

### [High] DB: Sequential Firestore round-trips in bootstrap

- **Location:** `lib/main.dart:146-156`
- **Category:** N+1
- **Symptom:** Splash stays visible while two serial Firestore round-trips execute (`get` then conditional `set`).
- **Evidence:**
  ```dart
  final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  final snap = await docRef.get();
  if (!snap.exists) {
    await docRef.set({...});
  }
  ```
- **Root cause:** User-doc provisioning is sequential and happens inside the splash gate, not parallelized with auth or splash delay.
- **Expected impact if unfixed:** Adds 1-2 Firestore RTTs (~200-600ms on cellular) to visible splash on new-user first launch.
- **Remediation:** Use `set({...}, SetOptions(merge: true))` to eliminate the read, or move the doc check into the `Future.wait` block.
- **Expected gain:** ~200-600ms splash reduction for new users.
- **Validation method:** Log timestamps around `_bootstrap` phases; confirm single Firestore call.
- **Spec note:** Acknowledged in `design.md` §D6 — bootstrap concurrency via `Future.wait` over auth + splash delay. The doc provisioning was added after the design was finalized.

### [Medium] DB: Transaction overhead in decrementScan

- **Location:** `lib/services/scan_quota_service.dart:149-154`
- **Category:** Algorithmic
- **Symptom:** Full transaction round-trip (read + write + potential retry) for a simple decrement.
- **Evidence:**
  ```dart
  await _firestore.runTransaction((tx) async {
    final snap = await tx.get(doc);
    final current = (snap.data()?['scansUsed'] as num?)?.toInt() ?? 0;
    final next = current > 0 ? current - 1 : 0;
    tx.update(doc, {'scansUsed': next});
  });
  ```
- **Root cause:** Client-side clamp logic forces a transaction; `FieldValue.increment(-1)` with a security rule enforcing `>= 0` would be atomic.
- **Expected impact if unfixed:** 2x latency vs. single write; contention retries under concurrent decrements.
- **Remediation:** Replace with `doc.update({'scansUsed': FieldValue.increment(-1)})` + server-side rule `request.resource.data.scansUsed >= 0`.
- **Expected gain:** ~50% latency reduction; eliminates retry storms.
- **Validation method:** Measure round-trip time before/after under load; confirm no negative values in Firestore.
- **Spec note:** Acknowledged in `design.md` §D4 — transaction chosen to satisfy clamp-at-zero requirement. Security rules are out of scope for this change.

### [Medium] Backend: Stale _cachedQuota causes false negatives in mayScan

- **Location:** `lib/services/scan_quota_service.dart:114-119`
- **Category:** Caching
- **Symptom:** `mayScan()` returns `false` until the stream emits its first snapshot, blocking scans on cold start.
- **Evidence:**
  ```dart
  Future<bool> mayScan() async {
    if (_effectivePremium) return true;
    final quota = _cachedQuota;
    if (quota == null) return false;
  ```
- **Root cause:** `_cachedQuota` is only populated inside the stream listener; no eager fetch.
- **Expected impact if unfixed:** Users see "quota exhausted" on app launch until Firestore responds.
- **Remediation:** Perform a one-shot `doc.get()` fallback when `_cachedQuota == null`, or initialize cache from `get()` before subscribing.
- **Expected gain:** Eliminates cold-start false block; perceived availability +100% at launch.
- **Validation method:** Kill app, relaunch, verify `mayScan()` returns correct value before first stream emission.
- **Spec note:** —

### [Medium] Frontend: N+1 Firestore reads on each scan tap

- **Location:** `lib/screens/scan_screen.dart:41`
- **Category:** N+1
- **Symptom:** Each scan tap triggers a fresh Firestore read even if quota was just read moments ago.
- **Evidence:**
  ```dart
  final quota = await ref.read(scanQuotaServiceProvider).quotaStream().first;
  ```
- **Root cause:** Quota is fetched via a one-shot stream subscription on every `_scan()` call instead of reading a cached provider value.
- **Expected impact if unfixed:** Extra Firestore document reads (billed); ~100-300 ms added latency per scan.
- **Remediation:** Use `ref.read(scanQuotaProvider).valueOrNull` if the provider already caches quota, or debounce with a TTL.
- **Expected gain:** Eliminates 1 Firestore read per scan attempt; ~200 ms faster scan start.
- **Validation method:** Firestore usage dashboard — compare read count before/after.
- **Spec note:** —

### [Medium] Frontend: Candidate tiles re-animate on every rebuild

- **Location:** `lib/screens/scan_screen.dart:419-421`
- **Category:** Algorithmic
- **Symptom:** Candidate tiles re-animate (fade + slide) on every parent rebuild, not just first appearance.
- **Evidence:**
  ```dart
  .animate().fadeIn(duration: 300.ms, delay: (60 * index).ms).slideX(begin: 0.1, end: 0, ...)
  ```
- **Root cause:** `flutter_animate` attaches implicit animation controllers per build. When `_scanning` toggles, the entire ListView rebuilds, restarting all tile animations.
- **Expected impact if unfixed:** Janky visual flicker; unnecessary animation controller churn on the UI thread.
- **Remediation:** Wrap tiles in `AnimatedBuilder` keyed on candidate identity, or use `Animate(autoPlay: true)` with a stable key so animations only run on first insert.
- **Expected gain:** Eliminates redundant animation cycles; smoother 60 fps during state transitions.
- **Validation method:** Flutter DevTools "Performance" overlay — verify no frame spikes when toggling scan state.
- **Spec note:** —

### [Medium] Frontend: dotenv and Firebase init serialized

- **Location:** `lib/main.dart:26-31`
- **Category:** Concurrency
- **Symptom:** Cold-start latency; dotenv I/O blocks Firebase init.
- **Evidence:**
  ```dart
  await dotenv.load(...);
  await Firebase.initializeApp(...);
  ```
- **Root cause:** Two independent async initializations are serialized.
- **Expected impact if unfixed:** Adds dotenv disk-read time (~50-150ms) to every cold start.
- **Remediation:** Run both via `Future.wait([dotenv.load(...), Firebase.initializeApp(...)])`.
- **Expected gain:** ~50-150ms startup reduction.
- **Validation method:** Measure time between `main()` entry and `runApp` with `Timeline` instrumentation.
- **Spec note:** —

### [Medium] Frontend: Analytics blocks startup path

- **Location:** `lib/main.dart:45-46`
- **Category:** Concurrency
- **Symptom:** `AnalyticsService.create()` and `logAppOpen()` block the path to `runApp`.
- **Evidence:**
  ```dart
  final analytics = await AnalyticsService.create();
  await analytics.logAppOpen();
  ```
- **Root cause:** Analytics is not required for first frame; it serializes startup.
- **Expected impact if unfixed:** Adds network/DB open time before any UI renders.
- **Remediation:** Fire-and-forget `unawaited(analytics.logAppOpen())`; defer `AnalyticsService.create` into a Riverpod provider initialized post-first-frame.
- **Expected gain:** ~100-300ms to first frame.
- **Validation method:** Compare `timeToFirstFrame` via `flutter run --profile` before/after.
- **Spec note:** —

### [Low] Backend: Redundant code paths — recordScan vs tryRecordScan

- **Location:** `lib/services/scan_quota_service.dart:122-142`
- **Category:** Algorithmic
- **Symptom:** `recordScan` blindly increments without quota check; `tryRecordScan` does atomic check-and-increment.
- **Evidence:**
  ```dart
  Future<void> recordScan() async {
    …
    await doc.set({'scansUsed': FieldValue.increment(1)}, SetOptions(merge: true));
  }
  ```
- **Root cause:** Two APIs for one operation; `recordScan` can exceed `kFreeScanLimit`.
- **Expected impact if unfixed:** Quota bypass if caller uses wrong method; wasted writes.
- **Remediation:** Deprecate `recordScan`; route all callers through `tryRecordScan`.
- **Expected gain:** Eliminates over-quota writes; simplifies maintenance.
- **Validation method:** Grep call sites; confirm zero callers of `recordScan`.
- **Spec note:** —

### [Low] Frontend: Three separate setState calls in scan flow

- **Location:** `lib/screens/scan_screen.dart:56-59, 79-82, 101`
- **Category:** Algorithmic
- **Symptom:** Three separate `setState` calls in one async flow trigger three rebuilds of the full widget tree.
- **Evidence:**
  ```dart
  setState((){_scanning=true}) → setState((){_candidates=...}) → setState((){_scanning=false})
  ```
- **Root cause:** Sequential state mutations without batching. The `finally` block always fires a third rebuild even when candidates were just set.
- **Expected impact if unfixed:** 3 full rebuilds of Scaffold + ListView per scan; compounded by finding #7 re-animating tiles.
- **Remediation:** Combine the post-scan state update: set `_candidates`, `_scanned`, and `_scanning = false` in a single `setState` inside the `try` block, removing the `finally` setState.
- **Expected gain:** Reduces rebuilds from 3 to 2 per scan; ~30% fewer widget allocations.
- **Validation method:** `debugProfileBuildsEnabled = true` — verify build count per scan action.
- **Spec note:** —

### [Low] Frontend: Closure allocation per candidate tile

- **Location:** `lib/screens/scan_screen.dart:251`
- **Category:** Algorithmic
- **Symptom:** New closure allocated per candidate tile on every build, defeating `const` optimization and `==` checks.
- **Evidence:**
  ```dart
  onTap: () => _searchFor(_candidates[i].title),
  ```
- **Root cause:** Inline lambda captures `_candidates[i].title` per iteration, creating N closures per rebuild.
- **Expected impact if unfixed:** Minor GC pressure with large candidate lists; prevents potential widget identity reuse.
- **Remediation:** Pass the index to `_CandidateTile` and let it call back via `onTap(int index)` with the lookup done inside the parent method, or use a precomputed list of callbacks.
- **Expected gain:** Negligible alone; reduces allocation pressure in combination with other fixes.
- **Validation method:** Dart DevTools allocation profile — fewer closures per build frame.
- **Spec note:** —

### [Low] Frontend: _ScanIntro rebuilds on every quota emission

- **Location:** `lib/screens/scan_screen.dart:270`
- **Category:** Caching
- **Symptom:** `_ScanIntro` rebuilds on every quota stream emission, even when displayed values are unchanged.
- **Evidence:**
  ```dart
  final quotaAsync = ref.watch(scanQuotaProvider);
  ```
- **Root cause:** `ref.watch` subscribes to all emissions. If the stream fires on unrelated Firestore updates (e.g., other collection changes), the intro card rebuilds unnecessarily.
- **Expected impact if unfixed:** Extra builds of GlassCard + Column subtree; minor but compounds with parent rebuilds.
- **Remediation:** Use `ref.watch(scanQuotaProvider.select((q) => q?.scansUsed))` to rebuild only when `scansUsed` or `isPremium` actually changes.
- **Expected gain:** Fewer rebuilds of the intro card; ~10-20% reduction in widget churn on quota updates.
- **Validation method:** Add `debugPrint` in `_ScanIntro.build` — confirm it fires only on material quota changes.
- **Spec note:** —

### [Low] Frontend: Fixed 1500ms splash delay

- **Location:** `lib/main.dart:109`
- **Category:** CWV
- **Symptom:** Fixed 1500ms minimum splash even when auth completes in <200ms.
- **Evidence:**
  ```dart
  static const Duration _minSplash = Duration(milliseconds: 1500);
  ```
- **Root cause:** Brand-moment delay is hardcoded and unconditionally waited.
- **Expected impact if unfixed:** Returning users on fast networks always wait 1.5s minimum.
- **Remediation:** Reduce to ~500ms or make adaptive based on whether cached auth credentials exist.
- **Expected gain:** ~1s splash reduction for returning users.
- **Validation method:** Measure splash-to-home transition time on warm start.
- **Spec note:** Acknowledged in `design.md` §D6 — 1500ms minimum splash is a brand-moment requirement.

### [Informational] Frontend: _doc recomputed on every access

- **Location:** `lib/services/scan_quota_service.dart:70-74`
- **Category:** Caching
- **Symptom:** `_auth.currentUser?.uid` and `_firestore.collection('users').doc(uid)` re-resolved per method call.
- **Evidence:**
  ```dart
  String? get _uid => _auth.currentUser?.uid;
  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  ```
- **Root cause:** Getter re-executes allocation each access; UID rarely changes mid-session.
- **Expected impact if unfixed:** Minor GC pressure; negligible latency.
- **Remediation:** Cache `_doc` in a field, invalidate on auth state change.
- **Expected gain:** Marginal; <1% latency.
- **Validation method:** Profile allocation count in DevTools.
- **Spec note:** —

---

## Acknowledged Trade-offs (from change artifacts)

- **1500ms minimum splash** — `design.md` §D6 explicitly accepts the brand-moment delay as a requirement. Not a finding.
- **Transaction for decrementScan** — `design.md` §D4 documents the choice to use a transaction for clamp-at-zero semantics. Security rules (which would allow `FieldValue.increment(-1)`) are out of scope for this change.
- **Firestore doc provisioning in bootstrap** — `design.md` §D6 describes the `Future.wait` pattern for auth + splash delay, but the doc provisioning was added after the design was finalized and is not yet parallelized.

---

## Observability Gaps

- **Firestore listener count** — No metric on active listeners; the critical resource leak will only be discovered via billing alerts or memory crashes.
- **Cold-start latency** — No timing instrumentation around `_bootstrap` phases; cannot measure the impact of serial Firestore operations.
- **Scan flow latency** — No metric on time from tap-to-camera-open; cannot quantify the N+1 read overhead.

---

## Prioritized Remediation Plan

### Block release (Critical / High)
1. **Firestore listener never cancelled** (`lib/services/scan_quota_service.dart:86-109`) — Store subscription and cancel in `ctrl.onCancel`; eliminates memory leak and billing overflow.
2. **N+1 Firestore listeners** (`lib/services/scan_quota_service.dart:78-111`) — Cache broadcast `StreamController` lazily; share one underlying `snapshots()` subscription.
3. **Sequential Firestore round-trips in bootstrap** (`lib/main.dart:146-156`) — Use `set({...}, SetOptions(merge: true))` to eliminate the read; reduces splash latency by 200-600ms.

### Next sprint (Medium)
1. **Transaction overhead in decrementScan** (`lib/services/scan_quota_service.dart:149-154`) — Replace with `FieldValue.increment(-1)` + server-side rule (requires security rules deployment).
2. **Stale _cachedQuota** (`lib/services/scan_quota_service.dart:114-119`) — Perform one-shot `doc.get()` fallback when cache is null.
3. **N+1 Firestore reads on scan tap** (`lib/screens/scan_screen.dart:41`) — Use `ref.read(scanQuotaProvider).valueOrNull` instead of creating a new stream subscription.
4. **Candidate tiles re-animate** (`lib/screens/scan_screen.dart:419-421`) — Use stable keys or `Animate(autoPlay: true)` to prevent re-animation on rebuild.
5. **dotenv and Firebase init serialized** (`lib/main.dart:26-31`) — Parallelize via `Future.wait`.
6. **Analytics blocks startup** (`lib/main.dart:45-46`) — Fire-and-forget `logAppOpen()`; defer service creation.

### Backlog (Low / Informational)
1. **Redundant recordScan vs tryRecordScan** (`lib/services/scan_quota_service.dart:122-142`) — Deprecate `recordScan`; route all callers through `tryRecordScan`.
2. **Three setState calls** (`lib/screens/scan_screen.dart:56-59, 79-82, 101`) — Combine post-scan state update into single `setState`.
3. **Closure allocation per tile** (`lib/screens/scan_screen.dart:251`) — Pass index to tile; lookup in parent method.
4. **_ScanIntro rebuilds** (`lib/screens/scan_screen.dart:270`) — Use `ref.watch(...select(...))` to rebuild only on material changes.
5. **Fixed 1500ms splash** (`lib/main.dart:109`) — Reduce to 500ms or make adaptive (acknowledged trade-off).
6. **_doc recomputed** (`lib/services/scan_quota_service.dart:70-74`) — Cache in field; invalidate on auth change.

---

## Validation Plan

Before merging, re-measure:
- [ ] Active Firestore listener count via Firestore console — target: 1 listener per user session
- [ ] Memory growth after 50 scan attempts via Flutter DevTools — target: <10 MB growth
- [ ] Cold-start time-to-home via `Timeline` instrumentation — target: <2s on cellular
- [ ] Scan tap-to-camera latency via `debugProfileBuildsEnabled` — target: <300ms
- [ ] First-frame time via `flutter run --profile` — target: <1.5s on fast network

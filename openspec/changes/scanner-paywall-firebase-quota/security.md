# Security Report — Scanner Paywall Firebase Quota

**Change:** `openspec/changes/scanner-paywall-firebase-quota/`
**Scan type:** SAST + SCA
**Scope:** diff vs `main`
**Branch:** `scanner-paywall-firebase-quota`
**Languages detected:** Dart (Flutter), Swift (generated), C++ (generated)
**Modules in scope:** auth bootstrap, scan quota service, scan gating UI, l10n, test suite
**Date:** 2025-07-18

## Executive Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 2 |
| Medium | 1 |
| Low | 1 |
| **Total** | **4** |

**Risk posture:** The change introduces Firebase Auth + Firestore as the trust backbone for quota enforcement. The two High findings are a silent auth-failure path that leaves the app unauthenticated without any user-visible signal, and a TOCTOU race between the quota check and the increment that a concurrent client can exploit to exceed the free limit. No Critical flaws were found. SCA is clean — both new dependencies are first-party Google packages with no known CVEs.

**Verdict:** Release after High fixed

---

## Module Summary

| Module | Files | Highest Severity |
|--------|-------|------------------|
| Auth bootstrap | `lib/main.dart` | High |
| Scan quota service | `lib/services/scan_quota_service.dart` | High |
| Scan gating UI | `lib/screens/scan_screen.dart` | Medium |
| Dependencies | `pubspec.yaml`, `pubspec.lock` | Low (informational) |

---

## SAST Findings

### [High] CWE-390 — Silent auth failure leaves app unauthenticated

- **Module:** `auth bootstrap`
- **File:** `lib/main.dart:130-134`
- **Flaw category:** Improper Error Handling — Detection of Error Condition Without Action
- **CWE:** CWE-390
- **OWASP 2025:** A09 — Security Logging and Monitoring Failures
- **Evidence:**
  ```dart
  Future<void> signIn() async {
    try {
      await FirebaseAuth.instance.signInAnonymously()
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
  ```
- **Exploit scenario:** An attacker on a degraded or intercepted network causes `signInAnonymously()` to throw or time out; the catch block swallows the error silently, `currentUser` remains null, the quota doc upsert is skipped, and the app proceeds to `HomeScreen` with no authenticated identity — bypassing quota tracking entirely.
- **Remediation:**
  ```dart
  Future<void> signIn() async {
    try {
      await FirebaseAuth.instance.signInAnonymously()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      widget.analytics.logEvent(
        name: 'auth_bootstrap_failed',
        parameters: {'error': '$e'},
      );
    }
  }
  ```
  Additionally, treat a null `currentUser` after `Future.wait` as a fatal state and show a retry screen rather than navigating to `HomeScreen`.
- **Spec note:** —

---

### [High] CWE-367 — TOCTOU race between mayScan() and recordScan()

- **Module:** `scan quota service`
- **File:** `lib/services/scan_quota_service.dart:114-126`
- **Flaw category:** Time-of-check Time-of-use (TOCTOU)
- **CWE:** CWE-367
- **OWASP 2025:** A04 — Insecure Design
- **Taint flow:** `mayScan()` reads `_cachedQuota.scansUsed` → returns `true` → `recordScan()` calls `FieldValue.increment(1)` — no atomic link between check and write
- **Evidence:**
  ```dart
  Future<bool> mayScan() async {
    ...
    return !quota.readFailed && quota.scansUsed < kFreeScanLimit;
  }

  Future<void> recordScan() async {
    ...
    await doc.set({'scansUsed': FieldValue.increment(1)}, SetOptions(merge: true));
  }
  ```
- **Exploit scenario:** A modified client fires concurrent scan requests; all pass `mayScan()` before any `recordScan()` commits, exceeding the free limit by N-1 scans where N is the concurrency level.
- **Remediation:** Merge the check and increment into a single Firestore transaction:
  ```dart
  Future<bool> tryRecordScan() async {
    if (_effectivePremium) return true;
    final doc = _doc;
    if (doc == null) return false;
    return await _firestore.runTransaction((tx) async {
      final snap = await tx.get(doc);
      final current = (snap.data()?['scansUsed'] as num?)?.toInt() ?? 0;
      if (current >= kFreeScanLimit) return false;
      tx.set(doc, {'scansUsed': current + 1}, SetOptions(merge: true));
      return true;
    });
  }
  ```
- **Spec note:** —

---

### [Medium] CWE-284 — Null currentUser after failed auth not treated as fatal

- **Module:** `auth bootstrap`
- **File:** `lib/main.dart:144-157`
- **Flaw category:** Improper Access Control
- **CWE:** CWE-284
- **OWASP 2025:** A01 — Broken Access Control
- **Evidence:**
  ```dart
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final docRef = FirebaseFirestore.instance
        .collection('users').doc(user.uid);
    ...
  }
  // Falls through to HomeScreen even if user is null
  widget.analytics.logScreenView(screenName: 'home');
  setState(() => _ready = true);
  ```
- **Exploit scenario:** When `signInAnonymously()` silently fails (see High finding above), `currentUser` is null, the quota doc is never created, and the app navigates to `HomeScreen`. The `ScanQuotaService` then operates with a null uid — `quotaStream()` returns a fail-closed quota, but the service is in an undefined state with no audit trail.
- **Remediation:** After `Future.wait`, if `currentUser` is null, set an error state and show a retry screen instead of navigating to `HomeScreen`.
- **Spec note:** —

---

### [Low] CWE-209 — Firestore stream error details silently discarded

- **Module:** `scan quota service`
- **File:** `lib/services/scan_quota_service.dart:101`
- **Flaw category:** Improper Error Handling — Loss of Audit Trail
- **CWE:** CWE-209 (inverse — information loss)
- **OWASP 2025:** A09 — Security Logging and Monitoring Failures
- **Evidence:**
  ```dart
  onError: (_) {
    ctrl.add(ScanQuota(
      scansUsed: kFreeScanLimit,
      isPremium: _isPremiumOverride,
      readFailed: true,
    ));
  },
  ```
- **Exploit scenario:** Firestore permission denials, network issues, or data tampering are indistinguishable from the client's perspective, hampering incident response and making it impossible to differentiate an attack from a transient failure.
- **Remediation:** Log the error object (with redacted PII) to the existing analytics service:
  ```dart
  onError: (error) {
    // Log to analytics for incident response
    ctrl.add(ScanQuota(...));
  },
  ```
- **Spec note:** —

---

## SCA Findings

No known CVEs for the new dependencies.

| Package | Version | Known CVEs | Severity | Fix Available |
|---------|---------|-----------|----------|---------------|
| `firebase_auth` | 5.7.0 | None | N/A | N/A |
| `cloud_firestore` | 5.6.12 | None | N/A | N/A |

Both are first-party Google packages published under BSD-3-Clause (permissive, no copyleft risk).

---

## Supply Chain Hygiene

- **Lock files present:** Yes (`pubspec.lock` committed)
- **Typosquatting suspects:** None — both packages match canonical pub.dev identifiers with Google-verified publisher status
- **Abandoned dependencies:** `shimmer` 3.0.0 (pre-existing, not introduced by this change) — low maintenance velocity, no recent releases

---

## License Risk

| Package | License | Risk | Commercial Use |
|---------|---------|------|---------------|
| `firebase_auth` | BSD-3-Clause | Low | Permitted |
| `cloud_firestore` | BSD-3-Clause | Low | Permitted |

No GPL / AGPL / SSPL / LGPL packages detected in the new dependency tree.

---

## Acknowledged Trade-offs (from change artifacts)

The following security-relevant decisions were explicitly recorded in the change artifacts and are accepted as-is:

1. **Firestore security rules are out of scope** — `design.md` §Migration Plan states: "Pre-deploy: Add the Firestore security rule restricting each user's doc to their own uid and forbidding client writes to `isPremium`. Out of scope for code." Without these rules, a modified client can set `isPremium: true` or reset `scansUsed` to 0 directly. **This is the single highest-risk item in the change** — the rules must be deployed before enabling traffic.

2. **IS_PREMIUM env flag is a client-side developer escape hatch** — `proposal.md` §Impact states: "the flag defaults to absent/empty; if a release carries `IS_PREMIUM=true` in its `.env`, every user of that build bypasses the gate. Document that `.env` is a build-time asset." The subagent flagged this as Critical, but it is explicitly acknowledged with a procedural mitigation (build-time documentation).

3. **Anonymous auth quota reset on Android** — `proposal.md` §Known limitation and `design.md` §Risks state: "On Android, uninstalling the app rotates SSAID and the new install gets a fresh anonymous uid and a fresh counter — the quota can be reset. iOS is bulletproof (Keychain survives uninstall). This is the documented tradeoff for 'no login required'."

---

## Prioritized Remediation Plan

### Block release (Critical / High)
1. **Silent auth failure** (`lib/main.dart:130-134`) — Log the error and treat null `currentUser` as fatal; show a retry screen instead of navigating to `HomeScreen`.
2. **TOCTOU race** (`lib/services/scan_quota_service.dart:114-126`) — Merge `mayScan()` check and `recordScan()` increment into a single Firestore transaction.

### Next sprint (Medium)
1. **Null currentUser not fatal** (`lib/main.dart:144-157`) — Add error state and retry UI when auth fails.

### Backlog (Low)
1. **Firestore error details discarded** (`lib/services/scan_quota_service.dart:101`) — Log errors to analytics for incident response.

### Deploy-time prerequisite (not code)
1. **Firestore security rules** — Deploy `match /users/{userId} { allow read, write: if request.auth.uid == userId; }` with no client write path for `isPremium` before enabling traffic.

---

## Metrics

- **Files scanned:** 10 (excluding generated platform files and planning artifacts)
- **Flaw density:** 0.5 flaws per 1000 LOC scanned (4 findings / ~870 LOC)
- **Est. remediation effort:** 2–3 hours (High findings require transaction refactor and error handling; Medium/Low are straightforward)

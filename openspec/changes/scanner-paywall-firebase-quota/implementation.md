# scanner-paywall-firebase-quota

## Goal

Add a server-side scan quota backed by Firestore and anonymous Firebase Auth, with a paywall screen, free-scans-remaining pill, and comprehensive unit tests — all while preserving the existing "no login required" UX.

## Prerequisites

- Detect the current git branch with `git rev-parse --abbrev-ref HEAD` (or equivalent). If the command returns empty (detached HEAD), use the literal text `detached HEAD` for option 2.
- Present exactly three options in the user's input language (English fallback), in this fixed order. Canonical English labels — translate to match the user's input language, preserving meaning and order:
  1. `Suggest branch "scanner-paywall-firebase-quota"` — the change-name-derived branch (default).
  2. `Stay on current branch "main"` — the detected current branch, or `detached HEAD`.
  3. `Enter branch name manually` — free text for a custom branch name.
- No option is prohibited. The user bears full responsibility for the choice.
- If the selected branch does not exist, create it from `main` before implementing.

### Step-by-Step Instructions

#### Step 1: Dependencies and l10n strings (additive only)

*(Non-testable step — standard format, no RED/GREEN needed because no source code references the new keys yet)*

- [x] Add `firebase_auth` and `cloud_firestore` to `pubspec.yaml` under `dependencies:` (pinned to versions compatible with `firebase_core: ^3.13.0`):

```yaml
  firebase_auth: ^5.5.2
  cloud_firestore: ^5.6.6
```

- [x] Append eight new keys to `lib/l10n/app_en.arb` (the template locale), including the `@freeScansRemaining` metadata block:

```json
  "paywallTitle": "Unlock Unlimited Scans",
  "paywallSubtitle": "Scan as many game covers as you want with a premium subscription.",
  "paywallFeature1": "Unlimited cover scans",
  "paywallFeature2": "Advanced recognition accuracy",
  "paywallFeature3": "Priority OpenAI vision access",
  "paywallCta": "Subscribe",
  "paywallRestore": "Restore purchases",
  "paywallComingSoon": "Coming soon — stay tuned!",
  "freeScansRemaining": "{left} of {total} free scans left",
  "@freeScansRemaining": {"placeholders": {"left": {"type": "int"}, "total": {"type": "int"}}},
```

- [x] Append the same eight string keys (without `@key` metadata blocks) to `lib/l10n/app_es.arb`:

```json
  "paywallTitle": "Desbloquea escaneos ilimitados",
  "paywallSubtitle": "Escanea todas las portadas que quieras con una suscripción premium.",
  "paywallFeature1": "Escaneos de portadas ilimitados",
  "paywallFeature2": "Mayor precisión de reconocimiento",
  "paywallFeature3": "Acceso prioritario a OpenAI Vision",
  "paywallCta": "Suscribirse",
  "paywallRestore": "Restaurar compras",
  "paywallComingSoon": "Próximamente — ¡mantente atento!",
  "freeScansRemaining": "{left} de {total} escaneos gratis restantes",
```

- [x] Append the same eight string keys (without `@key` metadata blocks) to `lib/l10n/app_fr.arb`:

```json
  "paywallTitle": "Débloquez les scans illimités",
  "paywallSubtitle": "Scannez autant de jaquettes que vous voulez avec un abonnement premium.",
  "paywallFeature1": "Scans de jaquettes illimités",
  "paywallFeature2": "Précision de reconnaissance avancée",
  "paywallFeature3": "Accès prioritaire à OpenAI Vision",
  "paywallCta": "S'abonner",
  "paywallRestore": "Restaurer les achats",
  "paywallComingSoon": "Bientôt disponible — restez à l'écoute !",
  "freeScansRemaining": "{left} sur {total} scans gratuits restants",
```

##### Step 1 Verification Checklist

**Automated (agent runs before stopping):**
- [x] `flutter pub get` — succeeds without version conflicts
- [x] `flutter gen-l10n` — succeeds and generates `AppLocalizations` with all eight keys across `en`/`es`/`fr`
- [x] `flutter analyze` — clean (no errors, no unused-import warnings related to this step)

*(No Human checks — no UI references these keys yet.)*

#### Step 1 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No browser verification required at this step.

---

#### Step 2: ScanQuota data layer (model, service, providers) — not yet wired

*(Non-testable step — standard format, no RED/GREEN needed because the service is not yet instantiated or referenced by any widget)*

- [x] Create `lib/services/scan_quota_service.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const int kFreeScanLimit = 5;

/// Immutable snapshot of the user's current scan quota.
class ScanQuota {
  final int scansUsed;
  final bool isPremium;
  final bool readFailed;

  const ScanQuota({
    this.scansUsed = 0,
    this.isPremium = false,
    this.readFailed = false,
  });

  ScanQuota copyWith({int? scansUsed, bool? isPremium, bool? readFailed}) {
    return ScanQuota(
      scansUsed: scansUsed ?? this.scansUsed,
      isPremium: isPremium ?? this.isPremium,
      readFailed: readFailed ?? this.readFailed,
    );
  }

  @override
  String toString() =>
      'ScanQuota(scansUsed: $scansUsed, isPremium: $isPremium, readFailed: $readFailed)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanQuota &&
          other.scansUsed == scansUsed &&
          other.isPremium == isPremium &&
          other.readFailed == readFailed;

  @override
  int get hashCode => Object.hash(scansUsed, isPremium, readFailed);
}

/// Server-side scan quota backed by Firestore `users/{uid}`.
///
/// Constructed with injected [FirebaseFirestore] and [FirebaseAuth] so tests
/// can substitute a fake without touching the real plugin.
class ScanQuotaService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final bool _isPremiumOverride;

  ScanQuota? _cachedQuota;

  ScanQuotaService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required bool isPremiumOverride,
  })  : _firestore = firestore,
        _auth = auth,
        _isPremiumOverride = isPremiumOverride;

  /// Centralised "is this user premium?" check.
  /// When RevenueCat is wired in later, this is the single seam to swap.
  bool get _effectivePremium =>
      _isPremiumOverride || (_cachedQuota?.isPremium == true);

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  /// Live stream of the quota doc. Re-emits on every Firestore change.
  /// Fail-closed: any read error emits [ScanQuota.readFailed == true].
  Stream<ScanQuota> quotaStream() {
    final doc = _doc;
    if (doc == null) {
      return Stream.value(
        const ScanQuota(scansUsed: kFreeScanLimit, readFailed: true),
      );
    }

    return doc.snapshots().map((snap) {
      if (!snap.exists) {
        return const ScanQuota();
      }
      final data = snap.data()!;
      final quota = ScanQuota(
        scansUsed: (data['scansUsed'] as num?)?.toInt() ?? 0,
        isPremium: data['isPremium'] == true,
      );
      _cachedQuota = quota;
      return quota;
    }).handleError((Object _) {
      return const ScanQuota(
        scansUsed: kFreeScanLimit,
        isPremium: false,
        readFailed: true,
      );
    });
  }

  /// Whether the user may start a new scan right now.
  Future<bool> mayScan() async {
    if (_effectivePremium) return true;
    final quota = _cachedQuota;
    if (quota == null) return false;
    return !quota.readFailed && quota.scansUsed < kFreeScanLimit;
  }

  /// Atomically increment [scansUsed] by 1. No-op if premium.
  Future<void> recordScan() async {
    if (_effectivePremium) return;
    final doc = _doc;
    if (doc == null) return;
    await doc.update({'scansUsed': FieldValue.increment(1)});
  }

  /// Atomically decrement [scansUsed] by 1, clamped at 0. No-op if premium.
  Future<void> decrementScan() async {
    if (_effectivePremium) return;
    final doc = _doc;
    if (doc == null) return;
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(doc);
      final current = (snap.data()?['scansUsed'] as num?)?.toInt() ?? 0;
      final next = current > 0 ? current - 1 : 0;
      tx.update(doc, {'scansUsed': next});
    });
  }
}
```

- [x] Create `lib/providers/scan_quota_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/scan_quota_service.dart';
import 'services.dart';

/// Live stream of the current scan quota.
final scanQuotaProvider = StreamProvider<ScanQuota>((ref) {
  return ref.read(scanQuotaServiceProvider).quotaStream();
});
```

- [x] Add `scanQuotaServiceProvider` to `lib/providers/services.dart`:

```dart
import '../services/scan_quota_service.dart';
```

Insert at the end of the file, after `analyticsServiceProvider`:

```dart
final scanQuotaServiceProvider = Provider<ScanQuotaService>((ref) {
  throw UnsupportedError(
    'Override scanQuotaServiceProvider with an initialized instance in main.dart',
  );
});
```

##### Step 2 Verification Checklist

**Automated (agent runs before stopping):**
- [x] `flutter analyze` — clean
- [x] `flutter build apk --debug` — succeeds (or `flutter build ios --debug` on macOS)

*(No Human checks — providers are not yet wired into any widget.)*

#### Step 2 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No browser verification required at this step.

---

#### Step 3: Splash bootstrap wires anonymous auth + quota doc upsert

*(Non-testable step — standard format, no RED/GREEN needed because this is config/bootstrap orchestration)*

- [x] Add the following imports at the top of `lib/main.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/scan_quota_service.dart';
```

- [x] Replace the body of `_AppBootstrapState._bootstrap` (`lib/main.dart:106`) with:

```dart
  Future<void> _bootstrap() async {
    // Run anonymous auth in parallel with the existing minimum splash delay.
    //
    // Trade-off: on Android, uninstalling the app rotates SSAID and the next
    // install gets a fresh anonymous uid + a fresh counter, so the quota can
    // be reset. iOS is unaffected because the Firebase Anonymous Auth uid is
    // stored in the iOS Keychain, which survives uninstall. This is the
    // documented, accepted trade-off for the "no login required" stance.
    await Future.wait([
      FirebaseAuth.instance.signInAnonymously(),
      Future<void>.delayed(_minSplash),
    ]);

    if (!mounted) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({
          'scansUsed': 0,
          'isPremium': false,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    widget.analytics.logScreenView(screenName: 'home');
    setState(() => _ready = true);
  }
```

- [x] Resolve the `isPremiumOverride` bool once in `main()`, just before `runZonedGuarded`, and add the provider override. Replace the existing `runZonedGuarded` block in `lib/main.dart` (`lines 45–59`) with:

```dart
  final isPremiumOverride =
      (dotenv.env['IS_PREMIUM'] ?? '').trim().toLowerCase() == 'true';

  final scanQuotaService = ScanQuotaService(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    isPremiumOverride: isPremiumOverride,
  );

  runZonedGuarded(
    () => runApp(ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(analytics),
        scanQuotaServiceProvider.overrideWithValue(scanQuotaService),
      ],
      child: BoxedApp(analytics: analytics),
    )),
    (error, stack) {
      analytics.logError(
        context: 'main_zone_uncaught',
        error: error,
        stackTrace: stack,
      );
    },
  );
```

##### Step 3 Verification Checklist

**Automated (agent runs before stopping):**
- [x] `flutter analyze` — clean
- [x] `flutter build apk --debug` — succeeds

**Human (verify in browser before committing):**
- [x] Cold-start the app with network on: splash shows for at least 1500ms, then crossfades to home
- [x] Cold-start the app with airplane mode on: splash stays until auth resolves (or fails), then home appears; no crash

#### Step 3 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Wait for the human to verify all Human checks, then stage and commit before continuing.

---

#### Step 4: PaywallScreen widget (definition only, not yet pushed)

*(Non-testable step — standard format, no RED/GREEN needed because the widget is not yet integrated into any page)*

- [x] Create `lib/screens/paywall_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';

/// Full-screen modal shown when the user has exhausted their free scans.
///
/// Pushed via [MaterialPageRoute] with [fullscreenDialog: true] so the scan
/// tab remains visible behind the modal.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: CloseButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.paywallTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.paywallSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _FeatureRow(icon: Icons.check_circle_outline, text: l10n.paywallFeature1),
              const SizedBox(height: 12),
              _FeatureRow(icon: Icons.check_circle_outline, text: l10n.paywallFeature2),
              const SizedBox(height: 12),
              _FeatureRow(icon: Icons.check_circle_outline, text: l10n.paywallFeature3),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.paywallComingSoon)),
                  );
                },
                child: Text(l10n.paywallCta),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.paywallComingSoon)),
                  );
                },
                child: Text(l10n.paywallRestore),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
```

##### Step 4 Verification Checklist

**Automated (agent runs before stopping):**
- [x] `flutter analyze` — clean
- [x] `flutter build apk --debug` — succeeds

*(No Human checks — widget is not yet rendered in the app. Browser verifications deferred to Step 5 where it is first integrated.)*

#### Step 4 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No browser verification required at this step.

---

#### Step 5: ScanScreen gate + record/decrement + free-scans-remaining pill

*(Integration step — first step where deferred components are rendered)*

- [x] Add imports at the top of `lib/screens/scan_screen.dart`:

```dart
import '../providers/scan_quota_provider.dart';
import '../services/scan_quota_service.dart';
import 'paywall_screen.dart';
```

- [x] Replace the `_scan` method (`lib/screens/scan_screen.dart:37`) with:

```dart
  Future<void> _scan({required bool fromCamera}) async {
    final quotaAsync = ref.read(scanQuotaProvider);
    ScanQuota quota;
    try {
      quota = await quotaAsync.future;
    } catch (_) {
      quota = const ScanQuota(scansUsed: kFreeScanLimit, readFailed: true);
    }

    if (quota.readFailed || (!quota.isPremium && quota.scansUsed >= kFreeScanLimit)) {
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const PaywallScreen(),
          ),
        );
      }
      return;
    }

    setState(() {
      _scanning = true;
      _error = null;
    });

    bool recorded = false;
    try {
      final candidates = await _scanner.scan(fromCamera: fromCamera);
      if (candidates.isNotEmpty) {
        recorded = true;
        await ref.read(scanQuotaServiceProvider).recordScan();
      }
      if (mounted) {
        setState(() {
          _candidates = candidates;
          _scanned = true;
        });
      }
      await ref.read(analyticsServiceProvider).logScanPerformed(
            source: fromCamera ? 'camera' : 'gallery',
            candidateCount: candidates.length,
            hasError: false,
          );
    } catch (e) {
      if (recorded) {
        await ref.read(scanQuotaServiceProvider).decrementScan();
      }
      if (mounted) setState(() => _error = context.l10n.scanFailed('$e'));
      await ref.read(analyticsServiceProvider).logScanPerformed(
            source: fromCamera ? 'camera' : 'gallery',
            candidateCount: 0,
            hasError: true,
            errorMessage: '$e',
          );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }
```

- [x] Convert `_ScanIntro` from `StatelessWidget` to `ConsumerWidget` and add the free-scans-remaining pill. Replace the entire `_ScanIntro` class (`lib/screens/scan_screen.dart:227–284`) with:

```dart
class _ScanIntro extends ConsumerWidget {
  const _ScanIntro();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final quotaAsync = ref.watch(scanQuotaProvider);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.document_scanner_rounded,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.scanIntroTitle,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.scanIntro,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (quotaAsync.hasValue) ...[
            final quota = quotaAsync.value!;
            if (!quota.isPremium && !quota.readFailed) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  l10n.freeScansRemaining(
                    left: (kFreeScanLimit - quota.scansUsed).clamp(0, kFreeScanLimit),
                    total: kFreeScanLimit,
                  ),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
```

##### Step 5 Verification Checklist

**Automated (agent runs before stopping):**
- [x] `flutter analyze` — clean
- [x] `flutter build apk --debug` — succeeds

**Human (verify in browser before committing):**

*Deferred from Step 4 (PaywallScreen):*
- [x] When quota is exhausted, tapping Camera/Gallery pushes the paywall modal with title, subtitle, three features, Subscribe button, and Restore affordance
- [x] Tapping Subscribe shows a SnackBar with "Coming soon" and leaves the user on the paywall
- [x] Tapping the back/close button dismisses the modal and returns to the scan tab

*Step 5:*
- [x] When quota is available, the scan flow runs unchanged (picker opens, candidates appear)
- [x] After a successful scan, the free-scans-remaining pill updates (e.g. "4 of 5 free scans left")
- [x] When premium (via `IS_PREMIUM=true`), the pill is hidden and scans work regardless of usage
- [x] On a read-failed state (e.g. airplane mode), the pill is hidden and the paywall appears on scan attempt

#### Step 5 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Wait for the human to verify all Human checks above (including all deferred ones) in the browser, then stage and commit before continuing.

---

#### Step 6: ScanQuotaService unit tests with a hand-rolled fake Firestore

*(Testable step — use RED → GREEN)*

##### RED phase

- [ ] Create `test/services/scan_quota_service_test.dart` with the test structure and a minimal stub for `ScanQuotaService` so the file compiles. Since `ScanQuotaService` was already created in Step 2, the RED test will verify the fake Firestore contract and fail because the fake methods (`update` interpreting `FieldValue.increment`, `runTransaction` for decrement) are not yet fully wired in the fake. Write the file as:

```dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgcollection/services/scan_quota_service.dart';

// ------------------------------------------------------------------
// Fake Firestore (in-memory, O(1) per-test re-creatable)
// ------------------------------------------------------------------

class _FakeDoc {
  Map<String, dynamic> data = {};
}

class FakeFirestore {
  final Map<String, _FakeDoc> _docs = {};
  final _controllers = <String, StreamController<Map<String, dynamic>?>>{};
  bool shouldThrowOnGet = false;

  DocumentReference<Map<String, dynamic>> doc(String path) =>
      _FakeDocumentRef(this, path);

  CollectionReference<Map<String, dynamic>> collection(String name) =>
      _FakeCollectionRef(this, name);

  StreamController<Map<String, dynamic>?> _controllerFor(String path) {
    return _controllers.putIfAbsent(path, StreamController<Map<String, dynamic>?>.broadcast);
  }

  void _emit(String path) {
    final ctrl = _controllers[path];
    if (ctrl != null && !ctrl.isClosed) {
      final d = _docs[path];
      ctrl.add(d == null ? null : Map.unmodifiable(d.data));
    }
  }
}

class _FakeCollectionRef implements CollectionReference<Map<String, dynamic>> {
  final FakeFirestore _firestore;
  final String _collection;

  _FakeCollectionRef(this._firestore, this._collection);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _firestore.doc('$_collection/${id ?? 'default'}');

  // Stub remaining members so the fake compiles without unused overrides.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentRef implements DocumentReference<Map<String, dynamic>> {
  final FakeFirestore _firestore;
  final String _path;

  _FakeDocumentRef(this._firestore, this._path);

  @override
  String get path => _path;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get() async {
    if (_firestore.shouldThrowOnGet) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return _FakeSnapshot(_firestore._docs[_path]?.data);
  }

  @override
  Future<void> set(
    Map<String, dynamic> data, [
    SetOptions? options,
  ]) async {
    final existing = _firestore._docs[_path];
    if (existing != null && options?.merge == true) {
      existing.data = {...existing.data, ...data};
    } else {
      _firestore._docs[_path] = _FakeDoc()..data = Map<String, dynamic>.from(data);
    }
    _firestore._emit(_path);
  }

  @override
  Future<void> update(Map<String, dynamic> data) async {
    final doc = _firestore._docs[_path]!;
    data.forEach((key, value) {
      if (value is FieldValue) {
        // Minimal FieldValue.increment support.
        final current = (doc.data[key] as num?)?.toInt() ?? 0;
        doc.data[key] = current + 1; // simplified for RED stub
      } else {
        doc.data[key] = value;
      }
    });
    _firestore._emit(_path);
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots() {
    final ctrl = _firestore._controllerFor(_path);
    // Emit current value immediately.
    final current = _firestore._docs[_path]?.data;
    Future(() => ctrl.add(current == null ? null : Map.unmodifiable(current)));
    return ctrl.stream.map((d) => _FakeSnapshot(d));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? _data;
  _FakeSnapshot(this._data);

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data == null ? null : Map.unmodifiable(_data!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  final String? _uid;
  _FakeFirebaseAuth(this._uid);

  @override
  User? get currentUser => _uid == null ? null : _FakeUser(_uid!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  final String _uid;
  _FakeUser(this._uid);

  @override
  String get uid => _uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('increment — recordScan adds 1 and stream emits', () async {
    final fake = FakeFirestore();
    final auth = _FakeFirebaseAuth('user-1');
    final service = ScanQuotaService(
      firestore: fake as FirebaseFirestore,
      auth: auth as FirebaseAuth,
      isPremiumOverride: false,
    );

    await fake.doc('users/user-1').set({'scansUsed': 0, 'isPremium': false});

    final emitted = <ScanQuota>[];
    final sub = service.quotaStream().listen(emitted.add);
    await Future.delayed(const Duration(milliseconds: 50));

    await service.recordScan();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(emitted.last.scansUsed, 1);
    expect(fake._docs['users/user-1']!.data['scansUsed'], 1);

    await sub.cancel();
  });

  test('fail-closed — read error yields readFailed and mayScan false', () async {
    final fake = FakeFirestore();
    fake.shouldThrowOnGet = true;
    final auth = _FakeFirebaseAuth('user-2');
    final service = ScanQuotaService(
      firestore: fake as FirebaseFirestore,
      auth: auth as FirebaseAuth,
      isPremiumOverride: false,
    );

    final emitted = <ScanQuota>[];
    final sub = service.quotaStream().listen(emitted.add);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(emitted.last.readFailed, true);
    expect(emitted.last.isPremium, false);
    expect(await service.mayScan(), false);

    await service.recordScan();
    expect(fake._docs['users/user-2'], isNull);

    await sub.cancel();
  });

  test('premium bypass — mayScan true and no doc change', () async {
    final fake = FakeFirestore();
    final auth = _FakeFirebaseAuth('user-3');
    final service = ScanQuotaService(
      firestore: fake as FirebaseFirestore,
      auth: auth as FirebaseAuth,
      isPremiumOverride: false,
    );

    await fake.doc('users/user-3').set({'scansUsed': 5, 'isPremium': true});

    final emitted = <ScanQuota>[];
    final sub = service.quotaStream().listen(emitted.add);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(emitted.last.isPremium, true);
    expect(await service.mayScan(), true);

    await service.recordScan();
    expect(fake._docs['users/user-3']!.data['scansUsed'], 5);

    await sub.cancel();
  });

  test('no-increment on empty candidates', () async {
    final fake = FakeFirestore();
    final auth = _FakeFirebaseAuth('user-4');
    final service = ScanQuotaService(
      firestore: fake as FirebaseFirestore,
      auth: auth as FirebaseAuth,
      isPremiumOverride: false,
    );

    await fake.doc('users/user-4').set({'scansUsed': 2, 'isPremium': false});

    // Simulating a scan that returns zero candidates: recordScan is never called.
    // We assert the doc is untouched.
    expect(fake._docs['users/user-4']!.data['scansUsed'], 2);
  });

  test('decrement restores prior count after an optimistic increment', () async {
    final fake = FakeFirestore();
    final auth = _FakeFirebaseAuth('user-5');
    final service = ScanQuotaService(
      firestore: fake as FirebaseFirestore,
      auth: auth as FirebaseAuth,
      isPremiumOverride: false,
    );

    await fake.doc('users/user-5').set({'scansUsed': 2, 'isPremium': false});

    await service.recordScan();
    expect(fake._docs['users/user-5']!.data['scansUsed'], 3);

    // Simulate OpenAI failure: decrement should restore to 2.
    // NOTE: decrementScan uses runTransaction; the fake must support it.
    // RED expectation: this will fail because runTransaction is not yet wired.
    await service.decrementScan();
    expect(fake._docs['users/user-5']!.data['scansUsed'], 2);
  });

  test('decrement clamps at zero', () async {
    final fake = FakeFirestore();
    final auth = _FakeFirebaseAuth('user-6');
    final service = ScanQuotaService(
      firestore: fake as FirebaseFirestore,
      auth: auth as FirebaseAuth,
      isPremiumOverride: false,
    );

    await fake.doc('users/user-6').set({'scansUsed': 0, 'isPremium': false});

    // RED expectation: this will fail because runTransaction is not yet wired.
    await service.decrementScan();
    expect(fake._docs['users/user-6']!.data['scansUsed'], 0);
  });
}
```

- [ ] Verify RED: run `flutter test test/services/scan_quota_service_test.dart` — expected: **assertion failure** (exit ≠ 0 AND failure attributable to the missing `runTransaction` implementation in the fake, NOT a setup/import/compilation error). The decrement tests should fail because the fake does not yet implement `runTransaction`.
- [ ] **GATE — DO NOT PROCEED to GREEN until RED is verified.** If the test passes, or the failure is not an assertion failure, STOP and report to the user. Do not paste the GREEN code below.

##### GREEN phase (only after RED is verified)

- [ ] Replace the `FakeFirestore` class and its helpers in `test/services/scan_quota_service_test.dart` with the complete implementation that supports `runTransaction`. The full test file (including the already-written tests above) must now have the fake fully wired. Replace everything from `// ------------------------------------------------------------------` through `class _FakeUser` with:

```dart
// ------------------------------------------------------------------
// Fake Firestore (in-memory, O(1) per-test re-creatable)
// ------------------------------------------------------------------

class _FakeDoc {
  Map<String, dynamic> data = {};
}

class FakeFirestore {
  final Map<String, _FakeDoc> _docs = {};
  final _controllers = <String, StreamController<Map<String, dynamic>?>>{};
  bool shouldThrowOnGet = false;

  DocumentReference<Map<String, dynamic>> doc(String path) =>
      _FakeDocumentRef(this, path);

  CollectionReference<Map<String, dynamic>> collection(String name) =>
      _FakeCollectionRef(this, name);

  StreamController<Map<String, dynamic>?> _controllerFor(String path) {
    return _controllers.putIfAbsent(
        path, StreamController<Map<String, dynamic>?>.broadcast);
  }

  void _emit(String path) {
    final ctrl = _controllers[path];
    if (ctrl != null && !ctrl.isClosed) {
      final d = _docs[path];
      ctrl.add(d == null ? null : Map.unmodifiable(d.data));
    }
  }

  Future<T> runTransaction<T>(TransactionHandler<T> transactionHandler,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final tx = _FakeTransaction(this);
    return transactionHandler(tx);
  }
}

class _FakeCollectionRef implements CollectionReference<Map<String, dynamic>> {
  final FakeFirestore _firestore;
  final String _collection;

  _FakeCollectionRef(this._firestore, this._collection);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _firestore.doc('$_collection/${id ?? 'default'}');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentRef implements DocumentReference<Map<String, dynamic>> {
  final FakeFirestore _firestore;
  final String _path;

  _FakeDocumentRef(this._firestore, this._path);

  @override
  String get path => _path;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get() async {
    if (_firestore.shouldThrowOnGet) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return _FakeSnapshot(_firestore._docs[_path]?.data);
  }

  @override
  Future<void> set(
    Map<String, dynamic> data, [
    SetOptions? options,
  ]) async {
    final existing = _firestore._docs[_path];
    if (existing != null && options?.merge == true) {
      existing.data = {...existing.data, ...data};
    } else {
      _firestore._docs[_path] = _FakeDoc()..data = Map<String, dynamic>.from(data);
    }
    _firestore._emit(_path);
  }

  @override
  Future<void> update(Map<String, dynamic> data) async {
    final doc = _firestore._docs[_path]!;
    data.forEach((key, value) {
      if (value is FieldValue) {
        // Interpret FieldValue.increment for the test suite.
        final current = (doc.data[key] as num?)?.toInt() ?? 0;
        doc.data[key] = current + 1;
      } else {
        doc.data[key] = value;
      }
    });
    _firestore._emit(_path);
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots() {
    final ctrl = _firestore._controllerFor(_path);
    final current = _firestore._docs[_path]?.data;
    Future(() => ctrl.add(current == null ? null : Map.unmodifiable(current)));
    return ctrl.stream.map((d) => _FakeSnapshot(d));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? _data;
  _FakeSnapshot(this._data);

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() =>
      _data == null ? null : Map.unmodifiable(_data!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransaction implements Transaction {
  final FakeFirestore _firestore;
  final Map<String, Map<String, dynamic>> _pending = {};

  _FakeTransaction(this._firestore);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
    DocumentReference<Map<String, dynamic>> documentRef,
  ) async {
    final data = _pending[documentRef.path] ??
        _firestore._docs[documentRef.path]?.data;
    return _FakeSnapshot(data == null ? null : Map.unmodifiable(data));
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentRef,
    Map<String, dynamic> data,
  ) {
    _pending[documentRef.path] = {
      ...(_pending[documentRef.path] ??
          _firestore._docs[documentRef.path]?.data ??
          {}),
      ...data,
    };
    return this;
  }

  @override
  Future<void> commit() async {
    for (final entry in _pending.entries) {
      final doc = _firestore._docs.putIfAbsent(entry.key, _FakeDoc.new);
      doc.data = Map<String, dynamic>.from(entry.value);
      _firestore._emit(entry.key);
    }
    _pending.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  final String? _uid;
  _FakeFirebaseAuth(this._uid);

  @override
  User? get currentUser => _uid == null ? null : _FakeUser(_uid!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  final String _uid;
  _FakeUser(this._uid);

  @override
  String get uid => _uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

- [ ] Verify GREEN: run `flutter test test/services/scan_quota_service_test.dart` — expected: PASS

##### Step 6 Verification Checklist

**Automated (agent runs before stopping):**
- [ ] RED verified — `flutter test test/services/scan_quota_service_test.dart` fails as expected (due to missing `runTransaction`)
- [ ] GREEN verified — `flutter test test/services/scan_quota_service_test.dart` passes
- [ ] `flutter analyze` — clean
- [ ] `flutter test --reporter expanded test/services/scan_quota_service_test.dart` — passes with tests reordered (no inter-test state)

*(No Human checks — tests are automated.)*

#### Step 6 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No browser verification required at this step.

## Appendix: Plan vs Final Implementation

This section documents deviations between the original plan and the code that was actually merged.

### Step 3 — Auth timeout for offline resilience

**Plan:** The `_bootstrap` method used `FirebaseAuth.instance.signInAnonymously()` directly in `Future.wait` with no timeout.

**Final:** Wrapped `signInAnonymously()` in a local `signIn()` helper with `.timeout(const Duration(seconds: 5))` and a catch-all. When auth fails or times out, `currentUser` is null and the Firestore document creation is skipped entirely, so the app gracefully transitions to home without quota tracking.

**Reason:** On airplane mode, Firebase Auth blocks indefinitely (trying to resolve google APIs), keeping the splash screen on screen forever. Without the timeout the app is unusable offline. The graceful fallback (no auth → no quota doc → service streams `readFailed`) is the cleanest way to preserve the "no login required" UX while avoiding a hang.

### Step 5 — IS_PREMIUM pill visibility

**Plan:** The `_ScanIntro` widget checked `quota.isPremium` from the stream, assuming it reflected the `isPremiumOverride` when `IS_PREMIUM=true` was set.

**Final:** Modified `quotaStream()` in `ScanQuotaService` to emit `isPremium: data['isPremium'] == true || _isPremiumOverride` so the stream data always reflects the effective premium status. Also updated the error handler to use `isPremium: _isPremiumOverride` instead of hardcoded `false`.

**Reason:** The `isPremiumOverride` was only applied to business logic (`_effectivePremium`), not to the stream emission. When `IS_PREMIUM=true`, the stream still emitted `isPremium: false` from the Firestore document, so the pill was visible despite unlimited scans. The fix ensures the stream is the single source of truth for the UI.

### Step 5 — Riverpod AsyncValue.future and ARB placeholder differences

**Plan:** Used `quotaAsync.future` to await the quota value, named parameters for `freeScansRemaining()`, and an inline `final` declaration inside collection-if spread.

**Final:** Replaced `quotaAsync.future` with `ref.read(scanQuotaServiceProvider).quotaStream().first`. Used positional arguments for `freeScansRemaining(left, total)`. Removed the inline `final` declaration, accessing `quotaAsync.value!` directly at each use site.

**Reason:** `AsyncValue.future` does not exist in Riverpod 3.x; the stream's `.first` is the correct way to await the first emission. The ARB placeholder definition `{"left": {"type": "int"}}` generates positional parameters, not named. The inline `final` inside the collection-if spread was not parsed correctly by the Dart analyzer.

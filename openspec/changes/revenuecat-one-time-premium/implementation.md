# revenuecat-one-time-premium

## Goal

Add a store-agnostic one-time premium purchase path via RevenueCat, wiring the paywall to real purchase/restore/price display and lighting up the existing quota gate through a promote-only bridge.

## Prerequisites

- Detect the current git branch with `git rev-parse --abbrev-ref HEAD` (or equivalent). If the command returns empty (detached HEAD), use the literal text `detached HEAD` for option 2.
- Present exactly three options in the user's input language (English fallback), in this fixed order. Canonical English labels — translate to match the user's input language, preserving meaning and order:
  1. `Suggest branch "revenuecat-one-time-premium"` — the change-name-derived branch (default).
  2. `Stay on current branch "{current-branch}"` — the detected current branch, or `detached HEAD`.
  3. `Enter branch name manually` — free text for a custom branch name.
- No option is prohibited. The user bears full responsibility for the choice.
- If the selected branch does not exist, create it from `main` before implementing.

### Step-by-Step Instructions

#### Step 1: Purchase seam — dependency, interface, models

*(Non-testable step — standard format)*

- [x] Add `purchases_flutter` dependency to `pubspec.yaml` (latest stable version).

```yaml
  purchases_flutter: ^8.4.0
```

- [x] Create `lib/services/purchase/purchase_service.dart`:

```dart
/// Plain model for a purchasable product.
class PurchaseProduct {
  final String id;
  final String priceString;

  const PurchaseProduct({
    required this.id,
    required this.priceString,
  });
}

/// Outcome of a purchase or restore attempt.
sealed class PurchaseOutcome {
  const PurchaseOutcome();
}

final class PurchaseSuccess extends PurchaseOutcome {
  const PurchaseSuccess();
}

final class PurchaseCancelled extends PurchaseOutcome {
  const PurchaseCancelled();
}

final class PurchaseError extends PurchaseOutcome {
  final String message;
  const PurchaseError(this.message);
}

/// Store-agnostic purchase service.
///
/// The single seam every consumer talks to. No `purchases_flutter` type
/// appears in this file.
abstract class PurchaseService {
  /// Configure the store SDK. Call once before [runApp].
  Future<void> initialize();

  /// Bind the store identity to the given uid.
  Future<void> identify(String uid);

  /// Whether the user currently has premium entitlement.
  Future<bool> isPremium();

  /// Stream of premium entitlement changes.
  Stream<bool> premiumUpdates();

  /// The premium product with localized price, or null if unavailable.
  Future<PurchaseProduct?> premiumProduct();

  /// Initiate a purchase of the premium product.
  Future<PurchaseOutcome> purchasePremium();

  /// Restore previous purchases.
  Future<PurchaseOutcome> restore();
}
```

##### Step 1 Verification Checklist

**Automated (agent runs before stopping):**
- [x] `flutter pub get` — completes without errors
- [x] `flutter analyze` — zero issues in `lib/services/purchase/purchase_service.dart`

**Human (verify in browser before committing):**
*(No Human checks — interface has no visible UI yet.)*

#### Step 1 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No browser verification required at this step.

---

#### Step 2: RevenueCat implementation

*(Non-testable step — standard format)*

- [x] Create `lib/services/purchase/revenuecat_purchase_service.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:purchases_flutter/purchases_flutter.dart';

import 'purchase_service.dart';

/// The ONLY file in the app that imports `purchases_flutter`.
/// Implements [PurchaseService] over RevenueCat.
class RevenueCatPurchaseService implements PurchaseService {
  final _premiumController = StreamController<bool>.broadcast();
  void Function()? _removeListener;

  @override
  Future<void> initialize() async {
    final apiKey = Platform.isIOS
        ? const String.fromEnvironment('REVENUECAT_IOS_KEY')
        : const String.fromEnvironment('REVENUECAT_ANDROID_KEY');

    final configuration = PurchasesConfiguration(apiKey);
    await Purchases.configure(configuration);

    _removeListener = Purchases.addCustomerInfoUpdateListener((info) {
      final isPremium = info.entitlements.active.containsKey('premium');
      _premiumController.add(isPremium);
    });
  }

  @override
  Future<void> identify(String uid) async {
    await Purchases.logIn(uid);
  }

  @override
  Future<bool> isPremium() async {
    final info = await Purchases.getCustomerInfo();
    return info.entitlements.active.containsKey('premium');
  }

  @override
  Stream<bool> premiumUpdates() => _premiumController.stream;

  @override
  Future<PurchaseProduct?> premiumProduct() async {
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.getPackage('premium');
      if (package == null) return null;
      final storeProduct = package.storeProduct;
      return PurchaseProduct(
        id: storeProduct.identifier,
        priceString: storeProduct.priceString,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PurchaseOutcome> purchasePremium() async {
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.getPackage('premium');
      if (package == null) {
        return const PurchaseError('Product not available');
      }
      final result = await Purchases.purchasePackage(package);
      final isPremium = result.customerInfo.entitlements.active.containsKey('premium');
      return isPremium ? const PurchaseSuccess() : const PurchaseError('Premium not activated');
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseCancelled();
      }
      return PurchaseError(e.message ?? 'Purchase failed');
    } catch (e) {
      return PurchaseError(e.toString());
    }
  }

  @override
  Future<PurchaseOutcome> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      final isPremium = info.entitlements.active.containsKey('premium');
      return isPremium
          ? const PurchaseSuccess()
          : const PurchaseError('No purchases to restore');
    } catch (e) {
      return PurchaseError(e.toString());
    }
  }
}
```

##### Step 2 Verification Checklist

**Automated (agent runs before stopping):**
- [x] `flutter analyze` — zero issues; confirm `purchases_flutter` is imported ONLY by this file and this file imports no Firestore symbol
- [x] Verify via grep that no other file under `lib/` imports `package:purchases_flutter/purchases_flutter.dart`

**Human (verify in browser before committing):**
*(No Human checks — SDK wrapper has no visible UI yet.)*

#### Step 2 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No browser verification required at this step.

---

#### Step 3: ScanQuotaService.markPremium()

*(Non-testable step — standard format; behavioral coverage deferred to Step 7 bridge test)*

- [x] Add `markPremium()` to `lib/services/scan_quota_service.dart` after the existing `decrementScan()` method:

```dart
  /// Promote the current user to premium with a merge write.
  /// No-op when there is no authenticated uid.
  Future<void> markPremium() async {
    final doc = _doc;
    if (doc == null) return;
    await doc.set({'isPremium': true}, SetOptions(merge: true));
  }
```

##### Step 3 Verification Checklist

**Automated (agent runs before stopping):**
- [x] `flutter analyze` — zero issues in `lib/services/scan_quota_service.dart`
- [x] Confirm `_effectivePremium` seam, `quotaStream()`, `IS_PREMIUM` override, and all existing methods are untouched except the additive `markPremium()`

**Human (verify in browser before committing):**
*(No Human checks — no visible UI change.)*

#### Step 3 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No browser verification required at this step.

---

#### Step 4: PremiumBridge

*(Non-testable step — standard format; behavioral coverage deferred to Step 7 bridge test)*

- [ ] Create `lib/services/purchase/premium_bridge.dart`:

```dart
import 'dart:async';

import '../scan_quota_service.dart';
import 'purchase_service.dart';

/// Bootstrap bridge that translates store entitlement updates into
/// `ScanQuotaService.markPremium()` writes, plus a one-shot silent restore
/// for fresh/rotated non-premium uids (Android uninstall self-heal).
class PremiumBridge {
  final PurchaseService _purchaseService;
  final ScanQuotaService _scanQuotaService;
  StreamSubscription<bool>? _premiumSub;
  bool _restoreAttempted = false;

  PremiumBridge({
    required PurchaseService purchaseService,
    required ScanQuotaService scanQuotaService,
  })  : _purchaseService = purchaseService,
        _scanQuotaService = scanQuotaService;

  void start() {
    _premiumSub = _purchaseService.premiumUpdates().listen((isPremium) {
      if (isPremium) {
        _scanQuotaService.markPremium();
      }
    });
    _maybeRestore();
  }

  Future<void> _maybeRestore() async {
    if (_restoreAttempted) return;
    _restoreAttempted = true;
    try {
      final alreadyPremium = await _purchaseService.isPremium();
      if (alreadyPremium) return;
      await _purchaseService.restore();
    } catch (_) {
      // Silent restore failures are swallowed (fire-and-forget).
    }
  }

  void dispose() {
    _premiumSub?.cancel();
  }
}
```

##### Step 4 Verification Checklist

**Automated (agent runs before stopping):**
- [ ] `flutter analyze` — zero issues in `lib/services/purchase/premium_bridge.dart`
- [ ] Confirm `PremiumBridge` imports no `purchases_flutter` symbol and `ScanQuotaService` is the only app service it couples to

**Human (verify in browser before committing):**
*(No Human checks — bridge has no visible UI yet.)*

#### Step 4 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No browser verification required at this step.

---

#### Step 5: Provider + main + bootstrap wiring

*(Non-testable step — standard format)*

- [ ] Add `purchaseServiceProvider` to `lib/providers/services.dart`:

```dart
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  throw UnsupportedError(
    'Override purchaseServiceProvider with an initialized instance in main.dart',
  );
});
```

Also add the import at the top of `lib/providers/services.dart`:

```dart
import '../services/purchase/purchase_service.dart';
```

- [ ] Modify `lib/main.dart` as follows:

Add import:

```dart
import 'services/purchase/purchase_service.dart';
import 'services/purchase/revenuecat_purchase_service.dart';
```

In `main()`, after `AnalyticsService.create()` and before `scanQuotaService` construction, add:

```dart
  final purchaseService = RevenueCatPurchaseService();
  await purchaseService.initialize();
```

Update `ProviderScope` overrides:

```dart
    () => runApp(ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(analytics),
        scanQuotaServiceProvider.overrideWithValue(scanQuotaService),
        purchaseServiceProvider.overrideWithValue(purchaseService),
      ],
```

Update `BoxedApp` constructor and fields:

```dart
class BoxedApp extends StatelessWidget {
  final AnalyticsService analytics;
  final PurchaseService purchaseService;
  final ScanQuotaService scanQuotaService;

  const BoxedApp({
    super.key,
    required this.analytics,
    required this.purchaseService,
    required this.scanQuotaService,
  });
```

Update `home` in `BoxedApp.build`:

```dart
      home: _AppBootstrap(
        analytics: analytics,
        purchaseService: purchaseService,
        scanQuotaService: scanQuotaService,
      ),
```

Update `_AppBootstrap` constructor and fields:

```dart
class _AppBootstrap extends StatefulWidget {
  final AnalyticsService analytics;
  final PurchaseService purchaseService;
  final ScanQuotaService scanQuotaService;

  const _AppBootstrap({
    required this.analytics,
    required this.purchaseService,
    required this.scanQuotaService,
  });
```

In `_AppBootstrapState._bootstrap()`, after `provisionQuotaDoc()` and before the `Future.wait`, add a helper:

```dart
    void startPurchaseBridge() {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      widget.purchaseService.identify(user.uid).catchError((_) {});
      PremiumBridge(
        purchaseService: widget.purchaseService,
        scanQuotaService: widget.scanQuotaService,
      ).start();
    }
```

Update the `Future.wait` call:

```dart
    await Future.wait([
      signIn().then((_) {
        provisionQuotaDoc();
        startPurchaseBridge();
      }),
      Future<void>.delayed(_minSplash),
    ]);
```

##### Step 5 Verification Checklist

**Automated (agent runs before stopping):**
- [ ] `flutter analyze` — zero issues across `lib/providers/services.dart` and `lib/main.dart`
- [ ] Verify that `main.dart` calls `PurchaseService.initialize()` before `runApp`
- [ ] Verify that `_AppBootstrap._bootstrap` calls `identify` and `PremiumBridge.start()` after sign-in and quota provisioning, and that neither call is `await`ed on the splash-critical path

**Human (verify in browser before committing):**
*(No Human checks — wiring is not yet visible in UI.)*

#### Step 5 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No browser verification required at this step.

---

#### Step 6: Paywall wiring + localization

*(Integration step — the paywall is already rendered in the app; all deferred UI checks from prior steps land here.)*

- [ ] Modify `lib/screens/paywall_screen.dart` to:

1. Add imports at the top:

```dart
import '../providers/services.dart';
import '../services/purchase/purchase_service.dart';
```

2. Change `PaywallScreen` from `ConsumerWidget` to `ConsumerStatefulWidget`:

```dart
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  late final Future<PurchaseProduct?> _productFuture;

  @override
  void initState() {
    super.initState();
    _productFuture = ref.read(purchaseServiceProvider).premiumProduct();
  }
```

3. Update `_build` body: replace the `FilledButton` and `TextButton` blocks, and the subtitle text:

```dart
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
                onPressed: () => _handlePurchase(context),
                child: FutureBuilder<PurchaseProduct?>(
                  future: _productFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    final product = snapshot.data;
                    if (product != null) {
                      return Text(l10n.paywallCtaPrice(product.priceString));
                    }
                    return Text(l10n.paywallCtaFallback);
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _handleRestore(context),
                child: Text(l10n.paywallRestore),
              ),
```

4. Add the two handler methods inside `_PaywallScreenState`:

```dart
  Future<void> _handlePurchase(BuildContext context) async {
    final outcome = await ref.read(purchaseServiceProvider).purchasePremium();
    if (!context.mounted) return;
    switch (outcome) {
      case PurchaseSuccess():
        Navigator.of(context).pop();
      case PurchaseCancelled():
        break;
      case PurchaseError():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.paywallPurchaseError)),
        );
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    final outcome = await ref.read(purchaseServiceProvider).restore();
    if (!context.mounted) return;
    switch (outcome) {
      case PurchaseSuccess():
        Navigator.of(context).pop();
      case PurchaseError(:final message):
        final l10n = context.l10n;
        final text = message.toLowerCase().contains('no purchases') ||
                message.toLowerCase().contains('nothing')
            ? l10n.paywallNothingToRestore
            : l10n.paywallRestoreError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text)),
        );
      case PurchaseCancelled():
        break;
    }
  }
```

- [ ] Modify `lib/l10n/app_en.arb`:

Replace the `paywallSubtitle` value:

```json
  "paywallSubtitle": "Scan as many game covers as you want with a one-time purchase.",
```

Replace the `paywallCta` value (change from subscription to one-time wording):

```json
  "paywallCta": "Unlock",
```

Add the new keys after `paywallComingSoon`:

```json
  "paywallCtaPrice": "Unlock for {price}",
  "@paywallCtaPrice": {"placeholders": {"price": {"type": "String"}}},
  "paywallCtaFallback": "Unlock Premium",
  "paywallPurchaseError": "Purchase failed. Please try again.",
  "paywallNothingToRestore": "No purchases to restore.",
  "paywallRestoreError": "Restore failed. Please try again.",
```

- [ ] Modify `lib/l10n/app_es.arb` with the same keys/structure:

```json
  "paywallSubtitle": "Escanea todas las portadas que quieras con una compra única.",
  "paywallCta": "Desbloquear",
  "paywallCtaPrice": "Desbloquear por {price}",
  "@paywallCtaPrice": {"placeholders": {"price": {"type": "String"}}},
  "paywallCtaFallback": "Desbloquear Premium",
  "paywallPurchaseError": "Error de compra. Inténtalo de nuevo.",
  "paywallNothingToRestore": "No hay compras para restaurar.",
  "paywallRestoreError": "Error al restaurar. Inténtalo de nuevo.",
```

- [ ] Modify `lib/l10n/app_fr.arb` with the same keys/structure:

```json
  "paywallSubtitle": "Scannez autant de jaquettes que vous voulez avec un achat unique.",
  "paywallCta": "Débloquer",
  "paywallCtaPrice": "Débloquer pour {price}",
  "@paywallCtaPrice": {"placeholders": {"price": {"type": "String"}}},
  "paywallCtaFallback": "Débloquer Premium",
  "paywallPurchaseError": "Échec de l'achat. Veuillez réessayer.",
  "paywallNothingToRestore": "Aucun achat à restaurer.",
  "paywallRestoreError": "Échec de la restauration. Veuillez réessayer.",
```

- [ ] Regenerate localization files:

```bash
flutter gen-l10n
```

##### Step 6 Verification Checklist

**Automated (agent runs before stopping):**
- [ ] `flutter gen-l10n` — completes without errors
- [ ] `flutter analyze` — zero issues across `lib/screens/paywall_screen.dart` and generated `lib/l10n/app_localizations*.dart`

**Human (verify in browser before committing):**

*Deferred from Steps 1–5 (purchase infrastructure is now visible in the paywall):*
- [ ] Trigger the paywall (exhaust free scans or use the dev flag). The CTA displays the real localized price (e.g. "$4.99") instead of a static string.
- [ ] If the store offering is unavailable, the CTA falls back to generic text and does not crash.
- [ ] The paywall subtitle describes a one-time purchase, not a subscription.

*Step 6:*
- [ ] Tap CTA → native purchase sheet opens.
- [ ] Cancel the native sheet → paywall stays open, no error SnackBar.
- [ ] Complete a test purchase (sandbox) → paywall dismisses and the scan gate unlocks.
- [ ] Tap Restore on a device with no prior purchase → localized "No purchases to restore" SnackBar appears, paywall stays open.
- [ ] The explicit Restore button is visible on iOS.

#### Step 6 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Wait for the human to verify all Human checks above (including all deferred ones) in the browser, then stage and commit before continuing.

---

#### Step 7: Tests

*(Testable step — standard format; writing tests and test infrastructure)*

- [ ] Extract shared fake infrastructure from `test/services/scan_quota_service_test.dart` into two new files, then update the original test to import them.

Create `test/fakes/fake_firestore.dart`:

```dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class FakeDoc {
  Map<String, dynamic> data = {};
}

class FakeFirestore implements FirebaseFirestore {
  final Map<String, FakeDoc> docs = {};
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
      final d = docs[path];
      ctrl.add(d == null ? null : Map.unmodifiable(d.data));
    }
  }

  Future<T> runTransaction<T>(TransactionHandler<T> transactionHandler,
      {Duration timeout = const Duration(seconds: 5),
      int maxAttempts = 5}) async {
    final tx = _FakeTransaction(this);
    final result = await transactionHandler(tx);
    await tx.commit();
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    if (_firestore.shouldThrowOnGet) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return _FakeSnapshot(_firestore.docs[_path]?.data);
  }

  @override
  Future<void> delete() async {
    _firestore.docs.remove(_path);
    _firestore._emit(_path);
  }

  @override
  Future<void> set(
    Map<String, dynamic> data, [
    SetOptions? options,
  ]) async {
    final existing = _firestore.docs[_path];
    if (existing != null && options?.merge == true) {
      existing.data = {...existing.data, ...data};
    } else {
      _firestore.docs[_path] = FakeDoc()..data = Map<String, dynamic>.from(data);
    }
    _firestore._emit(_path);
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    final doc = _firestore.docs[_path]!;
    for (final entry in data.entries) {
      final key = entry.key as String;
      final value = entry.value;
      if (value is FieldValue) {
        final current = (doc.data[key] as num?)?.toInt() ?? 0;
        doc.data[key] = current + 1;
      } else {
        doc.data[key] = value;
      }
    }
    _firestore._emit(_path);
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots(
      {bool includeMetadataChanges = false,
      ListenSource source = ListenSource.defaultSource}) {
    final ctrl = _firestore._controllerFor(_path);
    if (_firestore.shouldThrowOnGet) {
      Future(() => ctrl.addError(FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          )));
    } else {
      final current = _firestore.docs[_path]?.data;
      Future(() => ctrl.add(current == null ? null : Map.unmodifiable(current)));
    }
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
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentRef,
  ) async {
    final key = documentRef.path;
    final data = _pending[key] ?? _firestore.docs[key]?.data;
    return _FakeSnapshot(data) as DocumentSnapshot<T>;
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentRef,
    Map<String, dynamic> data,
  ) {
    _pending[documentRef.path] = {
      ...(_pending[documentRef.path] ??
          _firestore.docs[documentRef.path]?.data ??
          {}),
      ...data,
    };
    return this;
  }

  @override
  Future<void> commit() async {
    for (final entry in _pending.entries) {
      final doc = _firestore.docs.putIfAbsent(entry.key, FakeDoc.new);
      doc.data = Map<String, dynamic>.from(entry.value);
      _firestore._emit(entry.key);
    }
    _pending.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

Create `test/fakes/fake_auth.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';

class FakeFirebaseAuth implements FirebaseAuth {
  final String? uid;
  FakeFirebaseAuth(this.uid);

  @override
  User? get currentUser => uid == null ? null : FakeUser(uid!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUser implements User {
  final String uid;
  FakeUser(this.uid);

  @override
  String get uid => uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

- [ ] Update `test/services/scan_quota_service_test.dart` to import the shared fakes and remove the duplicate class definitions. Replace the top of the file (everything before `void main()`) with:

```dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgcollection/services/scan_quota_service.dart';

import '../fakes/fake_auth.dart';
import '../fakes/fake_firestore.dart';
```

Remove the old inline `FakeFirestore`, `_FakeDoc`, `_FakeCollectionRef`, `_FakeDocumentRef`, `_FakeSnapshot`, `_FakeTransaction`, `_FakeFirebaseAuth`, and `_FakeUser` class definitions. Keep `void main()` and all tests unchanged.

- [ ] Create `test/services/purchase/fake_purchase_service.dart`:

```dart
import 'dart:async';

import 'package:vgcollection/services/purchase/purchase_service.dart';

/// Hand-rolled fake for tests. Scriptable outcomes, product, and stream.
class FakePurchaseService implements PurchaseService {
  bool _isPremium = false;
  final _premiumController = StreamController<bool>.broadcast();
  PurchaseOutcome? _purchaseOutcome;
  PurchaseOutcome? _restoreOutcome;
  PurchaseProduct? _product;

  int identifyCallCount = 0;
  String? lastIdentifyUid;
  int purchaseCallCount = 0;
  int restoreCallCount = 0;

  set purchaseOutcome(PurchaseOutcome? value) => _purchaseOutcome = value;
  set restoreOutcome(PurchaseOutcome? value) => _restoreOutcome = value;
  set product(PurchaseProduct? value) => _product = value;

  void emitPremium(bool value) {
    _isPremium = value;
    _premiumController.add(value);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> identify(String uid) async {
    identifyCallCount++;
    lastIdentifyUid = uid;
  }

  @override
  Future<bool> isPremium() async => _isPremium;

  @override
  Stream<bool> premiumUpdates() => _premiumController.stream;

  @override
  Future<PurchaseProduct?> premiumProduct() async => _product;

  @override
  Future<PurchaseOutcome> purchasePremium() async {
    purchaseCallCount++;
    return _purchaseOutcome ?? const PurchaseError('Not configured');
  }

  @override
  Future<PurchaseOutcome> restore() async {
    restoreCallCount++;
    return _restoreOutcome ?? const PurchaseError('Not configured');
  }
}
```

- [ ] Create `test/screens/paywall_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgcollection/l10n/app_localizations.dart';
import 'package:vgcollection/providers/services.dart';
import 'package:vgcollection/screens/paywall_screen.dart';
import 'package:vgcollection/services/purchase/purchase_service.dart';

import '../services/purchase/fake_purchase_service.dart';

void main() {
  testWidgets('price renders in the CTA', (tester) async {
    final fake = FakePurchaseService();
    fake.product = const PurchaseProduct(id: 'premium', priceString: '\$4.99');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [purchaseServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PaywallScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('\$4.99'), findsOneWidget);
  });

  testWidgets('CTA success dismisses the paywall', (tester) async {
    final fake = FakePurchaseService();
    fake.purchaseOutcome = const PurchaseSuccess();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [purchaseServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => const PaywallScreen(),
                    ));
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          }),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsNothing);
  });

  testWidgets('Restore is wired', (tester) async {
    final fake = FakePurchaseService();
    fake.restoreOutcome = const PurchaseError('No purchases to restore');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [purchaseServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PaywallScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(fake.restoreCallCount, 1);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('cancel leaves paywall open with no error', (tester) async {
    final fake = FakePurchaseService();
    fake.purchaseOutcome = const PurchaseCancelled();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [purchaseServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PaywallScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
```

- [ ] Create `test/services/purchase/premium_bridge_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgcollection/services/purchase/premium_bridge.dart';
import 'package:vgcollection/services/scan_quota_service.dart';

import '../../fakes/fake_auth.dart';
import '../../fakes/fake_firestore.dart';
import 'fake_purchase_service.dart';

void main() {
  test('emission true writes isPremium through markPremium', () async {
    final fakeFirestore = FakeFirestore();
    final fakeAuth = FakeFirebaseAuth('user-1');
    final scanQuota = ScanQuotaService(
      firestore: fakeFirestore as FirebaseFirestore,
      auth: fakeAuth as FirebaseAuth,
      isPremiumOverride: false,
    );
    final fakePurchase = FakePurchaseService();

    await fakeFirestore.doc('users/user-1').set({
      'scansUsed': 2,
      'isPremium': false,
    });

    final bridge = PremiumBridge(
      purchaseService: fakePurchase,
      scanQuotaService: scanQuota,
    );
    bridge.start();

    fakePurchase.emitPremium(true);
    await Future.delayed(const Duration(milliseconds: 100));

    final doc = fakeFirestore.docs['users/user-1'];
    expect(doc, isNotNull);
    expect(doc!.data['isPremium'], true);
    expect(doc.data['scansUsed'], 2); // merge preserved sibling field
  });

  test('silent restore runs for non-premium uid', () async {
    final fakePurchase = FakePurchaseService();
    fakePurchase.restoreOutcome = const PurchaseSuccess();

    final fakeFirestore = FakeFirestore();
    final fakeAuth = FakeFirebaseAuth('user-2');
    final scanQuota = ScanQuotaService(
      firestore: fakeFirestore as FirebaseFirestore,
      auth: fakeAuth as FirebaseAuth,
      isPremiumOverride: false,
    );

    final bridge = PremiumBridge(
      purchaseService: fakePurchase,
      scanQuotaService: scanQuota,
    );
    bridge.start();

    await Future.delayed(const Duration(milliseconds: 100));
    expect(fakePurchase.restoreCallCount, 1);
  });

  test('silent restore is skipped for already-premium uid', () async {
    final fakePurchase = FakePurchaseService();
    fakePurchase.restoreOutcome = const PurchaseSuccess();
    fakePurchase.emitPremium(true);

    final fakeFirestore = FakeFirestore();
    final fakeAuth = FakeFirebaseAuth('user-3');
    final scanQuota = ScanQuotaService(
      firestore: fakeFirestore as FirebaseFirestore,
      auth: fakeAuth as FirebaseAuth,
      isPremiumOverride: false,
    );

    final bridge = PremiumBridge(
      purchaseService: fakePurchase,
      scanQuotaService: scanQuota,
    );
    bridge.start();

    await Future.delayed(const Duration(milliseconds: 100));
    expect(fakePurchase.restoreCallCount, 0);
  });
}
```

##### Step 7 Verification Checklist

**Automated (agent runs before stopping):**
- [ ] `flutter test test/services/scan_quota_service_test.dart` — all existing tests still pass after fake extraction
- [ ] `flutter test test/services/purchase/premium_bridge_test.dart` — passes
- [ ] `flutter test test/screens/paywall_screen_test.dart` — passes
- [ ] `flutter analyze` — zero issues across all new and modified test files
- [ ] Verify `FakePurchaseService` imports no `purchases_flutter` symbol
- [ ] Verify `RevenueCatPurchaseService` imports no Firestore symbol

**Human (verify in browser before committing):**
*(No new deferred checks — all UI behavior was already verified in Step 6.)*

#### Step 7 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No browser verification required at this step.

---

## Design Decisions Qualifying as ADR/DDR

The following decisions from `design.md` meet all three ADR/DDR criteria (hard to reverse, surprising without context, real trade-off):

- **D1** — Store-agnostic `PurchaseService` interface + separate RevenueCat impl
- **D2** — Promote-only bridge writing through a new `ScanQuotaService.markPremium()`
- **D4** — Identity anchored via `Purchases.logIn(uid)`, idempotent
- **D5** — Exactly one gated silent restore during bootstrap
- **D6** — Per-platform API keys via `String.fromEnvironment` dart-defines

The project does not currently maintain an `docs/adr/` or `docs/ddr/` directory. If you want these decisions preserved, run `/sai-3-implement` again after creating the directory and approving ADR creation.

## Appendix: Plan vs Final Implementation

### Step 2 — API differences in purchases_flutter 8.11.0

**Plan:** `addCustomerInfoUpdateListener` returns a `void Function()` removal handle stored as `_removeListener`.

**Final:** `addCustomerInfoUpdateListener` returns `void`. The listener function reference is stored directly and passed to `removeCustomerInfoUpdateListener` (visible in the companion dispose path).

**Reason:** The plan was written against an older SDK convention. In purchases_flutter 8.11.0, listeners are registered via `addCustomerInfoUpdateListener(callback)` which returns void, and removal is done via `removeCustomerInfoUpdateListener(callback)`.

**Plan:** `Purchases.purchasePackage(package)` returns a result with `result.customerInfo`.

**Final:** `Purchases.purchasePackage(package)` returns `Future<CustomerInfo>` directly — the CustomerInfo is the return value, not a field on a result wrapper.

**Reason:** SDK 8.x simplified the return type. No wrapper object.

**Plan:** `PlatformException` imported implicitly.

**Final:** Added `import 'package:flutter/services.dart'` for `PlatformException`.

**Reason:** `PlatformException` is not exported by `purchases_flutter`'s public API; it must be imported from `package:flutter/services.dart`.

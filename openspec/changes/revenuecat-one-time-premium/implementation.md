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
*(already applied)*
#### Step 2: RevenueCat implementation
*(already applied)*
#### Step 3: ScanQuotaService.markPremium()
*(already applied)*
#### Step 4: PremiumBridge
*(already applied)*
#### Step 5: Provider + main + bootstrap wiring
*(already applied)*
#### Step 6: Paywall wiring + localization
*(already applied)*
#### Step 7: Tests

*(Testable step — standard format; writing tests and test infrastructure)*

- [x] Extract shared fake infrastructure from `test/services/scan_quota_service_test.dart` into two new files, then update the original test to import them.

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

- [x] Update `test/services/scan_quota_service_test.dart` to import the shared fakes and remove the duplicate class definitions. Replace the top of the file (everything before `void main()`) with:

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

- [x] Create `test/services/purchase/fake_purchase_service.dart`:

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

- [x] Create `test/screens/paywall_screen_test.dart`:

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

- [x] Create `test/services/purchase/premium_bridge_test.dart`:

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
- [x] `flutter test test/services/scan_quota_service_test.dart` — all existing tests still pass after fake extraction
- [x] `flutter test test/services/purchase/premium_bridge_test.dart` — passes
- [x] `flutter test test/screens/paywall_screen_test.dart` — passes
- [x] `flutter analyze` — zero issues across all new and modified test files
- [x] Verify `FakePurchaseService` imports no `purchases_flutter` symbol
- [x] Verify `RevenueCatPurchaseService` imports no Firestore symbol

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

### Step 7 — Fake infrastructure compilation fixes

**Plan:** Shared `FakeUser` uses `final String uid` field + `String get uid` getter.

**Final:** Field renamed to `_uid` to avoid declaration conflict with the overriding getter.

**Reason:** Dart doesn't allow a field and getter with the same name in the same class when both are declared in the class.

**Plan:** `_FakeTransaction.update` parameter typed `Map<String, dynamic>`.

**Final:** Changed to `Map<Object, Object?>` to match the overridden `Transaction.update` signature, with explicit `data.cast<String, dynamic>()` for the internal map.

**Reason:** Parent interface (`cloud_firestore` 6.7.1) declares the parameter with `Map<Object, Object?>`.

**Plan:** `set` with merge does a simple spread (`...data`) — no FieldValue resolution.

**Final:** `set` with merge iterates entries and resolves `FieldValue.increment` the same way `update` does.

**Reason:** `recordScan` calls `doc.set({'scansUsed': FieldValue.increment(1)}, SetOptions(merge: true))`. Without FieldValue resolution, the Firestore fake stores the `FieldValue` object itself, which crashes when `quotaStream` casts `data['scansUsed'] as num?`.

**Plan:** `_FakeTransaction.commit` has `@override` annotation.

**Final:** Removed `@override`.

**Reason:** `Transaction` (cloud_firestore 6.7.1) does not define a `commit()` method. It's an internal method of the fake.

**Plan:** Paywall test uses `find.text(r'$4.99')`.

**Final:** Uses `find.textContaining(r'$4.99')`.

**Reason:** The rendered CTA text is `"Unlock for $4.99"` (localized prefix), not just the price string.

**Plan:** `FakeFirestore.doc`, `FakeFirestore.collection`, `FakeFirestore.runTransaction` lack `@override` annotations.

**Final:** Added `@override` to all three methods.

**Reason:** `flutter analyze` emitted `info`-level `annotate_overrides` warnings on these methods. Adding `@override` silences them.

**Plan:** Bridge test relies on transitive import of `PurchaseSuccess` from `fake_purchase_service.dart`.

**Final:** Added explicit `import 'package:vgcollection/services/purchase/purchase_service.dart'`.

**Reason:** Dart does not transitively expose imports from other files. `fake_purchase_service.dart` imports `purchase_service.dart` but doesn't re-export it, so `PurchaseSuccess` is not visible in the bridge test without a direct import.

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

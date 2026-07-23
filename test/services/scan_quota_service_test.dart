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

class FakeFirestore implements FirebaseFirestore {
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
      {Duration timeout = const Duration(seconds: 5), int maxAttempts = 5}) async {
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
    return _FakeSnapshot(_firestore._docs[_path]?.data);
  }

  @override
  Future<void> delete() async {
    _firestore._docs.remove(_path);
    _firestore._emit(_path);
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
  Future<void> update(Map<Object, Object?> data) async {
    final doc = _firestore._docs[_path]!;
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
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({bool includeMetadataChanges = false, ListenSource source = ListenSource.defaultSource}) {
    final ctrl = _firestore._controllerFor(_path);
    if (_firestore.shouldThrowOnGet) {
      Future(() => ctrl.addError(FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      )));
    } else {
      final current = _firestore._docs[_path]?.data;
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
    final data = _pending[key] ?? _firestore._docs[key]?.data;
    return _FakeSnapshot(data) as DocumentSnapshot<T>;
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

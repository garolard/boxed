import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class FakeDoc {
  Map<String, dynamic> data = {};
}

class FakeFirestore implements FirebaseFirestore {
  final Map<String, FakeDoc> docs = {};
  final _controllers = <String, StreamController<Map<String, dynamic>?>>{};
  bool shouldThrowOnGet = false;

  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      _FakeDocumentRef(this, path);

  @override
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

  @override
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
      final merged = Map<String, dynamic>.from(existing.data);
      for (final entry in data.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value is FieldValue) {
          final current = (merged[key] as num?)?.toInt() ?? 0;
          merged[key] = current + 1;
        } else {
          merged[key] = value;
        }
      }
      existing.data = merged;
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
    Map<Object, Object?> data,
  ) {
    _pending[documentRef.path] = <String, dynamic>{
      ...(_pending[documentRef.path] ??
          _firestore.docs[documentRef.path]?.data ??
          {}),
    }..addAll(data.cast<String, dynamic>());
    return this;
  }

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

import 'dart:async';

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

    final ctrl = StreamController<ScanQuota>.broadcast();
    doc.snapshots().listen(
      (snap) {
        if (!snap.exists) {
          ctrl.add(const ScanQuota());
          return;
        }
        final data = snap.data()!;
        final quota = ScanQuota(
          scansUsed: (data['scansUsed'] as num?)?.toInt() ?? 0,
          isPremium: data['isPremium'] == true || _isPremiumOverride,
        );
        _cachedQuota = quota;
        ctrl.add(quota);
      },
      onError: (_) {
        ctrl.add(ScanQuota(
          scansUsed: kFreeScanLimit,
          isPremium: _isPremiumOverride,
          readFailed: true,
        ));
      },
      cancelOnError: false,
    );
    return ctrl.stream;
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

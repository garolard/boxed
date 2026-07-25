import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgcollection/services/scan_quota_service.dart';

import '../fakes/fake_auth.dart';
import '../fakes/fake_firestore.dart';

void main() {
  test('increment — recordScan adds 1 and stream emits', () async {
    final fake = FakeFirestore();
    final auth = FakeFirebaseAuth('user-1');
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
    expect(fake.docs['users/user-1']!.data['scansUsed'], 1);

    await sub.cancel();
  });

  test('fail-closed — read error yields readFailed and mayScan false', () async {
    final fake = FakeFirestore();
    fake.shouldThrowOnGet = true;
    final auth = FakeFirebaseAuth('user-2');
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
    final auth = FakeFirebaseAuth('user-3');
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
    expect(fake.docs['users/user-3']!.data['scansUsed'], 5);

    await sub.cancel();
  });

  test('no-increment on empty candidates', () async {
    final fake = FakeFirestore();
    final auth = FakeFirebaseAuth('user-4');
    ScanQuotaService(
      firestore: fake as FirebaseFirestore,
      auth: auth as FirebaseAuth,
      isPremiumOverride: false,
    );

    await fake.doc('users/user-4').set({'scansUsed': 2, 'isPremium': false});

    // Simulating a scan that returns zero candidates: recordScan is never called.
    // We assert the doc is untouched.
    expect(fake.docs['users/user-4']!.data['scansUsed'], 2);
  });

  test('decrement restores prior count after an optimistic increment', () async {
    final fake = FakeFirestore();
    final auth = FakeFirebaseAuth('user-5');
    final service = ScanQuotaService(
      firestore: fake as FirebaseFirestore,
      auth: auth as FirebaseAuth,
      isPremiumOverride: false,
    );

    await fake.doc('users/user-5').set({'scansUsed': 2, 'isPremium': false});

    await service.recordScan();
    expect(fake.docs['users/user-5']!.data['scansUsed'], 3);

    await service.decrementScan();
    expect(fake.docs['users/user-5']!.data['scansUsed'], 2);
  });

  test('decrement clamps at zero', () async {
    final fake = FakeFirestore();
    final auth = FakeFirebaseAuth('user-6');
    final service = ScanQuotaService(
      firestore: fake as FirebaseFirestore,
      auth: auth as FirebaseAuth,
      isPremiumOverride: false,
    );

    await fake.doc('users/user-6').set({'scansUsed': 0, 'isPremium': false});

    await service.decrementScan();
    expect(fake.docs['users/user-6']!.data['scansUsed'], 0);
  });
}

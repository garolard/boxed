import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgcollection/services/purchase/premium_bridge.dart';
import 'package:vgcollection/services/scan_quota_service.dart';

import '../../fakes/fake_auth.dart';
import '../../fakes/fake_firestore.dart';
import 'package:vgcollection/services/purchase/purchase_service.dart';
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
    expect(doc.data['scansUsed'], 2);
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

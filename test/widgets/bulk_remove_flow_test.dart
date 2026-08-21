import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgcollection/l10n/app_localizations.dart';
import 'package:vgcollection/models/game.dart';
import 'package:vgcollection/providers/collection_provider.dart';
import 'package:vgcollection/providers/services.dart';
import 'package:vgcollection/screens/home_screen.dart';
import 'package:vgcollection/services/analytics_service.dart';
import 'package:vgcollection/services/review_service.dart';
import 'package:vgcollection/services/scan_quota_service.dart';

import '../services/purchase/fake_purchase_service.dart';

class _StubCollection extends CollectionNotifier {
  _StubCollection(this._games);

  final List<Game> _games;
  final List<List<int>> removedMany = [];
  final List<List<Game>> restoredMany = [];

  @override
  CollectionState build() => CollectionState(games: _games, loaded: true);

  @override
  Future<void> loadRecommendations({bool force = false}) async {}

  @override
  Future<List<Game>> removeMany(List<int> ids) async {
    removedMany.add(ids);
    final removed = _games.where((g) => ids.contains(g.id)).toList();
    state = state.copyWith(
      games: [
        for (final g in state.games)
          if (!ids.contains(g.id)) g,
      ],
    );
    return removed;
  }

  @override
  Future<void> restoreMany(List<Game> snapshot) async {
    restoredMany.add(snapshot);
    state = state.copyWith(games: [...state.games, ...snapshot]);
  }
}

class _FakeAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

class _FakeReview implements ReviewService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

class _FakeScanQuota implements ScanQuotaService {
  @override
  Stream<ScanQuota> quotaStream() => Stream.value(const ScanQuota());

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Future<_StubCollection> _pumpHome(WidgetTester tester, List<Game> games) async {
  final stub = _StubCollection(games);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionProvider.overrideWith(() => stub),
        analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
        reviewServiceProvider.overrideWithValue(_FakeReview()),
        scanQuotaServiceProvider.overrideWithValue(_FakeScanQuota()),
        purchaseServiceProvider.overrideWithValue(FakePurchaseService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  // Bounded pumps instead of pumpAndSettle: the offstage Search tab runs an
  // infinite (repeat) entrance animation, so pumpAndSettle would never settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  return stub;
}

Future<void> _pumpInteraction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  final games = [
    Game(id: 1, name: 'Chrono Trigger', ownedPlatformName: 'SNES', addedAt: DateTime(2024, 1, 1)),
    Game(id: 2, name: 'Final Fantasy VI', ownedPlatformName: 'SNES', addedAt: DateTime(2024, 2, 1)),
    Game(id: 3, name: 'Super Mario World', ownedPlatformName: 'SNES', addedAt: DateTime(2024, 3, 1)),
  ];

  testWidgets('full bulk-remove + undo flow round-trips the Shelf', (tester) async {
    final stub = await _pumpHome(tester, games);

    // Enter selection mode
    await tester.tap(find.byIcon(Icons.checklist_rounded));
    await _pumpInteraction(tester);

    // Select two games
    await tester.tap(find.text('Chrono Trigger'));
    await _pumpInteraction(tester);
    await tester.tap(find.text('Final Fantasy VI'));
    await _pumpInteraction(tester);

    // Tap Delete
    await tester.tap(find.byIcon(Icons.delete_rounded));
    await _pumpInteraction(tester);

    // Confirm dialog
    expect(find.text('Remove 2 games?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await _pumpInteraction(tester);

    // Assert removed
    expect(find.text('Chrono Trigger'), findsNothing);
    expect(find.text('Final Fantasy VI'), findsNothing);
    expect(find.text('Super Mario World'), findsOneWidget);

    // Undo
    await tester.tap(find.text('Undo'));
    await _pumpInteraction(tester);

    // Assert restored
    expect(find.text('Chrono Trigger'), findsOneWidget);
    expect(find.text('Final Fantasy VI'), findsOneWidget);
    expect(find.text('Super Mario World'), findsOneWidget);

    // Verify stub calls
    expect(stub.removedMany, hasLength(1));
    expect(stub.removedMany.single, containsAll([1, 2]));
    expect(stub.restoredMany, hasLength(1));
    expect(stub.restoredMany.single, hasLength(2));
  });
}
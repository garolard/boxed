import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vgcollection/models/game.dart';
import 'package:vgcollection/providers/collection_provider.dart';
import 'package:vgcollection/providers/services.dart';
import 'package:vgcollection/services/analytics_service.dart';
import 'package:vgcollection/services/collection_repository.dart';
import 'package:vgcollection/services/igdb_service.dart';
import 'package:vgcollection/services/review_service.dart';

class _FakeCollectionRepository extends CollectionRepository {
  final Map<int, Game> _games = {};

  _FakeCollectionRepository() : super();

  @override
  Future<List<Game>> getAll() async => _games.values.toList();

  @override
  Future<void> add(Game game) async {
    _games[game.id] = game;
  }

  @override
  Future<void> remove(int gameId) async {
    _games.remove(gameId);
  }

  @override
  Future<void> removeMany(List<int> ids) async {
    for (final id in ids) {
      _games.remove(id);
    }
  }

  @override
  Future<void> addMany(List<Game> games) async {
    for (final game in games) {
      _games[game.id] = game;
    }
  }
}

class _FakeAnalytics implements AnalyticsService {
  final List<Map<String, dynamic>> bulkRemovedEvents = [];

  @override
  void setCrashlyticsKey(String key, Object value) {}

  @override
  Future<void> logBulkGamesRemoved(BulkGamesRemovedParams params) async {
    bulkRemovedEvents.add({
      'count': params.count,
      'collectionSizeAfter': params.collectionSizeAfter,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeIgdb implements IgdbService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReview implements ReviewService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _createContainer({
  required CollectionRepository repo,
  required AnalyticsService analytics,
}) {
  return ProviderContainer(
    overrides: [
      collectionRepositoryProvider.overrideWithValue(repo),
      analyticsServiceProvider.overrideWithValue(analytics),
      igdbServiceProvider.overrideWithValue(_FakeIgdb()),
      reviewServiceProvider.overrideWithValue(_FakeReview()),
    ],
  );
}

Future<void> _waitForLoad(ProviderContainer container) async {
  final completer = Completer<void>();
  final sub = container.listen(collectionProvider, (prev, next) {
    if (next.loaded && !completer.isCompleted) {
      completer.complete();
    }
  });
  if (container.read(collectionProvider).loaded && !completer.isCompleted) {
    completer.complete();
  }
  await completer.future;
  sub.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CollectionNotifier bulk methods', () {
    late _FakeCollectionRepository fakeRepo;
    late _FakeAnalytics fakeAnalytics;

    setUp(() {
      fakeRepo = _FakeCollectionRepository();
      fakeAnalytics = _FakeAnalytics();
    });

    test('removeMany snapshots before deleting and returns the snapshot',
        () async {
      final g1 = Game(id: 1, name: 'A', ownedPlatformName: 'SNES', addedAt: DateTime(2024, 1, 1));
      final g2 = Game(id: 2, name: 'B', ownedPlatformName: 'PS1', addedAt: DateTime(2024, 2, 1));
      await fakeRepo.add(g1);
      await fakeRepo.add(g2);

      final container = _createContainer(repo: fakeRepo, analytics: fakeAnalytics);
      final notifier = container.read(collectionProvider.notifier);
      await _waitForLoad(container);

      final snapshot = await notifier.removeMany([1]);

      expect(snapshot, hasLength(1));
      expect(snapshot.single.id, 1);
      expect(snapshot.single.ownedPlatformName, 'SNES');
      expect(fakeRepo._games.containsKey(1), isFalse);
      expect(fakeRepo._games.containsKey(2), isTrue);
    });

    test('removeMany fires exactly one bulk_games_removed event', () async {
      final g1 = Game(id: 1, name: 'A', addedAt: DateTime.now());
      final g2 = Game(id: 2, name: 'B', addedAt: DateTime.now());
      await fakeRepo.add(g1);
      await fakeRepo.add(g2);

      final container = _createContainer(repo: fakeRepo, analytics: fakeAnalytics);
      final notifier = container.read(collectionProvider.notifier);
      await _waitForLoad(container);

      await notifier.removeMany([1, 2]);

      expect(fakeAnalytics.bulkRemovedEvents, hasLength(1));
      expect(fakeAnalytics.bulkRemovedEvents.single['count'], 2);
      expect(fakeAnalytics.bulkRemovedEvents.single['collectionSizeAfter'], 0);
    });

    test('restoreMany re-adds entries and fires no analytics', () async {
      final g1 = Game(id: 1, name: 'A', ownedPlatformName: 'SNES', addedAt: DateTime(2024, 1, 1));
      await fakeRepo.add(g1);

      final container = _createContainer(repo: fakeRepo, analytics: fakeAnalytics);
      final notifier = container.read(collectionProvider.notifier);
      await _waitForLoad(container);

      await notifier.removeMany([1]);
      expect(fakeRepo._games, isEmpty);

      await notifier.restoreMany([g1]);

      expect(fakeRepo._games.containsKey(1), isTrue);
      expect(fakeRepo._games[1]!.ownedPlatformName, 'SNES');
      expect(fakeAnalytics.bulkRemovedEvents, hasLength(1));
    });
  });
}
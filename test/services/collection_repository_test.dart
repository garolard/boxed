import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vgcollection/models/game.dart';
import 'package:vgcollection/services/collection_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> openInMemory() async {
    return openDatabase(
      inMemoryDatabasePath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE collection (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            data TEXT NOT NULL,
            added_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  group('CollectionRepository bulk methods', () {
    late CollectionRepository repo;

    setUp(() {
      repo = CollectionRepository(opener: openInMemory);
    });

    test('removeMany with empty input is a no-op', () async {
      await repo.add(Game(id: 1, name: 'A', addedAt: DateTime.now()));
      await repo.removeMany([]);
      final games = await repo.getAll();
      expect(games, hasLength(1));
    });

    test('removeMany deletes present ids and ignores absent ones', () async {
      await repo.add(Game(id: 1, name: 'A', addedAt: DateTime.now()));
      await repo.add(Game(id: 2, name: 'B', addedAt: DateTime.now()));
      await repo.add(Game(id: 3, name: 'C', addedAt: DateTime.now()));
      await repo.removeMany([1, 99, 3]);
      final games = await repo.getAll();
      expect(games.map((g) => g.id), [2]);
    });

    test('removeMany chunks at 500 ids inside a transaction', () async {
      for (var i = 1; i <= 600; i++) {
        await repo.add(Game(id: i, name: 'Game $i', addedAt: DateTime.now()));
      }
      await repo.removeMany([for (var i = 1; i <= 600; i++) i]);
      final games = await repo.getAll();
      expect(games, isEmpty);
    });

    test('addMany overwrites conflicting entries', () async {
      final original = Game(
        id: 1,
        name: 'A',
        ownedPlatformName: 'SNES',
        addedAt: DateTime(2024, 1, 1),
      );
      await repo.add(original);
      final updated = Game(
        id: 1,
        name: 'A',
        ownedPlatformName: 'PS1',
        addedAt: DateTime(2024, 6, 1),
      );
      await repo.addMany([updated]);
      final games = await repo.getAll();
      expect(games.single.ownedPlatformName, 'PS1');
      expect(games.single.addedAt, DateTime(2024, 6, 1));
    });
  });
}
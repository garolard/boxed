import 'package:flutter_test/flutter_test.dart';
import 'package:vgcollection/models/game.dart';

void main() {
  final igdbJson = {
    'id': 1068,
    'name': 'Super Mario Land',
    'cover': {'id': 99, 'image_id': 'co1abc'},
    'platforms': [
      {'id': 33, 'abbreviation': 'GB', 'name': 'Game Boy'},
    ],
    'genres': [
      {'id': 8, 'name': 'Platform'},
    ],
    'first_release_date': 608947200, // 1989-04-21
    'total_rating': 74.5,
    'summary': 'A platformer.',
    'similar_games': [1, 2, 3],
  };

  test('parses IGDB response', () {
    final game = Game.fromIgdb(igdbJson);
    expect(game.id, 1068);
    expect(game.name, 'Super Mario Land');
    expect(game.coverImageId, 'co1abc');
    expect(game.platformIds, [33]);
    expect(game.platformNames, ['GB']);
    expect(game.genres, ['Platform']);
    expect(game.releaseYear, 1989);
    expect(game.rating, 74.5);
    expect(game.similarGameIds, [1, 2, 3]);
    expect(game.coverUrl, contains('co1abc'));
  });

  test('round-trips through JSON with collection metadata', () {
    final owned = Game.fromIgdb(igdbJson).copyWith(
      ownedPlatformId: 33,
      ownedPlatformName: 'GB',
      addedAt: DateTime(2026, 7, 15),
    );
    final restored = Game.fromJson(owned.toJson());
    expect(restored.id, owned.id);
    expect(restored.name, owned.name);
    expect(restored.ownedPlatformId, 33);
    expect(restored.ownedPlatformName, 'GB');
    expect(restored.addedAt, DateTime(2026, 7, 15));
    expect(restored.similarGameIds, owned.similarGameIds);
  });

  test('handles minimal IGDB payload', () {
    final game = Game.fromIgdb({'id': 5, 'name': 'Tetris'});
    expect(game.coverUrl, isNull);
    expect(game.platformIds, isEmpty);
    expect(game.genres, isEmpty);
  });
}

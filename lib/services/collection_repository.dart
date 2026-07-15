import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/game.dart';

class ImportResult {
  final int imported;
  final int skipped;
  const ImportResult(this.imported, this.skipped);
}

/// Local persistence for the collection. Each row keeps a full JSON
/// snapshot of the game so the app works offline.
class CollectionRepository {
  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'vgcollection.db'),
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE collection (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          data TEXT NOT NULL,
          added_at INTEGER NOT NULL
        )
      '''),
    );
    return _db!;
  }

  Future<List<Game>> getAll() async {
    final db = await _database;
    final rows = await db.query('collection', orderBy: 'added_at DESC');
    return [
      for (final row in rows)
        Game.fromJson(jsonDecode(row['data'] as String) as Map<String, dynamic>),
    ];
  }

  Future<void> add(Game game) async {
    final db = await _database;
    final entry = game.copyWith(addedAt: game.addedAt ?? DateTime.now());
    await db.insert(
      'collection',
      {
        'id': entry.id,
        'name': entry.name,
        'data': jsonEncode(entry.toJson()),
        'added_at': entry.addedAt!.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> remove(int gameId) async {
    final db = await _database;
    await db.delete('collection', where: 'id = ?', whereArgs: [gameId]);
  }

  /// Writes the collection to a JSON file and returns its path.
  Future<String> exportToFile(List<Game> games) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().split('.').first.replaceAll(':', '-');
    final file = File(p.join(dir.path, 'vgcollection-$stamp.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'app': 'vgcollection',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'games': [for (final g in games) g.toJson()],
    }));
    return file.path;
  }

  /// Merges games from an exported JSON file. Existing entries are kept.
  Future<ImportResult> importFromFile(String path) async {
    final raw = jsonDecode(await File(path).readAsString());
    if (raw is! Map<String, dynamic> || raw['games'] is! List) {
      throw const FormatException('Not a vgcollection export file');
    }
    final existing = {for (final g in await getAll()) g.id};
    var imported = 0, skipped = 0;
    for (final item in raw['games'] as List) {
      final game = Game.fromJson(item as Map<String, dynamic>);
      if (existing.contains(game.id)) {
        skipped++;
      } else {
        await add(game);
        imported++;
      }
    }
    return ImportResult(imported, skipped);
  }
}

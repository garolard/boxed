import 'package:flutter/foundation.dart';

import '../models/game.dart';
import '../services/collection_repository.dart';
import '../services/igdb_service.dart';

class CollectionProvider extends ChangeNotifier {
  final CollectionRepository _repo;
  final IgdbService igdb;

  List<Game> _games = [];
  bool _loaded = false;

  List<Game> _recommendations = [];
  bool _recsLoading = false;
  String? _recsError;
  bool _recsStale = true;

  CollectionProvider({CollectionRepository? repo, IgdbService? igdb})
      : _repo = repo ?? CollectionRepository(),
        igdb = igdb ?? IgdbService();

  List<Game> get games => _games;
  bool get loaded => _loaded;
  List<Game> get recommendations => _recommendations;
  bool get recsLoading => _recsLoading;
  String? get recsError => _recsError;

  bool contains(int gameId) => _games.any((g) => g.id == gameId);

  Map<String, int> get countByPlatform {
    final map = <String, int>{};
    for (final g in _games) {
      final key = g.ownedPlatformName ?? 'Unknown';
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get countByGenre {
    final map = <String, int>{};
    for (final g in _games) {
      for (final genre in g.genres) {
        map[genre] = (map[genre] ?? 0) + 1;
      }
    }
    return map;
  }

  Future<void> load() async {
    _games = await _repo.getAll();
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(Game game, {int? platformId, String? platformName}) async {
    final entry = game.copyWith(
      ownedPlatformId: platformId,
      ownedPlatformName: platformName,
      addedAt: DateTime.now(),
    );
    await _repo.add(entry);
    _recsStale = true;
    await load();
  }

  Future<void> remove(int gameId) async {
    await _repo.remove(gameId);
    _recsStale = true;
    await load();
  }

  Future<String> exportCollection() => _repo.exportToFile(_games);

  Future<ImportResult> importCollection(String path) async {
    final result = await _repo.importFromFile(path);
    _recsStale = true;
    await load();
    return result;
  }

  /// Builds recommendations from the `similar_games` of owned titles:
  /// games suggested by several owned games rank first, ties broken by rating.
  Future<void> loadRecommendations({bool force = false}) async {
    if (_recsLoading || (!_recsStale && !force)) return;
    _recsLoading = true;
    _recsError = null;
    notifyListeners();
    try {
      final owned = {for (final g in _games) g.id};
      final frequency = <int, int>{};
      for (final g in _games) {
        for (final id in g.similarGameIds) {
          if (!owned.contains(id)) {
            frequency[id] = (frequency[id] ?? 0) + 1;
          }
        }
      }
      final topIds = frequency.keys.toList()
        ..sort((a, b) => frequency[b]!.compareTo(frequency[a]!));
      final fetched = await igdb.gamesByIds(topIds.take(50).toList());
      fetched.sort((a, b) {
        final byFreq = frequency[b.id]!.compareTo(frequency[a.id]!);
        if (byFreq != 0) return byFreq;
        return (b.rating ?? 0).compareTo(a.rating ?? 0);
      });
      _recommendations = fetched;
      _recsStale = false;
    } catch (e) {
      _recsError = e.toString();
    } finally {
      _recsLoading = false;
      notifyListeners();
    }
  }
}

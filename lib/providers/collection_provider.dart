import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import '../services/analytics_service.dart';
import '../services/collection_repository.dart';
import '../services/igdb_service.dart';
import 'services.dart';

const Object _unset = Object();

/// Immutable snapshot of the user's own collection plus the derived
/// recommendations state. Computed views (contains, countBy…) live here so
/// widgets can read them straight off the watched state.
class CollectionState {
  final List<Game> games;
  final bool loaded;
  final List<Game> recommendations;
  final bool recsLoading;
  final String? recsError;

  const CollectionState({
    this.games = const [],
    this.loaded = false,
    this.recommendations = const [],
    this.recsLoading = false,
    this.recsError,
  });

  bool contains(int gameId) => games.any((g) => g.id == gameId);

  Map<String, int> get countByPlatform {
    final map = <String, int>{};
    for (final g in games) {
      final key = g.ownedPlatformName ?? 'Unknown';
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get countByGenre {
    final map = <String, int>{};
    for (final g in games) {
      for (final genre in g.genres) {
        map[genre] = (map[genre] ?? 0) + 1;
      }
    }
    return map;
  }

  CollectionState copyWith({
    List<Game>? games,
    bool? loaded,
    List<Game>? recommendations,
    bool? recsLoading,
    Object? recsError = _unset,
  }) {
    return CollectionState(
      games: games ?? this.games,
      loaded: loaded ?? this.loaded,
      recommendations: recommendations ?? this.recommendations,
      recsLoading: recsLoading ?? this.recsLoading,
      recsError:
          identical(recsError, _unset) ? this.recsError : recsError as String?,
    );
  }
}

final collectionProvider =
    NotifierProvider<CollectionNotifier, CollectionState>(
        CollectionNotifier.new);

class CollectionNotifier extends Notifier<CollectionState> {
  late final CollectionRepository _repo;
  late final IgdbService _igdb;
  late final AnalyticsService _analytics;
  bool _recsStale = true;

  @override
  CollectionState build() {
    _repo = ref.read(collectionRepositoryProvider);
    _igdb = ref.read(igdbServiceProvider);
    _analytics = ref.read(analyticsServiceProvider);
    _load();
    return const CollectionState();
  }

  Future<void> _load() async {
    final games = await _repo.getAll();
    state = state.copyWith(games: games, loaded: true);
    _analytics.setCrashlyticsKey('collection_size', games.length);
  }

  Future<void> add(Game game, {int? platformId, String? platformName}) async {
    final entry = game.copyWith(
      ownedPlatformId: platformId,
      ownedPlatformName: platformName,
      addedAt: DateTime.now(),
    );
    await _repo.add(entry);
    _recsStale = true;
    await _load();
    await _analytics.logGameAdded(GameAddedParams(
      gameId: game.id,
      gameName: game.name,
      platformName: platformName,
      genreCount: game.genres.length,
      releaseYear: game.releaseYear,
      rating: game.rating,
      collectionSizeAfter: state.games.length,
    ));
  }

  Future<void> remove(int gameId) async {
    final removed = state.games.firstWhere((g) => g.id == gameId);
    await _repo.remove(gameId);
    _recsStale = true;
    await _load();
    await _analytics.logGameRemoved(GameRemovedParams(
      gameId: gameId,
      gameName: removed.name,
      platformName: removed.ownedPlatformName,
      collectionSizeAfter: state.games.length,
    ));
  }

  Future<String> exportCollection() => _repo.exportToFile(state.games);

  Future<ImportResult> importCollection(String path) async {
    final result = await _repo.importFromFile(path);
    _recsStale = true;
    await _load();
    return result;
  }

  /// Builds recommendations from the `similar_games` of owned titles:
  /// games suggested by several owned games rank first, ties broken by rating.
  Future<void> loadRecommendations({bool force = false}) async {
    if (state.recsLoading || (!_recsStale && !force)) return;
    state = state.copyWith(recsLoading: true, recsError: null);
    try {
      final owned = {for (final g in state.games) g.id};
      final frequency = <int, int>{};
      for (final g in state.games) {
        for (final id in g.similarGameIds) {
          if (!owned.contains(id)) {
            frequency[id] = (frequency[id] ?? 0) + 1;
          }
        }
      }
      final topIds = frequency.keys.toList()
        ..sort((a, b) => frequency[b]!.compareTo(frequency[a]!));
      final fetched = await _igdb.gamesByIds(topIds.take(50).toList());
      fetched.sort((a, b) {
        final byFreq = frequency[b.id]!.compareTo(frequency[a.id]!);
        if (byFreq != 0) return byFreq;
        return (b.rating ?? 0).compareTo(a.rating ?? 0);
      });
      _recsStale = false;
      state = state.copyWith(recommendations: fetched, recsLoading: false);
      await _analytics.logRecommendationsLoaded(
        recCount: fetched.length,
        collectionSize: state.games.length,
        hasError: false,
        forced: force,
      );
    } catch (e) {
      state = state.copyWith(recsLoading: false, recsError: e.toString());
      await _analytics.logRecommendationsLoaded(
        recCount: 0,
        collectionSize: state.games.length,
        hasError: true,
        errorMessage: '$e',
        forced: force,
      );
    }
  }
}

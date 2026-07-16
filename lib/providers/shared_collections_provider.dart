import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import '../models/platforms.dart';
import '../models/shared_collection.dart';
import '../services/collection_repository.dart';
import '../services/igdb_service.dart';
import '../services/qr_payload_codec.dart';
import 'services.dart';

class SharedCollectionsState {
  final List<SharedCollection> collections;
  final bool loaded;

  const SharedCollectionsState({
    this.collections = const [],
    this.loaded = false,
  });

  SharedCollectionsState copyWith({
    List<SharedCollection>? collections,
    bool? loaded,
  }) =>
      SharedCollectionsState(
        collections: collections ?? this.collections,
        loaded: loaded ?? this.loaded,
      );
}

final sharedCollectionsProvider =
    NotifierProvider<SharedCollectionsNotifier, SharedCollectionsState>(
        SharedCollectionsNotifier.new);

class SharedCollectionsNotifier extends Notifier<SharedCollectionsState> {
  late final CollectionRepository _repo;
  late final IgdbService _igdb;

  @override
  SharedCollectionsState build() {
    _repo = ref.read(collectionRepositoryProvider);
    _igdb = ref.read(igdbServiceProvider);
    _load();
    return const SharedCollectionsState();
  }

  Future<void> _load() async {
    final collections = await _repo.getSharedCollections();
    state = state.copyWith(collections: collections, loaded: true);
  }

  /// Hydrates a scanned payload: fetches full metadata from IGDB and
  /// saves the result as a named shared collection. The sender's platform
  /// choice is kept on each game for display.
  Future<SharedCollection> importFromPayload(QrPayload payload) async {
    final games =
        await _igdb.gamesByIds([for (final e in payload.entries) e.gameId]);
    final platformById = {
      for (final e in payload.entries) e.gameId: e.platformId,
    };
    final hydrated = [
      for (final g in games)
        g.copyWith(
          ownedPlatformId: platformById[g.id],
          ownedPlatformName: _platformName(g, platformById[g.id]),
        ),
    ];
    final name =
        payload.name.trim().isEmpty ? 'Shared collection' : payload.name.trim();
    final saved = await _repo.addSharedCollection(name, hydrated);
    await _load();
    return saved;
  }

  Future<void> delete(int id) async {
    await _repo.deleteSharedCollection(id);
    await _load();
  }

  String? _platformName(Game game, int? platformId) {
    if (platformId == null) return null;
    final i = game.platformIds.indexOf(platformId);
    if (i >= 0 && i < game.platformNames.length) return game.platformNames[i];
    for (final p in kPlatforms) {
      if (p.id == platformId) return p.shortName;
    }
    return null;
  }
}

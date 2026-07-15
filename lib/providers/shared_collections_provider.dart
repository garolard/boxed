import 'package:flutter/foundation.dart';

import '../models/game.dart';
import '../models/platforms.dart';
import '../models/shared_collection.dart';
import '../services/collection_repository.dart';
import '../services/igdb_service.dart';
import '../services/qr_payload_codec.dart';

class SharedCollectionsProvider extends ChangeNotifier {
  final CollectionRepository _repo;
  final IgdbService _igdb;

  List<SharedCollection> _collections = [];
  bool _loaded = false;

  SharedCollectionsProvider({
    required this._repo,
    required this._igdb,
  });

  List<SharedCollection> get collections => _collections;
  bool get loaded => _loaded;

  Future<void> load() async {
    _collections = await _repo.getSharedCollections();
    _loaded = true;
    notifyListeners();
  }

  /// Hydrates a scanned payload: fetches full metadata from IGDB and
  /// saves the result as a named shared collection. The sender's platform
  /// choice is kept on each game for display.
  Future<SharedCollection> importFromPayload(QrPayload payload) async {
    final games = await _igdb
        .gamesByIds([for (final e in payload.entries) e.gameId]);
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
    final name = payload.name.trim().isEmpty
        ? 'Shared collection'
        : payload.name.trim();
    final saved = await _repo.addSharedCollection(name, hydrated);
    await load();
    return saved;
  }

  Future<void> delete(int id) async {
    await _repo.deleteSharedCollection(id);
    await load();
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

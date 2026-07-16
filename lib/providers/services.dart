import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/collection_repository.dart';
import '../services/igdb_service.dart';

/// Shared singletons. The repository and IGDB client are created once and
/// injected into every notifier that needs them (overridable in tests).
final collectionRepositoryProvider =
    Provider<CollectionRepository>((ref) => CollectionRepository());

final igdbServiceProvider =
    Provider<IgdbService>((ref) => IgdbService());

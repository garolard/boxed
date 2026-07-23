import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics_service.dart';
import '../services/collection_repository.dart';
import '../services/igdb_service.dart';
import '../services/scan_quota_service.dart';

/// Shared singletons. The repository, IGDB client and analytics service are
/// created once and injected into every notifier that needs them
/// (overridable in tests).
final collectionRepositoryProvider =
    Provider<CollectionRepository>((ref) => CollectionRepository());

final igdbServiceProvider =
    Provider<IgdbService>((ref) => IgdbService(
          analytics: ref.read(analyticsServiceProvider),
        ));

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  throw UnsupportedError(
    'Override analyticsServiceProvider with an initialized instance in main.dart',
  );
});

final scanQuotaServiceProvider = Provider<ScanQuotaService>((ref) {
  throw UnsupportedError(
    'Override scanQuotaServiceProvider with an initialized instance in main.dart',
  );
});

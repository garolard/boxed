import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Typed parameter bundle for a search event.
class SearchEventParams {
  final String query;
  final String? platformFilter;
  final String? genreFilter;
  final int resultCount;
  final bool hasError;
  final String? errorMessage;

  const SearchEventParams({
    required this.query,
    this.platformFilter,
    this.genreFilter,
    required this.resultCount,
    this.hasError = false,
    this.errorMessage,
  });
}

/// Typed parameter bundle for adding a game.
class GameAddedParams {
  final int gameId;
  final String gameName;
  final String? platformName;
  final int genreCount;
  final int? releaseYear;
  final double? rating;
  final int collectionSizeAfter;

  const GameAddedParams({
    required this.gameId,
    required this.gameName,
    this.platformName,
    required this.genreCount,
    this.releaseYear,
    this.rating,
    required this.collectionSizeAfter,
  });
}

/// Typed parameter bundle for removing a game.
class GameRemovedParams {
  final int gameId;
  final String gameName;
  final String? platformName;
  final int collectionSizeAfter;

  const GameRemovedParams({
    required this.gameId,
    required this.gameName,
    this.platformName,
    required this.collectionSizeAfter,
  });
}

/// Typed parameter bundle for IGDB API errors.
class IgdbErrorParams {
  final String endpoint;
  final int? statusCode;
  final String errorMessage;
  final bool isAuthError;

  const IgdbErrorParams({
    required this.endpoint,
    this.statusCode,
    required this.errorMessage,
    this.isAuthError = false,
  });
}

/// Centralised wrapper around Firebase Analytics and Crashlytics.
///
/// Every public method is fire-and-forget and silently absorbs failures so
/// analytics can never crash the app or block user interaction.
class AnalyticsService {
  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;

  AnalyticsService({
    FirebaseAnalytics? analytics,
    FirebaseCrashlytics? crashlytics,
  })  : _analytics = analytics ?? FirebaseAnalytics.instance,
        _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  // ------------------------------------------------------------------
  //  Screen tracking
  // ------------------------------------------------------------------

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await _safe(() => _analytics.logScreenView(
          screenName: screenName,
          screenClass: screenClass ?? screenName,
        ));
  }

  // ------------------------------------------------------------------
  //  App lifecycle
  // ------------------------------------------------------------------

  Future<void> logAppOpen() async {
    await _safe(_analytics.logAppOpen);
  }

  // ------------------------------------------------------------------
  //  Navigation
  // ------------------------------------------------------------------

  Future<void> logTabChanged({required String tabName}) async {
    await _safe(() => _analytics.logEvent(
          name: 'tab_changed',
          parameters: {'tab_name': _trim(tabName, 100)},
        ));
  }

  // ------------------------------------------------------------------
  //  Search
  // ------------------------------------------------------------------

  Future<void> logSearch(SearchEventParams p) async {
    await _safe(() => _analytics.logEvent(
          name: 'search_performed',
          parameters: {
            'query': _trim(p.query, 100),
            if (p.platformFilter != null)
              'platform_filter': _trim(p.platformFilter!, 100),
            if (p.genreFilter != null)
              'genre_filter': _trim(p.genreFilter!, 100),
            'result_count': p.resultCount,
            'has_error': _bool(p.hasError),
            if (p.errorMessage != null)
              'error_message': _trim(p.errorMessage!, 100),
          },
        ));
  }

  // ------------------------------------------------------------------
  //  Collection mutations
  // ------------------------------------------------------------------

  Future<void> logGameAdded(GameAddedParams p) async {
    await _safe(() => _analytics.logEvent(
          name: 'game_added',
          parameters: {
            'game_id': p.gameId,
            'game_name': _trim(p.gameName, 100),
            if (p.platformName != null)
              'platform_name': _trim(p.platformName!, 100),
            'genre_count': p.genreCount,
            if (p.releaseYear != null) 'release_year': p.releaseYear!,
            if (p.rating != null) 'rating': p.rating!,
            'collection_size_after': p.collectionSizeAfter,
          },
        ));
  }

  Future<void> logGameRemoved(GameRemovedParams p) async {
    await _safe(() => _analytics.logEvent(
          name: 'game_removed',
          parameters: {
            'game_id': p.gameId,
            'game_name': _trim(p.gameName, 100),
            if (p.platformName != null)
              'platform_name': _trim(p.platformName!, 100),
            'collection_size_after': p.collectionSizeAfter,
          },
        ));
  }

  Future<void> logGameDetailView({
    required int gameId,
    required String gameName,
    required bool isOwned,
  }) async {
    await _safe(() => _analytics.logEvent(
          name: 'game_detail_view',
          parameters: {
            'game_id': gameId,
            'game_name': _trim(gameName, 100),
            'is_owned': _bool(isOwned),
          },
        ));
  }

  // ------------------------------------------------------------------
  //  Platform picker
  // ------------------------------------------------------------------

  Future<void> logPlatformPickerShown({
    required int gameId,
    required int platformCount,
  }) async {
    await _safe(() => _analytics.logEvent(
          name: 'platform_picker_shown',
          parameters: {
            'game_id': gameId,
            'platform_count': platformCount,
          },
        ));
  }

  // ------------------------------------------------------------------
  //  Import / Export
  // ------------------------------------------------------------------

  Future<void> logCollectionExported({required int gameCount}) async {
    await _safe(() => _analytics.logEvent(
          name: 'collection_exported',
          parameters: {'game_count': gameCount},
        ));
  }

  Future<void> logCollectionImported({
    required int importedCount,
    required int skippedCount,
    required bool hasError,
    String? errorMessage,
  }) async {
    await _safe(() => _analytics.logEvent(
          name: 'collection_imported',
          parameters: {
            'imported_count': importedCount,
            'skipped_count': skippedCount,
            'has_error': _bool(hasError),
            if (errorMessage != null)
              'error_message': _trim(errorMessage, 100),
          },
        ));
  }

  // ------------------------------------------------------------------
  //  Sharing
  // ------------------------------------------------------------------

  Future<void> logShareQrGenerated({required int gameCount}) async {
    await _safe(() => _analytics.logEvent(
          name: 'share_qr_generated',
          parameters: {'game_count': gameCount},
        ));
  }

  Future<void> logSharedCollectionCreated({required int gameCount}) async {
    await _safe(() => _analytics.logEvent(
          name: 'shared_collection_created',
          parameters: {'game_count': gameCount},
        ));
  }

  Future<void> logSharedCollectionViewed({
    required int collectionId,
    required int gameCount,
  }) async {
    await _safe(() => _analytics.logEvent(
          name: 'shared_collection_viewed',
          parameters: {
            'collection_id': collectionId,
            'game_count': gameCount,
          },
        ));
  }

  // ------------------------------------------------------------------
  //  Scan / OCR
  // ------------------------------------------------------------------

  Future<void> logScanPerformed({
    required String source,
    required int candidateCount,
    required bool hasError,
    String? errorMessage,
  }) async {
    await _safe(() => _analytics.logEvent(
          name: 'scan_performed',
          parameters: {
            'source': source, // 'camera' | 'gallery'
            'candidate_count': candidateCount,
            'has_error': _bool(hasError),
            if (errorMessage != null)
              'error_message': _trim(errorMessage, 100),
          },
        ));
  }

  // ------------------------------------------------------------------
  //  Recommendations
  // ------------------------------------------------------------------

  Future<void> logRecommendationsLoaded({
    required int recCount,
    required int collectionSize,
    required bool hasError,
    String? errorMessage,
    required bool forced,
  }) async {
    await _safe(() => _analytics.logEvent(
          name: 'recommendations_loaded',
          parameters: {
            'rec_count': recCount,
            'collection_size': collectionSize,
            'has_error': _bool(hasError),
            if (errorMessage != null)
              'error_message': _trim(errorMessage, 100),
            'forced': _bool(forced),
          },
        ));
  }

  // ------------------------------------------------------------------
  //  IGDB errors (debug helpers)
  // ------------------------------------------------------------------

  Future<void> logIgdbError(IgdbErrorParams p) async {
    await _safe(() => _analytics.logEvent(
          name: 'igdb_error',
          parameters: {
            'endpoint': _trim(p.endpoint, 100),
            if (p.statusCode != null) 'status_code': p.statusCode!,
            'error_message': _trim(p.errorMessage, 100),
            'is_auth_error': _bool(p.isAuthError),
          },
        ));

    // Also send to Crashlytics as a non-fatal so we can inspect stack traces.
    _crashlytics.recordError(
      Exception('IGDB error: ${p.errorMessage}'),
      null,
      reason: '${p.endpoint} | ${p.statusCode} | auth=${p.isAuthError}',
      fatal: false,
    );
  }

  // ------------------------------------------------------------------
  //  Generic error logging
  // ------------------------------------------------------------------

  /// Records a non-fatal error to Crashlytics and optionally logs an
  /// analytics event for context.
  Future<void> logError({
    required String context,
    required Object error,
    StackTrace? stackTrace,
    String? extra,
  }) async {
    _crashlytics.recordError(
      error,
      stackTrace,
      reason: context,
      information: extra == null ? [] : [extra],
      fatal: false,
    );

    await _safe(() => _analytics.logEvent(
          name: 'app_error',
          parameters: {
            'context': _trim(context, 100),
            'error_type': _trim(error.runtimeType.toString(), 100),
            if (extra != null) 'extra': _trim(extra, 100),
          },
        ));
  }

  /// Sets a Crashlytics custom key useful for debugging user state.
  void setCrashlyticsKey(String key, Object value) {
    _crashlytics.setCustomKey(key, value);
  }

  // ------------------------------------------------------------------
  //  Helpers
  // ------------------------------------------------------------------

  /// Firebase Analytics uses 1/0 for booleans.
  int _bool(bool v) => v ? 1 : 0;

  String _trim(String s, int max) => s.length > max ? s.substring(0, max) : s;

  /// Swallows any exception so analytics never leaks into UI logic.
  Future<void> _safe(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e, st) {
      // Analytics itself failed – only report in debug builds.
      if (kDebugMode) {
        debugPrint('Analytics error: $e\n$st');
      }
    }
  }
}

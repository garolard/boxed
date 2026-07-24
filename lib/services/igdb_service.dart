import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game.dart';
import 'analytics_service.dart';

class IgdbGenre {
  final int id;
  final String name;
  const IgdbGenre(this.id, this.name);
}

class IgdbException implements Exception {
  final String message;
  IgdbException(this.message);
  @override
  String toString() => message;
}

/// Client for the IGDB v4 API. Handles the Twitch client-credentials
/// OAuth flow and caches the app token in SharedPreferences.
class IgdbService {
  static const _tokenUrl = 'https://id.twitch.tv/oauth2/token';
  static const _apiBase = 'https://api.igdb.com/v4';
  static const _gameFields =
      'fields id,name,cover.image_id,platforms.id,platforms.abbreviation,'
      'platforms.name,genres.name,first_release_date,total_rating,summary,'
      'similar_games;';

  final http.Client _client;
  final AnalyticsService? _analytics;
  List<IgdbGenre>? _genresCache;

  IgdbService({http.Client? client, this._analytics})
      : _client = client ?? http.Client();

  String get _clientId => const String.fromEnvironment('IGDB_CLIENT_ID');
  String get _clientSecret => const String.fromEnvironment('IGDB_SECRET_ID');

  Future<String> _getToken({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('igdb_token');
    final expiry = prefs.getInt('igdb_token_expiry') ?? 0;
    if (!forceRefresh &&
        token != null &&
        DateTime.now().millisecondsSinceEpoch < expiry) {
      return token;
    }

    final res = await _client.post(Uri.parse(_tokenUrl), body: {
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'grant_type': 'client_credentials',
    });
    if (res.statusCode != 200) {
      final message =
          'IGDB auth failed (${res.statusCode}). Check IGDB_CLIENT_ID / IGDB_SECRET_ID in .env';
      _analytics?.logIgdbError(IgdbErrorParams(
        endpoint: 'oauth2/token',
        statusCode: res.statusCode,
        errorMessage: message,
        isAuthError: true,
      ));
      throw IgdbException(message);
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final newToken = json['access_token'] as String;
    final expiresIn = json['expires_in'] as int;
    await prefs.setString('igdb_token', newToken);
    // Refresh one hour early to stay clear of the expiry.
    await prefs.setInt(
        'igdb_token_expiry',
        DateTime.now().millisecondsSinceEpoch + (expiresIn - 3600) * 1000);
    return newToken;
  }

  Future<List<dynamic>> _query(String endpoint, String body) async {
    var token = await _getToken();
    var res = await _post(endpoint, body, token);
    if (res.statusCode == 401) {
      token = await _getToken(forceRefresh: true);
      res = await _post(endpoint, body, token);
    }
    if (res.statusCode != 200) {
      final message = 'IGDB request failed (${res.statusCode}): ${res.body}';
      _analytics?.logIgdbError(IgdbErrorParams(
        endpoint: endpoint,
        statusCode: res.statusCode,
        errorMessage: message,
        isAuthError: res.statusCode == 401,
      ));
      throw IgdbException(message);
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<http.Response> _post(String endpoint, String body, String token) =>
      _client.post(
        Uri.parse('$_apiBase/$endpoint'),
        headers: {
          'Client-ID': _clientId,
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: body,
      );

  String _escape(String s) => s.replaceAll('\\', '').replaceAll('"', '\\"');

  /// Search games by title, optionally filtered by platform and/or genre.
  Future<List<Game>> searchGames(
    String query, {
    int? platformId,
    int? genreId,
    int limit = 40,
  }) async {
    final where = <String>[];
    if (platformId != null) where.add('platforms = ($platformId)');
    if (genreId != null) where.add('genres = ($genreId)');
    final whereClause =
        where.isEmpty ? '' : 'where ${where.join(' & ')};';
    final body =
        'search "${_escape(query)}"; $_gameFields $whereClause limit $limit;';
    final results = await _query('games', body);
    return [for (final g in results) Game.fromIgdb(g as Map<String, dynamic>)];
  }

  /// Fetch games by their IGDB ids (used for recommendations).
  Future<List<Game>> gamesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final results = await _query(
        'games', '$_gameFields where id = (${ids.join(',')}); limit ${ids.length};');
    return [for (final g in results) Game.fromIgdb(g as Map<String, dynamic>)];
  }

  Future<List<IgdbGenre>> genres() async {
    if (_genresCache != null) return _genresCache!;
    final results =
        await _query('genres', 'fields id,name; sort name asc; limit 50;');
    _genresCache = [
      for (final g in results)
        IgdbGenre((g as Map<String, dynamic>)['id'] as int, g['name'] as String),
    ];
    return _genresCache!;
  }
}

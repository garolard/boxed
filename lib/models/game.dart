/// A videogame as returned by IGDB, plus collection metadata when owned.
class Game {
  final int id;
  final String name;
  final String? coverImageId;
  final List<int> platformIds;
  final List<String> platformNames;
  final List<String> genres;
  final int? releaseYear;
  final double? rating;
  final String? summary;
  final List<int> similarGameIds;

  // Collection metadata (null when the game is not in the collection).
  final int? ownedPlatformId;
  final String? ownedPlatformName;
  final DateTime? addedAt;

  const Game({
    required this.id,
    required this.name,
    this.coverImageId,
    this.platformIds = const [],
    this.platformNames = const [],
    this.genres = const [],
    this.releaseYear,
    this.rating,
    this.summary,
    this.similarGameIds = const [],
    this.ownedPlatformId,
    this.ownedPlatformName,
    this.addedAt,
  });

  String? get coverUrl => coverImageId == null
      ? null
      : 'https://images.igdb.com/igdb/image/upload/t_cover_big/$coverImageId.jpg';

  String? get thumbUrl => coverImageId == null
      ? null
      : 'https://images.igdb.com/igdb/image/upload/t_cover_small/$coverImageId.jpg';

  factory Game.fromIgdb(Map<String, dynamic> json) {
    final release = json['first_release_date'] as int?;
    return Game(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown',
      coverImageId: (json['cover'] as Map<String, dynamic>?)?['image_id'] as String?,
      platformIds: [
        for (final p in (json['platforms'] as List? ?? []))
          if (p is Map<String, dynamic>) p['id'] as int else p as int,
      ],
      platformNames: [
        for (final p in (json['platforms'] as List? ?? []))
          if (p is Map<String, dynamic>)
            (p['abbreviation'] ?? p['name'] ?? '') as String,
      ],
      genres: [
        for (final g in (json['genres'] as List? ?? []))
          if (g is Map<String, dynamic>) g['name'] as String,
      ],
      releaseYear: release == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(release * 1000).year,
      rating: (json['total_rating'] as num?)?.toDouble(),
      summary: json['summary'] as String?,
      similarGameIds: [
        for (final s in (json['similar_games'] as List? ?? [])) s as int,
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cover_image_id': coverImageId,
        'platform_ids': platformIds,
        'platform_names': platformNames,
        'genres': genres,
        'release_year': releaseYear,
        'rating': rating,
        'summary': summary,
        'similar_game_ids': similarGameIds,
        'owned_platform_id': ownedPlatformId,
        'owned_platform_name': ownedPlatformName,
        'added_at': addedAt?.toIso8601String(),
      };

  factory Game.fromJson(Map<String, dynamic> json) => Game(
        id: json['id'] as int,
        name: json['name'] as String,
        coverImageId: json['cover_image_id'] as String?,
        platformIds: List<int>.from(json['platform_ids'] ?? []),
        platformNames: List<String>.from(json['platform_names'] ?? []),
        genres: List<String>.from(json['genres'] ?? []),
        releaseYear: json['release_year'] as int?,
        rating: (json['rating'] as num?)?.toDouble(),
        summary: json['summary'] as String?,
        similarGameIds: List<int>.from(json['similar_game_ids'] ?? []),
        ownedPlatformId: json['owned_platform_id'] as int?,
        ownedPlatformName: json['owned_platform_name'] as String?,
        addedAt: json['added_at'] == null
            ? null
            : DateTime.tryParse(json['added_at'] as String),
      );

  Game copyWith({
    int? ownedPlatformId,
    String? ownedPlatformName,
    DateTime? addedAt,
  }) =>
      Game(
        id: id,
        name: name,
        coverImageId: coverImageId,
        platformIds: platformIds,
        platformNames: platformNames,
        genres: genres,
        releaseYear: releaseYear,
        rating: rating,
        summary: summary,
        similarGameIds: similarGameIds,
        ownedPlatformId: ownedPlatformId ?? this.ownedPlatformId,
        ownedPlatformName: ownedPlatformName ?? this.ownedPlatformName,
        addedAt: addedAt ?? this.addedAt,
      );
}

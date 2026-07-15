import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../providers/collection_provider.dart';
import '../screens/game_detail_screen.dart';
import 'platform_badge.dart';
import 'shimmer_box.dart';

/// The primary rich card used across the home grid, search results and
/// recommendations carousel. Designed to put the cover front and centre
/// with a colored overlay, owned indicator, and quick-add action.
class GameCoverCard extends StatelessWidget {
  final Game game;
  final String? subtitle;
  final bool dense;
  final VoidCallback? onAddPressed;

  const GameCoverCard({
    super.key,
    required this.game,
    this.subtitle,
    this.dense = false,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final owned = context.watch<CollectionProvider>().contains(game.id);
    final platformKey = game.ownedPlatformName ??
        (game.platformNames.isNotEmpty ? game.platformNames.first : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameDetailScreen(game: game),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                _CoverLayer(game: game, owned: owned),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: [
                      if (game.rating != null)
                        _RatingPill(rating: game.rating!),
                      const Spacer(),
                      if (owned) const _OwnedPill(),
                    ],
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: _Info(
                    game: game,
                    subtitle: subtitle,
                    platformKey: platformKey,
                    owned: owned,
                    onAddPressed: onAddPressed,
                    dense: dense,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverLayer extends StatelessWidget {
  final Game game;
  final bool owned;
  const _CoverLayer({required this.game, required this.owned});

  @override
  Widget build(BuildContext context) {
    final url = game.coverUrl;
    if (url == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.videogame_asset,
              color: Colors.white24, size: 64),
        ),
      );
    }
    return Hero(
      tag: 'cover-${game.id}',
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, _) => const ShimmerBox(),
        errorWidget: (_, _, _) => Container(
          color: Colors.black,
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white24),
          ),
        ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final double rating;
  const _RatingPill({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Colors.amberAccent.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 14),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(0),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnedPill extends StatelessWidget {
  const _OwnedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
        ),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withValues(alpha: 0.6),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, color: Colors.white, size: 14),
          SizedBox(width: 2),
          Text(
            'OWNED',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final Game game;
  final String? subtitle;
  final String? platformKey;
  final bool owned;
  final bool dense;
  final VoidCallback? onAddPressed;

  const _Info({
    required this.game,
    required this.subtitle,
    required this.platformKey,
    required this.owned,
    required this.dense,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final defaultSub = [
      if (game.releaseYear != null) '${game.releaseYear}',
      ?platformKey,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          game.name,
          maxLines: dense ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: dense ? 13 : 15,
            height: 1.15,
            shadows: const [
              Shadow(blurRadius: 4, color: Colors.black54),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (platformKey != null) ...[
              PlatformBadge(shortName: platformKey!, compact: true),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                subtitle ?? defaultSub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (onAddPressed != null) ...[
          const SizedBox(height: 6),
          _QuickAddButton(owned: owned, onPressed: onAddPressed!),
        ],
      ],
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  final bool owned;
  final VoidCallback onPressed;
  const _QuickAddButton({required this.owned, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: owned
                    ? const [Color(0xFFFF1744), Color(0xFFFF6E40)]
                    : const [Color(0xFFFF2E93), Color(0xFF7C4DFF)],
              ),
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(
                  color: (owned
                          ? const Color(0xFFFF1744)
                          : const Color(0xFFFF2E93))
                      .withValues(alpha: 0.55),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  owned ? Icons.remove_rounded : Icons.add_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  owned ? 'Remove' : 'Add to shelf',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

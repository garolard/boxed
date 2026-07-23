import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import '../l10n/l10n.dart';
import '../providers/collection_provider.dart';
import '../screens/game_detail_screen.dart';
import '../theme/app_theme.dart';
import 'platform_badge.dart';
import 'shimmer_box.dart';

/// The primary rich card used across the home grid, search results and
/// recommendations. Cover-focused with a dark gradient overlay,
/// rating/owned pills and a quick add/remove action.
class GameCoverCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = ref.watch(
      collectionProvider.select((s) => s.contains(game.id)),
    );
    final platformKey =
        game.ownedPlatformName ??
        (game.platformNames.isNotEmpty ? game.platformNames.first : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameDetailScreen(game: game)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppColors.surface,
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                _CoverLayer(game: game),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.92),
                        ],
                        stops: const [0.0, 0.55, 1.0],
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
  const _CoverLayer({required this.game});

  @override
  Widget build(BuildContext context) {
    final url = game.coverUrl;
    if (url == null) {
      return Container(
        color: AppColors.surfaceHi,
        child: const Center(
          child: Icon(
            Icons.videogame_asset,
            color: AppColors.textMuted,
            size: 64,
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => const ShimmerBox(),
      errorWidget: (_, _, _) => Container(
        color: AppColors.surfaceHi,
        child: const Center(
          child: Icon(Icons.broken_image, color: AppColors.textMuted),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.warning, size: 13),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(0),
            style: const TextStyle(
              color: AppColors.textPrimary,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, color: Colors.white, size: 13),
          const SizedBox(width: 2),
          Text(
            context.l10n.owned,
            style: const TextStyle(
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
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            height: 1.2,
            shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
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
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
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
    final l10n = context.l10n;
    final color = owned ? AppColors.danger : AppColors.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                owned ? Icons.remove_rounded : Icons.add_rounded,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                owned ? l10n.removeShort : l10n.addToShelfShort,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

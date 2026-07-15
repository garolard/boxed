import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../providers/collection_provider.dart';
import '../widgets/add_game_flow.dart';
import '../widgets/genre_chip.dart';
import '../widgets/glass_card.dart';
import '../widgets/neon_button.dart';
import '../widgets/platform_badge.dart';

class GameDetailScreen extends StatelessWidget {
  final Game game;

  const GameDetailScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final owned = context.watch<CollectionProvider>().contains(game.id);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          _CoverAppBar(game: game),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(blurRadius: 12, color: Colors.black54),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 100.ms)
                      .slideY(begin: 0.2, end: 0, duration: 500.ms, delay: 100.ms),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (game.releaseYear != null) _MetaPill(
                        icon: Icons.calendar_today_rounded,
                        label: '${game.releaseYear}',
                        color: const Color(0xFF00E5FF),
                      ),
                      if (game.rating != null) _MetaPill(
                        icon: Icons.star_rounded,
                        label: game.rating!.toStringAsFixed(0),
                        color: const Color(0xFFFFD600),
                      ),
                      for (final genre in game.genres.take(4))
                        GenreChip(name: genre),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                  if (game.platformNames.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionLabel(text: 'AVAILABLE ON'),
                    const SizedBox(height: 8),
                    PlatformBadgeRow(names: game.platformNames)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 300.ms),
                  ],
                  if (game.summary != null) ...[
                    const SizedBox(height: 24),
                    _SectionLabel(text: 'ABOUT'),
                    const SizedBox(height: 8),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        game.summary!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                  ],
                  const SizedBox(height: 28),
                  _PrimaryAction(owned: owned, game: game),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverAppBar extends StatelessWidget {
  final Game game;
  const _CoverAppBar({required this.game});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.fadeTitle,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (game.coverUrl != null)
              Hero(
                tag: 'cover-${game.id}',
                child: CachedNetworkImage(
                  imageUrl: game.coverUrl!,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF2E93), Color(0xFF7C4DFF)],
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Color(0x00000000),
                    Color(0xCC000000),
                  ],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
            if (game.ownedPlatformName != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 64,
                right: 16,
                child: PlatformBadge(shortName: game.ownedPlatformName!),
              ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: color.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFFFF2E93)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final bool owned;
  final Game game;
  const _PrimaryAction({required this.owned, required this.game});

  @override
  Widget build(BuildContext context) {
    if (owned) {
      return Column(
        children: [
          NeonButton(
            label: 'In your shelf',
            icon: Icons.check_circle_rounded,
            colors: const [Color(0xFF00E676), Color(0xFF00B0FF)],
            pulsing: true,
            onPressed: null,
          ),
          const SizedBox(height: 10),
          NeonOutlineButton(
            label: 'Remove from collection',
            icon: Icons.delete_outline_rounded,
            colors: const [Color(0xFFFF1744), Color(0xFFFF6E40)],
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              await context.read<CollectionProvider>().remove(game.id);
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.remove_circle, color: Color(0xFFFF6E40)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '"${game.name}" removed',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 400.ms, delay: 500.ms)
          .slideY(begin: 0.2, end: 0, duration: 500.ms, delay: 500.ms);
    }
    return NeonButton(
      label: 'Add to shelf',
      icon: Icons.add_rounded,
      onPressed: () => addGameFlow(context, game),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 500.ms)
        .slideY(begin: 0.2, end: 0, duration: 500.ms, delay: 500.ms);
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import '../l10n/l10n.dart';
import '../providers/collection_provider.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/add_game_flow.dart';
import '../widgets/genre_chip.dart';
import '../widgets/glass_card.dart';
import '../widgets/neon_button.dart';
import '../widgets/platform_badge.dart';

class GameDetailScreen extends ConsumerWidget {
  final Game game;

  const GameDetailScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = ref.watch(
      collectionProvider.select((s) => s.contains(game.id)),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          _CoverAppBar(game: game),
          SliverToBoxAdapter(
            child: ResponsiveCenter(
              maxWidth: context.readableMaxWidth,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                          game.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.18,
                            letterSpacing: -0.3,
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 100.ms)
                        .slideY(
                          begin: 0.2,
                          end: 0,
                          duration: 500.ms,
                          delay: 100.ms,
                        ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (game.releaseYear != null)
                          _MetaPill(
                            icon: Icons.calendar_today_rounded,
                            label: '${game.releaseYear}',
                            color: AppColors.accent,
                          ),
                        if (game.rating != null)
                          _MetaPill(
                            icon: Icons.star_rounded,
                            label: game.rating!.toStringAsFixed(0),
                            color: AppColors.warning,
                          ),
                        for (final genre in game.genres.take(4))
                          GenreChip(name: genre),
                      ],
                    ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                    if (game.platformNames.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _SectionLabel(text: context.l10n.availableOn),
                      const SizedBox(height: 10),
                      PlatformBadgeRow(
                        names: game.platformNames,
                      ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                    ],
                    if (game.summary != null) ...[
                      const SizedBox(height: 24),
                      _SectionLabel(text: context.l10n.about),
                      const SizedBox(height: 10),
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          game.summary!,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
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
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
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
              Container(color: AppColors.surface),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
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
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _PrimaryAction extends ConsumerWidget {
  final bool owned;
  final Game game;
  const _PrimaryAction({required this.owned, required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (owned) {
      return Column(
            children: [
              NeonButton(
                label: l10n.inYourShelf,
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                onPressed: null,
              ),
              const SizedBox(height: 10),
              NeonOutlineButton(
                label: l10n.removeFromCollection,
                icon: Icons.delete_outline_rounded,
                color: AppColors.danger,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  await ref.read(collectionProvider.notifier).remove(game.id);
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(
                            Icons.remove_circle,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.gameRemoved(game.name),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
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
          label: l10n.addToShelf,
          icon: Icons.add_rounded,
          onPressed: () => addGameFlow(context, ref, game),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 500.ms)
        .slideY(begin: 0.2, end: 0, duration: 500.ms, delay: 500.ms);
  }
}

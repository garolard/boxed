import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../providers/collection_provider.dart';
import '../providers/services.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/add_game_flow.dart';
import '../widgets/empty_state.dart';
import '../widgets/game_cover_card.dart';
import '../widgets/glass_card.dart';
import '../widgets/neon_button.dart';
import '../widgets/section_header.dart';

class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(analyticsServiceProvider).logScreenView(screenName: 'recommendations');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(collectionProvider.notifier).loadRecommendations(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionProvider);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          l10n.navForYou,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () => ref
                .read(collectionProvider.notifier)
                .loadRecommendations(force: true),
          ),
        ],
      ),
      body: SafeArea(child: _body(state, l10n)),
    );
  }

  Widget _body(CollectionState state, AppLocalizations l10n) {
    if (state.games.isEmpty) {
      return EmptyState(
        icon: Icons.auto_awesome_rounded,
        title: l10n.recsEmptyTitle,
        message: l10n.recsEmptyMessage,
        actionLabel: l10n.emptyShelfAction,
        actionIcon: Icons.search_rounded,
      );
    }
    if (state.recsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.recsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off,
                  color: AppColors.textMuted,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  state.recsError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 200,
                  child: NeonButton(
                    label: l10n.retry,
                    icon: Icons.refresh_rounded,
                    onPressed: () => ref
                        .read(collectionProvider.notifier)
                        .loadRecommendations(force: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (state.recommendations.isEmpty) {
      return Center(
        child: Text(
          l10n.recsTryAddingMore,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final recs = state.recommendations;
    return ResponsiveCenter(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
        children: [
          SectionHeader(
            title: l10n.featuredTitle,
            subtitle: l10n.featuredSubtitle,
            icon: Icons.auto_awesome_rounded,
          ),
          SizedBox(height: 320, child: _Carousel(games: recs)),
          SectionHeader(title: l10n.allPicks, icon: Icons.grid_view_rounded),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recs.length,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: context.coverExtent,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.68,
              ),
              itemBuilder: (_, i) {
                final game = recs[i];
                return GameCoverCard(
                      game: game,
                      dense: true,
                      onAddPressed: () => _toggle(context, game),
                    )
                    .animate()
                    .fadeIn(duration: 350.ms, delay: (30 * i).ms)
                    .slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 400.ms,
                      delay: (30 * i).ms,
                    );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, Game game) async {
    final notifier = ref.read(collectionProvider.notifier);
    if (ref.read(collectionProvider).contains(game.id)) {
      await notifier.remove(game.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gameRemoved(game.name))),
        );
      }
    } else {
      await addGameFlow(context, ref, game);
    }
  }
}

class _Carousel extends ConsumerStatefulWidget {
  final List<Game> games;
  const _Carousel({required this.games});

  @override
  ConsumerState<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends ConsumerState<_Carousel> {
  late final PageController _controller;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.78);
    _controller.addListener(() {
      setState(() => _page = _controller.page ?? 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.games.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (_, i) {
        final game = widget.games[i];
        final diff = (i - _page).abs().clamp(0, 1);
        final scale = 1 - diff * 0.06;
        return Transform.scale(
          scale: scale,
          child: GameCoverCard(
            game: game,
            onAddPressed: () => _toggle(context, game),
          ),
        );
      },
    );
  }

  Future<void> _toggle(BuildContext context, Game game) async {
    final notifier = ref.read(collectionProvider.notifier);
    if (ref.read(collectionProvider).contains(game.id)) {
      await notifier.remove(game.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gameRemoved(game.name))),
        );
      }
    } else {
      await addGameFlow(context, ref, game);
    }
  }
}

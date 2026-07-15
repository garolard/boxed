import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../providers/collection_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_game_flow.dart';
import '../widgets/empty_state.dart';
import '../widgets/game_cover_card.dart';
import '../widgets/glass_card.dart';
import '../widgets/neon_button.dart';
import '../widgets/section_header.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<CollectionProvider>().loadRecommendations());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CollectionProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'For you',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () => provider.loadRecommendations(force: true),
          ),
        ],
      ),
      body: SafeArea(
        child: _body(provider),
      ),
    );
  }

  Widget _body(CollectionProvider provider) {
    if (provider.games.isEmpty) {
      return const EmptyState(
        icon: Icons.auto_awesome_rounded,
        title: 'No recommendations yet',
        message:
            'Add a few games to your shelf and we\'ll suggest titles based on what you already love.',
        actionLabel: 'Search a game',
        actionIcon: Icons.search_rounded,
      );
    }
    if (provider.recsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.recsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off,
                    color: AppColors.textMuted, size: 40),
                const SizedBox(height: 12),
                Text(
                  provider.recsError!,
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
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    onPressed: () => provider.loadRecommendations(force: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (provider.recommendations.isEmpty) {
      return const Center(
        child: Text(
          'No recommendations yet — try adding more games.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final recs = provider.recommendations;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
      children: [
        const SectionHeader(
          title: 'Featured',
          subtitle: 'Based on what you own',
          icon: Icons.auto_awesome_rounded,
        ),
        SizedBox(
          height: 320,
          child: _Carousel(games: recs),
        ),
        const SectionHeader(
          title: 'All picks',
          icon: Icons.grid_view_rounded,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recs.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
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
                  .slideY(begin: 0.1, end: 0, duration: 400.ms, delay: (30 * i).ms);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _toggle(BuildContext context, Game game) async {
    final provider = context.read<CollectionProvider>();
    if (provider.contains(game.id)) {
      await provider.remove(game.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${game.name}" removed')),
        );
      }
    } else {
      await addGameFlow(context, game);
    }
  }
}

class _Carousel extends StatefulWidget {
  final List<Game> games;
  const _Carousel({required this.games});

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
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
    final provider = context.read<CollectionProvider>();
    if (provider.contains(game.id)) {
      await provider.remove(game.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${game.name}" removed')),
        );
      }
    } else {
      await addGameFlow(context, game);
    }
  }
}

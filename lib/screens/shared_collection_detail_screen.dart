import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shared_collection.dart';
import '../l10n/l10n.dart';
import '../providers/collection_provider.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/add_game_flow.dart';
import '../widgets/game_cover_card.dart';

/// Browse a friend's shared collection. Games can be added to the
/// user's own shelf from here; the shared list itself never changes it.
class SharedCollectionDetailScreen extends ConsumerWidget {
  final SharedCollection collection;

  const SharedCollectionDetailScreen({super.key, required this.collection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final own = ref.watch(collectionProvider);
    final l10n = context.l10n;
    final ownedCount = collection.games.where((g) => own.contains(g.id)).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ResponsiveCenter(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    l10n.sharedDetailCount(collection.games.length, ownedCount),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: context.coverExtent,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.68,
                ),
                delegate: SliverChildBuilderDelegate((context, i) {
                  final game = collection.games[i];
                  final owned = own.contains(game.id);
                  return GameCoverCard(
                        game: game,
                        dense: true,
                        onAddPressed: owned
                            ? null
                            : () => addGameFlow(context, ref, game),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: (30 * i).ms)
                      .slideY(
                        begin: 0.15,
                        end: 0,
                        duration: 500.ms,
                        delay: (30 * i).ms,
                        curve: Curves.easeOutCubic,
                      );
                }, childCount: collection.games.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

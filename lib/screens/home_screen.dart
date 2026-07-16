import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/game.dart';
import '../l10n/l10n.dart';
import '../providers/collection_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_game_flow.dart';
import '../widgets/empty_state.dart';
import '../widgets/game_cover_card.dart';
import '../widgets/genre_chip.dart';
import '../widgets/glass_card.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/stats_dashboard.dart';
import '../widgets/share_qr_sheet.dart';
import 'recommendations_screen.dart';
import 'scan_screen.dart';
import 'search_screen.dart';
import 'shared_collections_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  void _setTab(int i) {
    if (!mounted) return;
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          _SummaryTab(onJumpToSearch: () => _setTab(1)),
          SearchScreen(),
          ScanScreen(),
          RecommendationsScreen(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        index: _tab,
        onChanged: _setTab,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _BottomNav({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      _NavSpec(Icons.collections_bookmark_rounded, l10n.navShelf),
      _NavSpec(Icons.search_rounded, l10n.navSearch),
      _NavSpec(Icons.camera_rounded, l10n.navScan),
      _NavSpec(Icons.auto_awesome_rounded, l10n.navForYou),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavItem(
                        spec: items[i],
                        selected: i == index,
                        onTap: () => onChanged(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavSpec {
  final IconData icon;
  final String label;
  _NavSpec(this.icon, this.label);
}

class _NavItem extends StatelessWidget {
  final _NavSpec spec;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              spec.icon,
              color: selected
                  ? AppColors.accent
                  : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                spec.label,
                maxLines: 1,
                style: TextStyle(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  final VoidCallback onJumpToSearch;
  const _SummaryTab({required this.onJumpToSearch});

  Future<void> _export(BuildContext context) async {
    final provider = context.read<CollectionProvider>();
    final subject = context.l10n.shareSubject;
    final path = await provider.exportCollection();
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: subject),
    );
  }

  Future<void> _import(BuildContext context) async {
    final provider = context.read<CollectionProvider>();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final jsonGroup = XTypeGroup(
      label: l10n.fileLabelJson,
      extensions: const ['json'],
      uniformTypeIdentifiers: const ['public.json'],
      mimeTypes: const ['application/json'],
    );
    final picked = await openFile(acceptedTypeGroups: [jsonGroup]);
    if (picked == null) return;
    final path = picked.path;
    try {
      final result = await provider.importCollection(path);
      messenger.showSnackBar(SnackBar(
          content: Text(
              l10n.importResult(result.imported, result.skipped))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.importFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CollectionProvider>();
    final l10n = context.l10n;
    final games = provider.games;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            l10n.shelfTitle,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded,
                  color: AppColors.textPrimary),
              tooltip: l10n.sharedCollectionsTooltip,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SharedCollectionsScreen()),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textPrimary),
              onSelected: (v) => switch (v) {
                'export' => _export(context),
                'import' => _import(context),
                _ => showShareQrSheet(context),
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'share_qr',
                    child: ListTile(
                        leading: const Icon(Icons.qr_code_rounded),
                        title: Text(l10n.menuShareQr))),
                PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                        leading: const Icon(Icons.upload_file),
                        title: Text(l10n.menuExport))),
                PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                        leading: const Icon(Icons.download),
                        title: Text(l10n.menuImport))),
              ],
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverToBoxAdapter(
            child: !provider.loaded
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: _StatsSkeleton(),
                  )
                : games.isEmpty
                    ? _EmptyCollection(onSearch: onJumpToSearch)
                    : Column(
                        children: [
                          StatsDashboard(provider: provider),
                          if (provider.countByGenre.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _TopGenresRow(provider: provider),
                          ],
                        ],
                      ),
          ),
        ),
        if (!provider.loaded)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (games.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader(
              title: l10n.yourGames,
              subtitle: l10n.yourGamesSubtitle,
              icon: Icons.style_rounded,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final game = games[i];
                  return GameCoverCard(
                    game: game,
                    dense: true,
                    onAddPressed: () => _toggleOwnership(
                        context, game, !provider.contains(game.id)),
                  )
                      .animate()
                      .fadeIn(
                        duration: 400.ms,
                        delay: (30 * i).ms,
                        curve: Curves.easeOut,
                      )
                      .slideY(
                        begin: 0.15,
                        end: 0,
                        duration: 500.ms,
                        delay: (30 * i).ms,
                        curve: Curves.easeOutCubic,
                      );
                },
                childCount: games.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _toggleOwnership(
      BuildContext context, Game game, bool add) async {
    final provider = context.read<CollectionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final removedMessage = context.l10n.gameRemoved(game.name);
    if (add) {
      await addGameFlow(context, game);
    } else {
      await provider.remove(game.id);
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.remove_circle, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  removedMessage,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 140, height: 56),
          SizedBox(height: 14),
          ShimmerBox(height: 8, borderRadius: BorderRadius.all(Radius.circular(99))),
          SizedBox(height: 8),
          ShimmerBox(height: 8, borderRadius: BorderRadius.all(Radius.circular(99))),
          SizedBox(height: 8),
          ShimmerBox(height: 8, borderRadius: BorderRadius.all(Radius.circular(99))),
        ],
      ),
    );
  }
}

class _TopGenresRow extends StatelessWidget {
  final CollectionProvider provider;
  const _TopGenresRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    final byGenre = provider.countByGenre.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = byGenre.take(8).toList();
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: top.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GenreChip(name: top[i].key),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 200.ms)
        .slideY(begin: 0.2, end: 0, duration: 500.ms, delay: 200.ms);
  }
}

class _EmptyCollection extends StatelessWidget {
  final VoidCallback onSearch;
  const _EmptyCollection({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: EmptyState(
        title: l10n.emptyShelfTitle,
        message: l10n.emptyShelfMessage,
        actionLabel: l10n.emptyShelfAction,
        actionIcon: Icons.search_rounded,
        onAction: onSearch,
      ),
    );
  }
}

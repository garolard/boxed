import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/game.dart';
import '../providers/collection_provider.dart';
import '../widgets/add_game_flow.dart';
import '../widgets/empty_state.dart';
import '../widgets/game_cover_card.dart';
import '../widgets/genre_chip.dart';
import '../widgets/glass_card.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/stats_dashboard.dart';
import 'recommendations_screen.dart';
import 'scan_screen.dart';
import 'search_screen.dart';

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
      bottomNavigationBar: _NeonNavBar(
        index: _tab,
        onChanged: _setTab,
      ),
    );
  }
}

class _NeonNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _NeonNavBar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = const [
      _NavSpec(Icons.collections_bookmark_rounded, 'Shelf'),
      _NavSpec(Icons.search_rounded, 'Search'),
      _NavSpec(Icons.camera_rounded, 'Scan'),
      _NavSpec(Icons.auto_awesome_rounded, 'For you'),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(child: _NavItem(
                      spec: items[i],
                      selected: i == index,
                      onTap: () => onChanged(i),
                    )),
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
  const _NavSpec(this.icon, this.label);
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0xFFFF2E93), Color(0xFF7C4DFF)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF2E93)
                                .withValues(alpha: 0.55),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  spec.icon,
                  color: selected ? Colors.white : Colors.white70,
                  size: 20,
                ),
              ),
              const SizedBox(height: 3),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    spec.label,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
    final path = await provider.exportCollection();
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: 'My game collection'),
    );
  }

  Future<void> _import(BuildContext context) async {
    final provider = context.read<CollectionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    const jsonGroup = XTypeGroup(
      label: 'JSON',
      extensions: ['json'],
      uniformTypeIdentifiers: ['public.json'],
      mimeTypes: ['application/json'],
    );
    final picked = await openFile(acceptedTypeGroups: const [jsonGroup]);
    if (picked == null) return;
    final path = picked.path;
    try {
      final result = await provider.importCollection(path);
      messenger.showSnackBar(SnackBar(
          content: Text(
              'Imported ${result.imported} games (${result.skipped} already owned)')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CollectionProvider>();
    final games = provider.games;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [
                Color(0xFFFF2E93),
                Color(0xFF00E5FF),
                Color(0xFFFFD600),
              ],
            ).createShader(rect),
            child: const Text(
              'MY SHELF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onSelected: (v) =>
                  v == 'export' ? _export(context) : _import(context),
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                        leading: Icon(Icons.upload_file),
                        title: Text('Export collection'))),
                PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                        leading: Icon(Icons.download),
                        title: Text('Import collection'))),
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
          const SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Your games',
              subtitle: 'Tap a cover to view details',
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
                    onAddPressed: () =>
                        _toggleOwnership(context, game, !provider.contains(game.id)),
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
    if (add) {
      await addGameFlow(context, game);
    } else {
      await provider.remove(game.id);
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
          ShimmerBox(height: 10, borderRadius: BorderRadius.all(Radius.circular(99))),
          SizedBox(height: 8),
          ShimmerBox(height: 10, borderRadius: BorderRadius.all(Radius.circular(99))),
          SizedBox(height: 8),
          ShimmerBox(height: 10, borderRadius: BorderRadius.all(Radius.circular(99))),
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
      height: 36,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: EmptyState(
        title: 'Your shelf is empty',
        message:
            'Pop in the games you own physically. Search by title or scan a cover with your camera — we\'ll handle the rest.',
        actionLabel: 'Search a game',
        actionIcon: Icons.search_rounded,
        onAction: onSearch,
      ),
    );
  }
}

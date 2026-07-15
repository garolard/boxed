import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/platforms.dart';
import '../providers/collection_provider.dart';
import '../services/igdb_service.dart';
import '../widgets/add_game_flow.dart';
import '../widgets/empty_state.dart';
import '../widgets/game_cover_card.dart';
import '../widgets/genre_chip.dart';
import '../widgets/glass_card.dart';
import '../widgets/neon_button.dart';
import '../theme/platform_palette.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  List<Game> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  int? _platformId;
  int? _genreId;
  List<IgdbGenre> _genres = [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    _loadGenres();
    final q = widget.initialQuery;
    if (q != null && q.isNotEmpty) {
      _controller.text = q;
      _search();
    }
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await context.read<CollectionProvider>().igdb.genres();
      if (mounted) setState(() => _genres = genres);
    } catch (_) {
      // Genre filter stays hidden; search still works.
    }
  }

  void _onQueryChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _search);
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await context.read<CollectionProvider>().igdb.searchGames(
            query,
            platformId: _platformId,
            genreId: _genreId,
          );
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _searched = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
          ).createShader(rect),
          child: const Text(
            'SEARCH',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _ArcadeSearchBar(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _search(),
                onClear: () {
                  _controller.clear();
                  setState(() {
                    _results = [];
                    _searched = false;
                  });
                },
              ),
            ),
            _Filters(
              platformId: _platformId,
              genreId: _genreId,
              genres: _genres,
              onPlatformChanged: (v) {
                setState(() => _platformId = v);
                _search();
              },
              onGenreChanged: (v) {
                setState(() => _genreId = v);
                _search();
              },
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(99)),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              ),
            const SizedBox(height: 4),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 200,
                  child: NeonButton(
                    label: 'Try again',
                    icon: Icons.refresh_rounded,
                    onPressed: _search,
                    colors: const [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      if (!_searched) {
        return _SearchHint(onPick: (q) {
          _controller.text = q;
          _focusNode.unfocus();
          _search();
        });
      }
      return Center(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No matches',
          message:
              'Try a different title, pick a different system, or clear the genre filter.',
          actionLabel: 'Clear filters',
          actionIcon: Icons.refresh_rounded,
          actionColors: const [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
          onAction: () {
            setState(() {
              _platformId = null;
              _genreId = null;
            });
            _search();
          },
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GridView.builder(
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: _results.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.68,
        ),
        itemBuilder: (_, i) {
          final game = _results[i];
          return GameCoverCard(
            game: game,
            dense: true,
            onAddPressed: () => _onAdd(context, game),
          )
              .animate()
              .fadeIn(duration: 350.ms, delay: (30 * i).ms)
              .slideY(begin: 0.1, end: 0, duration: 400.ms, delay: (30 * i).ms);
        },
      ),
    );
  }

  Future<void> _onAdd(BuildContext context, Game game) async {
    final provider = context.read<CollectionProvider>();
    if (provider.contains(game.id)) {
      await provider.remove(game.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${game.name}" removed'),
          ),
        );
      }
    } else {
      await addGameFlow(context, game);
    }
  }
}

class _ArcadeSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _ArcadeSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  blurRadius: 22,
                ),
              ]
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: focused
                ? const Color(0xFF00E5FF)
                : Colors.white.withValues(alpha: 0.15),
            width: focused ? 1.5 : 1,
          ),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'Game title…',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF00E5FF),
            ),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: onClear,
                  ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            fillColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final int? platformId;
  final int? genreId;
  final List<IgdbGenre> genres;
  final ValueChanged<int?> onPlatformChanged;
  final ValueChanged<int?> onGenreChanged;
  const _Filters({
    required this.platformId,
    required this.genreId,
    required this.genres,
    required this.onPlatformChanged,
    required this.onGenreChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'SYSTEM',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: Container(height: 1, color: Colors.white10)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _PlatformPill(
                  label: 'All',
                  color: const Color(0xFFFF2E93),
                  selected: platformId == null,
                  onTap: () => onPlatformChanged(null),
                ),
                for (final p in kPlatforms) ...[
                  const SizedBox(width: 6),
                  _PlatformPill(
                    label: p.shortName,
                    color: PlatformPalette.of(p.shortName),
                    selected: platformId == p.id,
                    onTap: () => onPlatformChanged(p.id),
                  ),
                ],
              ],
            ),
          ),
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'GENRE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: Container(height: 1, color: Colors.white10)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  GenreChip(
                    name: 'All',
                    selected: genreId == null,
                    onTap: () => onGenreChanged(null),
                  ),
                  for (final g in genres) ...[
                    const SizedBox(width: 6),
                    GenreChip(
                      name: g.name,
                      selected: genreId == g.id,
                      onTap: () => onGenreChanged(g.id),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlatformPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _PlatformPill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: selected ? LinearGradient(colors: [color, color.withValues(alpha: 0.7)]) : null,
            color: selected ? null : color.withValues(alpha: 0.15),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.4),
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(99),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.55),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _SearchHint({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: const Icon(Icons.travel_explore_rounded,
                  color: Colors.white, size: 48),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                  duration: 1800.ms,
                  begin: const Offset(1, 1),
                  end: const Offset(1.08, 1.08),
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 20),
            const Text(
              'DISCOVER GAMES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Search the IGDB catalog. Filter by system or genre to drill down.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _Suggestion(label: 'Zelda', onPick: onPick),
                _Suggestion(label: 'Final Fantasy', onPick: onPick),
                _Suggestion(label: 'Metroid', onPick: onPick),
                _Suggestion(label: 'Hollow Knight', onPick: onPick),
                _Suggestion(label: 'Stardew Valley', onPick: onPick),
                _Suggestion(label: 'Persona 5', onPick: onPick),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  final String label;
  final ValueChanged<String> onPick;
  const _Suggestion({required this.label, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => onPick(label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

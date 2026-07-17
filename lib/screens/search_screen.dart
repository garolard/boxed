import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import '../models/platforms.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../providers/collection_provider.dart';
import '../providers/services.dart';
import '../services/analytics_service.dart';
import '../services/igdb_service.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/add_game_flow.dart';
import '../widgets/empty_state.dart';
import '../widgets/game_cover_card.dart';
import '../widgets/genre_chip.dart';
import '../widgets/glass_card.dart';
import '../widgets/neon_button.dart';
import '../theme/platform_palette.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
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
    ref.read(analyticsServiceProvider).logScreenView(screenName: 'search');
    final q = widget.initialQuery;
    if (q != null && q.isNotEmpty) {
      _controller.text = q;
      _search();
    }
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await ref.read(igdbServiceProvider).genres();
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
    final platformName = _platformId == null
        ? null
        : kPlatforms.firstWhere((p) => p.id == _platformId).shortName;
    final genreName = _genreId == null
        ? null
        : _genres.firstWhere((g) => g.id == _genreId).name;
    try {
      final results = await ref
          .read(igdbServiceProvider)
          .searchGames(query, platformId: _platformId, genreId: _genreId);
      if (mounted) setState(() => _results = results);
      await ref.read(analyticsServiceProvider).logSearch(SearchEventParams(
            query: query,
            platformFilter: platformName,
            genreFilter: genreName,
            resultCount: results.length,
          ));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      await ref.read(analyticsServiceProvider).logSearch(SearchEventParams(
            query: query,
            platformFilter: platformName,
            genreFilter: genreName,
            resultCount: 0,
            hasError: true,
            errorMessage: '$e',
          ));
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
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          l10n.searchTitle,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _SearchField(
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
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                ),
              const SizedBox(height: 4),
              Expanded(child: _body(l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off,
                  size: 40,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
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
                    label: l10n.tryAgain,
                    icon: Icons.refresh_rounded,
                    onPressed: _search,
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
        return _SearchHint(
          onPick: (q) {
            _controller.text = q;
            _focusNode.unfocus();
            _search();
          },
        );
      }
      return Center(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: l10n.noMatches,
          message: l10n.noMatchesMessage,
          actionLabel: l10n.clearFilters,
          actionIcon: Icons.refresh_rounded,
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
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: context.coverExtent,
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

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    final l10n = context.l10n;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused
              ? AppColors.accent
              : Colors.white.withValues(alpha: 0.06),
          width: focused ? 1.4 : 1,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: l10n.searchHint,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                  ),
                  onPressed: onClear,
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          fillColor: AppColors.surface,
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
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(l10n.filterSystem),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _PlatformPill(
                  label: l10n.filterAll,
                  color: AppColors.accent,
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
            _Label(l10n.filterGenre),
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  GenreChip(
                    name: l10n.filterAll,
                    color: AppColors.accent,
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
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
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.18) : AppColors.surface,
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.4),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.4,
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
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: 0.15),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.travel_explore_rounded,
                    color: AppColors.accent,
                    size: 40,
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
                  duration: 1800.ms,
                  begin: 1.0,
                  end: 1.06,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 18),
            Text(
              l10n.discoverGames,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.discoverGamesMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
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
            color: AppColors.surface,
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/l10n.dart';
import '../providers/collection_provider.dart';
import '../theme/app_theme.dart';
import 'animated_count.dart';
import 'glass_card.dart';

/// Dashboard header showing total games and a top-systems bar chart.
/// Uses a single accent color for the chart so it doesn't compete with
/// the platform badges elsewhere.
class StatsDashboard extends StatelessWidget {
  final CollectionState state;
  const StatsDashboard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final byPlatform = state.countByPlatform.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topPlatforms = byPlatform.take(4).toList();
    final maxCount = topPlatforms.isEmpty
        ? 1
        : topPlatforms.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final total = state.games.length;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedCount(
                value: total,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  l10n.gamesInShelf(total),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (topPlatforms.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l10n.topSystems,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < topPlatforms.length; i++)
              _BarRow(
                label: topPlatforms[i].key == 'Unknown'
                    ? l10n.unknownPlatform
                    : topPlatforms[i].key,
                value: topPlatforms[i].value,
                max: maxCount,
                delay: 80 * i,
              ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, curve: Curves.easeOut);
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final int delay;
  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (value / max).clamp(0.05, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHi,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                )
                    .animate(delay: delay.ms)
                    .scaleX(
                      begin: 0,
                      end: 1,
                      duration: 700.ms,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                    ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 24,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/collection_provider.dart';
import 'animated_count.dart';
import 'glass_card.dart';

/// Dashboard header that shows total games, top platforms (mini bar chart)
/// and a colorful "achievement-style" stat per top platform.
class StatsDashboard extends StatelessWidget {
  final CollectionProvider provider;
  const StatsDashboard({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final byPlatform = provider.countByPlatform.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topPlatforms = byPlatform.take(4).toList();
    final maxCount = topPlatforms.isEmpty
        ? 1
        : topPlatforms.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final total = provider.games.length;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      tint: Colors.white.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  colors: [
                    Color(0xFFFF2E93),
                    Color(0xFF00E5FF),
                    Color(0xFFFFD600),
                  ],
                ).createShader(rect),
                child: AnimatedCount(
                  value: total,
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  total == 1 ? 'game\nin your shelf' : 'games\nin your shelf',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          if (topPlatforms.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'TOP SYSTEMS',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < topPlatforms.length; i++)
              _BarRow(
                label: topPlatforms[i].key,
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
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF00E5FF),
                          Color(0xFF7C4DFF),
                          Color(0xFFFF2E93),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFFFF2E93),
                          blurRadius: 8,
                        ),
                      ],
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
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/platform_palette.dart';

/// Compact pill that shows a platform short name with its brand color and
/// a subtle glow. Use for owned-platform labels on game cards and details.
class PlatformBadge extends StatelessWidget {
  final String shortName;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool compact;

  const PlatformBadge({
    super.key,
    required this.shortName,
    this.fontSize = 11,
    this.padding =
        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = PlatformPalette.of(shortName);
    final accent = PlatformPalette.accentOf(shortName);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Text(
            shortName,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of platform badges, used in game details.
class PlatformBadgeRow extends StatelessWidget {
  final List<String> names;
  final double spacing;
  const PlatformBadgeRow({
    super.key,
    required this.names,
    this.spacing = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final n in names) PlatformBadge(shortName: n),
      ],
    );
  }
}

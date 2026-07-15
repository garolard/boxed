import 'package:flutter/material.dart';

import '../theme/platform_palette.dart';

/// Compact pill that shows a platform short name. Uses a dark tinted body
/// and a thin brand-color border, with white text — readable on any
/// background, with a hint of the platform's brand color.
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
    final body = PlatformPalette.bodyOf(shortName);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: body,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
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
              letterSpacing: 0.4,
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

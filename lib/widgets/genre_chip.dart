import 'package:flutter/material.dart';

import '../theme/platform_palette.dart';

/// Small colored chip showing a game genre. Each genre gets a stable color
/// derived from its name, so the same genre always uses the same hue.
class GenreChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback? onTap;
  final double fontSize;

  const GenreChip({
    super.key,
    required this.name,
    this.selected = false,
    this.onTap,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final color = GenrePalette.of(name);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: [color, color.withValues(alpha: 0.7)])
                : null,
            color: selected ? null : color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? color
                  : color.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Text(
            name.toUpperCase(),
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

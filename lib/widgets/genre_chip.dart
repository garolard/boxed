import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/platform_palette.dart';

/// Genre chip with a dark body, colored border and white text. Selected
/// state fills with the accent color for emphasis. Always readable, even
/// on the dark background.
class GenreChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback? onTap;
  final double fontSize;
  final Color? color;

  const GenreChip({
    super.key,
    required this.name,
    this.selected = false,
    this.onTap,
    this.fontSize = 11,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? GenrePalette.of(name);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color : AppColors.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? color
                  : color.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Text(
            name.toUpperCase(),
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

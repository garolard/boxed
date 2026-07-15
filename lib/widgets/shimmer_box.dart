import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart' as shimmer_pkg;

/// A lightweight shimmer box used as a placeholder for cover images and
/// other content while it loads.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final ShapeBorder? shape;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF221A45) : const Color(0xFFFFE2D5);
    final highlight =
        isDark ? const Color(0xFF3B2D6B) : const Color(0xFFFFFFFF);
    final borderRadius = this.borderRadius ?? BorderRadius.circular(12);
    return shimmer_pkg.Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1400),
      child: Container(
        width: width,
        height: height,
        decoration: shape != null
            ? ShapeDecoration(color: base, shape: shape!)
            : BoxDecoration(
                color: base,
                borderRadius: borderRadius,
              ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Calm background: a soft vertical gradient with a single, very low-opacity
/// blurred accent blob that slowly drifts. Designed to add depth without
/// color noise.
class GradientBackground extends StatefulWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = context.appBackgroundGradient;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: gradient),
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, _) {
              return CustomPaint(
                painter: _SoftGlowPainter(t: _controller.value),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _SoftGlowPainter extends CustomPainter {
  final double t;
  _SoftGlowPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final phase = t * 2 * math.pi;
    final cx = 0.5 + 0.18 * math.sin(phase);
    final cy = 0.18 + 0.06 * math.sin(phase + 1.2);
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);
    canvas.drawCircle(
      Offset(cx * size.width, cy * size.height),
      size.shortestSide * 0.55,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SoftGlowPainter oldDelegate) =>
      oldDelegate.t != t;
}

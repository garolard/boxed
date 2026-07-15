import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

/// Full-screen animated mesh-style background.
///
/// Renders a base gradient and three slowly drifting, blurred colored blobs
/// on top to give every screen a sense of motion and depth.
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
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              final t = _controller.value;
              return CustomPaint(
                painter: _BlobPainter(
                  t: t,
                  isDark: isDark,
                ),
              );
            },
          ),
        ),
        if (!isDark)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.25),
                  ],
                ),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  final double t;
  final bool isDark;
  _BlobPainter({required this.t, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final blobs = <_Blob>[
      _Blob(
        color: isDark
            ? const Color(0xFFFF2E93).withValues(alpha: 0.30)
            : const Color(0xFFFF6FB5).withValues(alpha: 0.45),
        dx: 0.15 + 0.18 * _wave(t * 2 * 3.14159),
        dy: 0.20 + 0.12 * _wave(t * 2 * 3.14159 + 1.0),
        r: size.shortestSide * 0.55,
      ),
      _Blob(
        color: isDark
            ? const Color(0xFF00E5FF).withValues(alpha: 0.25)
            : const Color(0xFF7FC8FF).withValues(alpha: 0.45),
        dx: 0.80 + 0.15 * _wave(t * 2 * 3.14159 + 2.0),
        dy: 0.35 + 0.12 * _wave(t * 2 * 3.14159 + 3.0),
        r: size.shortestSide * 0.50,
      ),
      _Blob(
        color: isDark
            ? const Color(0xFFFFD600).withValues(alpha: 0.18)
            : const Color(0xFFFFD9A0).withValues(alpha: 0.55),
        dx: 0.50 + 0.20 * _wave(t * 2 * 3.14159 + 4.0),
        dy: 0.85 + 0.10 * _wave(t * 2 * 3.14159 + 5.0),
        r: size.shortestSide * 0.45,
      ),
    ];

    for (final blob in blobs) {
      final paint = Paint()
        ..color = blob.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
      canvas.drawCircle(
        Offset(blob.dx * size.width, blob.dy * size.height),
        blob.r,
        paint,
      );
    }
  }

  static double _wave(double phase) {
    return 0.5 + 0.5 * (1 - (phase - 1).abs());
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.isDark != isDark;
}

class _Blob {
  final Color color;
  final double dx;
  final double dy;
  final double r;
  _Blob({
    required this.color,
    required this.dx,
    required this.dy,
    required this.r,
  });
}

/// Soft white-on-gradient veil used at the top of the screen for legibility.
class TopScrim extends StatelessWidget {
  final double height;
  const TopScrim({super.key, this.height = 180});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (isDark ? AppColors.darkBg : Colors.white)
                    .withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small floating chip badge (e.g. "New", "Hot"). Animated entry.
class FloatingBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const FloatingBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ).animate().scale(
          duration: 400.ms,
          curve: Curves.elasticOut,
        );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Splash screen shown while the app initializes.
///
/// Visuals match the brand: dark gradient background, soft violet glow,
/// the spines icon, the "BOXED" wordmark, and a subtle loading indicator
/// at the bottom. Used as the entry point before [HomeScreen] takes over.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _SplashBackground()),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 3),
                  Center(
                    child: _SpinesLogo(size: 168)
                        .animate()
                        .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                        .scale(
                          begin: const Offset(0.85, 0.85),
                          duration: 700.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ),
                  const SizedBox(height: 36),
                  Center(
                    child: Text(
                      'BOXED',
                      style: GoogleFonts.bungee(
                        fontSize: 38,
                        letterSpacing: 6,
                        color: AppColors.textPrimary,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 250.ms, duration: 600.ms)
                        .slideY(begin: 0.15, end: 0, duration: 700.ms, curve: Curves.easeOutCubic),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'YOUR GAMES, ORGANIZED',
                      style: GoogleFonts.bungee(
                        fontSize: 11,
                        letterSpacing: 4,
                        color: AppColors.textMuted,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 450.ms, duration: 600.ms)
                        .slideY(begin: 0.2, end: 0, duration: 700.ms, curve: Curves.easeOutCubic),
                  ),
                  const Spacer(flex: 4),
                  Center(
                    child: const _LoadingPulse()
                        .animate()
                        .fadeIn(delay: 700.ms, duration: 500.ms),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackground extends StatefulWidget {
  const _SplashBackground();

  @override
  State<_SplashBackground> createState() => _SplashBackgroundState();
}

class _SplashBackgroundState extends State<_SplashBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.bgGradient),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (_, _) {
            return CustomPaint(
              painter: _SplashGlowPainter(t: _controller.value),
            );
          },
        ),
      ],
    );
  }
}

class _SplashGlowPainter extends CustomPainter {
  final double t;
  _SplashGlowPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentGlow.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 140);
    final cx = size.width * (0.5 + 0.04 * (t - 0.5));
    final cy = size.height * 0.45;
    canvas.drawCircle(Offset(cx, cy), size.shortestSide * 0.55, paint);
  }

  @override
  bool shouldRepaint(covariant _SplashGlowPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// The three-spine icon, drawn natively (no asset dependency).
class _SpinesLogo extends StatelessWidget {
  final double size;
  const _SpinesLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SpinesPainter()),
    );
  }
}

class _SpinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // The design is authored in a 1024x1024 coordinate space. Scale it to
    // fit the canvas while keeping the aspect ratio, then center it.
    final scale = math.min(size.width, size.height) / 1024;
    final dx = (size.width - 1024 * scale) / 2;
    final dy = (size.height - 1024 * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    // From here on we draw in the original 1024x1024 space.
    final bottom = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFA78BFA), Color(0xFF6D4FE0)],
      ).createShader(const Rect.fromLTWH(302, 378, 420, 430));
    final middle = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB89BFF), Color(0xFF7A5FE8)],
      ).createShader(const Rect.fromLTWH(332, 318, 360, 430));
    final top = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFC4AAFF), Color(0xFF8B70F0)],
      ).createShader(const Rect.fromLTWH(362, 258, 300, 430));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(302, 378, 420, 430),
        const Radius.circular(28),
      ),
      bottom,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(332, 318, 360, 430),
        const Radius.circular(26),
      ),
      middle,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(362, 258, 300, 430),
        const Radius.circular(24),
      ),
      top,
    );

    final notch = Paint()..color = AppColors.bg.withValues(alpha: 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(452, 282, 120, 14),
        const Radius.circular(7),
      ),
      notch,
    );

    final highlight = Paint()..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawRect(
      const Rect.fromLTWH(362, 258, 300, 60),
      highlight,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpinesPainter oldDelegate) => false;
}

class _LoadingPulse extends StatefulWidget {
  const _LoadingPulse();

  @override
  State<_LoadingPulse> createState() => _LoadingPulseState();
}

class _LoadingPulseState extends State<_LoadingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final t = _controller.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (t + i / 3.0) % 1.0;
            final wave = 1.0 - (phase - 0.5).abs() * 2;
            final clamped = wave.clamp(0.0, 1.0);
            final scale = 0.6 + 0.4 * clamped;
            final opacity = 0.3 + 0.7 * clamped;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

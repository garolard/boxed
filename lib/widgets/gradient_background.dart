import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Calm background: a soft vertical gradient with a single, very low-opacity
/// accent blob that slowly drifts. Designed to add depth without color noise.
///
/// This widget is installed in [MaterialApp.builder], so it sits above the
/// Navigator and is on screen for the entire life of the app. That makes it
/// the one place where an always-on animation is genuinely expensive, so the
/// drift is deliberately cheap:
///
/// * The glow is a [RadialGradient] shader, not a blurred circle. The
///   previous `MaskFilter.blur(sigma: 120)` was a full-screen blur pass that
///   the raster cache cannot reuse, re-run on every single frame.
/// * It repaints at [_fps], not at the display refresh rate. The blob takes
///   [_period] to travel, so nobody can tell 10fps from 120fps here — but it
///   is 6-12x fewer frames.
/// * The ticker is a plain [Timer] that stops whenever the app is not
///   resumed, and never starts when the platform asks for reduced motion.
/// * The glow paints inside a [RepaintBoundary] and drives the painter via
///   `repaint:`, so a drift step repaints only the blob — it neither rebuilds
///   nor re-rasterizes the UI stacked on top of it.
class GradientBackground extends StatefulWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with WidgetsBindingObserver {
  /// How long the blob takes to complete one full drift loop.
  static const Duration _period = Duration(seconds: 24);

  /// Repaint rate of the blob. See the class doc for why this is not vsync.
  static const int _fps = 10;
  static const Duration _frame = Duration(milliseconds: 1000 ~/ _fps);

  /// Drives the painter directly, so a tick never rebuilds [widget.child].
  final ValueNotifier<double> _phase = ValueNotifier<double>(0);

  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-evaluated here so toggling "reduce motion" takes effect immediately.
    _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncTicker();
  }

  bool get _shouldAnimate {
    if (MediaQuery.disableAnimationsOf(context)) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  void _syncTicker() {
    if (_shouldAnimate) {
      _timer ??= Timer.periodic(_frame, _tick);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _tick(Timer _) {
    _elapsed += _frame;
    _phase.value =
        (_elapsed.inMilliseconds % _period.inMilliseconds) /
            _period.inMilliseconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _phase.dispose();
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
          child: RepaintBoundary(
            child: CustomPaint(painter: _SoftGlowPainter(_phase)),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _SoftGlowPainter extends CustomPainter {
  final ValueListenable<double> phase;

  _SoftGlowPainter(this.phase) : super(repaint: phase);

  /// Approximates the falloff of the Gaussian blur this used to be, so the
  /// blob still reads as a soft haze rather than a hard-edged disc.
  static const List<double> _stops = [0.0, 0.35, 0.65, 1.0];
  static const List<double> _alphas = [0.10, 0.075, 0.03, 0.0];

  @override
  void paint(Canvas canvas, Size size) {
    final angle = phase.value * 2 * math.pi;
    final cx = 0.5 + 0.18 * math.sin(angle);
    final cy = 0.18 + 0.06 * math.sin(angle + 1.2);
    final center = Offset(cx * size.width, cy * size.height);
    // Wider than the old circle: the blur used to spread well past its radius.
    final radius = size.shortestSide * 0.95;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..shader = RadialGradient(
        stops: _stops,
        colors: [
          for (final a in _alphas) AppColors.accent.withValues(alpha: a),
        ],
      ).createShader(rect);

    canvas.drawCircle(center, radius, paint);
  }

  // Repaints are driven by `repaint: phase`, not by widget rebuilds.
  @override
  bool shouldRepaint(covariant _SoftGlowPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';

/// Animates a numeric value counting up to `value` when first displayed.
class AnimatedCount extends StatefulWidget {
  final num value;
  final TextStyle? style;
  final Duration duration;
  final String suffix;
  final String prefix;

  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 1100),
    this.suffix = '',
    this.prefix = '',
  });

  @override
  State<AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _displayed = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: widget.value.toDouble())
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic))
      ..addListener(() => setState(() => _displayed = _animation.value));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: _displayed, end: widget.value.toDouble())
          .animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic))
        ..addListener(() => setState(() => _displayed = _animation.value));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.prefix}${_displayed.toStringAsFixed(0)}${widget.suffix}',
      style: widget.style,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Filled button with a gradient, colored glow, and a subtle press
/// animation. Used as the primary CTA across the app.
class NeonButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final List<Color> colors;
  final bool expand;
  final bool pulsing;

  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.colors = const [Color(0xFFFF2E93), Color(0xFF7C4DFF)],
    this.expand = true,
    this.pulsing = false,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final child = AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: disabled
                ? [Colors.grey.shade600, Colors.grey.shade700]
                : widget.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(99),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: widget.colors.first.withValues(alpha: 0.55),
                    blurRadius: 24,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: widget.onPressed,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    widget.label.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final wrapped = SizedBox(
      width: widget.expand ? double.infinity : null,
      child: child,
    );

    if (widget.pulsing && !disabled) {
      return wrapped
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            duration: 1200.ms,
            begin: const Offset(1, 1),
            end: const Offset(1.02, 1.02),
            curve: Curves.easeInOut,
          );
    }
    return wrapped;
  }
}

/// Outlined neon-style button: gradient border with translucent fill.
class NeonOutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final List<Color> colors;
  final bool expand;

  const NeonOutlineButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.colors = const [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return SizedBox(
      width: expand ? double.infinity : null,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: LinearGradient(colors: colors),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.35),
                      blurRadius: 18,
                    ),
                  ],
          ),
          padding: const EdgeInsets.all(2),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(99),
            child: InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: onPressed,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      ShaderMask(
                        shaderCallback: (rect) => LinearGradient(
                          colors: colors,
                        ).createShader(rect),
                        child: Icon(icon, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                    ],
                    ShaderMask(
                      shaderCallback: (rect) => LinearGradient(
                        colors: colors,
                      ).createShader(rect),
                      child: Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

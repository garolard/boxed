import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'neon_button.dart';

/// A friendly empty state with animated floating controller icons and a CTA.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final List<Color> actionColors;

  const EmptyState({
    super.key,
    this.icon = Icons.videogame_asset_off,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.actionColors = const [Color(0xFFFF2E93), Color(0xFF7C4DFF)],
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _floating(
                    Icons.sports_esports_rounded,
                    const Color(0xFFFF2E93),
                    0,
                    Alignment.topLeft,
                    offset: const Offset(-50, -20),
                  ),
                  _floating(
                    Icons.casino_rounded,
                    const Color(0xFF00E5FF),
                    200,
                    Alignment.topRight,
                    offset: const Offset(60, -10),
                  ),
                  _floating(
                    Icons.rocket_launch_rounded,
                    const Color(0xFFFFD600),
                    400,
                    Alignment.bottomLeft,
                    offset: const Offset(-60, 25),
                  ),
                  _floating(
                    Icons.star_rounded,
                    const Color(0xFF7C4DFF),
                    600,
                    Alignment.bottomRight,
                    offset: const Offset(50, 30),
                  ),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2E93), Color(0xFF7C4DFF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2E93).withValues(alpha: 0.5),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 56),
                  ).animate().scale(
                        duration: 600.ms,
                        curve: Curves.elasticOut,
                      ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 240,
                child: NeonButton(
                  label: actionLabel!,
                  icon: actionIcon,
                  expand: true,
                  colors: actionColors,
                  onPressed: onAction,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _floating(
    IconData icon,
    Color color,
    int delay,
    Alignment alignment, {
    required Offset offset,
  }) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 18,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ).animate(delay: delay.ms, onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -8, duration: 1600.ms)
            .then()
            .moveY(begin: -8, end: 0, duration: 1600.ms),
      ),
    );
  }
}

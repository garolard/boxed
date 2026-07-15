import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import 'neon_button.dart';

/// A friendly empty state with subtle floating controller icons and a CTA.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.icon = Icons.videogame_asset_off,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
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
                    const Offset(-50, -20),
                    Alignment.topLeft,
                    0,
                  ),
                  _floating(
                    Icons.casino_rounded,
                    const Offset(60, -10),
                    Alignment.topRight,
                    200,
                  ),
                  _floating(
                    Icons.rocket_launch_rounded,
                    const Offset(-60, 25),
                    Alignment.bottomLeft,
                    400,
                  ),
                  _floating(
                    Icons.star_rounded,
                    const Offset(50, 30),
                    Alignment.bottomRight,
                    600,
                  ),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 48),
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
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.45,
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
    Offset offset,
    Alignment alignment,
    int delay,
  ) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceHi,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ).animate(delay: delay.ms, onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -8, duration: 1600.ms)
            .then()
            .moveY(begin: -8, end: 0, duration: 1600.ms),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../l10n/l10n.dart';
import '../providers/collection_provider.dart';
import '../theme/app_theme.dart';
import 'platform_badge.dart';

/// Asks which platform the owned copy is for (when the game exists on
/// several), then adds the game to the collection.
Future<void> addGameFlow(BuildContext context, Game game) async {
  final provider = context.read<CollectionProvider>();
  int? platformId;
  String? platformName;

  if (game.platformNames.length > 1) {
    final choice = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PlatformPickerSheet(game: game),
    );
    if (choice == null) return;
    platformId = game.platformIds[choice];
    platformName = game.platformNames[choice];
  } else if (game.platformNames.isNotEmpty) {
    platformId = game.platformIds.first;
    platformName = game.platformNames.first;
  }

  await provider.add(game, platformId: platformId, platformName: platformName);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.gameAdded(game.name),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _PlatformPickerSheet extends StatelessWidget {
  final Game game;
  const _PlatformPickerSheet({required this.game});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHi2,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                l10n.whichVersion,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                game.name,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              for (var i = 0; i < game.platformNames.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context, i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHi,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Row(
                          children: [
                            PlatformBadge(shortName: game.platformNames[i]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                game.platformNames[i],
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 250.ms, delay: (40 * i).ms)
                      .slideX(
                        begin: 0.1,
                        end: 0,
                        duration: 280.ms,
                        delay: (40 * i).ms,
                        curve: Curves.easeOutCubic,
                      ),
                ),
            ],
          ),
        );
      },
    );
  }
}

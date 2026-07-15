import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../providers/collection_provider.dart';
import 'platform_badge.dart';

/// Asks which platform the owned copy is for (when the game exists on
/// several), then adds the game to the collection. Uses a colorful sheet
/// with a hero cover, platform picker chips and a glowing CTA.
Future<void> addGameFlow(BuildContext context, Game game) async {
  final provider = context.read<CollectionProvider>();
  int? platformId;
  String? platformName;

  if (game.platformNames.length > 1) {
    final choice = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
            const Icon(Icons.check_circle, color: Color(0xFF00E676)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '"${game.name}" added to collection',
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
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF221A45),
                Color(0xFF0E0B1F),
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const Text(
                'WHICH VERSION DO YOU OWN?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                game.name,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < game.platformNames.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.pop(context, i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
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
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white54,
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

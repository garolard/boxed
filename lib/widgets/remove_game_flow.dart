import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import '../l10n/l10n.dart';
import '../providers/collection_provider.dart';
import '../theme/app_theme.dart';

/// Asks for confirmation, removes the game, then offers an undo for as long as
/// the snackbar is on screen.
///
/// Returns `true` when the game was actually removed, so callers can react
/// (e.g. the detail screen pops itself). The undo restores the exact entry that
/// was removed — owned platform and original `addedAt` included.
Future<bool> removeGameFlow(
    BuildContext context, WidgetRef ref, Game game) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceHi,
      title: Text(l10n.removeGameTitle),
      content: Text(l10n.removeGameMessage(game.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.removeShort),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  if (!context.mounted) return false;

  // Snapshot the stored entry before deleting it: `game` may come from a
  // search result and lack the owned-platform / addedAt fields.
  final stored = ref
      .read(collectionProvider)
      .games
      .cast<Game?>()
      .firstWhere((g) => g!.id == game.id, orElse: () => null);

  // Held across the await and the possible route pop, so the undo callback
  // never touches a disposed element's context or ref.
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(collectionProvider.notifier);

  await notifier.remove(game.id);

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 5),
      // `persist` defaults to `action != null`, which would keep the snackbar
      // (and the undo window) up forever. The undo is time-boxed on purpose.
      persist: false,
      content: Row(
        children: [
          const Icon(Icons.remove_circle, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.gameRemoved(game.name),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      action: SnackBarAction(
        label: l10n.undo,
        textColor: AppColors.accent,
        onPressed: () => notifier.restore(stored ?? game),
      ),
    ),
  );
  return true;
}

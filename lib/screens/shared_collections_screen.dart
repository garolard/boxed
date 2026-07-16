import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/shared_collection.dart';
import '../l10n/l10n.dart';
import '../providers/shared_collections_provider.dart';
import '../services/qr_payload_codec.dart';
import '../services/qr_scan_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/neon_button.dart';
import 'shared_collection_detail_screen.dart';

/// Collections received from friends via QR codes: scan a new one,
/// browse or delete the saved ones.
class SharedCollectionsScreen extends StatefulWidget {
  const SharedCollectionsScreen({super.key});

  @override
  State<SharedCollectionsScreen> createState() =>
      _SharedCollectionsScreenState();
}

class _SharedCollectionsScreenState extends State<SharedCollectionsScreen> {
  final _scanner = QrScanService();
  bool _busy = false;

  Future<void> _scan({required bool fromCamera}) async {
    final provider = context.read<SharedCollectionsProvider>();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _busy = true);
    try {
      final codes = await _scanner.scan(fromCamera: fromCamera);
      if (codes == null) return; // picker cancelled
      if (codes.isEmpty) {
        _toast(messenger, l10n.scanNoQr);
        return;
      }
      QrPayload? payload;
      for (final code in codes) {
        payload = QrPayloadCodec.decode(code);
        if (payload != null) break;
      }
      if (payload == null) {
        _toast(messenger, l10n.notVgcQr);
        return;
      }
      if (payload.entries.isEmpty) {
        _toast(messenger, l10n.sharedEmpty);
        return;
      }
      final saved = await provider.importFromPayload(payload);
      if (!mounted) return;
      navigator.push(MaterialPageRoute(
        builder: (_) => SharedCollectionDetailScreen(collection: saved),
      ));
    } on FormatException {
      _toast(messenger, l10n.qrDamaged);
    } catch (e) {
      _toast(messenger, l10n.importFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(SnackBar(
      content: Text(message,
          style: const TextStyle(fontWeight: FontWeight.w700)),
    ));
  }

  Future<void> _confirmDelete(SharedCollection c) async {
    final provider = context.read<SharedCollectionsProvider>();
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHi,
        title: Text(l10n.deleteSharedTitle),
        content: Text(l10n.deleteSharedMessage(c.name, c.games.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) await provider.delete(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharedCollectionsProvider>();
    final l10n = context.l10n;
    final collections = provider.collections;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          l10n.sharedCollectionsTitle,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  label: l10n.scanACode,
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: _busy ? null : () => _scan(fromCamera: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeonOutlineButton(
                  label: l10n.fromGallery,
                  icon: Icons.photo_library_rounded,
                  onPressed: _busy ? null : () => _scan(fromCamera: false),
                ),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(99)),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          ],
          const SizedBox(height: 20),
          if (provider.loaded && collections.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: EmptyState(
                title: l10n.nothingSharedTitle,
                message: l10n.nothingSharedMessage,
              ),
            )
          else
            for (var i = 0; i < collections.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SharedCollectionRow(
                  collection: collections[i],
                  onDelete: () => _confirmDelete(collections[i]),
                )
                    .animate()
                    .fadeIn(duration: 300.ms, delay: (40 * i).ms)
                    .slideY(begin: 0.1, end: 0, duration: 350.ms),
              ),
        ],
      ),
    );
  }
}

class _SharedCollectionRow extends StatelessWidget {
  final SharedCollection collection;
  final VoidCallback onDelete;
  const _SharedCollectionRow({
    required this.collection,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SharedCollectionDetailScreen(collection: collection),
          ),
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.4),
            ),
          ),
          child: const Icon(Icons.people_alt_rounded,
              color: AppColors.accent, size: 22),
        ),
        title: Text(
          collection.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          l10n.sharedRowMeta(
            collection.games.length,
            DateFormat.yMMMd(locale).format(collection.createdAt),
          ),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: AppColors.textMuted),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

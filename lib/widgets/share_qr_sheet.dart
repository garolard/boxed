import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/l10n.dart';
import '../providers/collection_provider.dart';
import '../services/qr_payload_codec.dart';
import '../theme/app_theme.dart';

/// Bottom sheet that renders the user's collection as a QR code another
/// device can scan. Capped at [QrPayloadCodec.maxGames] games (QR capacity);
/// larger shelves share the most recently added ones.
Future<void> showShareQrSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ShareQrSheet(),
  );
}

class _ShareQrSheet extends ConsumerStatefulWidget {
  const _ShareQrSheet();

  @override
  ConsumerState<_ShareQrSheet> createState() => _ShareQrSheetState();
}

class _ShareQrSheetState extends ConsumerState<_ShareQrSheet> {
  late final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final games = ref.watch(collectionProvider).games;
    final capped = games.take(QrPayloadCodec.maxGames).toList();
    final data = QrPayloadCodec.encode(
      QrPayload(
        name: _nameController.text,
        entries: [for (final g in capped) QrEntry(g.id, g.ownedPlatformId)],
      ),
    );

    _nameController.text = l10n.defaultShelfName;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              l10n.shareQrTitle,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.shareQrSummary(capped.length),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (games.length > QrPayloadCodec.maxGames) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.shareQrCapped(games.length, QrPayloadCodec.maxGames),
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              maxLength: QrPayloadCodec.maxNameChars,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                labelText: l10n.collectionName,
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                // Black-on-white on purpose: the QR needs contrast, not theme.
                child: QrImageView(
                  data: data,
                  version: QrVersions.auto,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  size: 260,
                  gapless: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/title_candidate.dart';
import '../providers/scan_quota_provider.dart';
import '../providers/services.dart';
import '../services/cover_scan_service.dart';
import '../services/scan_quota_service.dart';
import 'paywall_screen.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/glass_card.dart';
import '../widgets/neon_button.dart';
import 'search_screen.dart';

/// Take a picture of a game cover, OCR the text on it and let the user
/// pick which detected title to search for.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _scanner = CoverScanService();
  List<TitleCandidate> _candidates = [];
  bool _scanning = false;
  bool _scanned = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsServiceProvider).logScreenView(screenName: 'scan');
  }

  Future<void> _scan({required bool fromCamera}) async {
    final quota = await ref.read(scanQuotaServiceProvider).quotaStream().first;

    if (quota.readFailed || (!quota.isPremium && quota.scansUsed >= kFreeScanLimit)) {
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const PaywallScreen(),
          ),
        );
      }
      return;
    }

    setState(() {
      _scanning = true;
      _error = null;
    });

    bool recorded = false;
    try {
      final candidates = await _scanner.scan(fromCamera: fromCamera);
      if (candidates.isNotEmpty) {
        final ok = await ref.read(scanQuotaServiceProvider).tryRecordScan();
        if (!ok && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const PaywallScreen(),
            ),
          );
          return;
        }
        recorded = ok;
      }
      if (mounted) {
        setState(() {
          _candidates = candidates;
          _scanned = true;
        });
      }
      await ref.read(analyticsServiceProvider).logScanPerformed(
            source: fromCamera ? 'camera' : 'gallery',
            candidateCount: candidates.length,
            hasError: false,
          );
    } catch (e) {
      if (recorded) {
        await ref.read(scanQuotaServiceProvider).decrementScan();
      }
      if (mounted) setState(() => _error = context.l10n.scanFailed('$e'));
      await ref.read(analyticsServiceProvider).logScanPerformed(
            source: fromCamera ? 'camera' : 'gallery',
            candidateCount: 0,
            hasError: true,
            errorMessage: '$e',
          );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _searchFor(String query) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: query)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          l10n.scanTitle,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: context.readableMaxWidth,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _ScanIntro(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: NeonButton(
                      label: l10n.camera,
                      icon: Icons.photo_camera_rounded,
                      onPressed: _scanning
                          ? null
                          : () => _scan(fromCamera: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: NeonOutlineButton(
                      label: l10n.gallery,
                      icon: Icons.photo_library_rounded,
                      onPressed: _scanning
                          ? null
                          : () => _scan(fromCamera: false),
                    ),
                  ),
                ],
              ),
              if (_scanning) ...[
                const SizedBox(height: 16),
                const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(99)),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                GlassCard(
                  tint: AppColors.danger.withValues(alpha: 0.12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_scanned && _candidates.isEmpty && !_scanning) ...[
                const SizedBox(height: 12),
                GlassCard(
                  child: Row(
                    children: [
                      const Icon(Icons.search_off, color: AppColors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.noReadableText,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_candidates.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.4),
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        l10n.candidatesFound(_candidates.length),
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.detectedText,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < _candidates.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CandidateTile(
                      candidate: _candidates[i],
                      onTap: () => _searchFor(_candidates[i].title),
                      index: i,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanIntro extends ConsumerWidget {
  const _ScanIntro();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final quotaAsync = ref.watch(scanQuotaProvider);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.document_scanner_rounded,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.scanIntroTitle,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.scanIntro,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (quotaAsync.hasValue) ...[
            if (!quotaAsync.value!.isPremium && !quotaAsync.value!.readFailed) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  l10n.freeScansRemaining(
                    (kFreeScanLimit - quotaAsync.value!.scansUsed).clamp(0, kFreeScanLimit),
                    kFreeScanLimit,
                  ),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final TitleCandidate candidate;
  final VoidCallback onTap;
  final int index;
  const _CandidateTile({
    required this.candidate,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: AppColors.accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      candidate.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ConfidenceBadge(percent: candidate.confidencePercent),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: (60 * index).ms)
        .slideX(begin: 0.1, end: 0, duration: 350.ms, delay: (60 * index).ms);
  }
}

/// Small pill showing how confident the model is about a candidate title.
class _ConfidenceBadge extends StatelessWidget {
  final int percent;
  const _ConfidenceBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    final color = percent >= 75
        ? AppColors.accent
        : percent >= 45
            ? AppColors.textSecondary
            : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$percent%',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

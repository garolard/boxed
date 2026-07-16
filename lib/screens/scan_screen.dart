import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/l10n.dart';
import '../services/cover_scan_service.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/glass_card.dart';
import '../widgets/neon_button.dart';
import 'search_screen.dart';

/// Take a picture of a game cover, OCR the text on it and let the user
/// pick which detected title to search for.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _scanner = CoverScanService();
  List<String> _candidates = [];
  bool _scanning = false;
  bool _scanned = false;
  String? _error;

  Future<void> _scan({required bool fromCamera}) async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final candidates = await _scanner.scan(fromCamera: fromCamera);
      if (mounted) {
        setState(() {
          _candidates = candidates;
          _scanned = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = context.l10n.scanFailed('$e'));
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
                      text: _candidates[i],
                      onTap: () => _searchFor(_candidates[i]),
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

class _ScanIntro extends StatelessWidget {
  const _ScanIntro();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
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
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final int index;
  const _CandidateTile({
    required this.text,
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
                      text,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
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

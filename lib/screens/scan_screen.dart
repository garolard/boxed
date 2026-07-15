import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/cover_scan_service.dart';
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
      if (mounted) setState(() => _error = 'Scan failed: $e');
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [Color(0xFFFFD600), Color(0xFFFF6E40)],
          ).createShader(rect),
          child: const Text(
            'SCAN COVER',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            const _Viewfinder(),
            const SizedBox(height: 20),
            const Text(
              'Point your camera at a physical game cover. The text is read on-device and you can search IGDB for any of the detected titles without typing.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: NeonButton(
                    label: 'Camera',
                    icon: Icons.photo_camera_rounded,
                    colors: const [Color(0xFFFFD600), Color(0xFFFF2E93)],
                    onPressed:
                        _scanning ? null : () => _scan(fromCamera: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NeonOutlineButton(
                    label: 'Gallery',
                    icon: Icons.photo_library_rounded,
                    colors: const [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                    onPressed:
                        _scanning ? null : () => _scan(fromCamera: false),
                  ),
                ),
              ],
            ),
            if (_scanning) ...[
              const SizedBox(height: 16),
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(99)),
                child: LinearProgressIndicator(minHeight: 4),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              GlassCard(
                tint: const Color(0xFFFF1744).withValues(alpha: 0.20),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.white,
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
              const GlassCard(
                child: Row(
                  children: [
                    Icon(Icons.search_off, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No readable text found — try a sharper photo, better lighting or hold the cover flat.',
                        style: TextStyle(
                          color: Colors.white,
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
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${_candidates.length} FOUND',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Detected text — tap to search',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < _candidates.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
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
    );
  }
}

class _Viewfinder extends StatefulWidget {
  const _Viewfinder();

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1240), Color(0xFF0B0820)],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF2E93).withValues(alpha: 0.35),
              blurRadius: 30,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0x33FF2E93),
                        Color(0x3300E5FF),
                        Color(0x33FFD600),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(painter: _GridPainter()),
              ),
              const _CornerMarkers(),
              AnimatedBuilder(
                animation: _controller,
                builder: (_, _) {
                  return Positioned(
                    left: 16,
                    right: 16,
                    top: 16 + (_controller.value * 240),
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0x00FF2E93),
                            Color(0xFFFF2E93),
                            Color(0x00FF2E93),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2E93)
                                .withValues(alpha: 0.7),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: const Color(0xFFFFD600)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.center_focus_weak_rounded,
                              color: Color(0xFFFFD600), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'READY TO SCAN',
                            style: TextStyle(
                              color: Color(0xFFFFD600),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 600.ms)
          .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerMarkers extends StatelessWidget {
  const _CornerMarkers();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: const [
            _Corner(Alignment.topLeft, Icons.flash_on_rounded),
            _Corner(Alignment.topRight, Icons.image_rounded),
            _Corner(Alignment.bottomLeft, Icons.text_fields_rounded),
            _Corner(Alignment.bottomRight, Icons.bolt_rounded),
          ],
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  const _Corner(this.alignment, this.icon);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.8),
            width: 1.5,
          ),
        ),
        child: Icon(icon, color: const Color(0xFF00E5FF), size: 16),
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2E93), Color(0xFF7C4DFF)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.search_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (60 * index).ms)
        .slideX(begin: 0.15, end: 0, duration: 350.ms, delay: (60 * index).ms);
  }
}

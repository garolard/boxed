import 'package:flutter/material.dart';

/// Layout breakpoints so the UI adapts from phones to tablets (e.g. a 10"
/// iPad) instead of stretching the mobile layout edge to edge.
///
/// - [compact]  phones and small windows            (< 600dp wide)
/// - [medium]   large phones / small tablets         (600–899dp)
/// - [expanded] tablets and desktop                  (>= 900dp)
enum FormFactor { compact, medium, expanded }

extension ResponsiveContext on BuildContext {
  Size get _screen => MediaQuery.sizeOf(this);

  FormFactor get formFactor {
    final w = _screen.width;
    if (w >= 900) return FormFactor.expanded;
    if (w >= 600) return FormFactor.medium;
    return FormFactor.compact;
  }

  /// True on iPad-class devices in either orientation. Drives whether the
  /// app shows a side navigation rail instead of a bottom nav bar.
  bool get isTablet => _screen.shortestSide >= 600;

  bool get isCompact => formFactor == FormFactor.compact;

  /// Max width the main content column should occupy. Keeps grids, cards and
  /// text from stretching too wide on large screens.
  double get contentMaxWidth => isTablet ? 1080 : double.infinity;

  /// Narrower bound for long-form reading content (e.g. a game description).
  double get readableMaxWidth => isTablet ? 760 : double.infinity;

  /// Horizontal page padding — roomier on tablets.
  double get pagePadding => isTablet ? 24 : 16;

  /// Largest edge length for a single game cover card in a grid. Tablets get
  /// slightly larger cards so a row doesn't turn into a wall of tiny covers.
  double get coverExtent => isTablet ? 200 : 220;
}

/// Centers its [child] and caps its width so content doesn't stretch across a
/// wide tablet screen. On phones it is a no-op (max width is infinite).
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const ResponsiveCenter({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? context.contentMaxWidth,
        ),
        child: child,
      ),
    );
  }
}

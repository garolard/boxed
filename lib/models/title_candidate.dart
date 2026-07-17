/// A game title guessed from a cover photo, with a 0–1 confidence score
/// describing how sure the vision model is that it read the title correctly.
class TitleCandidate {
  final String title;
  final double confidence;

  const TitleCandidate({required this.title, required this.confidence});

  /// Confidence as a rounded percentage (e.g. 0.83 -> 83).
  int get confidencePercent => (confidence.clamp(0, 1) * 100).round();

  factory TitleCandidate.fromJson(Map<String, dynamic> json) {
    final raw = json['confidence'];
    final score = raw is num ? raw.toDouble() : 0.0;
    return TitleCandidate(
      title: (json['title'] as String? ?? '').trim(),
      confidence: score.clamp(0.0, 1.0),
    );
  }
}

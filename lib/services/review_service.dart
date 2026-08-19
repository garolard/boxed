import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';

/// Collection sizes at which the user is asked for a store review. The
/// prompt re-arms at each milestone: both stores already cap how often the
/// native dialog can appear (iOS: at most 3 per 365 days; Play throttles
/// silently), so a later second milestone costs nothing and gives a second
/// chance with the most engaged users if the first prompt was dismissed or
/// silently skipped by the OS quota.
const List<int> kReviewPromptMilestones = [5, 25];

/// Thin seam over the `in_app_review` plugin so tests can substitute a fake
/// without touching the platform channel.
abstract class ReviewGateway {
  Future<bool> isAvailable();
  Future<void> requestReview();
}

class InAppReviewGateway implements ReviewGateway {
  final InAppReview _review;

  InAppReviewGateway({InAppReview? review})
      : _review = review ?? InAppReview.instance;

  @override
  Future<bool> isAvailable() => _review.isAvailable();

  @override
  Future<void> requestReview() => _review.requestReview();
}

/// Asks the user for a store review when their collection reaches each size
/// in [kReviewPromptMilestones].
///
/// Both stores enforce their own quotas on the native prompt (iOS shows it at
/// most 3 times per 365 days; Play may skip it silently), so requests are
/// additionally gated here: one attempt per milestone per install, persisted
/// in SharedPreferences.
class ReviewService {
  /// Collection size at the last successful request. An int, not a bool, so
  /// later milestones can re-arm the prompt.
  static const String _promptedAtSizeKey = 'review_prompted_at_size';

  final ReviewGateway _gateway;
  final SharedPreferences _prefs;
  final AnalyticsService _analytics;

  ReviewService({
    required this._gateway,
    required this._prefs,
    required this._analytics,
  });

  /// Requests the native review prompt when the collection has reached a
  /// milestone that hasn't been used yet.
  ///
  /// Best-effort: plugin failures are swallowed so a review request can never
  /// break the add-game flow, and nothing is persisted in that case so the
  /// milestone stays armed for a later add.
  Future<void> maybeRequestReview(int collectionSize) async {
    final lastPromptedAt = _prefs.getInt(_promptedAtSizeKey) ?? 0;
    final due = kReviewPromptMilestones
        .where((m) => m > lastPromptedAt && collectionSize >= m)
        .firstOrNull;
    if (due == null) return;
    try {
      if (!await _gateway.isAvailable()) return;
      await _gateway.requestReview();
      await _analytics.logReviewPromptRequested(
        milestone: due,
        collectionSize: collectionSize,
      );
      // Record the size, not the milestone, so already-passed milestones are
      // consumed too — a long-time user updating the app with a large
      // collection gets one prompt, not a backlog of them on consecutive adds.
      await _prefs.setInt(_promptedAtSizeKey, collectionSize);
    } catch (_) {
      // Never let a review prompt break the caller.
    }
  }
}

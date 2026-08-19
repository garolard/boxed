import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgcollection/services/analytics_service.dart';
import 'package:vgcollection/services/review_service.dart';

class _FakeReviewGateway implements ReviewGateway {
  bool available = true;
  bool throwOnRequest = false;
  int requests = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    if (throwOnRequest) throw Exception('plugin failure');
    requests++;
  }
}

/// Records only the review events; every other AnalyticsService member falls
/// through to noSuchMethod, as the rest of the test-suite fakes do.
class _FakeAnalytics implements AnalyticsService {
  /// (milestone, collectionSize) pairs the service was asked to log.
  final List<(int, int)> reviewPrompts = [];

  @override
  Future<void> logReviewPromptRequested({
    required int milestone,
    required int collectionSize,
  }) async {
    reviewPrompts.add((milestone, collectionSize));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final first = kReviewPromptMilestones.first;
  final second = kReviewPromptMilestones[1];

  late _FakeReviewGateway gateway;
  late _FakeAnalytics analytics;
  late SharedPreferences prefs;
  late ReviewService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    gateway = _FakeReviewGateway();
    analytics = _FakeAnalytics();
    service = ReviewService(gateway: gateway, prefs: prefs, analytics: analytics);
  });

  test('does nothing below the first milestone', () async {
    await service.maybeRequestReview(first - 1);

    expect(gateway.requests, 0);
    expect(analytics.reviewPrompts, isEmpty);
    expect(prefs.getInt('review_prompted_at_size'), isNull);
  });

  test('requests the prompt at a milestone, logs it and persists the size',
      () async {
    await service.maybeRequestReview(first);

    expect(gateway.requests, 1);
    expect(analytics.reviewPrompts, [(first, first)]);
    expect(prefs.getInt('review_prompted_at_size'), first);
  });

  test('requests the prompt when past a milestone not yet used', () async {
    await service.maybeRequestReview(first + 10);

    expect(gateway.requests, 1);
    expect(analytics.reviewPrompts, [(first, first + 10)]);
  });

  test('does not re-prompt at a milestone already used, even across instances',
      () async {
    await service.maybeRequestReview(first);

    // A fresh instance over the same prefs simulates a later app session.
    final nextSession =
        ReviewService(gateway: gateway, prefs: prefs, analytics: analytics);
    await nextSession.maybeRequestReview(first + 1);

    expect(gateway.requests, 1);
    expect(analytics.reviewPrompts, hasLength(1));
  });

  test('re-arms at the second milestone, then never again', () async {
    await service.maybeRequestReview(first);
    await service.maybeRequestReview(second - 1);
    expect(gateway.requests, 1);

    await service.maybeRequestReview(second);
    expect(gateway.requests, 2);
    expect(analytics.reviewPrompts, [(first, first), (second, second)]);
    expect(prefs.getInt('review_prompted_at_size'), second);

    await service.maybeRequestReview(second + 25);
    expect(gateway.requests, 2);
    expect(analytics.reviewPrompts, hasLength(2));
  });

  test('a long-time collection consumes passed milestones in a single prompt',
      () async {
    // Existing user updates the app with a large collection: one prompt, and
    // every earlier milestone is consumed with it.
    await service.maybeRequestReview(second + 5);
    expect(gateway.requests, 1);
    expect(analytics.reviewPrompts, [(first, second + 5)]);

    await service.maybeRequestReview(second + 6);
    expect(gateway.requests, 1);
  });

  test('skips the request when the plugin is unavailable and stays armed',
      () async {
    gateway.available = false;

    await service.maybeRequestReview(first);

    expect(gateway.requests, 0);
    expect(analytics.reviewPrompts, isEmpty);
    expect(prefs.getInt('review_prompted_at_size'), isNull);

    gateway.available = true;
    await service.maybeRequestReview(first);

    expect(gateway.requests, 1);
    expect(analytics.reviewPrompts, [(first, first)]);
  });

  test('swallows plugin failures and stays armed', () async {
    gateway.throwOnRequest = true;

    await service.maybeRequestReview(first);

    expect(gateway.requests, 0);
    expect(analytics.reviewPrompts, isEmpty);
    expect(prefs.getInt('review_prompted_at_size'), isNull);

    gateway.throwOnRequest = false;
    await service.maybeRequestReview(first);

    expect(gateway.requests, 1);
    expect(analytics.reviewPrompts, [(first, first)]);
  });

  test('respects a size persisted by a previous session', () async {
    SharedPreferences.setMockInitialValues({'review_prompted_at_size': second});
    final seededPrefs = await SharedPreferences.getInstance();
    final seeded =
        ReviewService(gateway: gateway, prefs: seededPrefs, analytics: analytics);

    await seeded.maybeRequestReview(second + 10);

    expect(gateway.requests, 0);
    expect(analytics.reviewPrompts, isEmpty);
  });
}

import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/models/review.dart';
import 'package:antigua_business_map/services/ranking_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ranking is the product promise. If these break, businesses are being
/// ranked by something other than what they earned.
void main() {
  Business makeBusiness({
    required String id,
    double seededRating = 0,
    int seededReviewCount = 0,
    int views = 0,
    int calls = 0,
    int taps = 0,
    BusinessCategory category = BusinessCategory.food,
    SubscriptionTier tier = SubscriptionTier.basic,
    int lastSpotlightWeek = -1,
  }) => Business(
    id: id,
    name: id,
    category: category,
    tier: tier,
    area: 'Dickenson Bay',
    description: '',
    seededRating: seededRating,
    seededReviewCount: seededReviewCount,
    views: views,
    calls: calls,
    whatsappTaps: taps,
    lastSpotlightWeek: lastSpotlightWeek,
  );

  group('ranking score', () {
    test('a business with no reviews scores near zero, not a perfect zero', () {
      // The Bayesian prior pulls an unknown business toward 3.8 rather than
      // pretending it has a 0.0 rating.
      final s = scoreBusiness(makeBusiness(id: 'new'));
      expect(s.total, greaterThan(0));
      expect(s.total, lessThan(50));
    });

    test('one perfect review does not outrank a consistent good record', () {
      final lucky = makeBusiness(
        id: 'lucky',
        seededRating: 5,
        seededReviewCount: 1,
      );
      final steady = makeBusiness(
        id: 'steady',
        seededRating: 4.5,
        seededReviewCount: 40,
      );

      expect(
        scoreBusiness(steady).total,
        greaterThan(scoreBusiness(lucky).total),
      );
    });

    test('engagement raises the score', () {
      final quiet = makeBusiness(
        id: 'quiet',
        seededRating: 4,
        seededReviewCount: 20,
      );
      final busy = makeBusiness(
        id: 'busy',
        seededRating: 4,
        seededReviewCount: 20,
        views: 800,
        calls: 90,
        taps: 60,
      );

      expect(
        scoreBusiness(busy).total,
        greaterThan(scoreBusiness(quiet).total),
      );
    });

    test('score never exceeds 100', () {
      final best = makeBusiness(
        id: 'best',
        seededRating: 5,
        seededReviewCount: 500,
        views: 100000,
        calls: 10000,
        taps: 10000,
      );
      expect(scoreBusiness(best).total, lessThanOrEqualTo(100));
    });

    test('paying more does not affect the score', () {
      final basic = makeBusiness(
        id: 'b',
        seededRating: 4.2,
        seededReviewCount: 30,
      );
      final premium = makeBusiness(
        id: 'p',
        tier: SubscriptionTier.featured,
        seededRating: 4.2,
        seededReviewCount: 30,
      );

      expect(scoreBusiness(premium).total, scoreBusiness(basic).total);
    });
  });

  group('review stats', () {
    test('blends seeded and live reviews', () {
      final b = makeBusiness(id: 'x', seededRating: 4, seededReviewCount: 10)
          .copyWithReviews([
            Review(
              id: 'r1',
              businessId: 'x',
              userId: 'u',
              rating: 5,
              body: '',
              createdAt: DateTime(2026),
              status: ReviewStatus.verified,
            ),
          ]);

      final stats = reviewStats(b);
      expect(stats.count, 11);
      expect(stats.average, closeTo((40 + 5) / 11, 0.001));
    });

    test('removed and locked reviews do not count', () {
      final b = makeBusiness(id: 'x', seededRating: 4, seededReviewCount: 4)
          .copyWithReviews([
            Review(
              id: 'r1',
              businessId: 'x',
              userId: 'u',
              rating: 1,
              body: '',
              createdAt: DateTime(2026),
              status: ReviewStatus.removed,
            ),
          ]);

      expect(reviewStats(b).count, 4);
    });
  });

  group('spotlight rotation', () {
    final many = List.generate(
      15,
      (i) => makeBusiness(
        id: 'b$i',
        tier: SubscriptionTier.featured,
        lastSpotlightWeek: i < 10 ? 1 : -1,
      ),
    );

    test('holds ten slots', () {
      expect(selectSpotlight(businesses: many, currentWeek: 2).length, 10);
    });

    test('serves the least recently featured first', () {
      final chosen = selectSpotlight(businesses: many, currentWeek: 2);
      // The ten that were featured in week 1 should be back in week 2, since
      // the five that never had a slot have the older timestamp.
      expect(chosen.first.id, 'b10');
    });

    test('advancing a week stamps the new holders', () {
      final next = advanceSpotlight(
        businesses: many,
        previousWeek: [],
        currentWeek: 5,
      );
      expect(next.every((b) => b.lastSpotlightWeek == 5), isTrue);
      expect(next.every((b) => b.isSpotlight), isTrue);
    });

    test('delisted businesses never take a slot', () {
      final withDead = [
        ...many,
        makeBusiness(
          id: 'dead',
          tier: SubscriptionTier.delisted,
          lastSpotlightWeek: -5,
        ),
      ];
      final chosen = selectSpotlight(businesses: withDead, currentWeek: 2);
      expect(chosen.any((b) => b.id == 'dead'), isFalse);
    });
  });
}

extension on Business {
  Business copyWithReviews(List<Review> r) => Business(
    id: id,
    name: name,
    category: category,
    tier: tier,
    area: area,
    description: description,
    seededRating: seededRating,
    seededReviewCount: seededReviewCount,
    reviews: r,
    views: views,
    calls: calls,
    whatsappTaps: whatsappTaps,
  );
}

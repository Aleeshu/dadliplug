import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/ranking_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The score exists twice: scoreBusiness() here, and public.rank_score() in
/// supabase/migrations/20261022100000_phase8_ranking.sql, which the nightly
/// snapshot and the Spotlight rotation use. The expected values below were
/// read from the live database:
///
///   select rank_score(0,0,0,0,0), rank_score(4.6,40,23,5,2500),
///          rank_score(3.5,3,0,0,0), rank_score(0,0,25,5,300);
///   -- 32, 92, 39, 71
///
/// If one formula changes, this fails until the other matches.
void main() {
  Business b({
    double seededRating = 0,
    int seededCount = 0,
    int liveSum = 0,
    int liveCount = 0,
    int views = 0,
  }) => Business(
    id: 'x',
    name: 'x',
    category: BusinessCategory.food,
    tier: SubscriptionTier.basic,
    area: 'x',
    description: 'x',
    seededRating: seededRating,
    seededReviewCount: seededCount,
    liveRatingSum: liveSum,
    liveReviewCount: liveCount,
    views: views,
  );

  test('matches public.rank_score', () {
    expect(scoreBusiness(b()).total, 32);
    expect(
      scoreBusiness(
        b(
          seededRating: 4.6,
          seededCount: 40,
          liveSum: 23,
          liveCount: 5,
          views: 2500,
        ),
      ).total,
      92,
    );
    expect(scoreBusiness(b(seededRating: 3.5, seededCount: 3)).total, 39);
    expect(scoreBusiness(b(liveSum: 25, liveCount: 5, views: 300)).total, 71);
  });

  test('live reviews on the listing row count toward the rating', () {
    final before = b(seededRating: 3, seededCount: 2);
    final after = b(seededRating: 3, seededCount: 2, liveSum: 25, liveCount: 5);
    expect(reviewStats(after).count, 7);
    expect(reviewStats(after).average, closeTo((6 + 25) / 7, 1e-9));
    expect(
      scoreBusiness(after).total,
      greaterThan(scoreBusiness(before).total),
    );
  });
}

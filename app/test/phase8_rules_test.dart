import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/leaderboard_service.dart';
import 'package:antigua_business_map/services/listing_filter_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// plan.md Phase 8: "Featured buys a slot and a badge, never a position", and
/// the rank "drives search order and the order inside the Featured page".
///
/// The score test already shows the tier is not an input. These pin the
/// places a customer actually sees an order: the leaderboard, search, and
/// the Featured page.
void main() {
  final now = DateTime.utc(2026, 10, 22);

  Business business(
    String id,
    SubscriptionTier tier, {
    double rating = 4.5,
    int reviews = 20,
    int views = 500,
  }) => Business(
    id: id,
    name: id,
    category: BusinessCategory.food,
    tier: tier,
    area: 'St. John’s',
    description: 'x',
    latitude: 17.1,
    longitude: -61.8,
    seededRating: rating,
    seededReviewCount: reviews,
    views: views,
    createdAt: DateTime.utc(2026),
  );

  // A strong Basic listing, and a weaker one paying for Featured.
  final strongBasic = business('strong-basic', SubscriptionTier.basic);
  final weakFeatured = business(
    'weak-featured',
    SubscriptionTier.featured,
    rating: 3.6,
    reviews: 4,
    views: 40,
  );

  test(
    'on the leaderboard, paying Featured does not lift a weaker listing',
    () {
      final board = const LeaderboardService().build(
        businesses: [weakFeatured, strongBasic],
        category: BusinessCategory.food,
        now: now,
      );
      expect(board.entries.map((e) => e.business.id), [
        'strong-basic',
        'weak-featured',
      ]);
    },
  );

  test(
    'two listings with the same numbers score the same whatever they pay',
    () {
      final board = const LeaderboardService().build(
        businesses: [
          business('a', SubscriptionTier.growing),
          business('b', SubscriptionTier.featured),
        ],
        category: BusinessCategory.food,
        now: now,
      );
      expect(board.entries[0].score.total, board.entries[1].score.total);
    },
  );

  test('search is in rank order by default, not by plan', () {
    final results = ListingFilter.apply([
      weakFeatured,
      strongBasic,
    ], const ListingQuery());
    expect(results.map((b) => b.id), ['strong-basic', 'weak-featured']);
  });

  test('the Featured page holds only Featured listings, in rank order', () {
    final strongFeatured = business(
      'strong-featured',
      SubscriptionTier.featured,
    );
    final page = featuredBusinesses([
      weakFeatured,
      strongBasic,
      strongFeatured,
    ]);
    expect(page.map((b) => b.id), ['strong-featured', 'weak-featured']);
  });
}

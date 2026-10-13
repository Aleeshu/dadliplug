import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/leaderboard_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the per-category leaderboard.
///
/// The one-month grace period is the design decision worth defending. A new
/// listing has no reviews and no views, so ranked honestly it sits last and the
/// board becomes "whoever got here first". These tests pin that behaviour down,
/// including the edges, because a grace period that is off by one day either
/// publishes a business that has no evidence behind it or hides one that has.
void main() {
  final now = DateTime.utc(2026, 6, 1);
  const service = LeaderboardService();

  Business business(
    String id, {
    BusinessCategory category = BusinessCategory.food,
    int daysOld = 90,
    int reviews = 10,
    double rating = 4.5,
    int views = 500,
  }) => Business(
        id: id,
        name: 'Business $id',
        category: category,
        tier: SubscriptionTier.basic,
        area: 'Dickenson Bay',
        description: 'x',
        latitude: 17.1,
        longitude: -61.8,
        seededReviewCount: reviews,
        seededRating: rating,
        views: views,
        createdAt: now.subtract(Duration(days: daysOld)),
      );

  group('grace period', () {
    test('a brand new listing is held off the board', () {
      final board = service.build(
        businesses: [business('new', daysOld: 3)],
        category: BusinessCategory.food,
        now: now,
      );

      expect(board.entries, isEmpty);
      expect(board.excluded, hasLength(1));
      expect(
        board.excluded.single.reason,
        LeaderboardExclusion.withinGracePeriod,
      );
    });

    test('a listing becomes eligible on the thirtieth day', () {
      // Exactly 30 days old is eligible. 29 is not.
      expect(
        service.isEligible(business: business('a', daysOld: 30), now: now),
        isTrue,
      );
      expect(
        service.isEligible(business: business('b', daysOld: 29), now: now),
        isFalse,
      );
    });

    test('a listing missing its creation date is treated as brand new', () {
      // Its age cannot be established, so it has not earned a public ranking.
      final undated = Business(
        id: 'undated',
        name: 'No date',
        category: BusinessCategory.food,
        tier: SubscriptionTier.basic,
        area: 'x',
        description: 'x',
        seededReviewCount: 50,
        views: 5000,
      );

      expect(undated.createdAt, isNull);
      expect(service.isEligible(business: undated, now: now), isFalse);
    });

    test('the exclusion says when the listing becomes eligible', () {
      final b = business('new', daysOld: 5);
      expect(
        service.eligibleFrom(business: b, now: now),
        now.subtract(const Duration(days: 5)).add(const Duration(days: 30)),
      );
    });
  });

  group('ordering', () {
    test('entries are ranked best first, numbered from one', () {
      final board = service.build(
        businesses: [
          business('low', rating: 3.0, reviews: 5),
          business('high', rating: 5.0, reviews: 40),
          business('mid', rating: 4.2, reviews: 20),
        ],
        category: BusinessCategory.food,
        now: now,
      );

      expect(board.entries.map((e) => e.business.id), ['high', 'mid', 'low']);
      expect(board.entries.map((e) => e.position), [1, 2, 3]);
    });

    test('the board is capped at ten but reports the real total', () {
      final many = [
        for (var i = 0; i < 15; i++)
          business('b$i', reviews: 30 - i, rating: 4.0 + (i % 5) * 0.1),
      ];
      final board = service.build(
        businesses: many,
        category: BusinessCategory.food,
        now: now,
      );

      expect(board.entries, hasLength(10));
      // Otherwise "Top 10" implies ten is all there is.
      expect(board.totalEligible, 15);
    });

    test('categories do not bleed into each other', () {
      final board = service.build(
        businesses: [
          business('food', category: BusinessCategory.food),
          business('beauty', category: BusinessCategory.beauty),
        ],
        category: BusinessCategory.food,
        now: now,
      );

      expect(board.entries.single.business.id, 'food');
      // The beauty business is not excluded either: it is simply not on this
      // board. Counting it as excluded would misreport why it is missing.
      expect(board.excluded, isEmpty);
    });
  });

  group('online businesses', () {
    test('are not ranked, because they have no pin or walk-in traffic', () {
      final board = service.build(
        businesses: [
          business(
            'online',
            category: BusinessCategory.online,
            daysOld: 400,
            reviews: 99,
          ),
        ],
        category: BusinessCategory.online,
        now: now,
      );

      expect(board.entries, isEmpty);
      expect(board.excluded.single.reason, LeaderboardExclusion.notRankable);
    });

    test('are never offered as a board to browse', () {
      final categories = service.categoriesWithEntries(
        businesses: [
          business('food', category: BusinessCategory.food),
          business(
            'online',
            category: BusinessCategory.online,
            reviews: 99,
            views: 9000,
          ),
        ],
        now: now,
      );

      expect(categories, contains(BusinessCategory.food));
      expect(categories, isNot(contains(BusinessCategory.online)));
    });
  });

  group('category availability', () {
    test('a category with only new listings has no board', () {
      // Offering an empty "Top 10" is worse than offering nothing.
      final categories = service.categoriesWithEntries(
        businesses: [business('new', category: BusinessCategory.beauty, daysOld: 2)],
        now: now,
      );

      expect(categories, isNot(contains(BusinessCategory.beauty)));
    });

    test('a category with one established listing still gets a board', () {
      final categories = service.categoriesWithEntries(
        businesses: [business('old', category: BusinessCategory.beauty)],
        now: now,
      );

      expect(categories, contains(BusinessCategory.beauty));
    });
  });
}
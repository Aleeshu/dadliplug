import 'package:antigua_business_map/core/routing/app_tabs.dart';
import 'package:antigua_business_map/features/business_admin/business_listing_screen.dart';
import 'package:antigua_business_map/features/listing/listing_screen.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/models/review.dart';
import 'package:antigua_business_map/services/business_repository.dart';
import 'package:antigua_business_map/services/ranking_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the bugs fixed while closing out Phase 4, so they cannot come back
/// quietly.
void main() {
  const base = Business(
    id: 'b1',
    name: 'Shack',
    category: BusinessCategory.food,
    tier: SubscriptionTier.basic,
    area: 'Dickenson Bay',
    description: '',
  );

  Review verified(int rating) => Review(
    id: 'r$rating',
    businessId: 'b1',
    userId: 'u',
    rating: rating,
    body: '',
    createdAt: DateTime(2026),
    status: ReviewStatus.verified,
  );

  group('rating label never calls unverified ratings verified', () {
    test('imported ratings only', () {
      final b = base.copyWith(seededRating: 4.2, seededReviewCount: 28);
      expect(ratingLabel(b), '(28 ratings from before Dadliplug)');
    });

    test('verified reviews only', () {
      final b = base.copyWith(reviews: [verified(5), verified(4)]);
      expect(ratingLabel(b), '(2 verified reviews)');
    });

    test('a mix says how many are verified', () {
      final b = base.copyWith(
        seededRating: 4,
        seededReviewCount: 10,
        reviews: [verified(5)],
      );
      expect(ratingLabel(b), '(11 ratings, 1 verified)');
    });
  });

  group('social handles are stored bare', () {
    test('strips a leading @', () {
      expect(normaliseHandle('@shack'), 'shack');
    });

    test('takes the handle out of a pasted profile URL', () {
      expect(normaliseHandle('https://instagram.com/shack/'), 'shack');
    });

    test('leaves a bare handle alone', () {
      expect(normaliseHandle(' shack '), 'shack');
    });
  });

  group('an owner save never writes billing or ranking fields', () {
    final fields = SupabaseBusinessRepository.editableFields(
      base.copyWith(views: 999, seededRating: 5, seededReviewCount: 99),
    );

    for (final forbidden in [
      'tier',
      'subscription_status',
      'views',
      'calls',
      'whatsapp_taps',
      'seeded_rating',
      'seeded_review_count',
      'last_spotlight_week',
      'created_at',
    ]) {
      test('$forbidden is absent', () {
        expect(fields.containsKey(forbidden), isFalse);
      });
    }

    test('blank optional text is stored as null, not an empty string', () {
      final f = SupabaseBusinessRepository.editableFields(
        base.copyWith(instagram: '  ', website: ''),
      );
      expect(f['instagram'], isNull);
      expect(f['website'], isNull);
    });

    test('hours are written in the keys the app reads back', () {
      final f = SupabaseBusinessRepository.editableFields(
        base.copyWith(
          hours: const OpeningHours(days: {3, 1}, opensAt: 11, closesAt: 22),
        ),
      );
      expect(f['hours'], {
        'days': [1, 3],
        'opensAt': 11.0,
        'closesAt': 22.0,
      });
    });
  });

  test('Spotlight keeps every field of the business it promotes', () {
    final b = base.copyWith(
      tags: ['cash_only'],
      instagram: 'shack',
      isClosedToday: true,
      createdAt: DateTime.utc(2026),
    );
    final next = advanceSpotlight(
      businesses: [b],
      previousWeek: const [],
      currentWeek: 7,
    ).single;

    expect(next.isSpotlight, isTrue);
    expect(next.lastSpotlightWeek, 7);
    expect(next.tags, ['cash_only']);
    expect(next.instagram, 'shack');
    expect(next.isClosedToday, isTrue);
    expect(next.createdAt, DateTime.utc(2026));
  });

  test('the team gets a Listings tab', () {
    expect(
      AppTabs.teamAdmin.map((t) => t.path),
      contains('/team/listings'),
    );
  });
}

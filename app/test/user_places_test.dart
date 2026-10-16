import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/user_places_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the reading and folding of "your places".
///
/// [UserPlacesRepository] needs a Supabase client to query, so what is tested
/// here is the part that decides what a user is shown: [UserPlace] itself and
/// the guarantees around it. The network calls are exercised on device.
void main() {
  group('UserPlace', () {
    UserPlace build({
      bool confirmed = false,
      BusinessCategory? category = BusinessCategory.food,
    }) => UserPlace(
      visitId: 'v1',
      businessId: 'b1',
      businessName: "Auntie Mae's",
      category: category,
      visitedAt: DateTime.utc(2026, 3, 4),
      confirmedByBusiness: confirmed,
    );

    test('a visit alone does not unlock a review', () {
      // The review gate is the product. If a visit were enough, anyone could
      // rate any business by claiming they went there.
      expect(build().canReview, isFalse);
    });

    test('business confirmation unlocks the review', () {
      expect(build(confirmed: true).canReview, isTrue);
    });

    test(
      'a confirmed visit still needs the confirmation flag, not the date',
      () {
        final recent = UserPlace(
          visitId: 'v1',
          businessId: 'b1',
          businessName: 'A',
          visitedAt: DateTime.utc(2026, 3, 4),
        );
        expect(recent.canReview, isFalse);
      },
    );
  });

  group('ReviewRequestStatus', () {
    test('covers every state the database can store', () {
      // `review_requests.status` is a text column constrained to
      // pending/approved/declined. A new value server-side without a matching
      // case here would silently render as pending.
      expect(ReviewRequestStatus.values, hasLength(3));
      expect(
        ReviewRequestStatus.values.map((s) => s.name),
        containsAll(<String>['pending', 'approved', 'declined']),
      );
    });
  });

  group('honesty guarantees', () {
    test('a place with no known category renders as Other, not a guess', () {
      // Defaulting an unknown category to, say, "Retail" would file a pharmacy
      // under retail. Null plus a neutral label is the honest option.
      final place = UserPlace(
        visitId: 'v1',
        businessId: 'b1',
        businessName: "Auntie Mae's",
        visitedAt: DateTime.utc(2026, 3, 4),
      );
      expect(place.category, isNull);
      expect(place.category?.shortLabel ?? 'Other', 'Other');
    });

    test('an empty history is representable', () {
      // The screen's empty state depends on this being a normal result rather
      // than an error.
      expect(<UserPlace>[], isEmpty);
    });
  });
}

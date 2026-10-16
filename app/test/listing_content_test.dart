import 'package:antigua_business_map/models/review.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the listing's own content: ads, announcements and events.
///
/// The listing is the app's most important screen and it is assembled from
/// several queries. The rules worth protecting are about what a customer is
/// told, and when something is left out.
void main() {
  final now = DateTime.utc(2026, 6);

  BusinessAd ad({
    DateTime? startsAt,
    DateTime? endsAt,
  }) => BusinessAd(
    id: 'a1',
    businessId: 'b1',
    businessName: "Auntie Mae's",
    title: 'Lunch special',
    startsAt: startsAt ?? DateTime.utc(2026, 5),
    endsAt: endsAt,
  );

  group('advertisement liveness', () {
    test('an ad with no end date keeps running', () {
      expect(ad().isLiveAt(now), isTrue);
    });

    test('an ad that has not started yet is not live', () {
      final future = ad(startsAt: DateTime.utc(2026, 7));
      expect(future.isLiveAt(now), isFalse);
    });

    test('an ad whose end date has passed is not live', () {
      final ended = ad(endsAt: DateTime.utc(2026, 5, 15));
      expect(ended.isLiveAt(now), isFalse);
    });

    test('an ad is live right up to its end date', () {
      // Off-by-one here would either hide a running ad or show an expired one.
      final ending = ad(endsAt: DateTime.utc(2026, 6));
      expect(ending.isLiveAt(now), isFalse);
      expect(ending.isLiveAt(DateTime.utc(2026, 5, 31, 23, 59)), isTrue);
    });
  });

  group('events', () {
    BusinessEvent event(DateTime startsAt) => BusinessEvent(
      id: 'e1',
      businessId: 'b1',
      businessName: "Auntie Mae's",
      title: 'Cuisine night',
      startsAt: startsAt,
    );

    test('a past event is past', () {
      expect(event(DateTime.utc(2026, 5)).isPastAt(now), isTrue);
    });

    test('a future event is not past', () {
      expect(event(DateTime.utc(2026, 7)).isPastAt(now), isFalse);
    });

    test('an event starting right now is not yet past', () {
      // Showing an event that begins this minute as already finished would
      // hide it from the calendar at exactly the moment it matters.
      expect(event(now).isPastAt(now), isFalse);
    });
  });

  group('reviews remain visible only when verified', () {
    test('the listing never shows an unverified review as a rating', () {
      // Shares the same promise as the rest of the screen: nothing reaches a
      // customer that the verification gate has not passed.
      final review = Review(
        id: 'r1',
        businessId: 'b1',
        userId: 'u1',
        rating: 5,
        body: 'Great',
        createdAt: _epoch,
      );
      expect(review.isVisible, isFalse);

      expect(
        Review(
          id: 'r2',
          businessId: 'b1',
          userId: 'u2',
          rating: 5,
          body: 'Great',
          createdAt: _epoch,
          status: ReviewStatus.verified,
        ).isVisible,
        isTrue,
      );
    });
  });
}

/// A fixed timestamp, so these tests do not depend on when they run.
final _epoch = DateTime.utc(2026);

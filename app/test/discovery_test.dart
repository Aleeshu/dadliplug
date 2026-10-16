import 'package:antigua_business_map/features/discovery/featured_screen.dart';
import 'package:antigua_business_map/features/search/search_screen.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/listing_filter_service.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/services/viewer_location.dart';
import 'package:antigua_business_map/widgets/business_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 5 discovery: search and sort, near me, and the Featured page.
void main() {
  Business business(
    String id, {
    SubscriptionTier tier = SubscriptionTier.basic,
    double? lat = 17.12,
    double? lng = -61.84,
    double rating = 0,
    int ratings = 0,
    String? name,
  }) => Business(
    id: id,
    name: name ?? 'Business $id',
    category: BusinessCategory.food,
    tier: tier,
    area: "St. John's",
    description: 'x',
    latitude: lat,
    longitude: lng,
    seededRating: rating,
    seededReviewCount: ratings,
  );

  // St. John's and English Harbour: about 17 km apart by straight line.
  const stJohns = GeoPoint(17.1211, -61.8447);
  const englishHarbour = GeoPoint(17.0040, -61.7640);

  group('distance', () {
    test('is zero to the same point', () {
      expect(distanceKm(stJohns, stJohns), 0);
    });

    test("St. John's to English Harbour is about 15 km", () {
      final km = distanceKm(stJohns, englishHarbour);
      expect(km, greaterThan(14));
      expect(km, lessThan(16));
    });

    test('is the same in both directions', () {
      expect(
        distanceKm(stJohns, englishHarbour),
        closeTo(distanceKm(englishHarbour, stJohns), 1e-9),
      );
    });

    test('a business with no location has no distance', () {
      expect(distanceTo(business('o', lat: null, lng: null), stJohns), isNull);
    });

    test('formats coarsely, because coarse location cannot do better', () {
      expect(formatDistance(0.01), 'Under 50 m');
      expect(formatDistance(0.34), '350 m');
      expect(formatDistance(2.44), '2.4 km');
      expect(formatDistance(17.6), '18 km');
    });
  });

  group('nearest sort', () {
    final near = business(
      'near',
      lat: stJohns.latitude,
      lng: stJohns.longitude,
    );
    final far = business(
      'far',
      lat: englishHarbour.latitude,
      lng: englishHarbour.longitude,
    );
    final online = business('online', lat: null, lng: null);

    test('puts the closest first', () {
      final sorted = ListingFilter.apply(
        [far, online, near],
        const ListingQuery(sort: ListingSort.nearest),
        origin: stJohns,
      );
      expect(sorted.map((b) => b.id), ['near', 'far', 'online']);
    });

    test('keeps online-only businesses, last, rather than dropping them', () {
      final sorted = ListingFilter.apply(
        [online, near],
        const ListingQuery(sort: ListingSort.nearest),
        origin: stJohns,
      );
      expect(sorted.last.id, 'online');
      expect(sorted, hasLength(2));
    });

    test('without a position, falls back to the earned order', () {
      final good = business('good', rating: 4.9, ratings: 40);
      final sorted = ListingFilter.apply(
        [near, good],
        const ListingQuery(sort: ListingSort.nearest),
      );
      expect(
        sorted.map((b) => b.id),
        ListingFilter.apply([
          near,
          good,
        ], const ListingQuery()).map((b) => b.id),
      );
    });
  });

  group('Featured page contents', () {
    test('holds only Featured and Trial listings', () {
      final result = featuredBusinesses([
        business('f', tier: SubscriptionTier.featured),
        business('t', tier: SubscriptionTier.trial),
        business('b'),
        business('g', tier: SubscriptionTier.growing),
      ]);
      expect(result.map((b) => b.id).toSet(), {'f', 't'});
    });

    test('is ordered by earned rank, not by input order', () {
      final weak = business('weak', tier: SubscriptionTier.featured);
      final strong = business(
        'strong',
        tier: SubscriptionTier.featured,
        rating: 4.8,
        ratings: 50,
      );
      expect(featuredBusinesses([weak, strong]).first.id, 'strong');
    });

    test('never includes a delisted business', () {
      expect(
        featuredBusinesses([business('d', tier: SubscriptionTier.delisted)]),
        isEmpty,
      );
    });
  });

  group('screens', () {
    Widget host(Widget child, List<Business> businesses) => ProviderScope(
      overrides: [
        businessListProvider.overrideWithValue(AsyncData(businesses)),
      ],
      child: MaterialApp(home: child),
    );

    testWidgets('search filters as you type', (tester) async {
      await tester.pumpWidget(
        host(const SearchScreen(), [
          business('a', name: 'Coconut Grill'),
          business('b', name: 'Harbour Salon'),
        ]),
      );
      await tester.pump();
      expect(find.text('Coconut Grill'), findsOneWidget);
      expect(find.text('Harbour Salon'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'salon');
      await tester.pump();
      expect(find.text('Coconut Grill'), findsNothing);
      expect(find.text('Harbour Salon'), findsOneWidget);
    });

    testWidgets('near me with location refused says so and keeps results', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const SearchScreen(
            initialSort: ListingSort.nearest,
            location: _RefusedLocation(),
          ),
          [business('a', name: 'Coconut Grill')],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.text(describeLocationProblem(LocationProblem.denied)),
        findsOneWidget,
      );
      expect(find.text('Coconut Grill'), findsOneWidget);
    });

    testWidgets('near me with a position shows distances', (tester) async {
      await tester.pumpWidget(
        host(
          const SearchScreen(
            initialSort: ListingSort.nearest,
            location: _FixedLocation(stJohns),
          ),
          [
            business(
              'a',
              name: 'Coconut Grill',
              lat: stJohns.latitude,
              lng: stJohns.longitude,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Under 50 m'), findsOneWidget);
    });

    testWidgets('a load failure is an error, not "no results"', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessListProvider.overrideWithValue(
              AsyncError(Exception('offline'), StackTrace.empty),
            ),
          ],
          child: const MaterialApp(home: SearchScreen()),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Could not load'), findsOneWidget);
      expect(find.textContaining('Nothing matches'), findsNothing);
    });

    testWidgets('the Featured page lists only Featured, and says it is paid', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const FeaturedScreen(), [
          business(
            'f',
            name: 'Featured Kitchen',
            tier: SubscriptionTier.featured,
          ),
          business('b', name: 'Basic Bakery'),
        ]),
      );
      await tester.pump();
      expect(find.text('Featured Kitchen'), findsOneWidget);
      expect(find.text('Basic Bakery'), findsNothing);
      expect(find.textContaining('not by what they pay'), findsOneWidget);
    });
  });
}

class _RefusedLocation extends ViewerLocation {
  const _RefusedLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationUnavailable(LocationProblem.denied);
}

class _FixedLocation extends ViewerLocation {
  const _FixedLocation(this.point);

  final GeoPoint point;

  @override
  Future<LocationResult> current() async => LocationFound(point);
}

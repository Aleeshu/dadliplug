import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/business_repository.dart';
import 'package:antigua_business_map/services/listing_filter_service.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository backed by a fixed list, for exercising the filter and provider
/// layers without a database.
class FakeBusinessRepository implements BusinessRepository {
  FakeBusinessRepository(this.list, {this._error});

  final List<Business> list;

  final ListingsUnavailable? _error;

  @override
  Stream<List<Business>> watchBusinesses() => _error != null
      ? Stream<List<Business>>.error(_error)
      : Stream.value(list);

  @override
  Future<List<Business>> getBusinesses() async {
    final error = _error;
    if (error != null) throw error;
    return list;
  }

  @override
  Future<Business?> getBusinessById(String id) async {
    final error = _error;
    if (error != null) throw error;
    for (final b in list) {
      if (b.id == id) return b;
    }
    return null;
  }

  // Writes are exercised against the real Supabase implementation rather than
  // here — a fake that records calls proves the mock is called, not that the
  // update reaches the database or respects RLS.
  @override
  Future<void> updateBusiness(Business business) async =>
      throw UnimplementedError('covered against the live database');

  @override
  Future<void> toggleClosedToday(String businessId, bool isClosed) async =>
      throw UnimplementedError('covered against the live database');

  @override
  Future<void> reportWrongInfo({
    required String businessId,
    required String reason,
    String details = '',
  }) async => throw UnimplementedError('covered against the live database');
}

Business _business({
  required String id,
  BusinessCategory category = BusinessCategory.food,
  SubscriptionTier tier = SubscriptionTier.basic,
  double rating = 4.5,
  int ratingCount = 10,
}) => Business(
  id: id,
  name: id,
  category: category,
  tier: tier,
  area: 'Dickenson Bay',
  description: '',
  seededRating: rating,
  seededReviewCount: ratingCount,
);

void main() {
  group('empty is not the same as broken', () {
    // The behaviour this file exists to protect. An earlier version of the
    // repository fell back to invented listings whenever the database returned
    // nothing, which meant a fresh database — the actual launch state — showed
    // seven fabricated businesses with real-looking phone numbers and ratings.
    // In an app whose pitch is accuracy, that is the worst possible default,
    // and on screen it looks entirely correct.
    test('an empty database yields an empty list', () async {
      final repo = FakeBusinessRepository(const []);
      expect(await repo.getBusinesses(), isEmpty);
    });

    // There is no sample data and no flag to turn any on. The database is
    // empty until the team adds real businesses, and the app says so.

    test('a backend failure throws rather than degrading silently', () async {
      final repo = FakeBusinessRepository(
        const [],
        error: const ListingsUnavailable('network down'),
      );
      expect(repo.getBusinesses(), throwsA(isA<ListingsUnavailable>()));
    });

    test('a failed stream emits an error, not empty data', () {
      final repo = FakeBusinessRepository(
        const [],
        error: const ListingsUnavailable('network down'),
      );
      expect(repo.watchBusinesses(), emitsError(isA<ListingsUnavailable>()));
    });
  });

  group('listing filter', () {
    final list = [
      _business(id: 'a'),
      _business(
        id: 'b',
        rating: 4.8,
        ratingCount: 50,
      ),
      _business(id: 'c', category: BusinessCategory.beauty),
      _business(
        id: 'd',
        tier: SubscriptionTier.delisted,
      ),
    ];

    test('delisted listings are excluded', () {
      final results = ListingFilter.apply(list, const ListingQuery());
      expect(results.map((b) => b.id), isNot(contains('d')));
    });

    test('category filter narrows correctly', () {
      final results = ListingFilter.apply(
        list,
        const ListingQuery(categories: {BusinessCategory.food}),
      );
      expect(results.map((b) => b.id), unorderedEquals(['a', 'b']));
    });

    test('results are ordered by earned rank, not insertion order', () {
      // 'b' has the better record, so it must lead even though 'a' is first
      // in the list. Paying for a tier must not change this.
      final results = ListingFilter.apply(list, const ListingQuery());
      expect(results.first.id, 'b');
    });

    test('search matches name, area, and menu', () {
      final withMenu = [
        const Business(
          id: 'm',
          name: 'The Place',
          category: BusinessCategory.food,
          tier: SubscriptionTier.basic,
          area: 'Falmouth',
          description: '',
          menu: [MenuItem(name: 'Pepperpot')],
        ),
      ];

      expect(
        ListingFilter.apply(
          withMenu,
          const ListingQuery(search: 'pepper'),
        ).length,
        1,
      );
      expect(
        ListingFilter.apply(
          withMenu,
          const ListingQuery(search: 'falmouth'),
        ).length,
        1,
      );
      expect(
        ListingFilter.apply(withMenu, const ListingQuery(search: 'nothing')),
        isEmpty,
      );
    });
  });

  group('map query notifier', () {
    test('toggles, clears, and tracks filter state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mapQueryProvider.notifier);
      expect(container.read(mapQueryProvider).categories, isEmpty);

      notifier.toggleCategory(BusinessCategory.food);
      expect(
        container.read(mapQueryProvider).categories,
        contains(BusinessCategory.food),
      );

      // Tapping twice removes it rather than double-adding.
      notifier.toggleCategory(BusinessCategory.food);
      expect(container.read(mapQueryProvider).categories, isEmpty);

      notifier.setOpenNowOnly(openNowOnly: true);
      expect(container.read(mapQueryProvider).openNowOnly, isTrue);

      notifier.setSearch('beach');
      expect(container.read(mapQueryProvider).search, 'beach');

      notifier.clearFilters();
      final cleared = container.read(mapQueryProvider);
      expect(cleared.categories, isEmpty);
      expect(cleared.openNowOnly, isFalse);
      expect(cleared.search, isEmpty);
    });
  });

  group('filtered businesses provider', () {
    test('applies the active query to the fetched list', () {
      final container = ProviderContainer(
        overrides: [
          businessListProvider.overrideWithValue(
            AsyncData([
              _business(id: 'a'),
              _business(id: 'b', category: BusinessCategory.beauty),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(filteredBusinessesProvider).value, hasLength(2));

      container
          .read(mapQueryProvider.notifier)
          .toggleCategory(BusinessCategory.beauty);

      final filtered = container.read(filteredBusinessesProvider).value!;
      expect(filtered, hasLength(1));
      expect(filtered.first.id, 'b');
    });

    test('an empty database filters to empty', () {
      final container = ProviderContainer(
        overrides: [
          businessListProvider.overrideWithValue(const AsyncData([])),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(filteredBusinessesProvider).value, isEmpty);
    });
  });
}

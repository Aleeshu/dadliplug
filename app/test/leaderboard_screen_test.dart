import 'package:antigua_business_map/core/theme/app_theme.dart';
import 'package:antigua_business_map/features/discovery/leaderboard_screen.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/business_repository.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the leaderboard screen.
///
/// Injected data rather than the live database, because the interesting cases
/// are ones the real database does not currently contain: a mix of established
/// and brand new listings, and a category with nothing to rank.
class _Repo implements BusinessRepository {
  _Repo(this.list);

  final List<Business> list;

  @override
  Stream<List<Business>> watchBusinesses() => Stream.value(list);

  @override
  Future<List<Business>> getBusinesses() async => list;

  @override
  Future<Business?> getBusinessById(String id) async =>
      list.where((b) => b.id == id).firstOrNull;

  @override
  Future<void> updateBusiness(Business business) async {}

  @override
  Future<void> toggleClosedToday(String businessId, bool isClosed) async {}

  @override
  Future<void> reportWrongInfo({
    required String businessId,
    required String reason,
    String details = '',
  }) async {}
}

Business _business(
  String name, {
  int daysOld = 120,
  int reviews = 20,
  double rating = 4.5,
  int views = 400,
  BusinessCategory category = BusinessCategory.food,
  SubscriptionTier tier = SubscriptionTier.basic,
}) =>
    Business(
      id: name.toLowerCase().replaceAll(' ', ''),
      name: name,
      category: category,
      tier: tier,
      area: 'Dickenson Bay',
      description: 'x',
      latitude: 17.1,
      longitude: -61.8,
      seededReviewCount: reviews,
      seededRating: rating,
      views: views,
      createdAt: DateTime.now().subtract(Duration(days: daysOld)),
    );

Widget _app(List<Business> list) => ProviderScope(
      overrides: [
        businessRepositoryProvider.overrideWithValue(_Repo(list)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const LeaderboardScreen(),
      ),
    );

void main() {
  testWidgets('lists eligible businesses best first', (tester) async {
    await tester.pumpWidget(
      _app([
        _business('Weak Spot', rating: 3.0, reviews: 5),
        _business('Strong Point', rating: 5.0, reviews: 40),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Strong Point'), findsOneWidget);
    expect(find.text('Weak Spot'), findsOneWidget);

    // Ranked, not alphabetical.
    final strong = tester.getTopLeft(find.text('Strong Point')).dy;
    final weak = tester.getTopLeft(find.text('Weak Spot')).dy;
    expect(strong, lessThan(weak));
  });

  testWidgets('a new listing is held back and says when it joins', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        _business('Established', reviews: 40),
        _business('Just Opened', daysOld: 3, reviews: 0),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Established'), findsOneWidget);
    // The new listing is not on the board...
    expect(find.text('Just Opened'), findsNothing);
    // ...but the owner can still find out when it will be.
    expect(find.textContaining('Just Opened'), findsOneWidget);
    expect(find.textContaining('joins'), findsOneWidget);
  });

  testWidgets('says so when nothing can be ranked yet', (tester) async {
    await tester.pumpWidget(_app([_business('Brand New', daysOld: 2)]));
    await tester.pumpAndSettle();

    // Must not render an empty "Top 10", which would read as broken.
    expect(find.text('No businesses to rank yet'), findsOneWidget);
  });

  testWidgets('a featured badge never lifts a business up the board', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        _business('Best Rated', rating: 5.0, reviews: 40),
        _business(
          'Paid And New',
          rating: 1.0,
          reviews: 1,
          tier: SubscriptionTier.featured,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    final best = tester.getTopLeft(find.text('Best Rated')).dy;
    final paid = tester.getTopLeft(find.text('Paid And New')).dy;
    expect(best, lessThan(paid));
  });
}
import 'package:antigua_business_map/features/discovery/bookmarks_screen.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Business business(String id, String name) => Business(
    id: id,
    name: name,
    category: BusinessCategory.food,
    tier: SubscriptionTier.basic,
    area: 'x',
    description: 'x',
  );

  Widget host({
    List<String> savedIds = const ['a'],
    bool offersFail = false,
  }) => ProviderScope(
    overrides: [
      followedBusinessIdsProvider.overrideWithValue(AsyncData(savedIds)),
      businessListProvider.overrideWithValue(
        AsyncData([business('a', 'Saved Grill'), business('b', 'Other Bar')]),
      ),
      savedEventIdsProvider.overrideWithValue(const AsyncData({})),
      upcomingEventsProvider.overrideWithValue(const AsyncData([])),
      offersProvider.overrideWithValue(
        offersFail
            ? AsyncError(Exception('offline'), StackTrace.empty)
            : AsyncData([
                BusinessAd(
                  id: 'o1',
                  businessId: 'a',
                  businessName: 'Saved Grill',
                  title: 'Lunch deal',
                  startsAt: DateTime.utc(2026),
                  offerCode: 'LUNCH30',
                ),
                BusinessAd(
                  id: 'o2',
                  businessId: 'b',
                  businessName: 'Other Bar',
                  title: 'Not saved',
                  startsAt: DateTime.utc(2026),
                  offerCode: 'OTHER1',
                ),
              ]),
      ),
    ],
    child: const MaterialApp(home: BookmarksScreen(isSignedIn: true)),
  );

  testWidgets('a guest is asked to sign in, not shown an empty list', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: BookmarksScreen(isSignedIn: false)),
      ),
    );
    expect(find.text('Sign in to save places'), findsOneWidget);
  });

  testWidgets('has the design tabs and lists only saved businesses', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();
    for (final tab in ['Businesses', 'Events', 'Offers']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(find.text('Saved Grill'), findsOneWidget);
    expect(find.text('Other Bar'), findsNothing);
  });

  testWidgets('offers are only from saved businesses', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.tap(find.text('Offers'));
    await tester.pumpAndSettle();
    expect(find.text('LUNCH30'), findsOneWidget);
    expect(find.text('OTHER1'), findsNothing);
  });

  testWidgets('an offers outage is an error, not "no offers"', (tester) async {
    await tester.pumpWidget(host(offersFail: true));
    await tester.pump();
    await tester.tap(find.text('Offers'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load'), findsOneWidget);
  });

  testWidgets('nothing saved says how to save', (tester) async {
    await tester.pumpWidget(host(savedIds: const []));
    await tester.pump();
    expect(find.text('Nothing saved yet'), findsOneWidget);
  });
}

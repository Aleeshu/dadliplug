import 'package:antigua_business_map/core/theme/app_theme.dart';
import 'package:antigua_business_map/features/listing/listing_screen.dart';
import 'package:antigua_business_map/features/listing/widgets/report_wrong_info_sheet.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/business_repository.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTestRepository implements BusinessRepository {
  FakeTestRepository(this.businesses);

  final Map<String, Business> businesses;
  bool reported = false;
  String? lastReportReason;

  @override
  Future<Business?> getBusinessById(String id) async => businesses[id];

  @override
  Future<List<Business>> getBusinesses() async => businesses.values.toList();

  @override
  Stream<List<Business>> watchBusinesses() =>
      Stream.value(businesses.values.toList());

  @override
  Future<void> updateBusiness(Business business) async {
    businesses[business.id] = business;
  }

  @override
  Future<void> toggleClosedToday(String businessId, bool isClosed) async {
    final b = businesses[businessId];
    if (b != null) {
      businesses[businessId] = b.copyWith(isClosedToday: isClosed);
    }
  }

  @override
  Future<void> reportWrongInfo({
    required String businessId,
    required String reason,
    String details = '',
  }) async {
    reported = true;
    lastReportReason = reason;
  }
}

void main() {
  final sampleBusiness = Business(
    id: 'test-1',
    name: 'Beach Shack Grill',
    category: BusinessCategory.food,
    tier: SubscriptionTier.premium,
    area: 'Dickenson Bay',
    description: 'Fresh grilled fish and cold drinks on the beach.',
    address: 'Dickenson Bay Main Road',
    howToFindUs: 'Past the red telephone box, right on the sand',
    phone: '+1 268 555 1234',
    whatsapp: '+1 268 555 5678',
    latitude: 17.145,
    longitude: -61.855,
    priceRange: r'$$',
    offer: '10% off catch of the day',
    tags: const [
      KnownBusinessTags.cashOnly,
      KnownBusinessTags.parking,
      KnownBusinessTags.outdoorSeating,
    ],
    hours: const OpeningHours(
      days: {1, 2, 3, 4, 5, 6, 7},
      opensAt: 11,
      closesAt: 22,
    ),
    menu: const [
      MenuItem(
        name: 'Grilled Mahi Mahi',
        detail: 'Served with seasoned rice and plantains',
        price: r'EC$45',
      ),
      MenuItem(
        name: 'Wadadli Beer',
        detail: 'Ice cold local lager',
        price: r'EC$10',
      ),
    ],
    seededRating: 4.8,
    seededReviewCount: 15,
    lastVerifiedAt: DateTime(2026, 10),
  );

  group('Phase 4: Opening Hours & Emergency Closure', () {
    test('openInfo reflects isClosedToday temporary closure', () {
      final openBusiness = sampleBusiness.copyWith(isClosedToday: false);
      final closedBusiness = sampleBusiness.copyWith(isClosedToday: true);

      final openStatus = openInfo(openBusiness);
      final closedStatus = openInfo(closedBusiness);

      expect(closedStatus.isOpen, isFalse);
      expect(closedStatus.isTemporary, isTrue);
      expect(closedStatus.label, contains('Closed today (temporary)'));
      expect(openStatus.isTemporary, isFalse);
    });
  });

  group('Phase 4: ListingScreen UI Rendering', () {
    testWidgets('renders all required Phase 4 business listing components', (
      tester,
    ) async {
      final fakeRepo = FakeTestRepository({'test-1': sampleBusiness});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ListingScreen(businessId: 'test-1'),
          ),
        ),
      );

      // Settle async future
      await tester.pumpAndSettle();

      // 1. Identification
      expect(find.text('Beach Shack Grill'), findsOneWidget);
      expect(find.text('Dickenson Bay'), findsOneWidget);
      // Appears twice by design: on the category badge, and again as the
      // placeholder when the listing has no photo yet. Asserting an exact count
      // here would break the moment a business uploads a picture, without
      // anything actually being wrong.
      expect(find.text('Food & drink'), findsWidgets);
      expect(find.text(r'$$'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('(15 verified reviews)'), findsOneWidget);

      // 2. Action buttons
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Directions'), findsOneWidget);

      // 3. Special offer banner
      expect(find.text('SPECIAL OFFER'), findsOneWidget);
      expect(find.text('10% off catch of the day'), findsOneWidget);

      // 4. "How to find us" landmark directions
      expect(find.text('How to find us'), findsOneWidget);
      expect(
        find.text('Past the red telephone box, right on the sand'),
        findsOneWidget,
      );

      // 5. Tags & amenities
      expect(find.text('Cash only'), findsOneWidget);
      expect(find.text('Parking on site'), findsOneWidget);
      expect(find.text('Outdoor seating'), findsOneWidget);

      // 6. Menu items
      expect(find.text('Grilled Mahi Mahi'), findsOneWidget);
      expect(find.text(r'EC$45'), findsOneWidget);
      expect(find.text('Wadadli Beer'), findsOneWidget);
      expect(find.text(r'EC$10'), findsOneWidget);

      // 7. Accuracy footer
      expect(find.textContaining('Data verified:'), findsOneWidget);
      expect(find.text('Report wrong info'), findsOneWidget);
    });

    testWidgets('displays emergency banner when business is closed today', (
      tester,
    ) async {
      final emergencyClosedBusiness = sampleBusiness.copyWith(
        isClosedToday: true,
      );
      final fakeRepo = FakeTestRepository({'test-1': emergencyClosedBusiness});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ListingScreen(businessId: 'test-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TEMPORARILY CLOSED TODAY'), findsOneWidget);
    });

    testWidgets('tapping Report wrong info opens report bottom sheet', (
      tester,
    ) async {
      final fakeRepo = FakeTestRepository({'test-1': sampleBusiness});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ListingScreen(businessId: 'test-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final reportButton = find.text('Report wrong info');
      expect(reportButton, findsOneWidget);

      // Sits below the fold on a phone-sized viewport. `ensureVisible` picks the
      // nearest Scrollable, which is not always the one holding this content on
      // a screen this nested — `scrollUntilVisible` names the axis explicitly
      // and keeps going until it actually arrives.
      await tester.scrollUntilVisible(
        reportButton,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(reportButton);
      await tester.pumpAndSettle();

      expect(find.byType(ReportWrongInfoSheet), findsOneWidget);
      expect(find.text('What needs updating?'), findsOneWidget);
      expect(find.text('Incorrect opening hours'), findsOneWidget);
    });
  });
}

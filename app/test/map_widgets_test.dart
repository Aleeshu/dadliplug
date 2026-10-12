import 'package:antigua_business_map/core/theme/app_theme.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/widgets/business_preview_card.dart';
import 'package:antigua_business_map/widgets/category_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the map screen's pieces.
///
/// Split from the repository tests because they need a widget tree rather than
/// a provider container. Layout review is still done by looking at the app;
/// these only check that the controls work and the right values render.
void main() {
  const business = Business(
    id: 'test-1',
    name: 'Sample Restaurant',
    category: BusinessCategory.food,
    tier: SubscriptionTier.premium,
    area: 'Dickenson Bay',
    description: 'Placeholder for widget tests.',
    priceRange: r'$$$',
    // Call and WhatsApp only render with a number. A listing without one is a
    // real case — a business that never gave us a phone number — so the card
    // has to cope rather than show dead buttons.
    phone: '+1 268 555 0000',
    whatsapp: '+1 268 555 0000',
    seededRating: 4.7,
    seededReviewCount: 25,
  );

  group('CategoryFilterBar', () {
    testWidgets('renders the open-now toggle and category chips', (
      tester,
    ) async {
      BusinessCategory? toggledCategory;
      bool? toggledOpenNow;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: CategoryFilterBar(
              selectedCategories: const {BusinessCategory.food},
              openNowOnly: false,
              onCategoryToggled: (cat) => toggledCategory = cat,
              onOpenNowToggled: (open) => toggledOpenNow = open,
            ),
          ),
        ),
      );

      expect(find.text('Open now'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);

      await tester.tap(find.text('Open now'));
      expect(toggledOpenNow, isTrue);

      await tester.tap(find.text('Beauty'));
      expect(toggledCategory, BusinessCategory.beauty);
    });

    testWidgets('an active chip is visually distinct from an inactive one', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: CategoryFilterBar(
              selectedCategories: const {BusinessCategory.food},
              openNowOnly: false,
              onCategoryToggled: (_) {},
              onOpenNowToggled: (_) {},
            ),
          ),
        ),
      );

      // The bar uses custom chips, so there is no `selected` property to read.
      // Selection shows as a bolder label. If these ever match, the user cannot
      // tell the filter is on — which is the failure worth catching.
      FontWeight weightOf(String label) =>
          tester.widget<Text>(find.text(label)).style!.fontWeight!;

      expect(weightOf('Food'), FontWeight.w700);
      expect(weightOf('Beauty'), FontWeight.w500);
    });
  });

  group('BusinessPreviewCard', () {
    testWidgets('renders the identifying details', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BusinessPreviewCard(
              business: business,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('Sample Restaurant'), findsOneWidget);
      expect(find.text('Dickenson Bay'), findsOneWidget);
      expect(find.text('Food & drink'), findsOneWidget);
      expect(find.text('View Listing'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
    });

    testWidgets('close calls back', (tester) async {
      var closed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BusinessPreviewCard(
              business: business,
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
    });

    testWidgets('an offer shows a DEAL badge, and none shows no badge', (
      tester,
    ) async {
      // The badge is the visible form of the premium offer. A business paying
      // $100 needs to see their deal on the map, so its absence when an offer
      // exists is worth catching.
      const withOffer = Business(
        id: 'deal',
        name: 'Sample Deal',
        category: BusinessCategory.food,
        tier: SubscriptionTier.premium,
        area: 'Dickenson Bay',
        description: '',
        phone: '+1 268 555 0000',
        offer: '20% off sunset cocktails',
      );

      Future<void> pump(WidgetTester tester, Business b) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BusinessPreviewCard(business: b, onClose: () {}),
          ),
        ),
      );

      await pump(tester, withOffer);
      expect(find.text('DEAL'), findsOneWidget);

      await pump(tester, business);
      expect(find.text('DEAL'), findsNothing);
    });

    testWidgets('a basic listing is not badged as premium', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BusinessPreviewCard(business: business, onClose: () {}),
          ),
        ),
      );

      // Nothing on the card claims a tier. Paid placement shows through
      // ranking and the Featured rail, not through a badge on the listing —
      // otherwise basic buyers would ask why they do not get one too.
      expect(find.text('Premium'), findsNothing);
      expect(find.text('Basic'), findsNothing);
    });
  });
}

import 'package:antigua_business_map/features/business_admin/plans_screen.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:flutter_test/flutter_test.dart';

/// The plans screen must not promise what a plan does not allow. Checked
/// against the same rules the app and database enforce.
void main() {
  Business on(SubscriptionTier tier) => Business(
    id: 'b',
    name: 'b',
    category: BusinessCategory.food,
    tier: tier,
    area: 'x',
    description: 'x',
  );

  String featuresOf(SubscriptionTier tier) =>
      kPlanOffers.firstWhere((o) => o.tier == tier).features.join('\n');

  test('three plans, in price order, Growth marked most popular', () {
    expect(kPlanOffers.map((o) => o.tier.label), [
      'Starter',
      'Growth',
      'Premium',
    ]);
    expect(kPlanOffers.map((o) => o.tier.monthlyPrice), [25, 50, 100]);
    expect(kPlanOffers.where((o) => o.popular).single.tier.label, 'Growth');
  });

  test('advertisement counts match the live-ad limits', () {
    expect(featuresOf(SubscriptionTier.growing), contains('1 running'));
    expect(on(SubscriptionTier.growing).liveAdLimit, 1);
    expect(featuresOf(SubscriptionTier.basic), contains('5 running'));
    expect(on(SubscriptionTier.basic).liveAdLimit, 5);
    expect(featuresOf(SubscriptionTier.featured), contains('Unlimited'));
    expect(on(SubscriptionTier.featured).liveAdLimit, isNull);
  });

  test('deals and the movable pin are promised only where allowed', () {
    expect(featuresOf(SubscriptionTier.growing), isNot(contains('Deals')));
    expect(on(SubscriptionTier.growing).canPostDeals, isFalse);
    expect(featuresOf(SubscriptionTier.basic), contains('Deals'));
    expect(on(SubscriptionTier.basic).canPostDeals, isTrue);
    expect(featuresOf(SubscriptionTier.basic), contains('Move your pin'));
    expect(on(SubscriptionTier.basic).canCustomisePin, isTrue);
    expect(on(SubscriptionTier.growing).canCustomisePin, isFalse);
  });
}

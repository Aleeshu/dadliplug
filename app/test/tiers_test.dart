import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:flutter_test/flutter_test.dart';

/// The plans as renamed on 2026-10-22 (Business Plan 2). These mirror the
/// database's live_ad_limit and plan_allows; if one side changes, both must.
void main() {
  Business on(SubscriptionTier tier, {SubscriptionTier? plan}) => Business(
    id: 'b',
    name: 'b',
    category: BusinessCategory.food,
    tier: tier,
    plan: plan,
    area: 'x',
    description: 'x',
  );

  test('owners see Starter, Growth and Premium', () {
    expect(SubscriptionTier.growing.label, 'Starter');
    expect(SubscriptionTier.basic.label, 'Growth');
    expect(SubscriptionTier.featured.label, 'Premium');
  });

  test('prices are unchanged', () {
    expect(SubscriptionTier.growing.monthlyPrice, 25);
    expect(SubscriptionTier.basic.monthlyPrice, 50);
    expect(SubscriptionTier.featured.monthlyPrice, 100);
  });

  test('running ads: Starter 1, Growth 5, Premium and trials unlimited', () {
    expect(on(SubscriptionTier.growing).liveAdLimit, 1);
    expect(on(SubscriptionTier.basic).liveAdLimit, 5);
    expect(on(SubscriptionTier.featured).liveAdLimit, isNull);
    expect(
      on(SubscriptionTier.trial, plan: SubscriptionTier.growing).liveAdLimit,
      isNull,
    );
  });

  test('deals: Growth, Premium and trials, not Starter', () {
    expect(on(SubscriptionTier.growing).canPostDeals, isFalse);
    expect(on(SubscriptionTier.basic).canPostDeals, isTrue);
    expect(on(SubscriptionTier.featured).canPostDeals, isTrue);
    expect(
      on(SubscriptionTier.trial, plan: SubscriptionTier.growing).canPostDeals,
      isTrue,
    );
  });

  test('a listing on hold keeps what its plan allows', () {
    final held = on(SubscriptionTier.overdue, plan: SubscriptionTier.basic);
    expect(held.canPostDeals, isTrue);
    expect(held.liveAdLimit, 5);
  });
}

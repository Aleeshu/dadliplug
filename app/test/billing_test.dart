import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/billing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 7 billing states (plan.md section 3): trial, paid, held, delisted.
void main() {
  final now = DateTime.utc(2026, 10, 21, 12);

  Business business(
    SubscriptionTier tier, {
    SubscriptionTier? plan,
    DateTime? trialEndsAt,
    DateTime? paidUntil,
    DateTime? holdUntil,
  }) => Business(
    id: 'b',
    name: 'B',
    category: BusinessCategory.food,
    tier: tier,
    area: 'x',
    description: 'x',
    plan: plan,
    trialEndsAt: trialEndsAt,
    paidUntil: paidUntil,
    holdUntil: holdUntil,
  );

  test('a trial says which plan it unlocks and when it ends', () {
    final s = billingStatus(
      business(
        SubscriptionTier.trial,
        plan: SubscriptionTier.featured,
        trialEndsAt: now.add(const Duration(days: 2)),
      ),
      now: now,
    );
    expect(s.title, 'Free trial');
    expect(s.detail, contains('Premium'));
    expect(s.detail, contains('in 2 days'));
    expect(s.tone, BillingTone.warn);
  });

  test('a held listing says the deadline and that nothing is lost yet', () {
    final s = billingStatus(
      business(
        SubscriptionTier.overdue,
        plan: SubscriptionTier.basic,
        // Noon in Antigua on the 28th.
        holdUntil: DateTime.utc(2026, 10, 28, 16),
      ),
      now: now,
    );
    expect(s.title, 'Payment due');
    expect(s.detail, contains('Oct 28'));
    expect(s.detail, contains('nothing is lost'));
    expect(s.tone, BillingTone.bad);
  });

  test('a delisted listing is told its content is kept', () {
    final s = billingStatus(business(SubscriptionTier.delisted), now: now);
    expect(s.title, 'Delisted');
    expect(s.detail, contains('kept'));
  });

  test('a paid plan shows its renewal, and warns in the last five days', () {
    final far = billingStatus(
      business(
        SubscriptionTier.basic,
        paidUntil: now.add(const Duration(days: 20)),
      ),
      now: now,
    );
    expect(far.title, 'Growth plan');
    expect(far.detail, startsWith('Paid until'));
    expect(far.tone, BillingTone.ok);

    final near = billingStatus(
      business(
        SubscriptionTier.basic,
        paidUntil: now.add(const Duration(days: 3)),
      ),
      now: now,
    );
    expect(near.detail, contains('Renews in 3 days'));
    expect(near.tone, BillingTone.warn);
  });

  test('a listing from before billing is not shown as expiring', () {
    // Rows set up before billing existed have no dates; they must not read
    // as overdue or about to lapse.
    final s = billingStatus(business(SubscriptionTier.featured), now: now);
    expect(s.tone, BillingTone.ok);
    expect(s.detail, 'No renewal date recorded.');
  });
}

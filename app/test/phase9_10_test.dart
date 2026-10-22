import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/seeding_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> row({
    String plan = 'unsure',
    String maintenance = 'unsure',
    String spend = 'none',
    List<String> channels = const [],
    String status = 'new',
  }) => {
    'id': 'l',
    'business_name': 'Shirley Plumbing',
    'category': 'services',
    'area': 'All Saints',
    'contact_name': 'Shirley',
    'phone': '+1 268 555 0101',
    'advertises_on': channels,
    'spend_band': spend,
    'plan_interest': plan,
    'maintenance': maintenance,
    'note': null,
    'source': 'app',
    'status': status,
    'team_note': null,
    'created_at': '2026-10-22T12:00:00Z',
  };

  group('leads', () {
    test('parse every stored value back', () {
      final l = Lead.fromMap(
        row(
          plan: 'basic',
          maintenance: 'team',
          spend: '50_150',
          channels: ['facebook', 'whatsapp_status', 'word_of_mouth'],
          status: 'trial',
        ),
      );
      expect(l.category, BusinessCategory.services);
      expect(l.spend, SpendBand.from50to150);
      expect(l.advertisesOn, [
        AdChannel.facebook,
        AdChannel.whatsappStatus,
        AdChannel.wordOfMouth,
      ]);
      expect(l.status, LeadStatus.trial);
    });

    test('every enum survives a round trip through the database name', () {
      for (final c in AdChannel.values) {
        expect(AdChannel.fromDb(c.dbName), c);
      }
      for (final b in SpendBand.values) {
        expect(SpendBand.fromDb(b.dbName), b);
      }
      for (final s in LeadStatus.values) {
        expect(LeadStatus.fromDb(s.dbName), s);
      }
    });

    test('an unknown channel is dropped, not guessed', () {
      final l = Lead.fromMap(row(channels: ['facebook', 'carrier_pigeon']));
      expect(l.advertisesOn, [AdChannel.facebook]);
    });
  });

  group('answers', () {
    final summary = LeadSummary.of([
      Lead.fromMap(row(plan: 'growing', maintenance: 'team')),
      Lead.fromMap(row(plan: 'basic', maintenance: 'team')),
      Lead.fromMap(row(plan: 'basic', maintenance: 'self')),
      Lead.fromMap(row(plan: 'featured', maintenance: 'team')),
      Lead.fromMap(row()),
    ]);

    test('counts plans and who keeps the listing', () {
      expect(summary.total, 5);
      expect(summary.byPlan['basic'], 2);
      expect(summary.byMaintenance['team'], 3);
    });

    test('share at or above a plan ignores the undecided', () {
      // 4 named a plan: 3 at Basic or above, 1 at Featured.
      expect(summary.shareAtLeast('basic'), 0.75);
      expect(summary.shareAtLeast('featured'), 0.25);
      expect(summary.shareAtLeast('growing'), 1.0);
    });

    test('no named plans means no share, not zero', () {
      expect(LeadSummary.of([Lead.fromMap(row())]).shareAtLeast('basic'), null);
    });
  });

  test('a pre-built listing is a flag on the business, off by default', () {
    const b = Business(
      id: 'b',
      name: 'b',
      category: BusinessCategory.food,
      tier: SubscriptionTier.basic,
      area: 'x',
      description: 'x',
    );
    expect(b.isProspect, isFalse);
    expect(b.copyWith(name: 'c').isProspect, isFalse);
  });
}

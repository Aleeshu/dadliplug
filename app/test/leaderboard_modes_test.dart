import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/leaderboard_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Business b(String id, {int views = 0, int calls = 0, int taps = 0}) =>
      Business(
        id: id,
        name: id,
        category: BusinessCategory.food,
        tier: SubscriptionTier.basic,
        area: 'x',
        description: 'x',
        views: views,
        calls: calls,
        whatsappTaps: taps,
      );

  final eligible = [
    b('earned-first', views: 100, calls: 1),
    b('most-viewed', views: 900),
    b('most-calls', views: 50, calls: 30, taps: 10),
  ];

  test('Most Viewed ranks by listing views', () {
    expect(
      rankBy(eligible, LeaderboardMode.viewed).map((e) => e.business.id),
      ['most-viewed', 'earned-first', 'most-calls'],
    );
  });

  test('Most Clicks ranks by calls and WhatsApp taps', () {
    final r = rankBy(eligible, LeaderboardMode.clicks);
    expect(r.first.business.id, 'most-calls');
    expect(r.first.position, 1);
    expect(
      LeaderboardMode.clicks.describe(r.first.business),
      '40 calls and taps',
    );
  });

  test('Most Engaging weights getting in touch over looking', () {
    // 900 views = 900; 50 views + 5 x 40 contacts = 250; 100 + 5 = 105.
    expect(
      rankBy(eligible, LeaderboardMode.engaging).first.business.id,
      'most-viewed',
    );
  });

  test('ties keep the earned order, so tabs do not reshuffle', () {
    final tied = [b('first'), b('second'), b('third')];
    expect(
      rankBy(tied, LeaderboardMode.viewed).map((e) => e.business.id),
      ['first', 'second', 'third'],
    );
  });

  test('a tab shows ten at most, numbered from one', () {
    final many = [for (var i = 0; i < 25; i++) b('b$i', views: i)];
    final r = rankBy(many, LeaderboardMode.viewed);
    expect(r, hasLength(10));
    expect(r.map((e) => e.position), [for (var i = 1; i <= 10; i++) i]);
  });
}

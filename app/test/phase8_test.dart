import 'package:antigua_business_map/features/team_admin/ranking_screen.dart';
import 'package:antigua_business_map/features/team_admin/spotlight_screen.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/ranking_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RankSnapshot snap(int day, int position) => RankSnapshot(
    day: DateTime(2026, 10, day),
    businessId: 'b',
    score: 50,
    position: position,
    of: 10,
  );

  group('weekly movement', () {
    test('compares with the snapshot a week back', () {
      // 5th a week ago, 2nd today: up three.
      expect(
        weeklyMovement([snap(14, 5), snap(18, 4), snap(21, 2)]),
        3,
      );
    });

    test('a missed night does not shrink the window', () {
      // No snapshot exactly 7 days back: day 15 (6 days) is used, not 10.
      expect(weeklyMovement([snap(10, 8), snap(15, 6), snap(21, 7)]), -1);
    });

    test('less than a week of history says nothing', () {
      expect(weeklyMovement([snap(19, 3), snap(21, 1)]), isNull);
      expect(weeklyMovement([snap(21, 1)]), isNull);
    });

    test('dropping places is negative', () {
      expect(weeklyMovement([snap(14, 1), snap(21, 4)]), -3);
    });
  });

  group('engagement warning', () {
    Business b({int views = 0, int calls = 0, int taps = 0}) => Business(
      id: 'b',
      name: 'b',
      category: BusinessCategory.food,
      tier: SubscriptionTier.basic,
      area: 'x',
      description: 'x',
      views: views,
      calls: calls,
      whatsappTaps: taps,
    );

    test('flags calls and taps outrunning views', () {
      expect(engagementWarning(b(views: 10, calls: 15, taps: 10)), isNotNull);
    });

    test('ignores a normal pattern and small numbers', () {
      expect(engagementWarning(b(views: 400, calls: 30, taps: 20)), isNull);
      expect(engagementWarning(b(views: 2, calls: 5, taps: 4)), isNull);
    });
  });

  group('spotlight turnover', () {
    test('is the coming Monday, island time', () {
      // Wednesday 21 Oct 2026, noon in Antigua.
      expect(
        nextSpotlightTurnover(DateTime.utc(2026, 10, 21, 16)),
        DateTime(2026, 10, 26),
      );
    });

    test('on a Monday it is the following Monday', () {
      expect(
        nextSpotlightTurnover(DateTime.utc(2026, 10, 26, 16)),
        DateTime(2026, 11, 2),
      );
    });

    test('Sunday night in Antigua is still Sunday', () {
      // 23:00 Sunday 25 Oct in Antigua is already Monday in UTC.
      expect(
        nextSpotlightTurnover(DateTime.utc(2026, 10, 26, 3)),
        DateTime(2026, 10, 26),
      );
    });
  });
}

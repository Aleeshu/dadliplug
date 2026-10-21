import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/specials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Business business({
    String? special = 'Grilled snapper',
    DateTime? postedAt,
    bool soldOut = false,
  }) => Business(
    id: 'b',
    name: 'b',
    category: BusinessCategory.food,
    tier: SubscriptionTier.basic,
    area: 'x',
    description: 'x',
    special: special,
    specialPostedAt: postedAt,
    specialSoldOut: soldOut,
  );

  // 08:00 in Antigua (UTC-4) on 21 October.
  final morning = DateTime.utc(2026, 10, 21, 12);

  test('a special posted earlier today is shown', () {
    final s = todaysSpecial(
      business(postedAt: DateTime.utc(2026, 10, 21, 11)),
      now: morning,
    );
    expect(s, (text: 'Grilled snapper', soldOut: false));
  });

  test("yesterday's special is gone, by island midnight not UTC", () {
    // 23:30 on the 20th in Antigua is 03:30 on the 21st in UTC.
    final lateLastNight = DateTime.utc(2026, 10, 21, 3, 30);
    expect(
      todaysSpecial(business(postedAt: lateLastNight), now: morning),
      isNull,
    );
  });

  test('a special posted at 21:00 island time still shows at 23:59', () {
    final posted = DateTime.utc(2026, 10, 22, 1); // 21:00 on the 21st
    final nearMidnight = DateTime.utc(2026, 10, 22, 3, 59); // 23:59
    expect(
      todaysSpecial(business(postedAt: posted), now: nearMidnight),
      isNotNull,
    );
  });

  test('sold out is carried through', () {
    final s = todaysSpecial(
      business(postedAt: DateTime.utc(2026, 10, 21, 11), soldOut: true),
      now: morning,
    );
    expect(s?.soldOut, isTrue);
  });

  test('no text or no posting time means no special', () {
    expect(
      todaysSpecial(business(special: null, postedAt: morning), now: morning),
      isNull,
    );
    expect(
      todaysSpecial(
        business(special: '  ', postedAt: morning),
        now: morning,
      ),
      isNull,
    );
    expect(todaysSpecial(business(), now: morning), isNull);
  });
}

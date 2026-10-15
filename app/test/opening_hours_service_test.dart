import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpeningHours.isOpenAt', () {
    // DateTime.weekday: Monday is 1, Sunday is 7.
    final monday2pm = DateTime(2026, 3, 2, 14);
    final sunday2pm = DateTime(2026, 3, 8, 14);

    test('open inside the window', () {
      const h = OpeningHours(
        days: {DateTime.monday},
      );
      expect(h.isOpenAt(monday2pm), isTrue);
    });

    test('closed before opening', () {
      const h = OpeningHours(days: {DateTime.monday});
      expect(
        h.isOpenAt(DateTime(2026, 3, 2, 8)),
        isFalse,
      );
    });

    test('closed on a day it does not run', () {
      const h = OpeningHours(days: {DateTime.monday});
      expect(h.isOpenAt(sunday2pm), isFalse);
    });

    test('24 hours is open at 3am', () {
      const h = OpeningHours(
        days: {1, 2, 3, 4, 5, 6, 7},
        opensAt: 0,
        closesAt: 24,
      );
      expect(h.is24Hours, isTrue);
      expect(h.isOpenAt(DateTime(2026, 3, 2, 3)), isTrue);
    });

    test('a bar open past midnight still counts as open at 1am', () {
      const h = OpeningHours(days: {5, 6}, opensAt: 18, closesAt: 2);
      expect(h.isOpenAt(DateTime(2026, 3, 7, 1)), isTrue);
      expect(h.isOpenAt(DateTime(2026, 3, 6, 19)), isTrue);
      expect(h.isOpenAt(DateTime(2026, 3, 7, 15)), isFalse);
    });

    test('never open when there are no days', () {
      expect(const OpeningHours().isOpenAt(monday2pm), isFalse);
    });
  });

  group('day label', () {
    test('daily', () {
      expect(
        const OpeningHours(days: {1, 2, 3, 4, 5, 6, 7}).label,
        'Daily',
      );
    });

    test('weekdays compress to a range', () {
      expect(
        const OpeningHours(days: {1, 2, 3, 4, 5}).label,
        'Mon–Fri',
      );
    });

    test('scattered days list separately', () {
      expect(
        const OpeningHours(days: {2, 4, 6}).label,
        'Tue, Thu, Sat',
      );
    });
  });

  group('Antigua clock', () {
    test('is UTC minus four, whatever the device timezone', () {
      // 18:00 UTC is 14:00 in Antigua. The old clock subtracted four hours
      // from local time, so on a phone in Antigua it read 10:00.
      final island = AntiguaClock.antiguaTimeOf(DateTime.utc(2026, 3, 2, 18));
      expect(island.hour, 14);
      expect(island.weekday, DateTime.monday);
    });

    test('crosses midnight back into the previous day', () {
      final island = AntiguaClock.antiguaTimeOf(DateTime.utc(2026, 3, 9, 2));
      expect(island.weekday, DateTime.sunday);
      expect(island.hour, 22);
    });
  });

  group('nextOpenDay', () {
    test('finds Sunday', () {
      // Sunday is 7. A plain `% 7` turned it into 0 and never matched.
      const h = OpeningHours(days: {DateTime.sunday});
      expect(h.nextOpenDay(DateTime.saturday), DateTime.sunday);
    });

    test('wraps from Sunday to Monday', () {
      const h = OpeningHours(days: {DateTime.monday});
      expect(h.nextOpenDay(DateTime.sunday), DateTime.monday);
    });
  });

  group('openInfo', () {
    const bar = Business(
      id: 'bar',
      name: 'Bar',
      category: BusinessCategory.food,
      tier: SubscriptionTier.basic,
      area: '',
      description: '',
      hours: OpeningHours(days: {5, 6}, opensAt: 18, closesAt: 2),
    );

    test('a bar open past midnight is labelled open at 1am', () {
      // Saturday 01:00 in Antigua, inside Friday night's session. The label
      // used to have its own window check that did not understand this.
      final info = openInfo(bar, now: DateTime(2026, 3, 7, 1));
      expect(info.isOpen, isTrue);
    });

    test('labels the next opening day by name', () {
      final info = openInfo(bar, now: DateTime(2026, 3, 8, 12));
      expect(info.isOpen, isFalse);
      expect(info.label, 'Closed, opens Fri 6 pm');
    });
  });

  group('formatHour', () {
    test('formats 12-hour time', () {
      expect(formatHour(6), '6 am');
      expect(formatHour(18), '6 pm');
      expect(formatHour(12), '12 pm');
      expect(formatHour(0), '12 am');
      expect(formatHour(9.5), '9:30 am');
    });
  });
}

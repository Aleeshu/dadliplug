import 'dart:io';

import 'package:antigua_business_map/features/more/legal_screens.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/listing_filter_service.dart';
import 'package:antigua_business_map/services/prelaunch_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Business business(
    String id, {
    Set<int> days = const {1, 2, 3, 4, 5},
    double opens = 9,
    double closes = 17,
  }) => Business(
    id: id,
    name: id,
    category: BusinessCategory.food,
    tier: SubscriptionTier.basic,
    area: 'x',
    description: 'x',
    hours: OpeningHours(days: days, opensAt: opens, closesAt: closes),
  );

  group('legal pages', () {
    for (final name in ['privacy', 'terms', 'delete-account']) {
      test('$name.md parses, and its contact line is filled in', () {
        final source = File('assets/legal/$name.md').readAsStringSync();
        expect(source, contains('{{CONTACT}}'));
        final blocks = parseLegal(source, contact: 'Email team@example.com.');
        expect(blocks.first, isA<LegalHeading>());
        final text = blocks.map((b) => b.text).join('\n');
        expect(text, contains('team@example.com'));
        expect(text, isNot(contains('{{')));
        // Every line became a block; nothing is left looking like Markdown.
        expect(text, isNot(contains('\n#')));
      });
    }

    test('lists, numbers and paragraphs', () {
      final blocks = parseLegal(
        '# T\n\n## Part\n\nOne\nline.\n\n- a\n- b\n\n1. first\n2. second\n',
        contact: '',
      );
      expect(blocks.map((b) => b.runtimeType.toString()), [
        'LegalHeading',
        'LegalHeading',
        'LegalParagraph',
        'LegalBullet',
        'LegalBullet',
        'LegalBullet',
        'LegalBullet',
      ]);
      expect(blocks[2].text, 'One line.');
      expect((blocks[6] as LegalBullet).number, 2);
    });

    test('the privacy policy says what deleting the account removes', () {
      final source = File('assets/legal/privacy.md').readAsStringSync();
      expect(source, contains('Delete account'));
      expect(source, contains('never sent to us or stored'));
    });
  });

  group('notices', () {
    AppNotice notice(DateTime start, DateTime? end) => AppNotice(
      id: 'n',
      isStorm: true,
      title: 't',
      body: '',
      linkUrl: null,
      startsAt: start,
      endsAt: end,
    );
    final now = DateTime(2026, 10, 22, 12);

    test('live between start and end', () {
      expect(
        notice(DateTime(2026, 10, 22), DateTime(2026, 10, 23)).isLiveAt(now),
        isTrue,
      );
    });

    test('an open-ended notice stays live until ended', () {
      expect(notice(DateTime(2026, 10, 2), null).isLiveAt(now), isTrue);
    });

    test('ended and scheduled notices are not live', () {
      expect(
        notice(DateTime(2026, 10, 20), DateTime(2026, 10, 21)).isLiveAt(now),
        isFalse,
      );
      expect(notice(DateTime(2026, 10, 23), null).isLiveAt(now), isFalse);
    });
  });

  group('collections', () {
    test('keep the team order and drop listings no longer visible', () {
      final c = Collection.fromMap({
        'id': 'c',
        'title': 'Best pepperpot',
        'blurb': '',
        'published': true,
        'collection_items': [
          {'business_id': 'b', 'position': 1},
          {'business_id': 'gone', 'position': 2},
          {'business_id': 'a', 'position': 0},
        ],
      });
      final resolved = c.resolve([business('a'), business('b')]);
      expect(resolved.map((b) => b.id), ['a', 'b']);
    });
  });

  group('time filters', () {
    test('open late: until 21:00 or later, or past midnight', () {
      expect(isOpenLate(business('a', closes: 22)), isTrue);
      expect(isOpenLate(business('a', closes: 21)), isTrue);
      expect(isOpenLate(business('a', opens: 18, closes: 2)), isTrue);
      expect(isOpenLate(business('a', closes: 20.5)), isFalse);
      expect(isOpenLate(business('a', days: {}, closes: 23)), isFalse);
    });

    test('open Sunday', () {
      expect(isOpenSunday(business('a', days: {6, 7})), isTrue);
      expect(isOpenSunday(business('a')), isFalse);
    });

    test('both filters apply through the query', () {
      final late = business('late', days: {5, 6, 7}, opens: 18, closes: 1);
      final early = business('early');
      final results = ListingFilter.apply([
        late,
        early,
      ], const ListingQuery(openLateOnly: true, openSundayOnly: true));
      expect(results.map((b) => b.id), ['late']);
    });
  });
}

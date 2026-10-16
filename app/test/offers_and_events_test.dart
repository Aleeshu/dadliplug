import 'dart:math';

import 'package:antigua_business_map/features/events/event_widgets.dart';
import 'package:antigua_business_map/features/events/events_screen.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('offer codes', () {
    test('typed codes are trimmed, upper-cased and de-spaced', () {
      expect(normaliseOfferCode(' lunch 10 '), 'LUNCH10');
      expect(normaliseOfferCode('   '), isNull);
      expect(normaliseOfferCode(null), isNull);
    });

    test('match the database format: 4 to 10 capitals and digits', () {
      expect(isValidOfferCode('LUNCH10'), isTrue);
      expect(isValidOfferCode('ABC'), isFalse);
      expect(isValidOfferCode('ABCDEFGHIJK'), isFalse);
      expect(isValidOfferCode('LUNCH-10'), isFalse);
    });

    test('generated codes are valid and avoid look-alike characters', () {
      final rng = Random(1);
      for (var i = 0; i < 200; i++) {
        final code = generateOfferCode(random: rng);
        expect(isValidOfferCode(code), isTrue, reason: code);
        expect(code, isNot(matches(RegExp('[01OI]'))), reason: code);
      }
    });

    test('an ad is an offer only when it has a code', () {
      BusinessAd ad({String? code}) => BusinessAd(
        id: 'a',
        businessId: 'b',
        businessName: 'B',
        title: 'T',
        startsAt: DateTime.utc(2026),
        offerCode: code,
      );
      expect(ad().isOffer, isFalse);
      expect(ad(code: '').isOffer, isFalse);
      expect(ad(code: 'LUNCH10').isOffer, isTrue);
    });
  });

  group('events', () {
    BusinessEvent event({
      String id = 'e',
      DateTime? startsAt,
      DateTime? endsAt,
      bool isFeatured = false,
      bool businessFeatured = false,
      String? organizer,
      List<String> tags = const [],
    }) => BusinessEvent(
      id: id,
      businessId: 'b',
      businessName: 'Beach Bar',
      title: 'Event $id',
      startsAt: startsAt ?? DateTime.now().add(const Duration(days: 2)),
      endsAt: endsAt,
      isFeatured: isFeatured,
      businessFeatured: businessFeatured,
      organizer: organizer,
      tags: tags,
    );

    test('an event still running is not past', () {
      // It started an hour ago and ends tonight: it must stay listed.
      final now = DateTime.utc(2026, 8, 22, 20);
      final running = event(
        startsAt: DateTime.utc(2026, 8, 22, 19),
        endsAt: DateTime.utc(2026, 8, 23, 3),
      );
      expect(running.isPastAt(now), isFalse);
    });

    test('featured by the team or by a Featured business', () {
      expect(event().featured, isFalse);
      expect(event(isFeatured: true).featured, isTrue);
      expect(event(businessFeatured: true).featured, isTrue);
    });

    test('the organizer falls back to the posting business', () {
      expect(event().organizerName, 'Beach Bar');
      expect(event(organizer: ' ').organizerName, 'Beach Bar');
      expect(
        event(organizer: 'Antigua Events Co.').organizerName,
        'Antigua Events Co.',
      );
    });

    test('times are Antigua time, whatever the phone is set to', () {
      // 22:00 UTC is 6:00 PM in Antigua (UTC-4, no daylight saving).
      final e = event(
        startsAt: DateTime.utc(2026, 8, 22, 22),
        endsAt: DateTime.utc(2026, 8, 23, 3),
      );
      // intl puts a narrow no-break space before AM/PM; compare as text.
      final shown = eventTimeRange(e)
          .replaceAll(String.fromCharCode(0x202F), ' ');
      expect(shown, '6:00 PM – 11:00 PM');
    });

    testWidgets('the Events screen shows the calendar and Featured Events', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            upcomingEventsProvider.overrideWithValue(
              AsyncData([
                event(id: 'f', isFeatured: true, tags: ['Music']),
                event(id: 'p'),
              ]),
            ),
          ],
          child: const MaterialApp(home: EventsScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Featured Events'), findsOneWidget);
      expect(find.text('Event f'), findsOneWidget);
      // Only featured events under Featured Events.
      expect(find.text('Event p'), findsNothing);
      expect(find.text('Music'), findsOneWidget);
    });

    testWidgets(
      'with nothing featured it lists upcoming, not an empty section',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              upcomingEventsProvider.overrideWithValue(AsyncData([event()])),
            ],
            child: const MaterialApp(home: EventsScreen()),
          ),
        );
        await tester.pump();
        expect(find.text('Upcoming Events'), findsOneWidget);
        expect(find.text('Event e'), findsOneWidget);
      },
    );

    testWidgets('a load failure is an error, not an empty calendar', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            upcomingEventsProvider.overrideWithValue(
              AsyncError(Exception('offline'), StackTrace.empty),
            ),
          ],
          child: const MaterialApp(home: EventsScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('Could not load events.'), findsOneWidget);
    });
  });
}

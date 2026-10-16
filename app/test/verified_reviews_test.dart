import 'package:antigua_business_map/features/reviews/reviews_section.dart';
import 'package:antigua_business_map/models/review.dart';
import 'package:antigua_business_map/services/reviews_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Phase 6: QR check-in and reviews behind it (plan.md sections 7 and 8).
void main() {
  group('visit QR', () {
    test('round-trips business and code', () {
      final payload = visitQrPayload('biz-1', 'A1B2C3');
      expect(parseVisitQr(payload), (businessId: 'biz-1', code: 'A1B2C3'));
    });

    test('a scanned code is normalised the way the till shows it', () {
      expect(parseVisitQr('dadliplug:visit:biz-1:a1b2c3')?.code, 'A1B2C3');
      expect(normaliseVisitCode(' a1 b2c3 '), 'A1B2C3');
    });

    test('anything that is not our QR is ignored, not guessed at', () {
      // A menu QR or a URL must never be read as a check-in.
      expect(parseVisitQr('https://example.com'), isNull);
      expect(parseVisitQr('dadliplug:visit::A1B2C3'), isNull);
      expect(parseVisitQr('dadliplug:visit:biz-1:'), isNull);
      expect(parseVisitQr('other:visit:biz-1:A1B2C3'), isNull);
    });
  });

  test('an offline check-in keeps the time it was scanned', () {
    // The server checks the code against the day it was scanned, so the
    // queued time must survive the trip through storage exactly.
    final item = PendingCheckIn('biz', 'A1B2C3', DateTime.utc(2026, 8, 22, 23));
    final back = PendingCheckIn.fromJson(item.toJson());
    expect(back.businessId, 'biz');
    expect(back.code, 'A1B2C3');
    expect(back.scannedAt, DateTime.utc(2026, 8, 22, 23));
  });

  test('approval rate is "approved of requests", and absent with none', () {
    ReviewAuditRow row(int requests, int approved) => ReviewAuditRow(
      businessId: 'b',
      businessName: 'B',
      requests: requests,
      approved: approved,
      declined: requests - approved,
      checkedInVisits: 0,
      reviews: 0,
      recentDeclineReasons: const [],
    );
    expect(row(10, 9).approvalRate, 0.9);
    expect(row(0, 0).approvalRate, isNull);
  });

  test('a refusal from the database is shown in its own words', () {
    expect(
      reviewErrorMessage(
        const PostgrestException(
          message: 'That code does not match this business today',
        ),
      ),
      'That code does not match this business today',
    );
    expect(reviewErrorMessage(Exception('socket')), contains('connection'));
  });

  testWidgets('a review says it came from a verified visit', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ReviewCard(
              review: Review(
                id: 'r',
                businessId: 'b',
                userId: 'u',
                rating: 4,
                body: 'Great fish',
                createdAt: DateTime.utc(2026, 8, 22),
                status: ReviewStatus.verified,
                reply: 'Thank you!',
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Verified visit'), findsOneWidget);
    expect(find.text('Great fish'), findsOneWidget);
    expect(find.textContaining('Thank you!'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
  });
}

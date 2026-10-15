import 'package:antigua_business_map/models/review.dart';
import 'package:antigua_business_map/services/report_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the month-end report arithmetic.
///
/// The report is what a renewal conversation is based on, so an off-by-one at a
/// month boundary silently drops a day of a paying customer's numbers.
void main() {
  group('month boundaries', () {
    test('month zero starts at the beginning of this month', () {
      final start = ReportRepository.monthStart(DateTime.utc(2026, 6, 15), 0);
      // Antigua midnight on the 1st is 04:00 UTC. Returning UTC midnight
      // opened every query window four hours early.
      expect(start, DateTime.utc(2026, 6, 1, 4));
    });

    test('one month back crosses the year boundary', () {
      final start = ReportRepository.monthStart(DateTime.utc(2026, 1, 15), 1);
      expect(start, DateTime.utc(2025, 12, 1, 4));
    });

    test('twelve months back is the same month a year earlier', () {
      // Mid-month UTC, so the Antigua offset cannot shift which month this is.
      // Midnight on the 1st would, correctly, still be the previous month there.
      final start = ReportRepository.monthStart(DateTime.utc(2026, 6, 15), 12);
      expect(start, DateTime.utc(2025, 6, 1, 4));
    });

    test('the boundary uses Antigua time, not device time', () {
      // 03:00 UTC on 1 June is still 31 May in Antigua (UTC-4). Computing the
      // boundary in UTC would start the month four hours early.
      final start = ReportRepository.monthStart(DateTime.utc(2026, 6, 1, 3), 0);
      expect(start, DateTime.utc(2026, 5, 1, 4));
    });

    test('the end of a month is the start of the next', () {
      final end = ReportRepository.monthEnd(DateTime.utc(2026, 12, 1, 4));
      expect(end, DateTime.utc(2027, 1, 1, 4));
    });

    test('the last evening of a month stays in that month', () {
      // 23:00 on 30 June in Antigua is 03:00 UTC on 1 July. It belongs to
      // June's report, which means June's window must end at 04:00 UTC.
      final june = ReportRepository.monthStart(DateTime.utc(2026, 6, 15), 0);
      final lastEvening = DateTime.utc(2026, 7, 1, 3);
      expect(lastEvening.isBefore(ReportRepository.monthEnd(june)), isTrue);
    });

    test('a future month still produces a valid range', () {
      final from = ReportRepository.monthStart(DateTime.utc(2026, 6, 15), -3);
      expect(from, DateTime.utc(2026, 9, 1, 4));
      expect(ReportRepository.monthEnd(from).isAfter(from), isTrue);
    });
  });

  group('star breakdown', () {
    test('averages nothing when there are no reviews', () {
      const breakdown = StarBreakdown.empty();
      expect(breakdown.total, 0);
      // Null, not zero. "0.0" beside an empty list reads as terrible rather
      // than as no data.
      expect(breakdown.average, isNull);
    });

    test('averages across all reviews', () {
      const breakdown = StarBreakdown(
        oneStar: 1,
        twoStar: 0,
        threeStar: 0,
        fourStar: 0,
        fiveStar: 1,
      );
      expect(breakdown.total, 2);
      expect(breakdown.average, 3.0);
    });

    test('counts each star separately', () {
      const breakdown = StarBreakdown(
        oneStar: 2,
        twoStar: 1,
        threeStar: 3,
        fourStar: 4,
        fiveStar: 10,
      );
      expect(breakdown.total, 20);
      expect(breakdown.countFor(5), 10);
      expect(breakdown.countFor(1), 2);
      // Out of range is zero rather than a crash.
      expect(breakdown.countFor(0), 0);
    });

    test('a single five star review reports its true average', () {
      // The score a customer sees is Bayesian for exactly this reason, so the
      // report should show the plain average and the raw total alongside it
      // rather than implying one review settles anything.
      const breakdown = StarBreakdown(
        oneStar: 0,
        twoStar: 0,
        threeStar: 0,
        fourStar: 0,
        fiveStar: 1,
      );
      expect(breakdown.average, 5.0);
      expect(breakdown.total, 1);
    });
  });

  group('only verified reviews count', () {
    test('a locked review is not counted', () {
      expect(isCountedInReport(ReviewStatus.locked), isFalse);
    });

    test('a pending request is not counted', () {
      expect(isCountedInReport(ReviewStatus.pending), isFalse);
    });

    test('a removed review is not counted', () {
      expect(isCountedInReport(ReviewStatus.removed), isFalse);
    });

    test('a verified review is counted', () {
      expect(isCountedInReport(ReviewStatus.verified), isTrue);
    });
  });

  group('report totals', () {
    MonthlyReport reportWith(List<AdPerformance> ads) => MonthlyReport(
          businessId: 'b1',
          month: DateTime.utc(2026, 6, 1),
          listingViews: 0,
          calls: 0,
          whatsappTaps: 0,
          ads: ads,
          reviews: const StarBreakdown.empty(),
          verifiedReviews: 0,
          newVisits: 0,
        );

    test('ad views sum across every advertisement', () {
      final report = reportWith([
        const AdPerformance(
          adId: '1',
          title: 'a',
          views: 10,
          wasRunning: true,
        ),
        const AdPerformance(
          adId: '2',
          title: 'b',
          views: 5,
          wasRunning: true,
        ),
      ]);
      expect(report.adViews, 15);
    });

    test('a business with no advertisements reports zero, not null', () {
      // Zero is the right answer here and null is the wrong one: unlike a star
      // rating, "no advertisements ran" genuinely is zero.
      expect(reportWith(const []).adViews, 0);
    });
  });
}
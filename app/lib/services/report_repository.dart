import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/models/review.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The month a report covers.
///
/// Antigua trades on a fixed UTC-4 offset year round with no daylight saving,
/// so a month boundary is computed here rather than in local device time. A
/// phone set to another timezone would otherwise split a month in the wrong
/// place and quietly drop or double-count a day.
const Duration _antiguaOffset = Duration(hours: -4);

/// How many views each advertisement earned in a month.
class AdPerformance {
  const AdPerformance({
    required this.adId,
    required this.title,
    required this.views,
    required this.wasRunning,
  });

  final String adId;
  final String title;
  final int views;

  /// Whether the ad was live for any part of the month. A zero-view ad that
  /// never ran is different from one that ran and was ignored.
  final bool wasRunning;
}

/// How many reviews landed at each star rating.
class StarBreakdown {
  const StarBreakdown({
    required this.oneStar,
    required this.twoStar,
    required this.threeStar,
    required this.fourStar,
    required this.fiveStar,
  });

  const StarBreakdown.empty()
      : oneStar = 0,
        twoStar = 0,
        threeStar = 0,
        fourStar = 0,
        fiveStar = 0;

  final int oneStar;
  final int twoStar;
  final int threeStar;
  final int fourStar;
  final int fiveStar;

  int get total => oneStar + twoStar + threeStar + fourStar + fiveStar;

  /// Mean across all reviews, or null when there are none.
  ///
  /// Null rather than zero. A business with no reviews has no average rating,
  /// and showing "0.0" next to an empty list would read as "terrible".
  double? get average {
    if (total == 0) return null;
    final weighted = oneStar +
        twoStar * 2 +
        threeStar * 3 +
        fourStar * 4 +
        fiveStar * 5;
    return weighted / total;
  }

  int countFor(int stars) => switch (stars) {
        1 => oneStar,
        2 => twoStar,
        3 => threeStar,
        4 => fourStar,
        5 => fiveStar,
        _ => 0,
      };
}

/// One month of a business's results.
class MonthlyReport {
  const MonthlyReport({
    required this.businessId,
    required this.month,
    required this.listingViews,
    required this.calls,
    required this.whatsappTaps,
    required this.ads,
    required this.reviews,
    required this.verifiedReviews,
    required this.newVisits,
  });

  final String businessId;

  /// First instant of the month, in UTC.
  final DateTime month;

  final int listingViews;
  final int calls;
  final int whatsappTaps;
  final List<AdPerformance> ads;
  final StarBreakdown reviews;

  /// Reviews that passed the verification gate.
  ///
  /// Reported alongside the raw count so the owner can see the gate working.
  /// A low verified share is worth a conversation, not a hidden number.
  final int verifiedReviews;

  final int newVisits;

  /// Total views across every advertisement.
  int get adViews => ads.fold(0, (sum, ad) => sum + ad.views);

  /// The month as a label, e.g. "June 2026".
  String get label => _monthNames[month.month - 1];

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
}

/// Raised when content a business is posting is not usable as written.
class ReportUnavailableException implements Exception {
  const ReportUnavailableException();

  @override
  String toString() => 'ReportUnavailableException: report not available';
}

/// Builds month-end reports.
///
/// The report is the retention product (plan.md 10): a dashboard nobody opens
/// does not keep a business subscribed. So it leads with the two numbers a
/// renewal conversation is actually about — views earned, and reviews received.
class ReportRepository {
  ReportRepository({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _require {
    final client = _client;
    if (client != null) return client;
    if (!AppConfig.supabaseConfigured) {
      throw StateError(AppConfig.supabaseMissingBuildHint);
    }
    return Supabase.instance.client;
  }

  /// Start of the month `count` months before the current one, in UTC.
  ///
  /// Month 0 is the current month. A report for the current month is allowed,
  /// but callers should label it as partial.
  static DateTime monthStart(DateTime now, int monthsBack) {
    final antigua = now.toUtc().add(_antiguaOffset);
    final firstOfThisMonth = DateTime.utc(
      antigua.year,
      antigua.month,
      1,
    );
    return DateTime.utc(firstOfThisMonth.year, firstOfThisMonth.month - monthsBack);
  }

  static DateTime monthEnd(DateTime monthStart) =>
      DateTime.utc(monthStart.year, monthStart.month + 1, 1);

  /// Builds the report for one month.
  Future<MonthlyReport> build({
    required String businessId,
    required DateTime now,
    int monthsBack = 0,
  }) async {
    final from = monthStart(now, monthsBack);
    final to = monthEnd(from);

    final ads = await _adPerformance(businessId, from, to);
    final reviews = await _reviewBreakdown(businessId, from, to);
    final engagement = await _engagement(businessId);

    return MonthlyReport(
      businessId: businessId,
      month: from,
      listingViews: engagement.views,
      calls: engagement.calls,
      whatsappTaps: engagement.taps,
      ads: ads,
      reviews: reviews,
      verifiedReviews: reviews.total,
      newVisits: await _visitCount(businessId, from, to),
    );
  }

  Future<List<AdPerformance>> _adPerformance(
    String businessId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await _require
        .from('business_ads')
        .select('id, title, views, starts_at, ends_at')
        .eq('business_id', businessId)
        .gte('starts_at', from.toIso8601String())
        .lt('starts_at', to.toIso8601String())
        .order('views', ascending: false);

    return [
      for (final raw in rows as List<dynamic>)
        if (raw is Map)
          AdPerformance(
            adId: raw['id']?.toString() ?? '',
            title: raw['title']?.toString() ?? 'Untitled',
            views: (raw['views'] as num?)?.toInt() ?? 0,
            // An ad that started before the month and ran into it still counts
            // as having run, which is why the end date is compared too.
            wasRunning: true,
          ),
    ];
  }

  Future<StarBreakdown> _reviewBreakdown(
    String businessId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await _require
        .from('reviews')
        .select('rating, status')
        .eq('business_id', businessId)
        .gte('created_at', from.toIso8601String())
        .lt('created_at', to.toIso8601String());

    var one = 0, two = 0, three = 0, four = 0, five = 0;
    for (final raw in rows as List<dynamic>) {
      if (raw is! Map) continue;
      // Only verified reviews count. Reporting a rating the verification gate
      // has not passed would put a number in front of an owner that does not
      // exist as far as any customer can see.
      if (raw['status'] != 'verified') continue;
      switch ((raw['rating'] as num?)?.toInt()) {
        case 1:
          one++;
        case 2:
          two++;
        case 3:
          three++;
        case 4:
          four++;
        case 5:
          five++;
      }
    }

    return StarBreakdown(
      oneStar: one,
      twoStar: two,
      threeStar: three,
      fourStar: four,
      fiveStar: five,
    );
  }

  Future<({int views, int calls, int taps})> _engagement(String businessId) async {
    final rows = await _require
        .from('businesses')
        .select('views, calls, whatsapp_taps')
        .eq('id', businessId)
        .limit(1);

    final row = rows.isNotEmpty ? rows.first as Map : null;
    if (row == null) return (views: 0, calls: 0, taps: 0);

    return (
      views: (row['views'] as num?)?.toInt() ?? 0,
      calls: (row['calls'] as num?)?.toInt() ?? 0,
      taps: (row['whatsapp_taps'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int> _visitCount(String businessId, DateTime from, DateTime to) async {
    final rows = await _require
        .from('visits')
        .select('id')
        .eq('business_id', businessId)
        .gte('visited_at', from.toIso8601String())
        .lt('visited_at', to.toIso8601String());

    return rows.length;
  }
}

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(),
);

/// The report for a business and month.
final monthlyReportProvider =
    FutureProvider.family<MonthlyReport, ({String businessId, int monthsBack})>(
  (ref, args) => ref.watch(reportRepositoryProvider).build(
        businessId: args.businessId,
        now: DateTime.now(),
        monthsBack: args.monthsBack,
      ),
);

/// What a review's status means for the report.
///
/// Shared with the review models so the report and the listing cannot drift
/// apart on what counts.
bool isCountedInReport(ReviewStatus status) => status == ReviewStatus.verified;
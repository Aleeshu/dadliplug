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

  /// The month covered, as Antigua's calendar month: midnight on the 1st,
  /// with `year` and `month` reading as Antigua sees them.
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

  /// The instant the month `monthsBack` months before the current one began,
  /// as a UTC instant.
  ///
  /// Antigua's month starts at local midnight, which is 04:00 UTC. The previous
  /// version picked the right month but returned UTC midnight, so every query
  /// window opened four hours early and closed four hours early: the last
  /// evening of each month was counted in the next one.
  ///
  /// Month 0 is the current month. A report for the current month is allowed,
  /// but callers should label it as partial.
  static DateTime monthStart(DateTime now, int monthsBack) {
    final antigua = now.toUtc().add(_antiguaOffset);
    return DateTime.utc(antigua.year, antigua.month - monthsBack, 1)
        .subtract(_antiguaOffset);
  }

  static DateTime monthEnd(DateTime monthStart) {
    final antigua = monthStart.add(_antiguaOffset);
    return DateTime.utc(antigua.year, antigua.month + 1, 1)
        .subtract(_antiguaOffset);
  }

  /// Builds the report for one month.
  ///
  /// Every count is for the month only. Views, calls and taps used to be read
  /// from the lifetime counters on the listing, so a "monthly" report showed
  /// everything since the listing went live and could never show a dip.
  Future<MonthlyReport> build({
    required String businessId,
    required DateTime now,
    int monthsBack = 0,
  }) async {
    final from = monthStart(now, monthsBack);
    final to = monthEnd(from);

    final results = await Future.wait([
      _adPerformance(businessId, from, to),
      _reviewBreakdown(businessId, from, to),
      _eventCount(businessId, 'view', from, to),
      _eventCount(businessId, 'call', from, to),
      _eventCount(businessId, 'whatsapp', from, to),
      _visitCount(businessId, from, to),
    ]);
    final reviews = results[1] as StarBreakdown;

    return MonthlyReport(
      businessId: businessId,
      month: from.add(_antiguaOffset),
      listingViews: results[2] as int,
      calls: results[3] as int,
      whatsappTaps: results[4] as int,
      ads: results[0] as List<AdPerformance>,
      reviews: reviews,
      verifiedReviews: reviews.total,
      newVisits: results[5] as int,
    );
  }

  /// Every ad that was live at any point in the month, with the views it
  /// earned inside the month.
  ///
  /// Previously only ads that *started* in the month were listed, with their
  /// lifetime view count. An ad running since last month vanished from the
  /// report while still earning views.
  Future<List<AdPerformance>> _adPerformance(
    String businessId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await _require
        .from('business_ads')
        .select('id, title, starts_at, ends_at')
        .eq('business_id', businessId)
        .lt('starts_at', to.toIso8601String())
        .or('ends_at.is.null,ends_at.gte.${from.toIso8601String()}');

    final ads = <AdPerformance>[];
    for (final raw in rows as List<dynamic>) {
      if (raw is! Map) continue;
      final id = raw['id']?.toString();
      if (id == null) continue;

      final views = await _require
          .from('engagement_events')
          .select('id')
          .eq('ad_id', id)
          .eq('kind', 'ad_view')
          .gte('occurred_at', from.toIso8601String())
          .lt('occurred_at', to.toIso8601String())
          .count(CountOption.exact);

      ads.add(
        AdPerformance(
          adId: id,
          title: raw['title']?.toString() ?? 'Untitled',
          views: views.count,
          wasRunning: true,
        ),
      );
    }

    ads.sort((a, b) => b.views.compareTo(a.views));
    return ads;
  }

  /// A server-side count, not a fetched list. PostgREST caps a response at a
  /// thousand rows by default, and counting a capped list would quietly
  /// under-report a busy listing's month.
  Future<int> _eventCount(
    String businessId,
    String kind,
    DateTime from,
    DateTime to,
  ) async {
    final response = await _require
        .from('engagement_events')
        .select('id')
        .eq('business_id', businessId)
        .eq('kind', kind)
        .gte('occurred_at', from.toIso8601String())
        .lt('occurred_at', to.toIso8601String())
        .count(CountOption.exact);
    return response.count;
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

  Future<int> _visitCount(String businessId, DateTime from, DateTime to) async {
    final response = await _require
        .from('visits')
        .select('id')
        .eq('business_id', businessId)
        .gte('visited_at', from.toIso8601String())
        .lt('visited_at', to.toIso8601String())
        .count(CountOption.exact);

    return response.count;
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
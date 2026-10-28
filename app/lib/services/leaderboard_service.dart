import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/ranking_service.dart';

/// One business as it appears on a leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.business,
    required this.position,
    required this.score,
  });

  final Business business;

  /// 1-based, as a person would say it.
  final int position;

  final RankingScore score;
}

/// Why a business is not on the leaderboard yet.
///
/// Kept as an explicit reason rather than a silent omission, because the screen
/// has to tell the business owner *why* their listing is missing. Being absent
/// without explanation reads as broken.
enum LeaderboardExclusion {
  /// Listed less than [LeaderboardService.gracePeriod] ago.
  withinGracePeriod,

  /// Online-only businesses have no pin and no walk-in traffic, so ranking them
  /// against shops is meaningless.
  notRankable,
}

/// A business excluded from the leaderboard, with the reason.
class ExcludedBusiness {
  const ExcludedBusiness({
    required this.business,
    required this.reason,
    required this.eligibleFrom,
  });

  final Business business;
  final LeaderboardExclusion reason;

  /// When it becomes eligible. Null when the reason is not time-based.
  final DateTime? eligibleFrom;
}

/// Per-category leaderboards: "Top 10 Food businesses by popularity".
///
/// ## The grace period
///
/// A new listing has no reviews, no views and no score. Ranked honestly it sits
/// dead last, and the board becomes a list of the businesses that were here
/// first. That punishes exactly the small and online businesses the Growing
/// tier is aimed at, and would make the leaderboard read as "inactivity is
/// punished" when it is really "recency is punished".
///
/// So a business stays off the board for one month after listing. By then it
/// has had a real chance to collect reviews and views, and if it still scores
/// badly that ranking means something.
///
/// A month is a judgement, not a measurement. It is long enough for a business
/// to be found and visited, and short enough that a launch cohort is not
/// invisible for a quarter. Revisit once real data exists.
class LeaderboardService {
  const LeaderboardService({this.gracePeriod, this.defaultSize});

  /// How long a new listing is held back.
  ///
  /// Injectable so the tests do not have to travel a month into the future.
  static const Duration defaultGracePeriod = Duration(days: 30);

  /// Default number of places shown per category.
  static const int defaultBoardSize = 10;

  final Duration? gracePeriod;
  final int? defaultSize;

  Duration get _grace => gracePeriod ?? defaultGracePeriod;

  int get _size => defaultSize ?? defaultBoardSize;

  /// The leaderboard for one category.
  ///
  /// Returns entries and exclusions together, because "why is my business not
  /// on this list" is the question every owner will ask.
  Leaderboard build({
    required List<Business> businesses,
    required BusinessCategory category,
    required DateTime now,
  }) {
    final inCategory = businesses.where((b) => b.category == category);

    final excluded = <ExcludedBusiness>[];
    final eligible = <Business>[];

    for (final business in inCategory) {
      final reason = _exclusionFor(business, now);
      if (reason != null) {
        excluded.add(
          ExcludedBusiness(
            business: business,
            reason: reason,
            eligibleFrom: reason == LeaderboardExclusion.withinGracePeriod
                ? _eligibleFrom(business, now)
                : null,
          ),
        );
        continue;
      }
      eligible.add(business);
    }

    final ranked = [...eligible]..sort(compareByRank);

    return Leaderboard(
      category: category,
      entries: [
        for (var i = 0; i < ranked.length && i < _size; i++)
          LeaderboardEntry(
            business: ranked[i],
            position: i + 1,
            score: scoreBusiness(ranked[i]),
          ),
      ],
      excluded: excluded,
      totalEligible: ranked.length,
    );
  }

  /// Every category that currently has at least one eligible business.
  ///
  /// An empty board for a category with listings on it is worse than no board,
  /// so the screen only offers categories that have something to show.
  List<BusinessCategory> categoriesWithEntries({
    required List<Business> businesses,
    required DateTime now,
  }) => BusinessCategory.values
      .where(
        (c) => build(
          businesses: businesses,
          category: c,
          now: now,
        ).entries.isNotEmpty,
      )
      .toList(growable: false);

  /// True when a business may appear on a board yet.
  bool isEligible({required Business business, required DateTime now}) =>
      _exclusionFor(business, now) == null;

  /// When this listing becomes eligible, or null if the reason is not time.
  DateTime? eligibleFrom({required Business business, required DateTime now}) {
    final reason = _exclusionFor(business, now);
    if (reason != LeaderboardExclusion.withinGracePeriod) return null;
    return _eligibleFrom(business, now);
  }

  LeaderboardExclusion? _exclusionFor(Business business, DateTime now) {
    // No location, no local ranking: an online-only shop is not competing
    // with the restaurant down the road for "Top 10 Food".
    if (!business.hasLocation) {
      return LeaderboardExclusion.notRankable;
    }
    if (_daysSinceListing(business, now) < _grace.inDays) {
      return LeaderboardExclusion.withinGracePeriod;
    }
    return null;
  }

  DateTime _eligibleFrom(Business business, DateTime now) {
    final created = business.createdAt;
    if (created == null) return now.add(_grace);
    return created.toUtc().add(_grace);
  }

  /// Days since listing, treating a missing `created_at` as zero.
  ///
  /// Null is treated as brand new on purpose: a listing whose age cannot be
  /// established has not earned a place on a public ranking yet.
  int _daysSinceListing(Business business, DateTime now) {
    final created = business.createdAt;
    if (created == null) return 0;
    return now.toUtc().difference(created.toUtc()).inDays;
  }
}

/// A built leaderboard for one category.
class Leaderboard {
  const Leaderboard({
    required this.category,
    required this.entries,
    required this.excluded,
    required this.totalEligible,
  });

  final BusinessCategory category;
  final List<LeaderboardEntry> entries;

  /// Businesses in this category that are not on the board, and why.
  final List<ExcludedBusiness> excluded;

  /// How many businesses qualified, which can exceed [entries] once the board
  /// is capped at ten.
  final int totalEligible;

  bool get isEmpty => entries.isEmpty;
}

/// What a leaderboard tab ranks by (2026-10-28 redesign). Every mode uses
/// the same eligible listings (grace period, no online-only), so a tab can
/// change the measure but never let anyone skip the rules.
enum LeaderboardMode {
  /// Earned score: rating, reviews and activity (plan.md 5).
  top('Top Businesses'),

  /// Listing views.
  viewed('Most Viewed'),

  /// Calls and WhatsApp taps: people who got in touch.
  clicks('Most Clicks'),

  /// Views, calls and taps, weighted toward getting in touch.
  engaging('Most Engaging');

  const LeaderboardMode(this.label);
  final String label;

  int metricOf(Business b) => switch (this) {
    LeaderboardMode.top => scoreBusiness(b).total,
    LeaderboardMode.viewed => b.views,
    LeaderboardMode.clicks => b.calls + b.whatsappTaps,
    LeaderboardMode.engaging => b.engagement,
  };

  String describe(Business b) => switch (this) {
    LeaderboardMode.top => '${scoreBusiness(b).total} points',
    LeaderboardMode.viewed => '${b.views} views',
    LeaderboardMode.clicks => '${b.calls + b.whatsappTaps} calls and taps',
    LeaderboardMode.engaging => '${b.engagement} activity',
  };
}

/// The top [size] of [eligible] by [mode], numbered from one. Ties keep the
/// earned order [eligible] arrives in, so a tab never reshuffles equal
/// businesses between refreshes.
List<LeaderboardEntry> rankBy(
  List<Business> eligible,
  LeaderboardMode mode, {
  int size = LeaderboardService.defaultBoardSize,
}) {
  final indexed = eligible.indexed.toList()
    ..sort((a, b) {
      final byMetric = mode.metricOf(b.$2).compareTo(mode.metricOf(a.$2));
      return byMetric != 0 ? byMetric : a.$1.compareTo(b.$1);
    });
  return [
    for (final (i, (_, b)) in indexed.take(size).indexed)
      LeaderboardEntry(business: b, position: i + 1, score: scoreBusiness(b)),
  ];
}

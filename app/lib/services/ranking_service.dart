import 'dart:math' as math;

import 'package:antigua_business_map/models/business.dart';

/// The popularity score, ported exactly from the prototype's `score()`.
///
/// Mirrored in SQL as `public.rank_score` for the nightly snapshot and the
/// Spotlight rotation; test/ranking_parity_test.dart pins the two together.
///
/// The whole product promise is that rank is earned, not bought, so this
/// function is the most important piece of logic in the app and should not be
/// changed casually. If it changes, the ranking a business earned silently
/// changes with it.
///
/// Three components:
///   rating  45%  Bayesian average, so a 5.0 from one reviewer does not
///               outrank a 4.8 from forty
///   volume  25%  logarithmic in review count, saturating around 60 reviews
///   engaged 30%  views, calls and WhatsApp taps, weighted toward intent
class RankingScore {
  const RankingScore({
    required this.rating,
    required this.volume,
    required this.engagement,
    required this.total,
  });

  /// Normalised 0–1, Bayesian-adjusted rating.
  final double rating;

  /// Normalised 0–1 review volume.
  final double volume;

  /// Normalised 0–1 engagement.
  final double engagement;

  /// Final 0–100, the number shown in the team dashboard.
  final int total;

  static const double kRatingWeight = 0.45;
  static const double kVolumeWeight = 0.25;
  static const double kEngagementWeight = 0.30;

  /// Prior mean. 3.8 rather than 3.0: on an island where businesses are
  /// mostly new to this, a neutral prior of 3.0 would punish anyone starting
  /// out and inflate anyone with a lucky first reviewer.
  static const double kBayesPriorMean = 3.8;

  /// Review count at which volume reaches full marks.
  static const int kVolumeSaturation = 61;

  /// Engagement at which the engagement term reaches full marks.
  static const int kEngagementSaturation = 3001;
}

/// Average rating and review count for a business.
///
/// Blends the ratings seeded before launch with the live ones, so a business
/// that imported twenty reviews is not shown as "0.0" on day one.
///
/// Live reviews come from the totals on the listing row, plus any review rows
/// attached to the model (tests, and the rank explainer's what-ifs). The
/// repository never attaches rows, so nothing is counted twice.
({int count, double average}) reviewStats(Business b) {
  final live = b.visibleReviews;
  final liveCount = b.liveReviewCount + live.length;
  final liveSum =
      b.liveRatingSum + live.fold<int>(0, (sum, r) => sum + r.rating);

  final count = b.seededReviewCount + liveCount;
  if (count == 0) return (count: 0, average: 0);

  final sum = b.seededRating * b.seededReviewCount + liveSum;
  return (count: count, average: sum / count);
}

RankingScore scoreBusiness(Business b) {
  final stats = reviewStats(b);

  // Bayesian average, so one perfect review cannot outrank a consistent record.
  final bayes =
      (RankingScore.kBayesPriorMean * 5 + stats.average * stats.count) /
      (5 + stats.count);

  final rating = (bayes - 1) / 4;

  final volume = math
      .min(
        1,
        math.log(1 + stats.count) / math.log(RankingScore.kVolumeSaturation),
      )
      .toDouble();

  final engagement = math
      .min(
        1,
        math.log(1 + b.engagement) /
            math.log(RankingScore.kEngagementSaturation),
      )
      .toDouble();

  final total =
      (100 *
              (RankingScore.kRatingWeight * rating +
                  RankingScore.kVolumeWeight * volume +
                  RankingScore.kEngagementWeight * engagement))
          .round();

  return RankingScore(
    rating: rating,
    volume: volume,
    engagement: engagement,
    total: total,
  );
}

/// Orders businesses by earned score. Ties break on review count, so a
/// tie doesn't produce a stable-but-arbitrary order between refreshes.
int compareByRank(Business a, Business b) {
  final byScore = scoreBusiness(b).total - scoreBusiness(a).total;
  if (byScore != 0) return byScore;
  return reviewStats(b).count - reviewStats(a).count;
}

/// Where a business sits among its own category. Shown to businesses as
/// "3rd of 12 in Food" — more honest than a global rank that would just
/// reward large categories.
({int position, int of}) rankWithinCategory(Business b, List<Business> all) {
  final same = all.where((x) => x.category == b.category).toList()
    ..sort(compareByRank);
  final index = same.indexWhere((x) => x.id == b.id);
  return (position: index + 1, of: same.length);
}

/// The Featured board.
///
/// Ten slots, and businesses rotate through them by least-recently-featured.
/// A business that held a slot last week waits six weeks before it can
/// return, so the ten premium subscribers on the island each see their turn
/// instead of the same names sitting on the board forever.
///
/// This is the one place in the app where the rotation is not strictly "top
/// by score" — a brand new premium subscriber needs a slot to justify the
/// price, and a score of zero puts them last. Score breaks ties within each
/// eligibility band.
List<Business> selectSpotlight({
  required List<Business> businesses,
  required int currentWeek,
  int slots = 10,
}) {
  final eligible = businesses.where((b) => b.tier.isVisible).toList()
    ..sort((a, b) {
      final byLastSeen = a.lastSpotlightWeek.compareTo(b.lastSpotlightWeek);
      if (byLastSeen != 0) return byLastSeen;
      return compareByRank(a, b);
    });

  return eligible.take(slots).toList(growable: false);
}

/// The 10 slots for the coming week, given who held them last week.
List<Business> advanceSpotlight({
  required List<Business> businesses,
  required List<Business> previousWeek,
  required int currentWeek,
  int slots = 10,
}) {
  final chosen = selectSpotlight(
    businesses: businesses,
    currentWeek: currentWeek,
    slots: slots,
  );
  // copyWith, not a hand-built constructor. The hand-built copy silently
  // dropped every field added after it was written — tags, socials, the
  // closed-today flag and createdAt — so a Spotlight business lost them.
  return chosen
      .map((b) => b.copyWith(isSpotlight: true, lastSpotlightWeek: currentWeek))
      .toList(growable: false);
}

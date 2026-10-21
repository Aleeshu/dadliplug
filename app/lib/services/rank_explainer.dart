import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/review.dart';
import 'package:antigua_business_map/services/ranking_service.dart';

/// One part of the ranking score, as an owner sees it.
class RankFactor {
  const RankFactor({
    required this.name,
    required this.weightPercent,
    required this.score,
    required this.explanation,
  });

  final String name;

  /// Its share of the total, as published in plan.md section 5.
  final int weightPercent;

  /// 0–1: how close this business is to full marks on it.
  final double score;
  final String explanation;
}

/// Why a business ranks where it does, and the single change most likely to
/// move it (plan.md Phase 7, "rank explainer").
///
/// The suggestion is computed, not guessed: each option is scored with the
/// real ranking function and the one that adds the most points wins. Nothing
/// here suggests anything rank cannot be bought with: a Featured plan buys the
/// Featured page, never a higher rank.
class RankExplanation {
  const RankExplanation({
    required this.position,
    required this.of,
    required this.total,
    required this.factors,
    required this.pointsToNext,
    required this.suggestion,
  });

  final int position;
  final int of;

  /// The 0–100 score.
  final int total;
  final List<RankFactor> factors;

  /// Points behind the business one place above, or null when first.
  final int? pointsToNext;
  final String suggestion;
}

RankExplanation explainRank(Business b, List<Business> all) {
  final place = rankWithinCategory(b, all);
  final score = scoreBusiness(b);
  final stats = reviewStats(b);

  final same = all.where((x) => x.category == b.category).toList()
    ..sort(compareByRank);
  final index = same.indexWhere((x) => x.id == b.id);
  final above = index > 0 ? same[index - 1] : null;
  final pointsToNext = above == null
      ? null
      : scoreBusiness(above).total - score.total;

  // What each realistic change would add, scored with the real formula.
  final fiveMoreReviews = scoreBusiness(_withExtraReviews(b, 5)).total;
  final moreActivity = scoreBusiness(
    b.copyWith(views: b.views + 300),
  ).total;
  final gains = <(int, String)>[
    (
      fiveMoreReviews - score.total,
      'Five more good reviews would add about '
          '${fiveMoreReviews - score.total} points. Show your visit QR at the '
          'till: customers who check in can review you.',
    ),
    (
      moreActivity - score.total,
      'About 300 more listing views would add about '
          '${moreActivity - score.total} points. A running advertisement or '
          'offer is what brings people to your listing.',
    ),
  ]..sort((x, y) => y.$1.compareTo(x.$1));

  final best = gains.first;
  final suggestion = best.$1 <= 0
      ? 'You are near full marks on every part. Keep your hours and offers '
            'current so customers keep coming back.'
      : best.$2;

  return RankExplanation(
    position: place.position,
    of: place.of,
    total: score.total,
    pointsToNext: pointsToNext,
    suggestion: suggestion,
    factors: [
      RankFactor(
        name: 'Rating',
        weightPercent: (RankingScore.kRatingWeight * 100).round(),
        score: score.rating,
        explanation: stats.count == 0
            ? 'No ratings yet. New listings start from an island-wide average.'
            : '${stats.average.toStringAsFixed(1)} stars from '
                  '${stats.count} ratings, adjusted so a few reviews cannot '
                  'swing it.',
      ),
      RankFactor(
        name: 'Number of reviews',
        weightPercent: (RankingScore.kVolumeWeight * 100).round(),
        score: score.volume,
        explanation:
            '${stats.count} so far. Full marks at about '
            '${RankingScore.kVolumeSaturation - 1}.',
      ),
      RankFactor(
        name: 'Customer activity',
        weightPercent: (RankingScore.kEngagementWeight * 100).round(),
        score: score.engagement,
        explanation:
            'Listing views, calls and WhatsApp taps, weighted toward calls '
            'and messages.',
      ),
    ],
  );
}

/// [b] as if [count] more five-star verified reviews had arrived.
Business _withExtraReviews(Business b, int count) => b.copyWith(
  reviews: [
    ...b.reviews,
    for (var i = 0; i < count; i++)
      Review(
        id: 'what-if-$i',
        businessId: b.id,
        userId: 'what-if',
        rating: 5,
        body: '',
        createdAt: DateTime.utc(2000),
        status: ReviewStatus.verified,
      ),
  ],
);

/// "1st", "2nd", "3rd", "4th"…
String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

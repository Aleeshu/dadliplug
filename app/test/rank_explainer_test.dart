import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/rank_explainer.dart';
import 'package:antigua_business_map/services/ranking_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Business business(
    String id, {
    BusinessCategory category = BusinessCategory.food,
    double rating = 0,
    int ratings = 0,
    int views = 0,
  }) => Business(
    id: id,
    name: id,
    category: category,
    tier: SubscriptionTier.basic,
    area: 'x',
    description: 'x',
    seededRating: rating,
    seededReviewCount: ratings,
    views: views,
  );

  test('position is within the category, not the whole island', () {
    final strong = business('strong', rating: 4.9, ratings: 50, views: 3000);
    final weak = business('weak', rating: 3.5, ratings: 3);
    final otherCategory = business(
      'salon',
      category: BusinessCategory.healthBeauty,
      rating: 5,
      ratings: 80,
      views: 5000,
    );
    final r = explainRank(weak, [strong, weak, otherCategory]);
    expect((r.position, r.of), (2, 2));
  });

  test('says how far behind the next place it is', () {
    final strong = business('strong', rating: 4.9, ratings: 50, views: 3000);
    final weak = business('weak', rating: 3.5, ratings: 3);
    final r = explainRank(weak, [strong, weak]);
    expect(
      r.pointsToNext,
      scoreBusiness(strong).total - scoreBusiness(weak).total,
    );
    expect(explainRank(strong, [strong, weak]).pointsToNext, isNull);
  });

  test('the factors are the published weights', () {
    final r = explainRank(business('a'), [business('a')]);
    expect(r.factors.map((f) => f.weightPercent), [45, 25, 30]);
  });

  test('a listing with few reviews is told to get reviews', () {
    // Five more reviews moves a 2-review listing far more than 300 views.
    final r = explainRank(
      business('a', rating: 4, ratings: 2, views: 2000),
      [business('a', rating: 4, ratings: 2, views: 2000)],
    );
    expect(r.suggestion, contains('reviews'));
  });

  test('a well-reviewed listing with no traffic is told to bring traffic', () {
    final r = explainRank(
      business('a', rating: 4.8, ratings: 60),
      [business('a', rating: 4.8, ratings: 60)],
    );
    expect(r.suggestion, contains('views'));
  });

  test('ordinals read naturally', () {
    expect(
      [1, 2, 3, 4, 11, 12, 13, 21, 22, 101].map(ordinal),
      [
        '1st',
        '2nd',
        '3rd',
        '4th',
        '11th',
        '12th',
        '13th',
        '21st',
        '22nd',
        '101st',
      ],
    );
  });
}

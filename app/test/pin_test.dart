import 'package:antigua_business_map/features/business_admin/pin_editor_screen.dart';
import 'package:antigua_business_map/features/map/island_ads_map.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const photo = 'https://example.com/boat.jpg';

  Business business(SubscriptionTier tier, {SubscriptionTier? plan}) =>
      Business(
        id: tier.name,
        name: tier.name,
        category: BusinessCategory.entertainment,
        tier: tier,
        plan: plan,
        area: 'x',
        description: 'x',
        latitude: 17.0,
        longitude: -61.8,
        pinImageUrl: photo,
      );

  group('who may move and customise the pin', () {
    test('Basic, Featured and trials may; Growing may not', () {
      expect(business(SubscriptionTier.basic).canCustomisePin, isTrue);
      expect(business(SubscriptionTier.featured).canCustomisePin, isTrue);
      expect(
        business(
          SubscriptionTier.trial,
          plan: SubscriptionTier.growing,
        ).canCustomisePin,
        isTrue,
      );
      expect(business(SubscriptionTier.growing).canCustomisePin, isFalse);
    });

    test('an overdue listing keeps what its plan allows during the hold', () {
      expect(
        business(
          SubscriptionTier.overdue,
          plan: SubscriptionTier.basic,
        ).canCustomisePin,
        isTrue,
      );
      expect(
        business(
          SubscriptionTier.overdue,
          plan: SubscriptionTier.growing,
        ).canCustomisePin,
        isFalse,
      );
    });
  });

  group('the map', () {
    test('draws the photo pin for Basic and above', () {
      final pin = IslandAdsMap.pinsFor([
        business(SubscriptionTier.featured),
      ], null).single;
      expect(pin.imageUrl, photo);
    });

    test(
      'a Growing listing shows the default pin even with a photo stored',
      () {
        // A Basic listing that lapsed to Growing keeps the column; the map
        // must stop showing it.
        final pin = IslandAdsMap.pinsFor([
          business(SubscriptionTier.growing),
        ], null).single;
        expect(pin.imageUrl, isNull);
      },
    );

    test('a photo pin is drawn separately from the category pin', () {
      final pins = IslandAdsMap.pinsFor([
        business(SubscriptionTier.basic),
        business(SubscriptionTier.growing),
      ], null);
      expect(pins[0].style, isNot(pins[1].style));
    });
  });

  test('a pin must land on Antigua or Barbuda', () {
    expect(isOnTheIslands(17.12, -61.85), isTrue); // St. John's
    expect(isOnTheIslands(17.63, -61.82), isTrue); // Codrington, Barbuda
    expect(isOnTheIslands(-61.85, 17.12), isFalse); // swapped
    expect(isOnTheIslands(18.2, -63.0), isFalse); // Anguilla
  });
}

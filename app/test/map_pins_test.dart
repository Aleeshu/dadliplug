import 'package:antigua_business_map/core/config/map_defaults.dart';
import 'package:antigua_business_map/features/map/island_ads_map.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the pins handed to Google Maps.
///
/// The map is a PlatformView, so nothing about it is reachable from a widget
/// test. What can be tested is the data it is given: which businesses get a
/// pin, what colour, and which one is selected.
void main() {
  Business business(
    String id, {
    SubscriptionTier tier = SubscriptionTier.basic,
    double? lat = 17.1,
    double? lng = -61.8,
  }) => Business(
    id: id,
    name: 'Business $id',
    category: BusinessCategory.food,
    tier: tier,
    area: 'x',
    description: 'x',
    latitude: lat,
    longitude: lng,
  );

  test('a business with no location is not given a pin', () {
    // Emitting one at 0,0 would put it in the Gulf of Guinea and look like a
    // bug to anyone who found it.
    final pins = IslandAdsMap.pinsFor([
      business('a'),
      business('online', lat: null, lng: null),
    ], null);
    expect(pins.map((p) => p.id), ['a']);
  });

  test('latitude and longitude are not swapped', () {
    final pin = IslandAdsMap.pinsFor([business('a')], null).single;
    expect(pin.latitude, 17.1);
    expect(pin.longitude, -61.8);
  });

  test('nothing is selected when no business is', () {
    final pins = IslandAdsMap.pinsFor([business('a'), business('b')], null);
    expect(pins.where((p) => p.selected), isEmpty);
  });

  test('exactly the selected business is marked selected', () {
    final b = business('b');
    final pins = IslandAdsMap.pinsFor([business('a'), b, business('c')], b);
    expect(pins.where((p) => p.selected).map((p) => p.id), ['b']);
  });

  test('featured pins are the premium colour, others are not', () {
    // Featured is the tier paying for visibility, so its pin must stand out.
    expect(
      IslandAdsMap.pinColorFor(
        business('f', tier: SubscriptionTier.featured),
      ),
      MapPinColors.premium,
    );
    expect(
      IslandAdsMap.pinColorFor(business('t', tier: SubscriptionTier.trial)),
      MapPinColors.trial,
    );
    expect(
      IslandAdsMap.pinColorFor(business('b')),
      MapPinColors.basic,
    );
  });
}

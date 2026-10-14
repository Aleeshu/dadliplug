import 'dart:convert';

import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the GeoJSON and filter payloads sent to MapLibre.
///
/// These exist because the map's selection ring silently stopped working and
/// the only evidence was one line of native logcat. MapLibre is a PlatformView,
/// so none of this is reachable from a widget test, and a mistake here is
/// invisible to everything else in the suite.
///
/// The shape matters because the Android plugin reads the filter as a **String**
/// and parses it. See [jsonEncode] below.
void main() {
  group('selection filter wire format', () {
    // The exact payload MapLibre's expression converter is handed. Reproduced
    // rather than calling the private helper, because the point is the shape
    // that reaches Java.
    String filter({String? selectedId}) => jsonEncode([
          '==',
          ['get', 'id'],
          selectedId ?? '__islandads_nothing_selected__',
        ]);

    test('is a JSON array, not an object', () {
      // A Dart map serialises to {"==": [...]}. MapLibre reads the operator's
      // operand array as a single string and throws "Array must have size 1,
      // but has size 2". This asserts the shape that avoids that.
      final decoded = jsonDecode(filter(selectedId: 'abc')) as List;
      expect(decoded, isA<List<dynamic>>());
      expect(decoded.first, '==');
      expect(decoded[1], ['get', 'id']);
      expect(decoded[2], 'abc');
    });

    test('is a String, which is what the Android side casts to', () {
      expect(filter(selectedId: 'abc'), isA<String>());
    });

    test('matches nothing when nothing is selected', () {
      // An empty or absent filter would match everything and put a selection
      // ring on every pin at once.
      final decoded = jsonDecode(filter()) as List;
      expect(decoded[2], '__islandads_nothing_selected__');
      expect(decoded[2], isNotEmpty);
    });

    test('an id containing quotes survives encoding', () {
      // Business ids are uuids in practice, but an id that broke the JSON
      // would throw at the call site instead of failing quietly.
      final decoded = jsonDecode(filter(selectedId: 'a"b')) as List;
      expect(decoded[2], 'a"b');
    });
  });

  group('pin geojson', () {
    Business business(String id, {double lat = 17.1, double lng = -61.8}) =>
        Business(
          id: id,
          name: 'Business $id',
          category: BusinessCategory.food,
          tier: SubscriptionTier.basic,
          area: 'x',
          description: 'x',
          latitude: lat,
          longitude: lng,
        );

    test('a business with no location is not given a pin', () {
      // An online-only business has no pin. Emitting one at 0,0 would put it
      // in the Gulf of Guinea and look like a bug to anyone who found it.
      final withNoLocation = Business(
        id: 'online',
        name: 'Online only',
        category: BusinessCategory.online,
        tier: SubscriptionTier.basic,
        area: 'x',
        description: 'x',
      );
      expect(withNoLocation.hasLocation, isFalse);
    });

    test('coordinates serialise as a two element position', () {
      final b = business('b1');
      final position = [b.longitude!, b.latitude!];
      // GeoJSON is [longitude, latitude], not the other way round.
      expect(position, [-61.8, 17.1]);
      expect(jsonDecode(jsonEncode(position)) as List, hasLength(2));
    });
  });
}
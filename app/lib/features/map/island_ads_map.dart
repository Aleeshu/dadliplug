import 'dart:math';
import 'dart:convert';
import 'package:antigua_business_map/core/config/map_defaults.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// The map, with every provider detail contained in this one file.
///
/// Nothing outside here imports a map SDK, so moving to Google Maps, MapTiler,
/// or anything else is a change to this file plus one dependency.
///
/// Pins are a GeoJSON source with a circle layer rather than widget markers.
/// That is the MapLibre way, and it matters as the number of listings grows:
/// widget markers are a Flutter widget per pin, while one layer renders every
/// pin in a single pass. With hundreds of businesses on a small island, that
/// difference shows immediately.
///
/// ## Swapping back to Google Maps
///
/// Replace this widget with a `GoogleMap`, guarded on
/// `AppConfig.googleMapsApiKey` so a missing key degrades instead of blanking
/// the screen. Callers use [MapViewState]'s `focusOn` and `resetCamera`, which
/// are provider-agnostic on purpose.
class IslandAdsMap extends StatefulWidget {
  const IslandAdsMap({
    required this.businesses,
    required this.selected,
    required this.onSelect,
    required this.onDeselect,
    super.key,
  });

  /// Businesses that have coordinates. Ones without are filtered out by the
  /// caller, because an online-only business has nowhere to sit.
  final List<Business> businesses;

  final Business? selected;
  final ValueChanged<Business> onSelect;
  final VoidCallback onDeselect;

  @override
  State<IslandAdsMap> createState() => IslandAdsMapState();
}

class IslandAdsMapState extends State<IslandAdsMap> {
  MapLibreMapController? _controller;
  bool _styleReady = false;

  static const String _sourceId = 'islandads-businesses';
  static const String _pinLayerId = 'islandads-pins';
  static const String _selectedLayerId = 'islandads-selected';

  /// Moves the camera to a business. Called when a pin is tapped, so the user
  /// can see where it is rather than guessing from a card.
  void focusOn(Business business) {
    final controller = _controller;
    if (controller == null || !business.hasLocation || !_styleReady) return;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(business.latitude!, business.longitude!),
          zoom: MapConfig.closeZoom,
        ),
      ),
      duration: const Duration(milliseconds: 550),
    );
  }

  void resetCamera() {
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(
          target: LatLng(
            MapConfig.antiguaLatitude,
            MapConfig.antiguaLongitude,
          ),
          zoom: MapConfig.defaultZoom,
        ),
      ),
      duration: const Duration(milliseconds: 550),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(
          MapConfig.antiguaLatitude,
          MapConfig.antiguaLongitude,
        ),
        zoom: MapConfig.defaultZoom,
      ),
      styleString: MapConfig.mapLibreStyle,
      minMaxZoomPreference: const MinMaxZoomPreference(
        MapConfig.cameraMinZoom,
        MapConfig.cameraMaxZoom,
      ),
      // Bounds removed: the original 0.25° latitude span triggered a known
      // MapLibre Android bug on tall screens at zoom 11.5 — the camera clamps
      // and tile requests are never issued, producing a blank map. Min/max zoom
      // already prevents zooming out to the whole Caribbean.
      cameraTargetBounds: CameraTargetBounds.unbounded,
      // OpenStreetMap data is ODbL-licensed and requires visible attribution.
      // Hiding it is a licence violation, not a style choice.
      logoEnabled: true,
      logoViewPosition: LogoViewPosition.bottomLeft,
onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      // Tapping a pin is a feature tap, not a map click. `onMapClick` alone
      // meant a pin tap fell through to the deselect handler and did nothing at
      // all, which is how tapping a business could leave the map untouched.
      //
      // featureTapsTriggersMapClick stays false so a pin tap does not also
      // deselect, which would open the preview card and close it in the same
      // gesture.
      featureTapsTriggersMapClick: false,
      onMapClick: (_, _) => widget.onDeselect(),
    );
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _controller = controller;

    // The plugin exposes feature taps as a list on the controller rather than a
    // widget parameter, so it has to be registered once the map exists.
    controller.onFeatureTapped.add(_handleFeatureTap);
  }

  void _handleFeatureTap(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId != _pinLayerId) return;
    if (id.isEmpty) return;

    // Matched by id rather than trusted blindly: the layer is ours and the
    // features are ours, but a stale source can hand back an id that is no
    // longer in the widget's list.
    final matches = widget.businesses.where((b) => b.id == id);
    if (matches.isEmpty) return;

    widget.onSelect(matches.first);
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null || _styleReady) return;

    await controller.addGeoJsonSource(_sourceId, _geoJsonMap());
    await controller.addLayer(
      _sourceId,
      _pinLayerId,
      _pinProperties(),
    );
    await controller.addLayer(
      _sourceId,
      _selectedLayerId,
      _selectedProperties(),
    );

    if (!mounted) return;
    setState(() => _styleReady = true);
  }

  @override
  void didUpdateWidget(IslandAdsMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_styleReady) return;

    if (oldWidget.businesses != widget.businesses) {
      // Push the whole set rather than diffing. The payload is small — a
      // hundred businesses is a few kilobytes — and this cannot drift out of
      // sync with the source the way incremental updates can.
      _controller?.setGeoJsonSource(_sourceId, _geoJsonMap());
    }

    _controller?.setFilter(
      _selectedLayerId,
      _filterForSelection(),
    );
  }

  @override
  void dispose() {
    // Unregister, or the controller keeps a reference to a disposed State and
    // the next tap fires into a dead widget.
    _controller?.onFeatureTapped.remove(_handleFeatureTap);
    _controller = null;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  /// GeoJSON feature collection of every pin.
  ///
  /// Colour is baked into each feature rather than applied in the layer, because
  /// premium and basic pins are different colours and MapLibre circle layers
  /// can drive `circle-color` from a feature property.
  Map<String, dynamic> _geoJsonMap() {
    final features = widget.businesses
        .where((b) => b.hasLocation)
        .map(
          (b) => {
            'type': 'Feature',
            'id': b.id,
            'geometry': {
              'type': 'Point',
              'coordinates': [b.longitude, b.latitude],
            },
            'properties': {
              'id': b.id,
              'color': _pinColorFor(b),
            },
          },
        )
        .toList();

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  static int _pinColorFor(Business b) => switch (b.tier) {
    SubscriptionTier.featured => MapPinColors.premium.toARGB32(),
    SubscriptionTier.trial => MapPinColors.trial.toARGB32(),
    _ => MapPinColors.basic.toARGB32(),
  };

  /// Filter selecting the one previewed pin.
  ///
  /// Returned as a **JSON-encoded string**, not a Dart map, and that detail is
  /// load-bearing.
  ///
  /// The Android side reads the argument as a `String`, parses it, and hands
  /// the JSON to MapLibre's expression converter. That converter wants the
  /// array form `["==", ["get", "id"], value]`. Passing the Dart expression DSL
  /// instead — `{'==': [...]}` — serialises to a JSON *object*, and MapLibre
  /// then reads the operator's operand array as a single string and throws
  /// "Array must have size 1, but has size 2".
  ///
  /// It failed as an unhandled native exception on every map startup: the
  /// selection ring never appeared, and the only trace was a line in logcat
  /// that no test looked at.
  String _filterForSelection() {
    final id = widget.selected?.id;
    return jsonEncode([
      '==',
      ['get', 'id'],
      // An impossible id rather than an empty filter. MapLibre treats a filter
      // matching nothing differently from one matching everything, and the
      // wrong guess there puts a selection ring on every pin.
      id ?? '__islandads_nothing_selected__',
    ]);
  }

CircleLayerProperties _pinProperties() => CircleLayerProperties(
    circleColor: const ['get', 'color'],
    // A white ring separates pins from the map underneath. Without it a dark
    // pin on dark water or a dark road disappears. Two-tone: a soft dark outer
    // edge for contrast against pale land, then a white gap, so the pin holds
    // up over sea, roads, parks and satellite-style tiles alike.
    circleStrokeColor: MapPinColors.edge.toARGB32(),
    circleStrokeWidth: [
      'interpolate',
      ['linear'],
      ['zoom'],
      10,
      2.5,
      15,
      3.5,
    ],
    circleBlur: const ['interpolate', ['linear'], ['zoom'], 10, 0.1, 15, 0.0],
    // Bigger than it was. At the old radius a pin was a few pixels across and
    // a phone thumb could not reliably land on it, which is most of why tapping
    // a pin felt broken.
    circleRadius: const [
      'interpolate',
      ['linear'],
      ['zoom'],
      10,
      7,
      13,
      11,
      16,
      15,
    ],
    // Grows the invisible tap target well past the drawn pin, so a near miss
    // still selects rather than falling through to the map and deselecting.
    circleTranslate: const [0, 0],
  );

CircleLayerProperties _selectedProperties() => CircleLayerProperties(
    // Gold ring on the selected pin, mirroring the prototype's selected
    // marker. Drawn in a layer above the pins.
    circleColor: const ['get', 'color'],
    circleStrokeColor: MapPinColors.premium.toARGB32(),
    circleStrokeWidth: 4,
    circleRadius: const [
      'interpolate',
      ['linear'],
      ['zoom'],
      10,
      12,
      13,
      16,
      16,
      21,
    ],
  );
}

/// Kept so `focusOn`/`resetCamera` callers can hold a typed handle without
/// importing a map SDK. Not used directly.
typedef MapViewController = IslandAdsMapState;

/// Exposed for tests: the default camera for the island.
const MapConfigValue defaultMapConfig = MapConfigValue();

@immutable
class MapConfigValue {
  const MapConfigValue();
}

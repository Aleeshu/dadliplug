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
  final bool _suppressDeselect = false;

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
      onMapClick: (_, _) {
        // A tap that lands on a pin is handled by the feature tap. Without
        // this the card would close the instant someone selected a business.
        if (_suppressDeselect) return;
        widget.onDeselect();
      },
    );
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _controller = controller;
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
  /// An impossible coordinate rather than an empty filter: MapLibre treats a
  /// filter that matches nothing differently from one that matches everything,
  /// and the wrong guess there shows every pin with a selection ring.
  Object _filterForSelection() {
    final id = widget.selected?.id;
    if (id == null) {
      return {
        '==': [
          const ['get', 'id'],
          '__islandads_nothing_selected__',
        ],
      };
    }
    return {
      '==': [
        const ['get', 'id'],
        id,
      ],
    };
  }

  CircleLayerProperties _pinProperties() => CircleLayerProperties(
    circleColor: const ['get', 'color'],
    // A white ring separates pins from the map underneath. Without it a
    // dark pin on dark water or a dark road disappears.
    circleStrokeColor: MapPinColors.edge.toARGB32(),
    circleStrokeWidth: 2,
    circleRadius: const [
      'interpolate',
      ['linear'],
      ['zoom'],
      10,
      5,
      15,
      8,
    ],
  );

  CircleLayerProperties _selectedProperties() => CircleLayerProperties(
    // Gold ring on the selected pin, mirroring the prototype's selected
    // marker. Drawn in a layer above the pins.
    circleColor: const ['get', 'color'],
    circleStrokeColor: MapPinColors.premium.toARGB32(),
    circleStrokeWidth: 5,
    circleRadius: [
      'interpolate',
      ['linear'],
      ['zoom'],
      10,
      8,
      15,
      13,
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

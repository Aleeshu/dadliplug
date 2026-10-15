import 'dart:async';
import 'dart:ui' as ui;

import 'package:antigua_business_map/core/config/map_defaults.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The map, with every provider detail contained in this one file.
///
/// Nothing outside here imports a map SDK. Callers use [IslandAdsMapState]'s
/// `focusOn` and `resetCamera`, which are provider-agnostic on purpose.
///
/// Pins are Google Maps markers with icons drawn once per colour, rather than
/// the default teardrop. The teardrop cannot show the tier colours, and a
/// featured business has to be findable at a glance.
///
/// The caller must not build this without a Maps key
/// (`AppConfig.hasGoogleMapsKey`). The Android SDK renders blank tiles with no
/// exception when the key is missing or rejected.
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

  /// The pins to draw, as plain data so it can be tested without a map.
  @visibleForTesting
  static List<MapPin> pinsFor(List<Business> businesses, Business? selected) =>
      [
        for (final b in businesses)
          if (b.hasLocation)
            MapPin(
              id: b.id,
              latitude: b.latitude!,
              longitude: b.longitude!,
              color: pinColorFor(b),
              selected: b.id == selected?.id,
            ),
      ];

  @visibleForTesting
  static Color pinColorFor(Business b) => switch (b.tier) {
    SubscriptionTier.featured => MapPinColors.premium,
    SubscriptionTier.trial => MapPinColors.trial,
    _ => MapPinColors.basic,
  };

  @override
  State<IslandAdsMap> createState() => IslandAdsMapState();
}

/// One pin, independent of any map SDK.
@immutable
class MapPin {
  const MapPin({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.color,
    required this.selected,
  });

  final String id;
  final double latitude;
  final double longitude;
  final Color color;
  final bool selected;
}

class IslandAdsMapState extends State<IslandAdsMap> {
  GoogleMapController? _controller;

  /// Drawn pin icons keyed by colour and selection. Empty until the first
  /// frame knows the device pixel ratio; markers use the default icon until
  /// then rather than waiting with no pins at all.
  final Map<(int, bool), BitmapDescriptor> _icons = {};
  double? _iconPixelRatio;

  static const _antigua = CameraPosition(
    target: LatLng(MapConfig.antiguaLatitude, MapConfig.antiguaLongitude),
    zoom: MapConfig.defaultZoom,
  );

  static const _cameraDuration = Duration(milliseconds: 550);

  /// Pin diameters in logical pixels. Big enough for a thumb to land on; at
  /// the old MapLibre radius a pin was a few pixels across and taps missed.
  static const double _pinSize = 26;
  static const double _selectedPinSize = 36;

  /// Moves the camera to a business. Called when a pin is tapped, so the user
  /// can see where it is rather than guessing from a card.
  void focusOn(Business business) {
    final controller = _controller;
    if (controller == null || !business.hasLocation) return;
    unawaited(
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(business.latitude!, business.longitude!),
            zoom: MapConfig.closeZoom,
          ),
        ),
        duration: _cameraDuration,
      ),
    );
  }

  void resetCamera() {
    final controller = _controller;
    if (controller == null) return;
    unawaited(
      controller.animateCamera(
        CameraUpdate.newCameraPosition(_antigua),
        duration: _cameraDuration,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ratio = MediaQuery.devicePixelRatioOf(context);
    if (ratio != _iconPixelRatio) {
      _iconPixelRatio = ratio;
      unawaited(_drawIcons(ratio));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: _antigua,
      minMaxZoomPreference: const MinMaxZoomPreference(
        MapConfig.cameraMinZoom,
        MapConfig.cameraMaxZoom,
      ),
      // Keeps users from wandering into empty ocean. This was removed under
      // MapLibre, whose Android build stopped requesting tiles when bounded on
      // tall screens; Google's SDK has no such bug.
      cameraTargetBounds: CameraTargetBounds(
        LatLngBounds(
          southwest: const LatLng(
            MapConfig.southWestLatitude,
            MapConfig.southWestLongitude,
          ),
          northeast: const LatLng(
            MapConfig.northEastLatitude,
            MapConfig.northEastLongitude,
          ),
        ),
      ),
      // The screen has its own recentre button and preview card. The SDK's
      // zoom buttons and directions toolbar would sit under them.
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      onMapCreated: (controller) => _controller = controller,
      // Marker taps do not reach onTap, so this only fires on the map itself.
      onTap: (_) => widget.onDeselect(),
      markers: _markers(),
    );
  }

  Set<Marker> _markers() => {
    for (final pin in IslandAdsMap.pinsFor(
      widget.businesses,
      widget.selected,
    ))
      Marker(
        markerId: MarkerId(pin.id),
        position: LatLng(pin.latitude, pin.longitude),
        icon:
            _icons[(pin.color.toARGB32(), pin.selected)] ??
            BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        // Without this the SDK pans to the pin and opens an empty info window,
        // fighting focusOn for the camera.
        consumeTapEvents: true,
        zIndexInt: pin.selected ? 1 : 0,
        onTap: () => _onPinTap(pin.id),
      ),
  };

  void _onPinTap(String id) {
    // Matched by id rather than captured: the marker set can be a frame behind
    // the widget's list, and a stale marker must not open a removed business.
    final matches = widget.businesses.where((b) => b.id == id);
    if (matches.isEmpty) return;
    widget.onSelect(matches.first);
  }

  Future<void> _drawIcons(double ratio) async {
    final colors = {
      MapPinColors.basic,
      MapPinColors.premium,
      MapPinColors.trial,
    };
    final icons = <(int, bool), BitmapDescriptor>{};
    for (final color in colors) {
      for (final selected in [false, true]) {
        icons[(color.toARGB32(), selected)] = await _drawPin(
          color,
          selected: selected,
          ratio: ratio,
        );
      }
    }
    if (!mounted || ratio != _iconPixelRatio) return;
    setState(() => _icons
      ..clear()
      ..addAll(icons));
  }

  /// A filled circle with a two-tone edge: a soft dark outer edge for contrast
  /// against pale land, then a white gap so the pin holds up over sea and
  /// roads. The selected pin is larger with a gold ring.
  static Future<BitmapDescriptor> _drawPin(
    Color fill, {
    required bool selected,
    required double ratio,
  }) async {
    final logical = selected ? _selectedPinSize : _pinSize;
    final px = (logical * ratio).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(px / 2, px / 2);
    final radius = px / 2;

    canvas
      ..drawCircle(
        center,
        radius,
        Paint()..color = selected ? MapPinColors.premium : MapPinColors.edge,
      )
      ..drawCircle(center, radius * 0.82, Paint()..color = Colors.white)
      ..drawCircle(center, radius * 0.66, Paint()..color = fill);

    final image = await recorder.endRecording().toImage(px, px);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: logical,
      height: logical,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}

import 'dart:async';
import 'dart:ui' as ui;

import 'package:antigua_business_map/core/config/map_defaults.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The map, with every provider detail contained in this one file.
///
/// Nothing outside here imports a map SDK. Callers use [IslandAdsMapState]'s
/// `focusOn` and `resetCamera`, which are provider-agnostic on purpose.
///
/// Pins are the Dadliplug design's: a red teardrop with the business's
/// category icon in white, so a restaurant reads as a restaurant before it is
/// tapped. Featured listings carry a gold ring so a paying Featured business
/// is still findable at a glance. Each style is drawn once and reused.
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
              category: b.category,
              featured: b.tier.holdsFeaturedSlot,
              selected: b.id == selected?.id,
            ),
      ];

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
    required this.category,
    required this.featured,
    required this.selected,
  });

  final String id;
  final double latitude;
  final double longitude;
  final BusinessCategory category;

  /// Holds a Featured slot: drawn with a gold ring.
  final bool featured;
  final bool selected;

  /// Which drawn icon this pin uses.
  PinStyle get style => (category, featured, selected);
}

/// Pins sharing a style share one drawn bitmap.
typedef PinStyle = (BusinessCategory, bool, bool);

class IslandAdsMapState extends State<IslandAdsMap> {
  GoogleMapController? _controller;
  Business? _pendingFocus;

  /// Drawn pin icons by style. Filled lazily for the styles on screen; a
  /// marker uses the default icon for the moment its style is being drawn,
  /// rather than the map waiting with no pins at all.
  final Map<PinStyle, BitmapDescriptor> _icons = {};
  final Set<PinStyle> _drawing = {};
  double? _iconPixelRatio;

  static const _antigua = CameraPosition(
    target: LatLng(MapConfig.antiguaLatitude, MapConfig.antiguaLongitude),
    zoom: MapConfig.defaultZoom,
  );

  static const _cameraDuration = Duration(milliseconds: 550);

  /// Pin widths in logical pixels; height is 1.3x. Big enough for a thumb to
  /// land on.
  static const double _pinWidth = 34;
  static const double _selectedPinWidth = 46;

  /// Moves the camera to a business. Called when a pin is tapped, so the user
  /// can see where it is rather than guessing from a card.
  void focusOn(Business business) {
    if (!business.hasLocation) return;
    final controller = _controller;
    if (controller == null) {
      // Asked before the native map is ready (opened from Get Directions):
      // move there as soon as it is.
      _pendingFocus = business;
      return;
    }
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
      _icons.clear();
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
      onMapCreated: (controller) {
        _controller = controller;
        final pending = _pendingFocus;
        _pendingFocus = null;
        if (pending != null) focusOn(pending);
      },
      // Marker taps do not reach onTap, so this only fires on the map itself.
      onTap: (_) => widget.onDeselect(),
      markers: _markers(),
    );
  }

  Set<Marker> _markers() {
    final pins = IslandAdsMap.pinsFor(widget.businesses, widget.selected);
    _ensureIcons(pins.map((p) => p.style));
    return {for (final pin in pins) _marker(pin)};
  }

  Marker _marker(MapPin pin) => Marker(
    markerId: MarkerId(pin.id),
    position: LatLng(pin.latitude, pin.longitude),
    icon: _icons[pin.style] ?? BitmapDescriptor.defaultMarker,
    // Without this the SDK pans to the pin and opens an empty info window,
    // fighting focusOn for the camera.
    consumeTapEvents: true,
    zIndexInt: pin.selected ? 1 : 0,
    onTap: () => _onPinTap(pin.id),
  );

  void _onPinTap(String id) {
    // Matched by id rather than captured: the marker set can be a frame behind
    // the widget's list, and a stale marker must not open a removed business.
    final matches = widget.businesses.where((b) => b.id == id);
    if (matches.isEmpty) return;
    widget.onSelect(matches.first);
  }

  void _ensureIcons(Iterable<PinStyle> styles) {
    final ratio = _iconPixelRatio;
    if (ratio == null) return;
    for (final style in styles.toSet()) {
      if (_icons.containsKey(style) || !_drawing.add(style)) continue;
      unawaited(
        _drawPin(style, ratio).then((icon) {
          _drawing.remove(style);
          if (!mounted || ratio != _iconPixelRatio) return;
          setState(() => _icons[style] = icon);
        }),
      );
    }
  }

  /// A red teardrop with a white edge and the category icon in white.
  static Future<BitmapDescriptor> _drawPin(PinStyle style, double ratio) async {
    final (category, featured, selected) = style;
    final logicalWidth = selected ? _selectedPinWidth : _pinWidth;
    final logicalHeight = logicalWidth * 1.3;
    final w = (logicalWidth * ratio).ceil();
    final h = (logicalHeight * ratio).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final edge = w * 0.06;
    final radius = w / 2 - edge;
    final center = Offset(w / 2, radius + edge);
    final tip = Offset(w / 2, h - edge);

    // Circle plus a wedge down to the tip: a teardrop.
    final drop = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..moveTo(center.dx - radius * 0.72, center.dy + radius * 0.7)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(center.dx + radius * 0.72, center.dy + radius * 0.7)
      ..close();

    canvas
      ..drawPath(
        drop,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = edge * 2
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(drop, Paint()..color = MapPinColors.premium);

    if (featured) {
      canvas.drawCircle(
        center,
        radius * 0.8,
        Paint()
          ..color = MapPinColors.trial
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.12,
      );
    }

    final icon = category.icon;
    final glyph = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: radius * 1.05,
          color: Colors.white,
        ),
      ),
    )..layout();
    glyph.paint(canvas, center - Offset(glyph.width / 2, glyph.height / 2));

    final image = await recorder.endRecording().toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: logicalWidth,
      height: logicalHeight,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}

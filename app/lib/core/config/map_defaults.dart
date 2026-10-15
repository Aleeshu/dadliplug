/// Map configuration, shared by [IslandAdsMap] and the screens around it.
///
/// The map is Google Maps. It was MapLibre on OpenFreeMap tiles until
/// 2026-10 to avoid needing a key; the key is now in `.env` and reaches
/// Android through the dart-defines (see `android/app/build.gradle.kts`).
library;

import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/features/map/island_ads_map.dart'
    show IslandAdsMap;
import 'package:flutter/material.dart';

abstract final class MapConfig {
  /// Antigua, centred so both main islands sit comfortably in view.
  static const double antiguaLatitude = 17.06;
  static const double antiguaLongitude = -61.7694;
  static const double defaultZoom = 11.5;
  static const double closeZoom = 15;

  /// Street level is as close as a listing needs.
  static const double minZoom = 10;
  static const double maxZoom = 18;

  /// Kept close to the default zoom, tighter than Google's own range.
  /// A small island does not benefit from being zoomed out to the Caribbean.
  static const double cameraMinZoom = 10;
  static const double cameraMaxZoom = 18;

  /// Bounds for panning. Keeps users from wandering into empty ocean.
  static const double southWestLatitude = 16.95;
  static const double southWestLongitude = -61.95;
  static const double northEastLatitude = 17.20;
  static const double northEastLongitude = -61.60;

  /// Zoom above which the Featured rail expands rather than peeking.
  /// Phase 5 behaviour, set here so the map and the rail agree.
  static const double featuredRailExpandZoom = 12.5;
}

/// Pin colours by subscription tier.
///
/// Mirrors the prototype: dark for a basic listing, Antigua's flag red for
/// premium, gold while a trial is running. Premium is the one business paying
/// for visibility, so it should be findable at a glance without opening
/// anything.
abstract final class MapPinColors {
  /// Colours for map pins.
  ///
  /// Taken from the light palette deliberately. A pin has to stay legible
  /// against a light map in both themes, so it does not follow the theme the
  /// way the surrounding UI does.
  static final Color basic = AppPalette.light.pin;
  static final Color premium = AppPalette.light.red;
  static final Color trial = AppPalette.light.trial;
  static final Color edge = AppPalette.light.pinEdge;
}

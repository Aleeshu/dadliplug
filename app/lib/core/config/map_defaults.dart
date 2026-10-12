/// Map configuration.
///
/// ## Why MapLibre and not Google Maps
///
/// Google Maps charges per API call once you pass roughly 28,000 a month, needs
/// a billing account before it will hand over a key, and — as we found — renders
/// an unexplained black screen when the key is missing or invalid. None of that
/// is acceptable for a project with no budget and no traffic yet.
///
/// [mapLibreStyle] points at OpenFreeMap: OpenStreetMap data on MapLibre's
/// open renderer. No API key, no signup, no billing account, no usage ceiling.
/// The trade is that the style is OpenStreetMap's rather than Google's, which is
/// a good deal for an island whose roads and beaches are what a visitor needs.
///
/// ## Swapping back to Google Maps
///
/// Add `google_maps_flutter`, put `AppConfig.googleMapsApiKey` behind a key
/// check so a missing key degrades instead of blanking, and replace
/// [IslandAdsMap] in `features/map/` with a `GoogleMap`. Nothing else in the app
/// touches a map SDK: camera positions, pin colours and the selected business
/// are all provider-agnostic.
library;

import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/features/map/island_ads_map.dart'
    show IslandAdsMap;
import 'package:flutter/material.dart';

abstract final class MapConfig {
  /// OpenFreeMap "Liberty" style. Vector tiles, no key required.
  ///
  /// Swap for `positron` (light, minimal) or `bright` if the liberty style
  /// reads too busy behind the listing cards.
  static const String mapLibreStyle =
      'https://tiles.openfreemap.org/styles/liberty';

  /// Antigua, centred so both main islands sit comfortably in view.
  static const double antiguaLatitude = 17.06;
  static const double antiguaLongitude = -61.7694;
  static const double defaultZoom = 11.5;
  static const double closeZoom = 15;

  /// Kept below MapLibre's max of 22 because the tileset runs out of detail
  /// well before that, and letting a user zoom into blank tiles looks broken.
  static const double minZoom = 10;
  static const double maxZoom = 18;

  /// Kept close to the default zoom, unlike Google's more permissive range.
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

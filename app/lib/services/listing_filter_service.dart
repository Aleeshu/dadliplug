import 'dart:math' as math;

import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:antigua_business_map/services/ranking_service.dart';

/// Listing filtering, ported from the prototype's `filt()`.
///
/// The `openNow` filter is the one that decides whether a user drives across
/// the island, so it is a first-class filter rather than a sort option.
class ListingQuery {
  const ListingQuery({
    this.categories = const {},
    this.openNowOnly = false,
    this.search = '',
    this.sort = ListingSort.ranked,
  });

  final Set<BusinessCategory> categories;
  final bool openNowOnly;
  final String search;
  final ListingSort sort;

  ListingQuery copyWith({
    Set<BusinessCategory>? categories,
    bool? openNowOnly,
    String? search,
    ListingSort? sort,
  }) => ListingQuery(
    categories: categories ?? this.categories,
    openNowOnly: openNowOnly ?? this.openNowOnly,
    search: search ?? this.search,
    sort: sort ?? this.sort,
  );

  bool get isFiltering =>
      categories.isNotEmpty || openNowOnly || search.trim().isNotEmpty;
}

enum ListingSort {
  /// Earned score, highest first. The default, and the honest one.
  ranked,

  /// Rating, breaking ties on review count.
  topRated,

  name,

  /// Closest to the viewer first. Needs the viewer's location, which is used
  /// for this sort and never stored (plan.md section 12). Without one, falls
  /// back to [ranked] rather than guessing a position.
  nearest,
}

/// A point on the map. Used for the viewer's position, which is held only
/// while the screen that asked for it is open.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// Great-circle distance in kilometres.
///
/// Haversine. At island scale the error against an ellipsoid is metres, far
/// below what coarse location can resolve anyway.
double distanceKm(GeoPoint a, GeoPoint b) {
  const earthRadiusKm = 6371.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.sqrt(h));
}

/// Distance from [origin] to a business, or null when it has no location.
double? distanceTo(Business b, GeoPoint origin) => b.hasLocation
    ? distanceKm(origin, GeoPoint(b.latitude!, b.longitude!))
    : null;

/// Featured page contents: businesses holding a Featured slot, in earned
/// order. Never ordered by price or by who signed up first (plan.md 3).
List<Business> featuredBusinesses(List<Business> businesses) =>
    businesses
        .where((b) => b.tier.isVisible && b.tier.holdsFeaturedSlot)
        .toList()
      ..sort(compareByRank);

class ListingFilter {
  /// Whether a business passes the query, ignoring sort.
  static bool matches(Business b, ListingQuery q) {
    if (!b.tier.isVisible) return false;

    if (q.categories.isNotEmpty && !q.categories.contains(b.category)) {
      return false;
    }

    if (q.openNowOnly && !openInfo(b).isOpen) return false;

    final term = q.search.trim().toLowerCase();
    if (term.isNotEmpty && !_haystack(b).contains(term)) return false;

    return true;
  }

  /// Filter, then sort.
  ///
  /// [origin] is the viewer's position, needed only for
  /// [ListingSort.nearest].
  static List<Business> apply(
    List<Business> businesses,
    ListingQuery q, {
    GeoPoint? origin,
  }) {
    final results = businesses.where((b) => matches(b, q)).toList();

    switch (q.sort) {
      case ListingSort.nearest when origin != null:
        // Online-only businesses have no distance. They go last, in earned
        // order, rather than being dropped: they are still valid results.
        results.sort((a, b) {
          final da = distanceTo(a, origin);
          final db = distanceTo(b, origin);
          if (da == null && db == null) return compareByRank(a, b);
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
      case ListingSort.ranked || ListingSort.nearest:
        results.sort(compareByRank);
      case ListingSort.topRated:
        results.sort((a, b) {
          final ra = reviewStats(a);
          final rb = reviewStats(b);
          final byRating = rb.average.compareTo(ra.average);
          if (byRating != 0) return byRating;
          return rb.count.compareTo(ra.count);
        });
      case ListingSort.name:
        results.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }

    return results;
  }

  /// Matches on the same fields as the prototype's prototype: name, category,
  /// area, description, and menu items. Menu text matters more than it looks —
  /// somebody looking for "seafood" should find the restaurant that lists it.
  static String _haystack(Business b) => [
    b.name,
    b.category.label,
    b.area,
    b.description,
    ...b.menu.map((m) => '${m.name ?? ''} ${m.detail ?? ''}'),
  ].join(' ').toLowerCase();
}

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
}

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
  static List<Business> apply(List<Business> businesses, ListingQuery q) {
    final results = businesses.where((b) => matches(b, q)).toList();

    switch (q.sort) {
      case ListingSort.ranked:
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

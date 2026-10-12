/// Industry categories.
///
/// Exactly the eight from the prototype, with the same hues. Hues drive the
/// category icon tiles and pin tints, so a business's industry is recognisable
/// from the map before you read a single word.
///
/// The prototype's set is deliberately coarser than a full taxonomy. That is
/// the right call for a first release: eight filters is already a lot for a
/// phone screen, and businesses can be listed under the nearest match rather
/// than forcing a category they don't fit. New categories are a cheap addition
/// — add an entry here and the filter chip appears.
library;

enum BusinessCategory {
  food,
  beauty,
  trades,
  medical,
  tourism,
  retail,
  professional,
  online,
}

extension BusinessCategoryX on BusinessCategory {
  /// Full name, used in listings and as the search haystack.
  String get label => switch (this) {
    BusinessCategory.food => 'Food & drink',
    BusinessCategory.beauty => 'Salons & beauty',
    BusinessCategory.trades => 'Trades',
    BusinessCategory.medical => 'Medical',
    BusinessCategory.tourism => 'Tourism',
    BusinessCategory.retail => 'Retail',
    BusinessCategory.professional => 'Professional',
    BusinessCategory.online => 'Online-only',
  };

  /// Chip label on the map filter bar. Kept short so eight of them fit in a
  /// horizontally scrolling row without truncating.
  String get shortLabel => switch (this) {
    BusinessCategory.food => 'Food',
    BusinessCategory.beauty => 'Beauty',
    BusinessCategory.trades => 'Trades',
    BusinessCategory.medical => 'Medical',
    BusinessCategory.tourism => 'Tours',
    BusinessCategory.retail => 'Retail',
    BusinessCategory.professional => 'Pro',
    BusinessCategory.online => 'Online',
  };

  /// Icon tile hue from the prototype. Feeds the gradient placeholder used
  /// until a business uploads real photos.
  int get hue => switch (this) {
    BusinessCategory.food => 18,
    BusinessCategory.beauty => 330,
    BusinessCategory.trades => 42,
    BusinessCategory.medical => 165,
    BusinessCategory.tourism => 200,
    BusinessCategory.retail => 272,
    BusinessCategory.professional => 222,
    BusinessCategory.online => 95,
  };

  /// Online-only businesses have no walk-in location. They are filtered out of
  /// the map view and appear in list results only, since there is nothing
  /// meaningful to place on the map.
  bool get isMapLess => this == BusinessCategory.online;

  /// Map pin tint, as a HSL hue for `BitmapDescriptor.defaultMarkerWithHue`.
  double get pinHue => hue.toDouble();

  static BusinessCategory fromName(String name) => BusinessCategory.values
      .firstWhere((c) => c.name == name, orElse: () => BusinessCategory.food);

  /// Storage-safe form. Enum names are already lowercase.
  static List<BusinessCategory> get all => BusinessCategory.values;
}

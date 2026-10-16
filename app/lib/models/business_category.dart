/// Industry categories.
///
/// The nine from the Dadliplug design (2026-10-15), replacing the prototype's
/// eight. Existing listings were mapped across in migration
/// `20261015120000_design_categories.sql`; the database stores `dbName`.
///
/// Each category has its own colour and icon, used for the category circles,
/// list placeholders and map pins, so an industry is recognisable before you
/// read a word.
///
/// There is no "online-only" category any more. A business with no walk-in
/// location is simply one with no coordinates: it has no map pin and is kept
/// off the leaderboards, whatever its category.
library;

import 'package:flutter/material.dart';

enum BusinessCategory {
  food,
  shopping,
  services,
  healthBeauty,
  entertainment,
  automotive,
  realEstate,
  education,
  other,
}

extension BusinessCategoryX on BusinessCategory {
  /// Full name, used in listings and as the search haystack.
  String get label => switch (this) {
    BusinessCategory.food => 'Food & Drink',
    BusinessCategory.shopping => 'Shopping',
    BusinessCategory.services => 'Services',
    BusinessCategory.healthBeauty => 'Health & Beauty',
    BusinessCategory.entertainment => 'Entertainment',
    BusinessCategory.automotive => 'Automotive',
    BusinessCategory.realEstate => 'Real Estate',
    BusinessCategory.education => 'Education',
    BusinessCategory.other => 'Other',
  };

  /// Chip label. Kept short so a row of them scrolls without truncating.
  String get shortLabel => switch (this) {
    BusinessCategory.food => 'Food',
    BusinessCategory.shopping => 'Shopping',
    BusinessCategory.services => 'Services',
    BusinessCategory.healthBeauty => 'Beauty',
    BusinessCategory.entertainment => 'Fun',
    BusinessCategory.automotive => 'Auto',
    BusinessCategory.realEstate => 'Property',
    BusinessCategory.education => 'Education',
    BusinessCategory.other => 'Other',
  };

  /// What belongs here, shown under the name on the Categories screen.
  String get examples => switch (this) {
    BusinessCategory.food => 'Restaurants, Cafés, Bars, Takeaway',
    BusinessCategory.shopping => 'Clothing, Electronics, Home & More',
    BusinessCategory.services => 'Repairs, Cleaning, Trades, Professional',
    BusinessCategory.healthBeauty => 'Salons, Spas, Fitness, Healthcare',
    BusinessCategory.entertainment => 'Events, Tours, Activities, Nightlife',
    BusinessCategory.automotive => 'Repairs, Parts, Rentals',
    BusinessCategory.realEstate => 'Rentals, Sales, Property Services',
    BusinessCategory.education => 'Schools, Training, Courses',
    BusinessCategory.other => 'Online and everything else',
  };

  IconData get icon => switch (this) {
    BusinessCategory.food => Icons.restaurant,
    BusinessCategory.shopping => Icons.shopping_bag,
    BusinessCategory.services => Icons.build,
    BusinessCategory.healthBeauty => Icons.spa,
    BusinessCategory.entertainment => Icons.local_activity,
    BusinessCategory.automotive => Icons.directions_car,
    BusinessCategory.realEstate => Icons.home_work,
    BusinessCategory.education => Icons.school,
    BusinessCategory.other => Icons.mail,
  };

  /// The category's colour, from the design. Used for the icon circle, list
  /// placeholders and pins.
  Color get color => switch (this) {
    BusinessCategory.food => const Color(0xFFE8253F),
    BusinessCategory.shopping => const Color(0xFFF59E0B),
    BusinessCategory.services => const Color(0xFF2E7CF6),
    BusinessCategory.healthBeauty => const Color(0xFF8B5CF6),
    BusinessCategory.entertainment => const Color(0xFFEC4899),
    BusinessCategory.automotive => const Color(0xFF2563EB),
    BusinessCategory.realEstate => const Color(0xFF16A34A),
    BusinessCategory.education => const Color(0xFF7C3AED),
    BusinessCategory.other => const Color(0xFFDB2777),
  };

  /// Hue of [color], for the gradient placeholder shown until a business
  /// uploads real photos.
  int get hue => HSLColor.fromColor(color).hue.round();

  /// The value stored in `businesses.category`.
  String get dbName => switch (this) {
    BusinessCategory.healthBeauty => 'health_beauty',
    BusinessCategory.realEstate => 'real_estate',
    _ => name,
  };

  /// Parses a stored category. Accepts [dbName] or the enum name. Anything
  /// unrecognised is "Other", never a guess at a real category: a listing
  /// filed under the wrong industry is worse than one filed under none.
  static BusinessCategory fromName(String raw) {
    final normalised = raw
        .replaceAll('_', '')
        .replaceAll(' ', '')
        .toLowerCase();
    for (final c in BusinessCategory.values) {
      if (c.name.toLowerCase() == normalised) return c;
    }
    return BusinessCategory.other;
  }

  static List<BusinessCategory> get all => BusinessCategory.values;
}

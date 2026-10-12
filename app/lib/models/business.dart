import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/models/review.dart';

/// How a business pays us.
enum SubscriptionTier {
  /// $50/mo — map pin and listing
  basic,

  /// $100/mo — everything in basic plus a Featured slot
  premium,

  /// 3-day trial. Does not convert, so the listing is removed.
  trial,

  /// Grace period: paid, then lapsed. Listing still up, business sees a
  /// warning in their dashboard.
  overdue,

  /// Not paying. Kept in the database for history, hidden in the app.
  delisted,
}

extension SubscriptionTierX on SubscriptionTier {
  String get label => switch (this) {
    SubscriptionTier.basic => 'Basic',
    SubscriptionTier.premium => 'Premium',
    SubscriptionTier.trial => 'Trial',
    SubscriptionTier.overdue => 'Overdue',
    SubscriptionTier.delisted => 'Delisted',
  };

  /// What the business pays per month.
  int get monthlyPrice => this == SubscriptionTier.premium ? 100 : 50;

  /// Premium buys the Featured slot. Trial gets one too — a business needs to
  /// see what they are paying for during the three days.
  bool get holdsFeaturedSlot =>
      this == SubscriptionTier.premium || this == SubscriptionTier.trial;

  /// Whether a listing in this state appears in the app at all. Overdue does,
  /// because we warn before we delist.
  bool get isVisible => this != SubscriptionTier.delisted;

  static SubscriptionTier fromName(String name) =>
      SubscriptionTier.values.firstWhere(
        (t) => t.name == name,
        orElse: () => SubscriptionTier.delisted,
      );
}

/// Opening hours, as the prototype models them: a set of weekdays plus one
/// open and close time for the whole week. Most Antigua businesses don't vary
/// hours by day, so this is a simpler and more honest model than a per-day
/// schedule. If a business genuinely needs per-day hours, the shape grows
/// rather than the whole model being replaced.
class OpeningHours {
  const OpeningHours({
    this.days = const {},
    this.opensAt = 9,
    this.closesAt = 17,
  });

  /// `DateTime.sunday` (7) through `DateTime.saturday` (6).
  final Set<int> days;

  /// Fractional hours. 9.5 is 9:30am. Lets us handle open-until-midnight and
  /// 24-hour businesses without special cases.
  final double opensAt;
  final double closesAt;

  bool get is24Hours => days.length == 7 && opensAt == 0 && closesAt == 24;

  bool get isNever => days.isEmpty;

  /// Whether open at the given moment. `[now]` is expected in Antigua time,
  /// not device time — see `AntiguaClock`.
  bool isOpenAt(DateTime now) {
    if (isNever) return false;
    if (is24Hours) return true;
    if (!days.contains(now.weekday)) return false;

    final t = now.hour + now.minute / 60;
    if (opensAt <= closesAt) return t >= opensAt && t < closesAt;
    // Closes after midnight, e.g. a bar open 18:00-02:00.
    return t >= opensAt || t < closesAt;
  }

  /// The next day it opens, scanning forward from today. Null if it never
  /// opens. Drives the "Closed, opens Fri 6pm" label.
  int? nextOpenDay(int todayWeekday) {
    for (var i = 1; i <= 7; i++) {
      final d = (todayWeekday + i) % 7;
      if (days.contains(d)) return d;
    }
    return null;
  }

  /// "Daily", "Mon–Fri", "Tue, Thu, Sat". Compressed runs, matching the
  /// prototype's `daysLabel`.
  String get label => _compressDays(days);

  static String _compressDays(Set<int> days) {
    if (days.length == 7) return 'Daily';
    if (days.isEmpty) return 'Closed';

    // Sunday-first, to match DateTime.weekday where Sunday is 7.
    final active = <String>[
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
    ].map((n) => days.contains(_weekdayFor(n)) ? n : '').toList();

    final runs = <String>[];
    var i = 0;
    while (i < 7) {
      if (active[i].isEmpty) {
        i++;
        continue;
      }
      var j = i;
      while (j + 1 < 7 && active[j + 1].isNotEmpty) {
        j++;
      }
      runs.add(i == j ? active[i] : '${active[i]}–${active[j]}');
      i = j + 1;
    }
    return runs.isEmpty ? 'Closed' : runs.join(', ');
  }

  static int _weekdayFor(String name) => switch (name) {
    'Sun' => 7,
    'Mon' => 1,
    'Tue' => 2,
    'Wed' => 3,
    'Thu' => 4,
    'Fri' => 5,
    _ => 6,
  };
}

/// A place on the map.
class Business {
  const Business({
    required this.id,
    required this.name,
    required this.category,
    required this.tier,
    required this.area,
    required this.description,
    this.hours = const OpeningHours(),
    this.photos = const [],
    this.menu = const [],
    this.phone,
    this.whatsapp,
    this.website,
    this.address,
    this.latitude,
    this.longitude,
    this.priceRange,
    this.offer,
    this.acceptsReviews = true,
    this.isSpotlight = false,
    this.lastSpotlightWeek = -1,
    this.seededRating = 0,
    this.seededReviewCount = 0,
    this.reviews = const [],
    this.views = 0,
    this.calls = 0,
    this.whatsappTaps = 0,
    this.howToFindUs,
    this.tags = const [],
    this.isClosedToday = false,
    this.lastVerifiedAt,
  });

  final String id;
  final String name;
  final BusinessCategory category;
  final SubscriptionTier tier;

  /// Neighbourhood or area of Antigua, e.g. "Dickenson Bay". Used in search
  /// and shown under the business name.
  final String area;

  final String description;
  final OpeningHours hours;
  final List<BusinessPhoto> photos;

  /// Menu for food, service list for everything else. One list, since the
  /// display is identical — name, detail, price.
  final List<MenuItem> menu;

  final String? phone;
  final String? whatsapp;
  final String? website;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? priceRange;

  /// Promotional deal text. A paid premium feature and the reason a business
  /// hands over their actual offer rather than a vague "special available".
  final String? offer;

  /// A business can opt out of reviews entirely. Paying customers ask for it.
  final bool acceptsReviews;

  final bool isSpotlight;

  /// Week index this business last held a Spotlight slot. Lowest value is
  /// served first, so the ten slots rotate and everyone gets a turn.
  final int lastSpotlightWeek;

  /// Ratings that arrived before the app, imported so a new listing is not
  /// shown as "0 reviews". Seeded, never editable by the business.
  final double seededRating;
  final int seededReviewCount;

  /// Live reviews. Denormalised onto the business document so the rating and
  /// count render without a second query — a listing screen needs them
  /// immediately, and on a small island the network is often slow.
  final List<Review> reviews;

  final int views;
  final int calls;
  final int whatsappTaps;

  /// Free-text landmark directions, e.g. "Past the roundabout, opposite the market".
  /// Island addresses are rarely standard street addresses.
  final String? howToFindUs;

  /// Practical tags e.g. 'cash_only', 'accepts_cards', 'accepts_usd', 'parking'.
  final List<String> tags;

  /// Emergency 1-tap temporary closure (hurricane season, Carnival, holidays).
  final bool isClosedToday;

  /// Timestamp when the listing details were last verified by team or owner.
  final DateTime? lastVerifiedAt;

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasOffer => offer != null && offer!.isNotEmpty;
  bool get isPremium => tier == SubscriptionTier.premium;

  /// Engagement weighted toward intent. A tap is a stronger signal than a
  /// view, and a call stronger still.
  int get engagement => views + 5 * (calls + whatsappTaps);

  int get totalReviewCount => seededReviewCount + visibleReviews.length;

  List<Review> get visibleReviews =>
      reviews.where((r) => r.isVisible).toList(growable: false);

  Business copyWith({
    String? id,
    String? name,
    BusinessCategory? category,
    SubscriptionTier? tier,
    String? area,
    String? description,
    OpeningHours? hours,
    List<BusinessPhoto>? photos,
    List<MenuItem>? menu,
    String? phone,
    String? whatsapp,
    String? website,
    String? address,
    double? latitude,
    double? longitude,
    String? priceRange,
    String? offer,
    bool? acceptsReviews,
    bool? isSpotlight,
    int? lastSpotlightWeek,
    double? seededRating,
    int? seededReviewCount,
    List<Review>? reviews,
    int? views,
    int? calls,
    int? whatsappTaps,
    String? howToFindUs,
    List<String>? tags,
    bool? isClosedToday,
    DateTime? lastVerifiedAt,
  }) => Business(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    tier: tier ?? this.tier,
    area: area ?? this.area,
    description: description ?? this.description,
    hours: hours ?? this.hours,
    photos: photos ?? this.photos,
    menu: menu ?? this.menu,
    phone: phone ?? this.phone,
    whatsapp: whatsapp ?? this.whatsapp,
    website: website ?? this.website,
    address: address ?? this.address,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    priceRange: priceRange ?? this.priceRange,
    offer: offer ?? this.offer,
    acceptsReviews: acceptsReviews ?? this.acceptsReviews,
    isSpotlight: isSpotlight ?? this.isSpotlight,
    lastSpotlightWeek: lastSpotlightWeek ?? this.lastSpotlightWeek,
    seededRating: seededRating ?? this.seededRating,
    seededReviewCount: seededReviewCount ?? this.seededReviewCount,
    reviews: reviews ?? this.reviews,
    views: views ?? this.views,
    calls: calls ?? this.calls,
    whatsappTaps: whatsappTaps ?? this.whatsappTaps,
    howToFindUs: howToFindUs ?? this.howToFindUs,
    tags: tags ?? this.tags,
    isClosedToday: isClosedToday ?? this.isClosedToday,
    lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
  );
}

/// Known practical amenity tags for Antigua businesses.
abstract final class KnownBusinessTags {
  static const String cashOnly = 'cash_only';
  static const String acceptsCards = 'accepts_cards';
  static const String acceptsUsd = 'accepts_usd';
  static const String parking = 'parking';
  static const String accessibility = 'accessibility';
  static const String familyFriendly = 'family_friendly';
  static const String wifi = 'wifi';
  static const String outdoorSeating = 'outdoor_seating';

  static const List<String> all = [
    cashOnly,
    acceptsCards,
    acceptsUsd,
    parking,
    accessibility,
    familyFriendly,
    wifi,
    outdoorSeating,
  ];

  static String labelFor(String tag) => switch (tag) {
    cashOnly => 'Cash only',
    acceptsCards => 'Accepts cards',
    acceptsUsd => r'Accepts US$',
    parking => 'Parking on site',
    accessibility => 'Wheelchair access',
    familyFriendly => 'Family-friendly',
    wifi => 'Free Wi-Fi',
    outdoorSeating => 'Outdoor seating',
    _ => tag,
  };
}

/// Business content is tracked in the prototype as `menu` (array of
/// `[name, detail, price]`).
class MenuItem {
  const MenuItem({this.name, this.detail, this.price});

  final String? name;
  final String? detail;
  final String? price;

  Map<String, dynamic> toMap() => {
    if (name != null) 'name': name,
    if (detail != null) 'detail': detail,
    if (price != null) 'price': price,
  };
}

class BusinessPhoto {
  const BusinessPhoto({this.url, this.caption});

  final String? url;
  final String? caption;

  Map<String, dynamic> toMap() => {
    if (url != null) 'url': url,
    if (caption != null) 'caption': caption,
  };
}

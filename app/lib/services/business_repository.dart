import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Raised when the listings query fails.
///
/// Exists so the UI can distinguish "no businesses yet" from "we could not
/// reach the database". Collapsing the two is how a broken backend ends up
/// looking like a successful empty state.
class ListingsUnavailable implements Exception {
  const ListingsUnavailable(this.cause);

  final Object cause;

  @override
  String toString() => 'ListingsUnavailable: $cause';
}

/// Contract for fetching and observing business listings.
abstract interface class BusinessRepository {
  /// Stream of listings. Emits an empty list when there are none, and throws
  /// [ListingsUnavailable] when the backend cannot be reached.
  Stream<List<Business>> watchBusinesses();

  /// One-off fetch. Same empty-versus-error contract as [watchBusinesses].
  Future<List<Business>> getBusinesses();

  /// A single business by id, or null if there is none.
  Future<Business?> getBusinessById(String id);

  /// Saves editable fields of an existing listing.
  ///
  /// Writes a whitelist rather than the whole model. Round-tripping an entire
  /// `Business` back to the database would let a stale client overwrite
  /// subscription status, ranking counters, or the featured-slot week — fields
  /// the client must never set. Tier and subscription state change only when
  /// the team records a payment.
  Future<void> updateBusiness(Business business);

  /// Marks a listing closed for today, or reopens it.
  ///
  /// The most time-sensitive control in the app. A hurricane closure still
  /// showing "Open 9am–5pm" sends someone across the island for nothing, which
  /// is the fastest way to lose a paying customer.
  Future<void> toggleClosedToday(String businessId, {required bool isClosed});

  /// Flags a listing as wrong. Any user, no account required.
  ///
  /// The safety net under the pitch that the team keeps listings accurate.
  Future<void> reportWrongInfo({
    required String businessId,
    required String reason,
    String details = '',
  });
}

/// Team-only listing operations: creating a listing and setting what it pays.
///
/// Kept apart from [BusinessRepository] because only the team does these, and
/// the database enforces that (`businesses_insert_team`, and the field guard in
/// `20261014120000`). Owners editing their own listing never touch this.
abstract interface class ListingAdminRepository {
  /// Every listing the caller administers, delisted ones included.
  ///
  /// The public list drops delisted rows, which is right for customers and
  /// wrong for the team: a lapsed listing is exactly the one they need to find.
  Future<List<Business>> getAllListings();

  /// Creates a listing and returns its id.
  Future<String> createBusiness(Business business);

  /// Records which plan a listing is on, as `subscription_status` and `tier`
  /// together so the two can never disagree.
  Future<void> setSubscription(String businessId, SubscriptionTier tier);
}

/// Supabase implementation of [BusinessRepository].
///
/// Reads `public.businesses`. Row Level Security already hides delisted
/// listings from users, so this does not filter on them again.
///
/// **No fallback data.** If the query returns nothing, the caller gets nothing.
/// The database is empty until the team adds real businesses, and the app says
/// so. Inventing listings — even obviously placeholder ones — risks a real
/// person's number being called, or a business being shown a rating nobody
/// gave it, in an app whose entire pitch is that the information is accurate.
class SupabaseBusinessRepository
    implements BusinessRepository, ListingAdminRepository {
  SupabaseBusinessRepository({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _require {
    final client = _client;
    if (client != null) return client;
    // A build with no credentials must fail loudly, not quietly show nothing.
    // But it must also say *why*. Reaching for `Supabase.instance` here raises
    // a bare `_isInitialized` assertion from deep inside the SDK, which reaches
    // the user as an unexplained "Could not load businesses" and costs hours to
    // trace back to a missing dart-define.
    if (!AppConfig.supabaseConfigured) {
      throw const BackendNotConfigured();
    }
    return Supabase.instance.client;
  }

  @override
  Stream<List<Business>> watchBusinesses() async* {
    // Realtime is a nice-to-have, not a requirement. On a phone in Antigua the
    // WebSocket that carries live updates is the first thing to drop, and a
    // dropped stream must not mean an empty map — someone on a weak
    // connection still needs to see the listings that exist.
    //
    // So: follow the live stream, and if it ever errors, do one plain fetch
    // instead. If that fails too the error propagates, because a genuinely
    // unreachable database must not be mistaken for an island with no
    // businesses.
    try {
      await for (final rows
          in _require.from('businesses').stream(primaryKey: ['id'])) {
        yield _visible(rows);
      }
    } catch (error) {
      debugPrint('Live listings stopped ($error). Trying a one-off fetch.');
      yield await getBusinesses();
    }
  }

  @override
  Future<List<Business>> getBusinesses() async {
    try {
      final rows = await _require.from('businesses').select().order('name');
      return _visible(rows);
    } catch (error) {
      debugPrint('Could not load businesses: $error');
      throw ListingsUnavailable(error);
    }
  }

  @override
  Future<Business?> getBusinessById(String id) async {
    try {
      final row = await _require
          .from('businesses')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return _fromMap(row);
    } catch (error) {
      throw ListingsUnavailable(error);
    }
  }

  @override
  Future<void> updateBusiness(Business business) async {
    try {
      await _require
          .from('businesses')
          .update(editableFields(business))
          .eq('id', business.id);
    } catch (error) {
      throw ListingsUnavailable(error);
    }
  }

  @override
  Future<List<Business>> getAllListings() async {
    try {
      // RLS returns delisted rows only to someone who administers them, so
      // this cannot leak a lapsed listing to a customer.
      final rows = await _require.from('businesses').select().order('name');
      return rows.map(_fromMap).toList(growable: false);
    } catch (error) {
      throw ListingsUnavailable(error);
    }
  }

  @override
  Future<String> createBusiness(Business business) async {
    try {
      final row = await _require
          .from('businesses')
          .insert({
            ...editableFields(business),
            'tier': business.tier.name,
            'subscription_status': business.tier.name,
          })
          .select('id')
          .single();
      return '${row['id']}';
    } catch (error) {
      throw ListingsUnavailable(error);
    }
  }

  @override
  Future<void> setSubscription(String businessId, SubscriptionTier tier) async {
    try {
      await _require
          .from('businesses')
          .update({'tier': tier.name, 'subscription_status': tier.name})
          .eq('id', businessId);
    } catch (error) {
      throw ListingsUnavailable(error);
    }
  }

  /// The columns an owner may write.
  ///
  /// A whitelist rather than the whole model: subscription state, counters and
  /// seeded ratings are absent on purpose, and the database refuses them from
  /// anyone but the team regardless.
  @visibleForTesting
  static Map<String, Object?> editableFields(Business business) => {
    'name': business.name,
    'category': business.category.dbName,
    'area': business.area,
    'description': business.description,
    'address': _nullIfBlank(business.address),
    'how_to_find_us': _nullIfBlank(business.howToFindUs),
    'phone': _nullIfBlank(business.phone),
    'whatsapp': _nullIfBlank(business.whatsapp),
    'whatsapp_business': _nullIfBlank(business.whatsappBusiness),
    'website': _nullIfBlank(business.website),
    'instagram': _nullIfBlank(business.instagram),
    'facebook': _nullIfBlank(business.facebook),
    'tiktok': _nullIfBlank(business.tiktok),
    'price_range': _nullIfBlank(business.priceRange),
    'offer': _nullIfBlank(business.offer),
    'latitude': business.latitude,
    'longitude': business.longitude,
    'tags': business.tags,
    'is_closed_today': business.isClosedToday,
    'last_verified_at': DateTime.now().toUtc().toIso8601String(),
    'hours': {
      'days': business.hours.days.toList()..sort(),
      'opensAt': business.hours.opensAt,
      'closesAt': business.hours.closesAt,
    },
    'photos': business.photos.map((p) => p.toMap()).toList(),
    'menu': business.menu.map((m) => m.toMap()).toList(),
  };

  static String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> toggleClosedToday(
    String businessId, {
    required bool isClosed,
  }) async {
    try {
      await _require
          .from('businesses')
          .update({'is_closed_today': isClosed})
          .eq('id', businessId);
    } catch (error) {
      throw ListingsUnavailable(error);
    }
  }

  @override
  Future<void> reportWrongInfo({
    required String businessId,
    required String reason,
    String details = '',
  }) async {
    try {
      final user = _require.auth.currentUser;
      await _require.from('listing_reports').insert({
        'business_id': businessId,
        if (user != null) 'user_id': user.id,
        'reason': reason,
        'details': details,
      });
    } catch (error) {
      throw ListingsUnavailable(error);
    }
  }

  /// Maps rows to models, dropping anything the user should not see.
  ///
  /// An empty result stays empty. There is no sample data and no fallback:
  /// the database has no businesses until the team adds real ones, and the app
  /// says so. Inventing listings — even obviously placeholder ones — risks a
  /// real person's number being called, or a business being shown a rating
  /// nobody gave it.
  List<Business> _visible(List<Map<String, dynamic>> rows) {
    return rows
        .map(_fromMap)
        // A team member's session can read pre-built listings; customers'
        // screens must not show them, even on the team's own phone.
        .where((b) => b.tier.isVisible && !b.isProspect)
        .toList(growable: false);
  }

  /// Parses a Supabase row into a [Business].
  ///
  /// Every field is read defensively because a row written by hand in the SQL
  /// editor can be missing anything, and one malformed row should not take the
  /// whole map down.
  static Business _fromMap(Map<String, dynamic> map) {
    return Business(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      category: BusinessCategoryX.fromName('${map['category'] ?? ''}'),
      tier: _resolveTier(map),
      area: '${map['area'] ?? ''}',
      description: '${map['description'] ?? ''}',
      hours: _parseHours(map['hours']),
      photos: _parsePhotos(map['photos']),
      menu: _parseMenu(map['menu']),
      phone: map['phone'] as String?,
      whatsapp: map['whatsapp'] as String?,
      website: map['website'] as String?,
      address: map['address'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      priceRange: map['price_range'] as String?,
      offer: (map['offer'] as String?)?.trim().isEmpty ?? true
          ? null
          : (map['offer'] as String).trim(),
      seededRating: (map['seeded_rating'] as num?)?.toDouble() ?? 0,
      seededReviewCount: (map['seeded_review_count'] as num?)?.toInt() ?? 0,
      liveReviewCount: (map['review_count'] as num?)?.toInt() ?? 0,
      liveRatingSum: (map['review_rating_sum'] as num?)?.toInt() ?? 0,
      views: (map['views'] as num?)?.toInt() ?? 0,
      calls: (map['calls'] as num?)?.toInt() ?? 0,
      whatsappTaps: (map['whatsapp_taps'] as num?)?.toInt() ?? 0,
      lastSpotlightWeek: (map['last_spotlight_week'] as num?)?.toInt() ?? -1,
      howToFindUs: map['how_to_find_us'] as String?,
      tags: _parseTags(map['tags']),
      isClosedToday: (map['is_closed_today'] as bool?) ?? false,
      lastVerifiedAt: _parseDateTime(map['last_verified_at']),
      plan: switch (map['tier']) {
        final String t
            when const {'growing', 'basic', 'featured'}.contains(t) =>
          SubscriptionTierX.fromName(t),
        _ => null,
      },
      trialEndsAt: _parseDateTime(map['trial_ends_at']),
      paidUntil: _parseDateTime(map['paid_until']),
      holdUntil: _parseDateTime(map['hold_until']),
      special: map['special'] as String?,
      specialPostedAt: _parseDateTime(map['special_posted_at']),
      specialSoldOut: (map['special_sold_out'] as bool?) ?? false,
      isProspect: (map['is_prospect'] as bool?) ?? false,
      pinImageUrl: map['pin_image_url'] as String?,
      createdAt: _parseDateTime(map['created_at']),
      instagram: _blankToNull(map['instagram']),
      facebook: _blankToNull(map['facebook']),
      tiktok: _blankToNull(map['tiktok']),
      whatsappBusiness: _blankToNull(map['whatsapp_business']),
    );
  }

  static List<String> _parseTags(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((t) => t.toString()).toList();
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  /// Treats an empty string as absent.
  ///
  /// A hand-written row or a cleared form field stores `''` rather than null,
  /// and an empty social handle would otherwise render as a dead, tappable
  /// link on the listing.
  static String? _blankToNull(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Resolves which subscription state a listing is actually in.
  ///
  /// The row carries two columns and they can disagree. `subscription_status`
  /// is authoritative because it is what Row Level Security filters on — if it
  /// says `delisted`, the listing should not be treated as live regardless of
  /// what `tier` claims. `tier` only decides which paid plan it is on.
  static SubscriptionTier _resolveTier(Map<String, dynamic> map) {
    final status = map['subscription_status'] as String?;
    if (status != null && status.isNotEmpty) {
      return SubscriptionTierX.fromName(status);
    }

    // No status recorded. Fall back to the plan, but never past `delisted`:
    // a business with no subscription record is not paying.
    final tier = map['tier'] as String?;
    if (tier == null || tier.isEmpty) return SubscriptionTier.delisted;

    final resolved = SubscriptionTierX.fromName(tier);
    return resolved == SubscriptionTier.delisted
        ? SubscriptionTier.delisted
        : resolved;
  }

  /// Parses opening hours.
  ///
  /// Missing or empty data produces `OpeningHours()` — which reports closed,
  /// because [OpeningHours.isNever] is true. It does **not** guess a sensible
  /// week. Inventing Mon–Sat hours for a business we know nothing about would
  /// send someone to a closed door and contradict the accuracy pitch.
  static OpeningHours _parseHours(Object? raw) {
    if (raw is! Map) return const OpeningHours();

    final days = raw['days'];
    if (days is! List || days.isEmpty) return const OpeningHours();

    final parsed = days
        .whereType<num>()
        .map((d) => d.toInt())
        .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
        .toSet();

    if (parsed.isEmpty) return const OpeningHours();

    return OpeningHours(
      days: parsed,
      opensAt: (raw['opensAt'] as num?)?.toDouble() ?? 9,
      closesAt: (raw['closesAt'] as num?)?.toDouble() ?? 17,
    );
  }

  static List<BusinessPhoto> _parsePhotos(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(
          (p) => BusinessPhoto(
            url: p['url'] as String?,
            caption: p['caption'] as String?,
          ),
        )
        .toList();
  }

  static List<MenuItem> _parseMenu(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(
          (m) => MenuItem(
            name: m['name'] as String?,
            detail: m['detail'] as String?,
            price: m['price'] as String?,
          ),
        )
        .toList();
  }
}

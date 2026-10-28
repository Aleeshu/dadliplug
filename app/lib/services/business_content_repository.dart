import 'dart:math';

import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// An advertisement a business has posted.
///
/// This is the literal pitch — an app businesses advertise in — so it is a first
/// class record with its own view count, not a field on the listing. The month
/// end report is "views per ad", which needs them separated.
class BusinessAd {
  const BusinessAd({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.title,
    required this.startsAt,
    this.body = '',
    this.imageUrl,
    this.linkUrl,
    this.endsAt,
    this.views = 0,
    this.offerCode,
    this.offerTerms,
    this.kind = 'general',
  });

  final String id;
  final String businessId;
  final String businessName;
  final String title;
  final String body;
  final String? imageUrl;
  final String? linkUrl;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int views;

  /// The code a customer says at the till. An ad with a code is an offer.
  /// Featured listings only; the database refuses one on any other plan.
  final String? offerCode;

  bool get isOffer => offerCode != null && offerCode!.isNotEmpty;

  /// The business's conditions on an offer, e.g. "Mon–Thu lunch, one per
  /// person". Shown with the claimed code at the till.
  final String? offerTerms;

  /// special_offer, new_product, event or general: chosen in the first
  /// step of the create-ad wizard.
  final String kind;

  /// Whether the ad is still running.
  ///
  /// An ad with no end date runs until the business stops it. An ad whose end
  /// date has passed is hidden rather than deleted, so the owner can still see
  /// what happened to it in their reports.
  bool isLiveAt(DateTime now) =>
      !startsAt.isAfter(now) && (endsAt == null || endsAt!.isAfter(now));
}

/// What sort of post an announcement is, as labelled on the Bulletin Board.
/// Stored by [name]; anything unrecognised reads as ordinary business news.
enum AnnouncementKind {
  important,
  offer,
  community,
  business;

  static AnnouncementKind fromName(String? raw) => values.firstWhere(
    (k) => k.name == raw,
    orElse: () => AnnouncementKind.business,
  );
}

/// A message from a business to its customers.
class Announcement {
  const Announcement({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.title,
    required this.createdAt,
    this.body = '',
    this.readByViewer = false,
    this.kind = AnnouncementKind.business,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String title;
  final String body;
  final DateTime createdAt;

  /// Drives the coloured label on the Bulletin Board card.
  final AnnouncementKind kind;

  /// Whether the signed-in viewer has opened it. Drives the read receipt.
  final bool readByViewer;
}

/// Something a business is putting on.
class BusinessEvent {
  const BusinessEvent({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.title,
    required this.startsAt,
    this.body = '',
    this.endsAt,
    this.locationNote,
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.tags = const [],
    this.organizer,
    this.website,
    this.phone,
    this.isFeatured = false,
    this.businessFeatured = false,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String title;
  final String body;
  final DateTime startsAt;
  final DateTime? endsAt;

  /// The venue, as people say it: "Dickenson Bay", "Heritage Quay".
  final String? locationNote;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final List<String> tags;

  /// Who runs it, when that is not the posting business. Falls back to the
  /// business name for display.
  final String? organizer;
  final String? website;
  final String? phone;

  /// Featured by the team.
  final bool isFeatured;

  /// Posted by a business holding a Featured slot.
  final bool businessFeatured;

  /// Shown under Featured Events.
  bool get featured => isFeatured || businessFeatured;

  String get organizerName => (organizer?.trim().isNotEmpty ?? false)
      ? organizer!.trim()
      : businessName;

  bool get hasLocation => latitude != null && longitude != null;

  bool isPastAt(DateTime now) => (endsAt ?? startsAt).isBefore(now);
}

/// Raised when a signed-out visitor asks for their own saved businesses.
class NotSignedInException implements Exception {
  const NotSignedInException();

  @override
  String toString() => 'NotSignedInException: this needs a signed-in user.';
}

/// Raised when content a business is posting is not usable as written.
///
/// Caught by the posting forms to show the message next to the field, rather
/// than letting a database constraint violation reach the owner as a generic
/// failure with no idea which field was at fault.
class InvalidContentException implements Exception {
  const InvalidContentException(this.message);

  final String message;

  @override
  String toString() => 'InvalidContentException: $message';
}

/// Reads the content businesses post, and the viewer's own follows.
///
/// Follows double as bookmarks: one relationship serves both, so there is no
/// way to hold a business you follow and a separate copy you merely saved.
class BusinessContentRepository {
  BusinessContentRepository({this._client, this._userId});

  final SupabaseClient? _client;
  final String? _userId;

  SupabaseClient get _require {
    final client = _client;
    if (client != null) return client;
    if (!AppConfig.supabaseConfigured) {
      throw const BackendNotConfigured();
    }
    return Supabase.instance.client;
  }

  String get _uid {
    final id = _userId;
    if (id != null && id.isNotEmpty) return id;
    final current = _require.auth.currentUser;
    if (current == null) throw const NotSignedInException();
    return current.id;
  }

  /// Live advertisements, newest first.
  Future<List<BusinessAd>> loadAds({required String businessId}) async {
    final rows = await _require
        .from('business_ads')
        .select(
          'id, business_id, title, body, image_url, link_url, '
          'starts_at, ends_at, views, offer_code, offer_terms, kind, '
          'businesses (id, name)',
        )
        .eq('business_id', businessId)
        .order('starts_at', ascending: false);

    return _foldAds(rows);
  }

  /// Every running offer, across all businesses, newest first.
  ///
  /// Filtered to live in the query, so an ended offer is never shown with a
  /// code the till will no longer honour.
  /// Every advertisement running now, newest first: the raw material of the
  /// Home feed. RLS hides ads of listings that are not public.
  Future<List<BusinessAd>> loadLiveAds({DateTime? now}) async {
    final at = (now ?? DateTime.now()).toUtc().toIso8601String();
    final rows = await _require
        .from('business_ads')
        .select(
          'id, business_id, title, body, image_url, link_url, '
          'starts_at, ends_at, views, offer_code, offer_terms, kind, '
          'businesses (id, name)',
        )
        .lte('starts_at', at)
        .or('ends_at.is.null,ends_at.gt.$at')
        .order('starts_at', ascending: false)
        .limit(200);
    return _foldAds(rows);
  }

  /// One advertisement, for its own page and shared links.
  Future<BusinessAd?> loadAd(String id) async {
    final rows = await _require
        .from('business_ads')
        .select(
          'id, business_id, title, body, image_url, link_url, '
          'starts_at, ends_at, views, offer_code, offer_terms, kind, '
          'businesses (id, name)',
        )
        .eq('id', id)
        .limit(1);
    final ads = _foldAds(rows);
    return ads.isEmpty ? null : ads.first;
  }

  Future<List<BusinessAd>> loadOffers({DateTime? now}) async {
    final at = (now ?? DateTime.now()).toUtc().toIso8601String();
    final rows = await _require
        .from('business_ads')
        .select(
          'id, business_id, title, body, image_url, link_url, '
          'starts_at, ends_at, views, offer_code, offer_terms, kind, '
          'businesses (id, name)',
        )
        .not('offer_code', 'is', null)
        .lte('starts_at', at)
        .or('ends_at.is.null,ends_at.gt.$at')
        .order('starts_at', ascending: false)
        .limit(100);

    return _foldAds(rows);
  }

  /// Records that a customer redeemed an offer at the till. Business only;
  /// the database checks the caller runs this listing.
  Future<void> recordRedemption(String adId) async {
    await _require.rpc<void>('record_redemption', params: {'p_ad_id': adId});
  }

  /// Announcements from businesses the viewer follows, newest first.
  ///
  /// Falls back to every announcement when following nothing, because an empty
  /// feed on a brand new app is a worse first impression than a busy one, and
  /// nothing here is private.
  Future<List<Announcement>> loadAnnouncements({
    bool followedOnly = true,
  }) async {
    final query = _require
        .from('business_announcements')
        .select(
          'id, business_id, title, body, created_at, kind, '
          'businesses (id, name)',
        )
        .order('created_at', ascending: false)
        .limit(100);

    final rows = await query;
    return _foldAnnouncements(rows);
  }

  static const _eventColumns =
      'id, business_id, title, body, starts_at, ends_at, location_note, '
      'image_url, latitude, longitude, tags, organizer, website, phone, '
      'is_featured, '
      'businesses (id, name, subscription_status, latitude, longitude)';

  /// Upcoming events across all businesses, soonest first.
  Future<List<BusinessEvent>> loadEvents({bool upcomingOnly = true}) async {
    final rows = await _require
        .from('business_events')
        .select(_eventColumns)
        .order('starts_at', ascending: true)
        .limit(200);

    return _foldEvents(rows);
  }

  /// One event, or null when it does not exist (or is not visible).
  Future<BusinessEvent?> loadEvent(String id) async {
    final row = await _require
        .from('business_events')
        .select(_eventColumns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final events = _foldEvents([row]);
    return events.isEmpty ? null : events.single;
  }

  /// Events the viewer saved.
  Future<Set<String>> loadSavedEventIds() async {
    final rows = await _require
        .from('event_saves')
        .select('event_id')
        .eq('user_id', _uid);
    return {
      for (final row in rows as List<dynamic>)
        if (row is Map && row['event_id'] != null) '${row['event_id']}',
    };
  }

  /// Saves or unsaves an event.
  Future<void> setEventSaved({
    required String eventId,
    required bool saved,
  }) async {
    if (saved) {
      await _require.from('event_saves').upsert({
        'user_id': _uid,
        'event_id': eventId,
      });
    } else {
      await _require
          .from('event_saves')
          .delete()
          .eq('user_id', _uid)
          .eq('event_id', eventId);
    }
  }

  /// Businesses the viewer follows or has bookmarked.
  Future<List<String>> loadFollowedBusinessIds() async {
    final rows = await _require
        .from('business_follows')
        .select('business_id')
        .eq('user_id', _uid);

    return [
      for (final row in rows as List<dynamic>)
        if (row is Map && row['business_id'] != null) '${row['business_id']}',
    ];
  }

  /// Businesses whose announcements the viewer asked to be alerted to.
  Future<Set<String>> loadAlertBusinessIds() async {
    final rows = await _require
        .from('business_follows')
        .select('business_id')
        .eq('user_id', _uid)
        .eq('notify', true);

    return {
      for (final row in rows as List<dynamic>)
        if (row is Map && row['business_id'] != null) '${row['business_id']}',
    };
  }

  /// Turns announcement alerts for a business on or off. Turning them on
  /// also saves the business, since alerts come from what you follow.
  Future<void> setAlerts({
    required String businessId,
    required bool notify,
  }) async {
    await _require.from('business_follows').upsert({
      'user_id': _uid,
      'business_id': businessId,
      'notify': notify,
    });
  }

  /// Follow or unfollow. Returns the state the viewer is now in.
  Future<bool> setFollow({
    required String businessId,
    required bool follow,
  }) async {
    if (follow) {
      await _require.from('business_follows').upsert({
        'user_id': _uid,
        'business_id': businessId,
      });
    } else {
      await _require
          .from('business_follows')
          .delete()
          .eq('user_id', _uid)
          .eq('business_id', businessId);
    }
    return follow;
  }

  /// Records that the viewer opened an announcement.
  ///
  /// Failure is swallowed on purpose: a missing read receipt must never stop
  /// someone reading the message.
  Future<void> markAnnouncementRead(String announcementId) async {
    try {
      await _require.from('announcement_reads').upsert({
        'announcement_id': announcementId,
        'user_id': _uid,
      });
    } catch (error) {
      debugPrint('Could not record announcement read: $error');
    }
  }

  /// Posts an advertisement.
  ///
  /// Rejects an empty title before it reaches the database, so the owner sees
  /// the problem immediately rather than as a constraint violation. The column
  /// has the same check, but that arrives as an opaque 400.
  Future<void> postAd({
    required String businessId,
    required String title,
    String body = '',
    String? imageUrl,
    String? linkUrl,
    DateTime? endsAt,
    String? offerCode,
    String? offerTerms,
    String kind = 'general',
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const InvalidContentException('An advertisement needs a title.');
    }
    final terms = offerTerms?.trim();
    final code = normaliseOfferCode(offerCode);
    if (code != null && !isValidOfferCode(code)) {
      throw const InvalidContentException(
        'An offer code is 4 to 10 letters and numbers, like LUNCH10.',
      );
    }

    try {
      await _require.from('business_ads').insert({
        'business_id': businessId,
        'title': cleanTitle,
        'body': body.trim(),
        if (imageUrl != null && imageUrl.trim().isNotEmpty)
          'image_url': imageUrl.trim(),
        if (linkUrl != null && linkUrl.trim().isNotEmpty)
          'link_url': linkUrl.trim(),
        'ends_at': endsAt?.toUtc().toIso8601String(),
        'offer_code': ?code,
        'kind': kind,
        if (code != null && terms != null && terms.isNotEmpty)
          'offer_terms': terms,
      });
    } on PostgrestException catch (error) {
      // The plan's limits (live ads, deals) are enforced by the database;
      // its message says what to do, so show it rather than "no signal".
      if (error.code == '23514') throw InvalidContentException(error.message);
      rethrow;
    }
  }

  /// Ends a running advertisement without deleting it.
  ///
  /// Deleting would lose the view count, which is the number the month end
  /// report is built from. The ad stays in the history, marked finished.
  Future<void> endAd(String adId, {DateTime? at}) async {
    await _require
        .from('business_ads')
        .update({'ends_at': (at ?? DateTime.now()).toUtc().toIso8601String()})
        .eq('id', adId);
  }

  /// Posts an announcement.
  Future<void> postAnnouncement({
    required String businessId,
    required String title,
    String body = '',
    AnnouncementKind kind = AnnouncementKind.business,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const InvalidContentException('An announcement needs a title.');
    }

    await _require.from('business_announcements').insert({
      'business_id': businessId,
      'title': cleanTitle,
      'body': body.trim(),
      'kind': kind.name,
    });
  }

  /// Posts an event.
  ///
  /// An event that ends before it starts is rejected rather than inserted: the
  /// database has the same check, but a constraint violation surfaces as a
  /// generic error with no hint about which field was wrong.
  Future<void> postEvent({
    required String businessId,
    required String title,
    required DateTime startsAt,
    String body = '',
    DateTime? endsAt,
    String? locationNote,
    String? imageUrl,
    List<String> tags = const [],
    String? organizer,
    String? website,
    String? phone,
    double? latitude,
    double? longitude,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const InvalidContentException('An event needs a title.');
    }
    String? clean(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();
    if (endsAt != null && endsAt.isBefore(startsAt)) {
      throw const InvalidContentException(
        'An event cannot finish before it starts.',
      );
    }

    await _require.from('business_events').insert({
      'business_id': businessId,
      'title': cleanTitle,
      'body': body.trim(),
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      if (locationNote != null && locationNote.trim().isNotEmpty)
        'location_note': locationNote.trim(),
      'image_url': ?clean(imageUrl),
      'tags': [
        for (final t in tags)
          if (t.trim().isNotEmpty) t.trim(),
      ],
      'organizer': ?clean(organizer),
      'website': ?clean(website),
      'phone': ?clean(phone),
      'latitude': ?latitude,
      'longitude': ?longitude,
    });
  }

  String _nameFrom(Object? business) => business is Map
      ? (business['name'] as String? ?? 'a business')
      : 'a business';

  List<BusinessAd> _foldAds(List<dynamic> rows) {
    final ads = <BusinessAd>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final id = raw['id']?.toString();
      final businessId = raw['business_id']?.toString();
      final title = raw['title']?.toString();
      final startsAt = DateTime.tryParse(raw['starts_at']?.toString() ?? '');
      if (id == null ||
          businessId == null ||
          title == null ||
          startsAt == null) {
        continue;
      }
      ads.add(
        BusinessAd(
          id: id,
          businessId: businessId,
          businessName: _nameFrom(raw['businesses']),
          title: title,
          body: raw['body']?.toString() ?? '',
          imageUrl: raw['image_url']?.toString(),
          linkUrl: raw['link_url']?.toString(),
          startsAt: startsAt,
          endsAt: DateTime.tryParse(raw['ends_at']?.toString() ?? ''),
          views: (raw['views'] as num?)?.toInt() ?? 0,
          offerCode: raw['offer_code']?.toString(),
          offerTerms: raw['offer_terms']?.toString(),
          kind: raw['kind']?.toString() ?? 'general',
        ),
      );
    }
    return ads;
  }

  List<Announcement> _foldAnnouncements(List<dynamic> rows) {
    final out = <Announcement>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final id = raw['id']?.toString();
      final businessId = raw['business_id']?.toString();
      final title = raw['title']?.toString();
      final createdAt = DateTime.tryParse(raw['created_at']?.toString() ?? '');
      if (id == null ||
          businessId == null ||
          title == null ||
          createdAt == null) {
        continue;
      }
      out.add(
        Announcement(
          id: id,
          businessId: businessId,
          businessName: _nameFrom(raw['businesses']),
          title: title,
          body: raw['body']?.toString() ?? '',
          createdAt: createdAt,
          kind: AnnouncementKind.fromName(raw['kind']?.toString()),
        ),
      );
    }
    return out;
  }

  static double? _double(Object? v) => v is num ? v.toDouble() : null;

  List<BusinessEvent> _foldEvents(List<dynamic> rows) {
    final out = <BusinessEvent>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final business = raw['businesses'] is Map
          ? raw['businesses'] as Map
          : null;
      final id = raw['id']?.toString();
      final businessId = raw['business_id']?.toString();
      final title = raw['title']?.toString();
      final startsAt = DateTime.tryParse(raw['starts_at']?.toString() ?? '');
      if (id == null ||
          businessId == null ||
          title == null ||
          startsAt == null) {
        continue;
      }
      out.add(
        BusinessEvent(
          id: id,
          businessId: businessId,
          businessName: _nameFrom(raw['businesses']),
          title: title,
          body: raw['body']?.toString() ?? '',
          startsAt: startsAt,
          endsAt: DateTime.tryParse(raw['ends_at']?.toString() ?? ''),
          locationNote: raw['location_note']?.toString(),
          imageUrl: raw['image_url']?.toString(),
          // An event without its own coordinates is at the business.
          latitude: _double(raw['latitude']) ?? _double(business?['latitude']),
          longitude:
              _double(raw['longitude']) ?? _double(business?['longitude']),
          tags: [
            for (final t in (raw['tags'] as List<dynamic>? ?? const [])) '$t',
          ],
          organizer: raw['organizer']?.toString(),
          website: raw['website']?.toString(),
          phone: raw['phone']?.toString(),
          isFeatured: raw['is_featured'] == true,
          businessFeatured: const {
            'featured',
            'trial',
          }.contains(business?['subscription_status']),
        ),
      );
    }
    return out;
  }
}

final businessContentRepositoryProvider = Provider<BusinessContentRepository>(
  (ref) => BusinessContentRepository(),
);

// Inferred: the family type is only nameable via riverpod/src.
// ignore: specify_nonobvious_property_types
final businessAdsProvider = FutureProvider.family<List<BusinessAd>, String>(
  (ref, businessId) => ref
      .watch(businessContentRepositoryProvider)
      .loadAds(businessId: businessId),
);

final announcementsProvider = FutureProvider<List<Announcement>>(
  (ref) => ref.watch(businessContentRepositoryProvider).loadAnnouncements(),
);

final upcomingEventsProvider = FutureProvider<List<BusinessEvent>>((ref) async {
  final events = await ref
      .watch(businessContentRepositoryProvider)
      .loadEvents();
  final now = DateTime.now();
  return events.where((e) => !e.isPastAt(now)).toList(growable: false);
});

/// One event by id.
// Inferred: the family type is only nameable via riverpod/src.
// ignore: specify_nonobvious_property_types
final eventProvider = FutureProvider.family<BusinessEvent?, String>(
  (ref, id) => ref.watch(businessContentRepositoryProvider).loadEvent(id),
);

/// Events the viewer saved. Empty for a guest.
final savedEventIdsProvider = FutureProvider<Set<String>>((ref) async {
  try {
    return await ref
        .watch(businessContentRepositoryProvider)
        .loadSavedEventIds();
  } on NotSignedInException {
    return const {};
  } on BackendNotConfigured {
    return const {};
  }
});

/// Running offers across every business.
final offersProvider = FutureProvider<List<BusinessAd>>(
  (ref) => ref.watch(businessContentRepositoryProvider).loadOffers(),
);

/// Businesses the viewer gets announcement alerts from. Empty for a guest.
final alertBusinessIdsProvider = FutureProvider<Set<String>>((ref) async {
  try {
    return await ref
        .watch(businessContentRepositoryProvider)
        .loadAlertBusinessIds();
  } on NotSignedInException {
    return const {};
  } on BackendNotConfigured {
    return const {};
  }
});

/// Businesses the viewer follows. Empty for a guest rather than an error.
final followedBusinessIdsProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(businessContentRepositoryProvider);
  try {
    return await repo.loadFollowedBusinessIds();
  } on NotSignedInException {
    return const [];
  } on BackendNotConfigured {
    // No credentials in this build. A guest sees no bookmarks rather than an
    // error, because bookmarks are not the point of the app.
    debugPrint('Bookmarks unavailable: no signed-in user or backend');
    return const [];
  }
});

/// Upper-cases and trims a typed code; null when blank.
String? normaliseOfferCode(String? raw) {
  final code = raw?.trim().toUpperCase().replaceAll(' ', '');
  return (code == null || code.isEmpty) ? null : code;
}

/// Matches the database's `business_ads_offer_code_format`.
bool isValidOfferCode(String code) =>
    RegExp(r'^[A-Z0-9]{4,10}$').hasMatch(code);

/// A fresh six-character code with no look-alike characters (no 0/O, 1/I),
/// because it is read aloud and typed at a till.
String generateOfferCode({Random? random}) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = random ?? Random.secure();
  return List.generate(6, (_) => alphabet[rng.nextInt(alphabet.length)]).join();
}

final liveAdsProvider = FutureProvider<List<BusinessAd>>(
  (ref) => ref.watch(businessContentRepositoryProvider).loadLiveAds(),
);

// Inferred: the family type is only nameable via riverpod/src.
// ignore: specify_nonobvious_property_types
final adProvider = FutureProvider.family<BusinessAd?, String>(
  (ref, id) => ref.watch(businessContentRepositoryProvider).loadAd(id),
);

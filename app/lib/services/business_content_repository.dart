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

  /// Whether the ad is still running.
  ///
  /// An ad with no end date runs until the business stops it. An ad whose end
  /// date has passed is hidden rather than deleted, so the owner can still see
  /// what happened to it in their reports.
  bool isLiveAt(DateTime now) =>
      !startsAt.isAfter(now) && (endsAt == null || endsAt!.isAfter(now));
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
  });

  final String id;
  final String businessId;
  final String businessName;
  final String title;
  final String body;
  final DateTime createdAt;

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
  });

  final String id;
  final String businessId;
  final String businessName;
  final String title;
  final String body;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? locationNote;

  bool isPastAt(DateTime now) => startsAt.isBefore(now);
}

/// Raised when a signed-out visitor asks for their own saved businesses.
class NotSignedInException implements Exception {
  const NotSignedInException();

  @override
  String toString() =>
      'NotSignedInException: this needs a signed-in user.';
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
      throw StateError(AppConfig.supabaseMissingBuildHint);
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
          'starts_at, ends_at, views, businesses (id, name)',
        )
        .eq('business_id', businessId)
        .order('starts_at', ascending: false);

    return _foldAds(rows);
  }

  /// Announcements from businesses the viewer follows, newest first.
  ///
  /// Falls back to every announcement when following nothing, because an empty
  /// feed on a brand new app is a worse first impression than a busy one, and
  /// nothing here is private.
  Future<List<Announcement>> loadAnnouncements({bool followedOnly = true}) async {
    final query = _require
        .from('business_announcements')
        .select(
          'id, business_id, title, body, created_at, '
          'businesses (id, name)',
        )
        .order('created_at', ascending: false)
        .limit(100);

    final rows = await query;
    return _foldAnnouncements(rows);
  }

  /// Upcoming events across all businesses, soonest first.
  Future<List<BusinessEvent>> loadEvents({bool upcomingOnly = true}) async {
    final rows = await _require
        .from('business_events')
        .select(
          'id, business_id, title, body, starts_at, ends_at, location_note, '
          'businesses (id, name)',
        )
        .order('starts_at', ascending: true)
        .limit(200);

    return _foldEvents(rows);
  }

  /// Businesses the viewer follows or has bookmarked.
  Future<List<String>> loadFollowedBusinessIds() async {
    final rows = await _require
        .from('business_follows')
        .select('business_id')
        .eq('user_id', _uid);

    return [
      for (final row in rows as List<dynamic>)
        if (row is Map && row['business_id'] != null)
          '${row['business_id']}',
    ];
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
      if (id == null || businessId == null || title == null || startsAt == null) {
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
      if (id == null || businessId == null || title == null || createdAt == null) {
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
        ),
      );
    }
    return out;
  }

  List<BusinessEvent> _foldEvents(List<dynamic> rows) {
    final out = <BusinessEvent>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final id = raw['id']?.toString();
      final businessId = raw['business_id']?.toString();
      final title = raw['title']?.toString();
      final startsAt = DateTime.tryParse(raw['starts_at']?.toString() ?? '');
      if (id == null || businessId == null || title == null || startsAt == null) {
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
        ),
      );
    }
    return out;
  }
}

final businessContentRepositoryProvider = Provider<BusinessContentRepository>(
  (ref) => BusinessContentRepository(),
);

final businessAdsProvider = FutureProvider.family<List<BusinessAd>, String>(
  (ref, businessId) =>
      ref.watch(businessContentRepositoryProvider).loadAds(businessId: businessId),
);

final announcementsProvider = FutureProvider<List<Announcement>>(
  (ref) => ref.watch(businessContentRepositoryProvider).loadAnnouncements(),
);

final upcomingEventsProvider = FutureProvider<List<BusinessEvent>>((ref) async {
  final events = await ref.watch(businessContentRepositoryProvider).loadEvents();
  final now = DateTime.now();
  return events.where((e) => !e.isPastAt(now)).toList(growable: false);
});

/// Businesses the viewer follows. Empty for a guest rather than an error.
final followedBusinessIdsProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(businessContentRepositoryProvider);
  try {
    return await repo.loadFollowedBusinessIds();
  } on NotSignedInException {
    return const [];
  } on StateError {
    // No credentials in this build. A guest sees no bookmarks rather than an
    // error, because bookmarks are not the point of the app.
    debugPrint('Bookmarks unavailable: no signed-in user or backend');
    return const [];
  }
});
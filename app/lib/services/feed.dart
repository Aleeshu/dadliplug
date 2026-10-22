import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/services/specials.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FeedKind { deal, ad, special, announcement, event }

/// One post in the Home feed.
class FeedItem {
  const FeedItem({
    required this.kind,
    required this.id,
    required this.business,
    required this.title,
    required this.subtitle,
    required this.at,
    required this.sortAt,
    this.imageUrl,
  });

  final FeedKind kind;

  /// The ad, announcement or event id; the business id for a special.
  final String id;
  final Business business;
  final String title;
  final String subtitle;
  final String? imageUrl;

  /// When it was posted (or, for an event, when it starts).
  final DateTime at;

  /// Where it sorts: posts by when they went up; an event as if posted as
  /// long ago as it is away, so tomorrow's event sits with yesterday's posts.
  final DateTime sortAt;

  /// From a Featured business, so labelled as paid placement. The label is
  /// the point: a paid post must never pass for an ordinary one.
  bool get sponsored => business.tier.holdsFeaturedSlot;

  /// Where tapping it goes.
  String get route => switch (kind) {
    FeedKind.deal || FeedKind.ad => '/ad/$id',
    FeedKind.event => '/event/$id',
    FeedKind.special || FeedKind.announcement => '/listing/${business.id}',
  };
}

/// How far back announcements count as fresh, and how far ahead events.
const kFeedAnnouncementWindow = Duration(days: 14);
const kFeedEventWindow = Duration(days: 7);

/// Every slot at this interval is offered to a sponsored post first.
const kSponsoredEvery = 5;

/// The Home feed: fresh ads, deals, specials, announcements and the week's
/// events, newest first (Business Plan 2).
///
/// Sponsored posts (Featured businesses) are labelled, and the first slot of
/// every block of [kSponsoredEvery] goes to the freshest sponsored post not
/// yet shown. Everything else is strictly by time: paying buys a labelled
/// slot, never the whole feed.
List<FeedItem> buildFeed({
  required List<Business> businesses,
  required List<BusinessAd> ads,
  required List<Announcement> announcements,
  required List<BusinessEvent> events,
  required DateTime now,
  BusinessCategory? category,
  int limit = 100,
}) {
  // Only posts from listings customers can see, in the chosen category.
  final byId = {
    for (final b in businesses)
      if (category == null || b.category == category) b.id: b,
  };
  final items = <FeedItem>[];

  for (final ad in ads) {
    final b = byId[ad.businessId];
    if (b == null || !ad.isLiveAt(now)) continue;
    items.add(
      FeedItem(
        kind: ad.isOffer ? FeedKind.deal : FeedKind.ad,
        id: ad.id,
        business: b,
        title: ad.title,
        subtitle: ad.isOffer
            ? (ad.offerTerms?.isNotEmpty ?? false)
                  ? ad.offerTerms!
                  : 'Deal: claim it in the app'
            : ad.body,
        imageUrl: ad.imageUrl,
        at: ad.startsAt,
        sortAt: ad.startsAt,
      ),
    );
  }

  for (final b in byId.values) {
    final special = todaysSpecial(b, now: now);
    final posted = b.specialPostedAt;
    if (special == null || special.soldOut || posted == null) continue;
    items.add(
      FeedItem(
        kind: FeedKind.special,
        id: b.id,
        business: b,
        title: special.text,
        subtitle: "Today's special",
        at: posted,
        sortAt: posted,
      ),
    );
  }

  for (final a in announcements) {
    final b = byId[a.businessId];
    if (b == null || now.difference(a.createdAt) > kFeedAnnouncementWindow) {
      continue;
    }
    items.add(
      FeedItem(
        kind: FeedKind.announcement,
        id: a.id,
        business: b,
        title: a.title,
        subtitle: a.body,
        at: a.createdAt,
        sortAt: a.createdAt,
      ),
    );
  }

  for (final e in events) {
    final b = byId[e.businessId];
    final until = e.startsAt.difference(now);
    if (b == null || until.isNegative || until > kFeedEventWindow) continue;
    items.add(
      FeedItem(
        kind: FeedKind.event,
        id: e.id,
        business: b,
        title: e.title,
        subtitle: e.locationNote ?? e.body,
        imageUrl: e.imageUrl,
        at: e.startsAt,
        sortAt: now.subtract(until),
      ),
    );
  }

  items.sort((a, b) => b.sortAt.compareTo(a.sortAt));

  final sponsored = items.where((i) => i.sponsored).toList();
  final used = <FeedItem>{};
  final out = <FeedItem>[];
  var organic = 0;
  while (out.length < limit && used.length < items.length) {
    if (out.length % kSponsoredEvery == 0) {
      final next = sponsored.where((i) => !used.contains(i)).firstOrNull;
      if (next != null) {
        out.add(next);
        used.add(next);
        continue;
      }
    }
    while (organic < items.length && used.contains(items[organic])) {
      organic++;
    }
    if (organic >= items.length) break;
    out.add(items[organic]);
    used.add(items[organic]);
  }
  return out;
}

/// The feed for Home and the Feed screen, from what is already loaded.
/// Any one source failing leaves the rest: a feed with no events still works.
// Inferred: the family type is only nameable via riverpod/src.
// ignore: specify_nonobvious_property_types
final feedProvider = FutureProvider.family<List<FeedItem>, BusinessCategory?>((
  ref,
  category,
) async {
  final businesses = await ref.watch(businessListProvider.future);
  Future<List<T>> orEmpty<T>(Future<List<T>> f) =>
      f.catchError((Object _) => <T>[]);
  final ads = await orEmpty(ref.watch(liveAdsProvider.future));
  final announcements = await orEmpty(ref.watch(announcementsProvider.future));
  final events = await orEmpty(ref.watch(upcomingEventsProvider.future));
  return buildFeed(
    businesses: businesses,
    ads: ads,
    announcements: announcements,
    events: events,
    now: DateTime.now(),
    category: category,
  );
});

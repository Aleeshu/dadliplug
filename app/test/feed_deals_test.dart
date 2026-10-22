import 'package:antigua_business_map/features/discovery/ad_screen.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:antigua_business_map/services/deals.dart';
import 'package:antigua_business_map/services/feed.dart';
import 'package:antigua_business_map/services/report_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 22, 16);

  Business business(
    String id, {
    SubscriptionTier tier = SubscriptionTier.basic,
    BusinessCategory category = BusinessCategory.food,
  }) => Business(
    id: id,
    name: 'Biz $id',
    category: category,
    tier: tier,
    area: 'x',
    description: 'x',
  );

  BusinessAd ad(
    String id,
    String businessId, {
    required Duration ago,
    String? code,
    DateTime? endsAt,
  }) => BusinessAd(
    id: id,
    businessId: businessId,
    businessName: 'Biz $businessId',
    title: 'Ad $id',
    startsAt: now.subtract(ago),
    endsAt: endsAt,
    offerCode: code,
  );

  List<FeedItem> feed({
    required List<Business> businesses,
    List<BusinessAd> ads = const [],
    List<Announcement> announcements = const [],
    List<BusinessEvent> events = const [],
    BusinessCategory? category,
  }) => buildFeed(
    businesses: businesses,
    ads: ads,
    announcements: announcements,
    events: events,
    now: now,
    category: category,
  );

  group('the feed', () {
    test('is newest first, and an ad with a code is a deal', () {
      final items = feed(
        businesses: [business('a')],
        ads: [
          ad('old', 'a', ago: const Duration(days: 3)),
          ad('new', 'a', ago: const Duration(hours: 1), code: 'LUNCH10'),
        ],
      );
      expect(items.map((i) => i.id), ['new', 'old']);
      expect(items.first.kind, FeedKind.deal);
      expect(items.first.route, '/ad/new');
    });

    test('drops ended ads and posts from listings customers cannot see', () {
      final items = feed(
        businesses: [business('a')],
        ads: [
          ad('ended', 'a', ago: const Duration(days: 9), endsAt: now),
          ad('hidden', 'gone', ago: const Duration(hours: 1)),
        ],
      );
      expect(items, isEmpty);
    });

    test('filters by category', () {
      final items = feed(
        businesses: [
          business('food'),
          business('salon', category: BusinessCategory.healthBeauty),
        ],
        ads: [
          ad('f', 'food', ago: const Duration(hours: 1)),
          ad('s', 'salon', ago: const Duration(hours: 2)),
        ],
        category: BusinessCategory.healthBeauty,
      );
      expect(items.map((i) => i.id), ['s']);
    });

    test('an event tomorrow sorts like a post from yesterday', () {
      final items = feed(
        businesses: [business('a')],
        ads: [
          ad('hour', 'a', ago: const Duration(hours: 1)),
          ad('twodays', 'a', ago: const Duration(days: 2)),
        ],
        events: [
          BusinessEvent(
            id: 'e',
            businessId: 'a',
            businessName: 'Biz a',
            title: 'Steel pan night',
            startsAt: now.add(const Duration(days: 1)),
          ),
          BusinessEvent(
            id: 'far',
            businessId: 'a',
            businessName: 'Biz a',
            title: 'Next month',
            startsAt: now.add(const Duration(days: 30)),
          ),
        ],
      );
      expect(items.map((i) => i.id), ['hour', 'e', 'twodays']);
    });

    test('old announcements are not fresh', () {
      final items = feed(
        businesses: [business('a')],
        announcements: [
          Announcement(
            id: 'recent',
            businessId: 'a',
            businessName: 'Biz a',
            title: 'New hours',
            createdAt: now.subtract(const Duration(days: 2)),
          ),
          Announcement(
            id: 'stale',
            businessId: 'a',
            businessName: 'Biz a',
            title: 'Old news',
            createdAt: now.subtract(const Duration(days: 40)),
          ),
        ],
      );
      expect(items.map((i) => i.id), ['recent']);
    });

    test('sponsored posts are labelled and get one slot in every five', () {
      final featured = business('paid', tier: SubscriptionTier.featured);
      final items = feed(
        businesses: [business('a'), featured],
        ads: [
          for (var i = 0; i < 8; i++)
            ad('o$i', 'a', ago: Duration(hours: i + 1)),
          ad('p1', 'paid', ago: const Duration(days: 5)),
          ad('p2', 'paid', ago: const Duration(days: 6)),
          ad('p3', 'paid', ago: const Duration(days: 7)),
        ],
      );
      // Slots 0 and 5 go to sponsored posts; the rest stay in time order,
      // and the third sponsored post waits its turn by time.
      expect(items[0].id, 'p1');
      expect(items[5].id, 'p2');
      expect(items.where((i) => i.sponsored).map((i) => i.id), [
        'p1',
        'p2',
        'p3',
      ]);
      expect(
        items.where((i) => !i.sponsored).map((i) => i.id),
        [for (var i = 0; i < 8; i++) 'o$i'],
      );
    });
  });

  group('deals', () {
    test('a code read off a phone is forgiven spaces and case', () {
      expect(normaliseDealCode(' abc 234 '), 'ABC234');
      expect(normaliseDealCode('ab-c2-34'), 'ABC234');
    });

    test('a shared deal says what, where, the terms, and the public link', () {
      final text = adShareText(
        BusinessAd(
          id: 'ad-1',
          businessId: 'b',
          businessName: 'Demo Kitchen',
          title: 'Sunset Happy Hour',
          startsAt: now,
          offerCode: 'SUNSET15',
          offerTerms: 'Mon to Thu, 4 to 7pm',
        ),
      );
      expect(text, startsWith('Deal at Demo Kitchen: Sunset Happy Hour'));
      expect(text, contains('Mon to Thu, 4 to 7pm'));
      expect(text, endsWith('/a/ad-1'));
    });
  });

  group('best ad this month', () {
    AdPerformance perf(
      String id, {
      int views = 0,
      int opens = 0,
      int shares = 0,
      int redemptions = 0,
    }) => AdPerformance(
      adId: id,
      title: id,
      views: views,
      opens: opens,
      shares: shares,
      redemptions: redemptions,
      wasRunning: true,
    );

    MonthlyReport report(List<AdPerformance> ads) => MonthlyReport(
      businessId: 'b',
      month: DateTime(2026, 10),
      listingViews: 0,
      calls: 0,
      whatsappTaps: 0,
      ads: ads,
      reviews: const StarBreakdown.empty(),
      verifiedReviews: 0,
      newVisits: 0,
    );

    test('a redemption outweighs a pile of views', () {
      final r = report([
        perf('seen', views: 900),
        perf('worked', views: 40, redemptions: 10),
      ]);
      expect(r.bestAd?.adId, 'worked');
      expect(r.redemptions, 10);
    });

    test('no activity means no best ad, not an arbitrary one', () {
      expect(report([perf('a'), perf('b')]).bestAd, isNull);
    });
  });
}

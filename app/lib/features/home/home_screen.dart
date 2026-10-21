import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:antigua_business_map/services/listing_filter_service.dart';
import 'package:antigua_business_map/widgets/offer_code_chip.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/services/prelaunch_repository.dart';
import 'package:antigua_business_map/services/ranking_repository.dart';
import 'package:antigua_business_map/widgets/notice_banner.dart';
import 'package:antigua_business_map/widgets/business_card.dart';
import 'package:antigua_business_map/widgets/category_icon.dart';
import 'package:antigua_business_map/widgets/dadliplug_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Home: search, the categories, and Featured businesses.
///
/// The map moved to its own tab in the Dadliplug design. Home is where a
/// visitor decides what they are looking for; the map is where they find it.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Insets.giant),
          children: const [
            Padding(
              padding: EdgeInsets.fromLTRB(
                Insets.huge,
                Insets.lg,
                Insets.md,
                Insets.md,
              ),
              child: Row(
                children: [
                  DadliplugLogo(),
                  Spacer(),
                  _AlertBell(),
                ],
              ),
            ),
            NoticeBanner(
              padding: EdgeInsets.fromLTRB(
                Insets.huge,
                0,
                Insets.huge,
                Insets.md,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Insets.huge),
              child: _SearchBar(),
            ),
            SizedBox(height: Insets.huge),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Insets.huge),
              child: _Hero(),
            ),
            SizedBox(height: Insets.giant),
            _CategoryRow(),
            SizedBox(height: Insets.giant),
            _FeaturedSection(),
            _SpotlightSection(),
            _CollectionsSection(),
            _OffersSection(),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.app,
      borderRadius: BorderRadius.circular(Corners.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(Corners.pill),
        onTap: () => context.push('/search'),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: Insets.huge),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Corners.pill),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: palette.muted),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  'Search businesses, products, services…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyMedium.copyWith(color: palette.muted),
                ),
              ),
              Icon(Icons.tune, color: palette.ink, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Discover Antigua's Best" banner, over a real photo of the island:
/// English Harbour from Shirley Heights. Never a stock beach from somewhere
/// else, which would be the first untrue thing on the screen.
///
/// The photo is CC BY 4.0 and must stay credited: Dr. Thomas Liptak,
/// https://commons.wikimedia.org/wiki/File:Antigua_Shirley's_Heights_English_Harbour.jpg
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Corners.xxl + 4),
      child: ColoredBox(
        // No fixed height: with large accessibility text a fixed banner
        // overflowed. It sizes to its content instead.
        color: const Color(0xFF0A4D7A),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/hero_antigua.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
            ),
            // Darkens the left, where the text sits, so it reads over a
            // bright sky and sea; the right shows the harbour clearly.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xCC062C47), Color(0x33062C47)],
                  ),
                ),
              ),
            ),
            Positioned(
              right: Insets.md,
              bottom: Insets.xs,
              child: Text(
                'Photo: Thomas Liptak, CC BY 4.0',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 9,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.giant),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Discover\nAntigua’s Best',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Shop · Dine · Explore',
                    style: AppText.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: Insets.xl),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.gold,
                      foregroundColor: palette.ink,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.huge,
                      ),
                    ),
                    onPressed: () => context.go('/categories'),
                    child: const Text('Browse Businesses →'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.huge),
        itemCount: BusinessCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: Insets.xl),
        itemBuilder: (context, i) {
          final c = BusinessCategory.values[i];
          return InkWell(
            borderRadius: BorderRadius.circular(Corners.xl),
            onTap: () => context.push(categoryRoute(c)),
            child: SizedBox(
              width: 80,
              child: Column(
                children: [
                  CategoryIcon(category: c),
                  const SizedBox(height: Insets.sm),
                  // Two-word names wrap ("Health & / Beauty"); a long single
                  // word ("Entertainment") shrinks rather than breaking
                  // mid-word.
                  for (final line in _lines(c.label))
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        line,
                        maxLines: 1,
                        style: AppText.caption.copyWith(
                          color: palette.ink,
                          height: 1.15,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Splits "Health & Beauty" into "Health &" / "Beauty"; one word stays one
/// line.
List<String> _lines(String label) {
  final words = label.split(' ');
  if (words.length < 2) return [label];
  final split = (words.length / 2).ceil();
  return [words.take(split).join(' '), words.skip(split).join(' ')];
}

class _FeaturedSection extends ConsumerWidget {
  const _FeaturedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final businessesAsync = ref.watch(businessListProvider);
    // Which businesses have a running offer, for the OFFER tag. An offers
    // outage just means no tags, never a broken section.
    final offerIds = {
      for (final o in ref.watch(offersProvider).value ?? const <BusinessAd>[])
        o.businessId,
    };

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(Insets.huge, 0, Insets.md, 0),
      child: Row(
        children: [
          Text(
            'Featured Businesses',
            style: AppText.titleLarge.copyWith(color: palette.ink),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => context.push('/featured'),
            child: Text(
              'See All ›',
              style: AppText.labelMedium.copyWith(color: palette.red),
            ),
          ),
        ],
      ),
    );

    return businessesAsync.when(
      skipError: true,
      data: (all) {
        final featured = featuredBusinesses(all);
        if (featured.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: Insets.sm),
            SizedBox(
              height: 232,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.huge,
                  vertical: Insets.xs,
                ),
                itemCount: featured.length,
                separatorBuilder: (_, _) => const SizedBox(width: Insets.xl),
                itemBuilder: (_, i) => BusinessCard(
                  business: featured[i],
                  hasOffer: offerIds.contains(featured[i].id),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.all(Insets.giant),
        child: Center(child: CircularProgressIndicator(color: palette.red)),
      ),
      // An error, never an empty section: an outage must not read as "no
      // featured businesses".
      error: (err, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.huge),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Could not load businesses. Check your connection.',
                style: AppText.bodyMedium.copyWith(color: palette.muted),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(businessListProvider),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// This week's Spotlight: ten businesses taking turns (plan.md section 3).
///
/// Says plainly that it rotates, so nobody reads a slot as a ranking. Hidden
/// when empty or on an error; it is a bonus row, not Home's purpose.
class _SpotlightSection extends ConsumerWidget {
  const _SpotlightSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final spotlight = ref.watch(spotlightProvider).value ?? const [];
    if (spotlight.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.huge),
            child: Text(
              "This Week's Spotlight",
              style: AppText.titleLarge.copyWith(color: palette.ink),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.huge, 2, Insets.huge, 0),
            child: Text(
              'Businesses take turns here. A new set every Monday.',
              style: AppText.caption.copyWith(color: palette.muted),
            ),
          ),
          const SizedBox(height: Insets.sm),
          SizedBox(
            height: 232,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.huge,
                vertical: Insets.xs,
              ),
              itemCount: spotlight.length,
              separatorBuilder: (_, _) => const SizedBox(width: Insets.xl),
              itemBuilder: (_, i) => BusinessCard(business: spotlight[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// The team's collections ("Best pepperpot"), as tappable tiles.
class _CollectionsSection extends ConsumerWidget {
  const _CollectionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final collections = ref.watch(homeCollectionsProvider).value ?? const [];
    if (collections.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.huge),
            child: Text(
              "The Team's Picks",
              style: AppText.titleLarge.copyWith(color: palette.ink),
            ),
          ),
          const SizedBox(height: Insets.sm),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Insets.huge),
              itemCount: collections.length,
              separatorBuilder: (_, _) => const SizedBox(width: Insets.md),
              itemBuilder: (context, i) {
                final (c, businesses) = collections[i];
                return SizedBox(
                  width: 220,
                  child: Material(
                    color: palette.goldBg,
                    borderRadius: BorderRadius.circular(Corners.xl),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Corners.xl),
                      onTap: () => context.push('/collection/${c.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.titleMedium.copyWith(
                                color: palette.goldInk,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${businesses.length} '
                              '${businesses.length == 1 ? 'place' : 'places'}',
                              style: AppText.labelMedium.copyWith(
                                color: palette.goldInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The newest offers, with a way to all of them. Hidden when there are none,
/// and on an error: offers are a bonus on Home, not its reason for being.
class _OffersSection extends ConsumerWidget {
  const _OffersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final offers = ref.watch(offersProvider).value ?? const <BusinessAd>[];
    if (offers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Insets.giant),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.huge, 0, Insets.md, 0),
            child: Row(
              children: [
                Text(
                  'Latest Offers',
                  style: AppText.titleLarge.copyWith(color: palette.ink),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/offers'),
                  child: Text(
                    'See All ›',
                    style: AppText.labelMedium.copyWith(color: palette.red),
                  ),
                ),
              ],
            ),
          ),
          for (final offer in offers.take(3))
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Insets.huge,
              ),
              leading: const OfferBadge(),
              title: Text(
                offer.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.titleSmall.copyWith(color: palette.ink),
              ),
              subtitle: Text(
                offer.businessName,
                style: AppText.caption.copyWith(color: palette.muted),
              ),
              trailing: Text(
                offer.offerCode!,
                style: AppText.labelMedium.copyWith(
                  color: palette.red,
                  letterSpacing: 1.5,
                ),
              ),
              onTap: () => context.push('/listing/${offer.businessId}'),
            ),
        ],
      ),
    );
  }
}

/// The bell, with a count of this week's announcements from businesses the
/// viewer asked to be alerted to. In-app stand-in for push, which needs
/// Firebase (plan.md section 15).
class _AlertBell extends ConsumerWidget {
  const _AlertBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final alertIds = ref.watch(alertBusinessIdsProvider).value ?? const {};
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final count = alertIds.isEmpty
        ? 0
        : (ref.watch(announcementsProvider).value ?? const <Announcement>[])
              .where(
                (a) =>
                    alertIds.contains(a.businessId) &&
                    a.createdAt.isAfter(weekAgo),
              )
              .length;

    return IconButton(
      tooltip: count == 0 ? 'Bulletin Board' : '$count new announcements',
      onPressed: () => context.push('/announcements'),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: palette.red,
        label: Text('$count'),
        child: const Icon(Icons.notifications_none),
      ),
    );
  }
}

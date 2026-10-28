import 'package:antigua_business_map/features/events/event_widgets.dart';
import 'package:antigua_business_map/features/reviews/reviews_section.dart';
import 'package:antigua_business_map/features/listing/claim_sheet.dart';
import 'package:antigua_business_map/features/listing/request_sheet.dart';
import 'package:antigua_business_map/services/push_service.dart';
import 'package:antigua_business_map/services/requests.dart';
import 'package:antigua_business_map/services/specials.dart';
import 'package:antigua_business_map/services/reviews_repository.dart';
import 'package:antigua_business_map/widgets/offer_code_chip.dart';
import 'package:antigua_business_map/widgets/verified_badge.dart';
import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/listing/widgets/report_wrong_info_sheet.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:antigua_business_map/services/engagement_recorder.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:antigua_business_map/services/ranking_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Provider fetching a single business listing by ID.
///
/// The type is inferred on purpose. Riverpod 3 does not export the family
/// type publicly, and spelling it out needed an import from `riverpod/src/...`,
/// a private path that breaks on any package update.
// ignore: specify_nonobvious_property_types
final singleBusinessProvider = FutureProvider.family<Business?, String>(
  (ref, id) => ref.watch(businessRepositoryProvider).getBusinessById(id),
);

/// How a listing's rating is described.
///
/// Only reviews that passed the visit gate may be called verified. Ratings the
/// team entered from before the app existed have passed no gate, and the
/// listing called them "verified reviews" — the one claim this app sells
/// itself on (handover 6.2). They are counted, and labelled for what they are.
String ratingLabel(Business b) {
  final stats = reviewStats(b);
  final verified = b.liveReviewCount + b.visibleReviews.length;
  final imported = b.seededReviewCount;

  if (imported == 0) {
    return '($verified verified ${verified == 1 ? 'review' : 'reviews'})';
  }
  if (verified == 0) {
    return '(${stats.count} ${stats.count == 1 ? 'rating' : 'ratings'} '
        'from before Dadliplug)';
  }
  return '(${stats.count} ratings, $verified verified)';
}

/// Phase 4 Business Listing Screen.
///
/// Features:
/// - Photo gallery / category gradient hero
/// - Business details, rating, category, and price range
/// - "Closed today" emergency weather/holiday alert
/// - Real-time Antigua opening hours status
/// - Click to call, click to WhatsApp with prefilled text, directions button
/// - "How to find us" island landmark directions
/// - Amenity & payment tags (Cash only, Accepts cards, etc.)
/// - Full weekly hours schedule
/// - Menu / services catalogue
/// - Last-verified date & "Report wrong info" modal
class ListingScreen extends ConsumerWidget {
  const ListingScreen({required this.businessId, super.key});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final businessAsync = ref.watch(singleBusinessProvider(businessId));

    // The listing's own content. Read here rather than inside the content
    // widget, which is a StatefulWidget for the photo carousel and cannot
    // watch providers.
    //
    // Failures degrade to empty rather than taking the listing down. A business
    // with a broken ads query still has an address and hours, and hiding those
    // behind an error would be a worse outcome than omitting its adverts.
    final ads = ref.watch(businessAdsProvider(businessId)).value ?? const [];
    final allAnnouncements = ref.watch(announcementsProvider).value ?? const [];
    final allEvents = ref.watch(upcomingEventsProvider).value ?? const [];

    final now = DateTime.now();
    final liveAds = ads.where((a) => a.isLiveAt(now)).toList(growable: false);
    final latestAnnouncement = allAnnouncements
        .where((a) => a.businessId == businessId)
        .firstOrNull;
    final upcomingEvents = allEvents
        .where((e) => e.businessId == businessId)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: palette.app,
      body: businessAsync.when(
        data: (business) {
          if (business == null) {
            return _NotFoundView(palette: palette);
          }
          return _ListingContent(
            business: business,
            ads: liveAds,
            latestAnnouncement: latestAnnouncement,
            upcomingEvents: upcomingEvents,
            socials: _socialsFor(business),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: palette.red),
        ),
        error: (err, _) => _ErrorView(
          palette: palette,
          onRetry: () => ref.invalidate(singleBusinessProvider(businessId)),
        ),
      ),
    );
  }

  /// Builds the tappable social links for a listing.
  ///
  /// Only links the business actually supplied. No placeholders: an "Instagram"
  /// button that opens nothing is worse than no button, because it tells the
  /// customer the business is reachable there when it is not.
  static List<SocialLink> _socialsFor(Business b) => [
    if (b.website?.isNotEmpty ?? false)
      SocialLink(
        label: 'Website',
        handle: b.website!,
        icon: Icons.language_outlined,
        url: Uri.tryParse(
          b.website!.startsWith('http') ? b.website! : 'https://${b.website}',
        ),
      ),
    if (b.instagram?.isNotEmpty ?? false)
      SocialLink(
        label: 'Instagram',
        handle: '@${b.instagram}',
        icon: Icons.camera_alt_outlined,
        url: Uri.tryParse('https://instagram.com/${b.instagram}'),
      ),
    if (b.facebook?.isNotEmpty ?? false)
      SocialLink(
        label: 'Facebook',
        handle: b.facebook!,
        icon: Icons.thumb_up_outlined,
        url: Uri.tryParse(
          b.facebook!.startsWith('http')
              ? b.facebook!
              : 'https://facebook.com/${b.facebook}',
        ),
      ),
    if (b.tiktok?.isNotEmpty ?? false)
      SocialLink(
        label: 'TikTok',
        handle: '@${b.tiktok}',
        icon: Icons.music_note_outlined,
        url: Uri.tryParse('https://tiktok.com/@${b.tiktok}'),
      ),
  ];
}

/// One tappable social account.
class SocialLink {
  const SocialLink({
    required this.label,
    required this.handle,
    required this.icon,
    required this.url,
  });

  final String label;
  final String handle;
  final IconData icon;

  /// Null when the stored value could not be parsed into a URL. Such a link is
  /// rendered but not tappable, rather than being hidden: the customer should
  /// still see that the business has an account there.
  final Uri? url;
}

class _ListingContent extends ConsumerStatefulWidget {
  const _ListingContent({
    required this.business,
    this.ads = const [],
    this.latestAnnouncement,
    this.upcomingEvents = const [],
    this.socials = const [],
  });

  final Business business;
  final List<BusinessAd> ads;
  final Announcement? latestAnnouncement;
  final List<BusinessEvent> upcomingEvents;
  final List<SocialLink> socials;

  @override
  ConsumerState<_ListingContent> createState() => _ListingContentState();
}

class _ListingContentState extends ConsumerState<_ListingContent> {
  int _activePhotoIndex = 0;

  /// About, Photos or Reviews, as in the design.
  int _tab = 0;

  /// Ads already counted on this visit. A rebuild must not count them again;
  /// the server only deduplicates signed-in viewers, so a guest's every
  /// rebuild would otherwise be a fresh view.
  final Set<String> _countedAds = {};

  EngagementRecorder get _recorder => ref.read(engagementRecorderProvider);

  @override
  void initState() {
    super.initState();
    _recorder.record(widget.business.id, EngagementKind.view);
    _countAds();
  }

  @override
  void didUpdateWidget(covariant _ListingContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ads arrive after the listing itself, so they are counted as they land.
    _countAds();
  }

  void _countAds() {
    for (final ad in widget.ads) {
      if (_countedAds.add(ad.id)) {
        _recorder.record(ad.businessId, EngagementKind.adView, adId: ad.id);
      }
    }
  }

  void _call(Business b) {
    _recorder.record(b.id, EngagementKind.call);
    _launchUrl('tel:${b.phone}');
  }

  void _whatsApp(Business b) {
    _recorder.record(b.id, EngagementKind.whatsapp);
    _launchWhatsApp(b);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.business;
    final liveAds = widget.ads;
    final latestAnnouncement = widget.latestAnnouncement;
    final upcomingEvents = widget.upcomingEvents;
    final socials = widget.socials;
    final palette = context.palette;
    final status = openInfo(b);

    return CustomScrollView(
      slivers: [
        // 1. Hero AppBar with Photos or Gradient
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: palette.surface,
          foregroundColor: palette.ink,
          leading: IconButton(
            icon: CircleAvatar(
              backgroundColor: palette.surface.withValues(alpha: 0.85),
              child: Icon(Icons.arrow_back, color: palette.ink, size: 20),
            ),
            onPressed: () => context.pop(),
          ),
          actions: [
            _AlertButton(businessId: b.id),
            _BookmarkButton(businessId: b.id),
            IconButton(
              icon: CircleAvatar(
                backgroundColor: palette.surface.withValues(alpha: 0.85),
                child: Icon(Icons.share_outlined, color: palette.ink, size: 20),
              ),
              onPressed: () => _shareListing(b),
              tooltip: 'Share on WhatsApp',
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildHeroBackground(b, palette),
          ),
        ),

        // 2. Listing Body
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category + Deal badge + Price range
                Row(
                  children: [
                    _Badge(
                      label: b.category.label,
                      bgColor: palette.surface,
                      fgColor: palette.ink,
                      borderColor: palette.line,
                    ),
                    if (b.priceRange != null && b.priceRange!.isNotEmpty) ...[
                      const SizedBox(width: Insets.sm),
                      _Badge(
                        label: b.priceRange!,
                        bgColor: palette.surface,
                        fgColor: palette.muted,
                        borderColor: palette.line,
                      ),
                    ],
                    if (b.hasOffer) ...[
                      const SizedBox(width: Insets.sm),
                      _Badge(
                        label: 'DEAL',
                        bgColor: palette.goldBg,
                        fgColor: palette.goldInk,
                        icon: Icons.local_offer,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Insets.md),

                // Business Name, beside its category icon (the design's logo
                // circle; a business's own logo comes with photo uploads).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The round logo from the redesign. A business's own logo
                    // arrives with photo uploads; until then, its category.
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: b.category.color,
                        border: Border.all(color: palette.surface, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                      child: Icon(
                        b.category.icon,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: Insets.lg),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              b.name,
                              style: AppText.displayMedium.copyWith(
                                color: palette.ink,
                              ),
                            ),
                          ),
                          if (b.tier.isVerified)
                            const Padding(
                              padding: EdgeInsets.only(left: Insets.sm, top: 6),
                              child: VerifiedBadge(size: 20),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (b.area.isNotEmpty) ...[
                  const SizedBox(height: Insets.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: palette.muted,
                      ),
                      const SizedBox(width: Insets.xs),
                      Text(
                        b.area,
                        style: AppText.titleMedium.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: Insets.md),

                // Rating & Review Count
                if (b.seededRating > 0 || b.totalReviewCount > 0) ...[
                  Row(
                    children: [
                      Icon(Icons.star, size: 20, color: palette.gold),
                      const SizedBox(width: Insets.xs),
                      Text(
                        reviewStats(b).average.toStringAsFixed(1),
                        style: AppText.numeric.copyWith(
                          fontSize: 18,
                          color: palette.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: Insets.xs),
                      Flexible(
                        child: Text(
                          ratingLabel(b),
                          style: AppText.bodyMedium.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                ],

                // Emergency "Closed Today" Banner (Hurricane / Carnival / Holiday)
                if (b.isClosedToday) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Insets.lg),
                    decoration: BoxDecoration(
                      color: palette.badBg,
                      borderRadius: BorderRadius.circular(Corners.md),
                      border: Border.all(
                        color: palette.bad.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: palette.bad,
                          size: 24,
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TEMPORARILY CLOSED TODAY',
                                style: AppText.titleSmall.copyWith(
                                  color: palette.bad,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: Insets.xxs),
                              Text(
                                'This business has posted a temporary closure today '
                                '(e.g. holiday, event, or weather).',
                                style: AppText.bodyMedium.copyWith(
                                  color: palette.bad,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                ] else ...[
                  // Regular Open Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.lg,
                      vertical: Insets.sm,
                    ),
                    decoration: BoxDecoration(
                      color: status.isOpen ? palette.goodBg : palette.badBg,
                      borderRadius: BorderRadius.circular(Corners.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          status.isOpen ? Icons.schedule : Icons.lock_clock,
                          size: 16,
                          color: status.isOpen ? palette.good : palette.bad,
                        ),
                        const SizedBox(width: Insets.xs),
                        Text(
                          status.label,
                          style: AppText.bodyMedium.copyWith(
                            color: status.isOpen ? palette.good : palette.bad,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                ],

                // Today's special. Hidden on a closed day: it cannot be had.
                if (!b.isClosedToday)
                  if (todaysSpecial(b) case final special?) ...[
                    _SpecialBanner(
                      text: special.text,
                      soldOut: special.soldOut,
                    ),
                    const SizedBox(height: Insets.lg),
                  ],

                // Action Buttons Strip: Call, WhatsApp, Directions
                _buildActionStrip(context, b, palette),
                const SizedBox(height: Insets.xl),

                _ListingTabs(
                  selected: _tab,
                  // Reviews it can actually show: verified ones. The
                  // ratings from before Dadliplug have no text to list.
                  reviewCount:
                      ref
                          .watch(reviewsForBusinessProvider(b.id))
                          .value
                          ?.where((r) => r.isVisible)
                          .length ??
                      0,
                  onSelect: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: Insets.xl),

                if (_tab == 0) ...[
                  // Promotional Offer Card
                  if (b.hasOffer) ...[
                    _buildOfferCard(b, palette),
                    const SizedBox(height: Insets.xl),
                  ],

                  // Running advertisements. Above everything else, because an
                  // advertisement is the reason a business is on the app and
                  // burying it under the address would defeat the pitch.
                  if (liveAds.isNotEmpty) ...[
                    _SectionHeader(title: 'Advertisements', palette: palette),
                    const SizedBox(height: Insets.sm),
                    for (final ad in liveAds)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.sm),
                        child: _AdCard(ad: ad),
                      ),
                    const SizedBox(height: Insets.lg),
                  ],

                  // Latest announcement, if there is one. Only the most recent:
                  // a wall of notices buries the business details, and older ones
                  // live on the Notices tab.
                  if (latestAnnouncement case final announcement?) ...[
                    _AnnouncementCard(announcement: announcement),
                    const SizedBox(height: Insets.xl),
                  ],

                  // Description / About
                  if (b.description.isNotEmpty) ...[
                    _SectionHeader(title: 'About', palette: palette),
                    const SizedBox(height: Insets.sm),
                    Text(
                      b.description,
                      style: AppText.bodyLarge.copyWith(color: palette.ink),
                    ),
                    const SizedBox(height: Insets.xl),
                  ],

                  // "How to find us" (Landmark Directions)
                  if (b.howToFindUs != null && b.howToFindUs!.isNotEmpty) ...[
                    _SectionHeader(title: 'How to find us', palette: palette),
                    const SizedBox(height: Insets.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(Insets.lg),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(Corners.md),
                        border: Border.all(color: palette.line),
                        boxShadow: Shadows.card,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.directions_outlined,
                            color: palette.blue,
                            size: 22,
                          ),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: Text(
                              b.howToFindUs!,
                              style: AppText.bodyLarge.copyWith(
                                color: palette.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                  ],

                  // Amenities / Practical Tags (Cash only, Cards, Parking, etc.)
                  if (b.tags.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Practical info & amenities',
                      palette: palette,
                    ),
                    const SizedBox(height: Insets.sm),
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.sm,
                      children: [
                        for (final tag in b.tags)
                          _TagChip(tag: tag, palette: palette),
                      ],
                    ),
                    const SizedBox(height: Insets.xl),
                  ],

                  // Opening Hours Section
                  _SectionHeader(title: 'Hours', palette: palette),
                  const SizedBox(height: Insets.sm),
                  _buildHoursCard(b, palette),
                  const SizedBox(height: Insets.xl),

                  // Menu or Services
                  if (b.menu.isNotEmpty) ...[
                    _SectionHeader(
                      title: b.category == BusinessCategory.food
                          ? 'Menu highlights'
                          : 'Services & pricing',
                      palette: palette,
                    ),
                    const SizedBox(height: Insets.sm),
                    _buildMenuCard(b, palette),
                    const SizedBox(height: Insets.xl),
                  ],

                  // Upcoming events. Only ones still to happen: a listing showing
                  // last month's events reads as unmaintained.
                  if (upcomingEvents.isNotEmpty) ...[
                    _SectionHeader(title: 'Coming up', palette: palette),
                    const SizedBox(height: Insets.sm),
                    for (final event in upcomingEvents)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.sm),
                        child: _EventRow(event: event),
                      ),
                    const SizedBox(height: Insets.lg),
                  ],

                  // Social accounts. Where most Antigua businesses are actually
                  // reachable, so this sits above the address rather than below.
                  if (socials.isNotEmpty) ...[
                    _SectionHeader(title: 'Find them online', palette: palette),
                    const SizedBox(height: Insets.sm),
                    _SocialRow(links: socials),
                    const SizedBox(height: Insets.xl),
                  ],

                  // Address & Location card
                  if (b.address != null && b.address!.isNotEmpty) ...[
                    _SectionHeader(title: 'Location', palette: palette),
                    const SizedBox(height: Insets.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(Insets.lg),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(Corners.md),
                        border: Border.all(color: palette.line),
                        boxShadow: Shadows.card,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            color: palette.muted,
                            size: 22,
                          ),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: Text(
                              b.address!,
                              style: AppText.bodyMedium.copyWith(
                                color: palette.ink,
                              ),
                            ),
                          ),
                          // No Directions button here. Call, WhatsApp and
                          // Directions all live in the action row below, so a
                          // second way to reach directions was the same action
                          // twice on one screen — and the only one of the three
                          // with a duplicate.
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                  ],
                ],

                if (_tab == 1) ...[
                  _PhotoGrid(business: b),
                  const SizedBox(height: Insets.xl),
                ],

                // Reviews: verified visits only (plan.md sections 7 and 8).
                if (_tab == 2) ...[
                  ReviewsSection(
                    businessId: b.id,
                    acceptsReviews: b.acceptsReviews,
                  ),
                  const SizedBox(height: Insets.xl),
                ],

                // Accuracy & Trust Footer
                _buildAccuracyFooter(context, b, palette),
                const SizedBox(height: Insets.giant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBackground(Business b, AppPalette palette) {
    if (b.photos.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: b.photos.length,
            onPageChanged: (i) => setState(() => _activePhotoIndex = i),
            itemBuilder: (context, index) {
              final photo = b.photos[index];
              return photo.url != null && photo.url!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: photo.url!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => ColoredBox(color: palette.line),
                      errorWidget: (_, _, _) =>
                          _buildCategoryPlaceholder(b, palette),
                    )
                  : _buildCategoryPlaceholder(b, palette);
            },
          ),
          if (b.photos.length > 1)
            Positioned(
              bottom: Insets.md,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < b.photos.length; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _activePhotoIndex == i
                            ? palette.surface
                            : palette.surface.withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    }
    return _buildCategoryPlaceholder(b, palette);
  }

  Widget _buildCategoryPlaceholder(Business b, AppPalette palette) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(
              1,
              b.category.hue.toDouble(),
              0.65,
              0.45,
            ).toColor(),
            HSLColor.fromAHSL(
              1,
              (b.category.hue + 25) % 360,
              0.75,
              0.25,
            ).toColor(),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 54, color: palette.surface),
            const SizedBox(height: Insets.sm),
            Text(
              b.category.label,
              style: AppText.titleMedium.copyWith(
                color: palette.surface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionStrip(
    BuildContext context,
    Business b,
    AppPalette palette,
  ) {
    final hasPhone = b.phone != null && b.phone!.isNotEmpty;
    final hasWhatsApp = b.whatsapp != null && b.whatsapp!.isNotEmpty;
    // The map needs coordinates; an address alone cannot be pinned.
    final hasLocation = b.hasLocation;

    // One row of pills, as in the 2026-10-28 redesign: Call filled in the
    // action colour, Message (WhatsApp) and Directions outlined.
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Corners.pill),
    );
    const compact = EdgeInsets.symmetric(horizontal: 8, vertical: 12);
    final outlined = OutlinedButton.styleFrom(
      shape: pill,
      padding: compact,
      foregroundColor: palette.ink,
      side: BorderSide(color: palette.line),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (hasPhone)
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(shape: pill, padding: compact),
                  onPressed: () => _call(b),
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call'),
                ),
              ),
            if (hasPhone && (hasWhatsApp || hasLocation))
              const SizedBox(width: Insets.sm),
            if (hasWhatsApp)
              Expanded(
                child: OutlinedButton.icon(
                  style: outlined,
                  onPressed: () => _whatsApp(b),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('Message'),
                ),
              ),
            if (hasWhatsApp && hasLocation) const SizedBox(width: Insets.sm),
            if (hasLocation)
              Expanded(
                child: OutlinedButton.icon(
                  style: outlined,
                  onPressed: () {
                    _recorder.record(b.id, EngagementKind.directions);
                    context.go('/map?focus=${b.id}');
                  },
                  icon: const Icon(Icons.directions_outlined, size: 18),
                  label: const FittedBox(child: Text('Directions')),
                ),
              ),
          ],
        ),
        if (hasWhatsApp) ...[
          // Quotes for trades, slots for salons, tours, classes, viewings.
          if (requestKindFor(b.category) != null) ...[
            const SizedBox(height: Insets.md),
            OutlinedButton.icon(
              onPressed: () => RequestSheet.show(
                context,
                b,
                onSent: () => _recorder.record(b.id, EngagementKind.whatsapp),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.ink,
                side: BorderSide(color: palette.line),
              ),
              icon: Icon(
                requestKindFor(b.category) == RequestKind.quote
                    ? Icons.request_quote_outlined
                    : Icons.event_available_outlined,
                size: 18,
              ),
              label: Text(requestLabel(b)),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildOfferCard(Business b, AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: palette.goldBg,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: palette.gold.withValues(alpha: 0.5)),
        boxShadow: Shadows.card,
      ),
      child: Row(
        children: [
          Icon(Icons.stars, color: palette.goldInk, size: 28),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPECIAL OFFER',
                  style: AppText.caption.copyWith(
                    color: palette.goldInk,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: Insets.xxs),
                Text(
                  b.offer!,
                  style: AppText.titleMedium.copyWith(
                    color: palette.goldInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  'Mention Dadliplug when visiting to redeem.',
                  style: AppText.caption.copyWith(color: palette.goldInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursCard(Business b, AppPalette palette) {
    final nowWeekday = AntiguaClock.now().weekday;
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: palette.line),
        boxShadow: Shadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            b.hours.label,
            style: AppText.titleSmall.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Insets.md),
          const Divider(height: 1),
          const SizedBox(height: Insets.sm),
          for (var i = 1; i <= 7; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      dayNames[i - 1],
                      style: AppText.bodyMedium.copyWith(
                        color: i == nowWeekday ? palette.ink : palette.muted,
                        fontWeight: i == nowWeekday
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (i == nowWeekday)
                    Container(
                      margin: const EdgeInsets.only(right: Insets.sm),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.xs,
                        vertical: Insets.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: palette.app,
                        borderRadius: BorderRadius.circular(Corners.sm),
                      ),
                      child: Text(
                        'TODAY',
                        style: AppText.caption.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: palette.muted,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    b.hours.days.contains(i)
                        ? '${formatHour(b.hours.opensAt)} – ${formatHour(b.hours.closesAt)}'
                        : 'Closed',
                    style: AppText.numeric.copyWith(
                      color: b.hours.days.contains(i)
                          ? palette.ink
                          : palette.muted,
                      fontWeight: i == nowWeekday
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuCard(Business b, AppPalette palette) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: palette.line),
        boxShadow: Shadows.card,
      ),
      child: Column(
        children: [
          for (var i = 0; i < b.menu.length; i++) ...[
            Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.menu[i].name ?? 'Item',
                          style: AppText.titleSmall.copyWith(
                            color: palette.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (b.menu[i].detail != null &&
                            b.menu[i].detail!.isNotEmpty) ...[
                          const SizedBox(height: Insets.xxs),
                          Text(
                            b.menu[i].detail!,
                            style: AppText.bodyMedium.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (b.menu[i].price != null &&
                      b.menu[i].price!.isNotEmpty) ...[
                    const SizedBox(width: Insets.md),
                    Text(
                      b.menu[i].price!,
                      style: AppText.numeric.copyWith(
                        color: palette.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (i < b.menu.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildAccuracyFooter(
    BuildContext context,
    Business b,
    AppPalette palette,
  ) {
    // No date means nobody has verified it. Showing today's date instead, as
    // this used to, invented a verification that never happened.
    final verifiedDate = b.lastVerifiedAt;
    final verifiedLabel = verifiedDate == null
        ? 'Not yet verified'
        : 'Last verified ${DateFormat('MMM d, yyyy').format(verifiedDate.toLocal())}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 18, color: palette.muted),
              const SizedBox(width: Insets.xs),
              Text(
                verifiedLabel,
                style: AppText.caption.copyWith(color: palette.muted),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Notice something incorrect? We manually maintain all listings in Antigua.',
            style: AppText.bodyMedium.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.md),
          OutlinedButton.icon(
            onPressed: () => ReportWrongInfoSheet.show(context, b),
            icon: const Icon(Icons.edit_note, size: 18),
            label: const Text('Report wrong info'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: palette.line),
              foregroundColor: palette.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Corners.sm),
              ),
            ),
          ),
          const SizedBox(height: Insets.sm),
          ClaimPrompt(business: b),
        ],
      ),
    );
  }

  static Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static Future<void> _launchWhatsApp(Business b) async {
    final rawNumber = b.whatsapp ?? '';
    final clean = rawNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final prefilled = Uri.encodeComponent(
      'Hi, I found you on Dadliplug (${b.name}). Are you open today?',
    );
    final uri = Uri.parse('https://wa.me/$clean?text=$prefilled');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Shares to WhatsApp, where most word of mouth on the island runs
  /// (plan.md 11), with the listing's public page so WhatsApp shows a
  /// preview card.
  static Future<void> _shareListing(Business b) async {
    final lines = [
      '${b.name}${b.area.isEmpty ? '' : ' — ${b.area}'}',
      if (b.phone?.isNotEmpty ?? false) 'Call: ${b.phone}',
      if (b.howToFindUs?.isNotEmpty ?? false) b.howToFindUs!,
      // The link makes WhatsApp show a preview card with the photo, and
      // opens the listing's public page for people without the app.
      AppConfig.publicListingUrl(b.id),
    ];
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(lines.join('\n'))}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// One running advertisement on the listing.
///
/// The view count is deliberately not shown here. It is the business's number,
/// not the customer's, and putting "412 views" on the public listing would be
/// competitive information the owner did not agree to publish.
class _AdCard extends StatelessWidget {
  const _AdCard({required this.ad});

  final BusinessAd ad;

  @override
  Widget build(BuildContext context) {
    // Opens the ad's own page: to share it, or claim the deal.
    return GestureDetector(
      onTap: () => context.push('/ad/${ad.id}'),
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: palette.red.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ad.imageUrl?.isNotEmpty ?? false) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(Corners.md),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: ad.imageUrl!,
                  fit: BoxFit.cover,
                  // A broken picture link hides itself rather than leaving
                  // a grey box on the listing.
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: Insets.sm),
          ],
          Row(
            children: [
              Icon(Icons.campaign_outlined, size: 16, color: palette.red),
              const SizedBox(width: Insets.xs),
              Text(
                ad.isOffer ? 'OFFER' : 'ADVERTISEMENT',
                style: AppText.sectionLabel.copyWith(color: palette.red),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            ad.title,
            style: AppText.titleMedium.copyWith(color: palette.ink),
          ),
          if (ad.body.isNotEmpty) ...[
            const SizedBox(height: Insets.xs),
            Text(
              ad.body,
              style: AppText.bodyMedium.copyWith(color: palette.ink),
            ),
          ],
          if (ad.isOffer) ...[
            const SizedBox(height: Insets.sm),
            OfferCodeChip(code: ad.offerCode!),
          ],
          if (ad.linkUrl?.isNotEmpty ?? false) ...[
            const SizedBox(height: Insets.sm),
            Builder(
              builder: (context) {
                // Only opens when the stored value parses as a web address. A
                // malformed URL is shown as plain text rather than as a link
                // that throws when tapped — the old null check could never be
                // false here, so it guarded nothing.
                final uri = Uri.tryParse(ad.linkUrl!);
                final usable =
                    uri != null &&
                    (uri.scheme == 'http' || uri.scheme == 'https');
                return InkWell(
                  onTap: usable
                      ? () =>
                            launchUrl(uri, mode: LaunchMode.externalApplication)
                      : null,
                  child: Text(
                    ad.linkUrl!,
                    style: AppText.bodyMedium.copyWith(
                      color: usable ? palette.red : palette.muted,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// The most recent announcement, surfaced on the listing so a closure notice
/// is visible to someone who never opens the Notices tab.
class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: palette.goldBg,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: palette.gold),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign_outlined, size: 18, color: palette.goldInk),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement.title,
                  style: AppText.titleMedium.copyWith(color: palette.goldInk),
                ),
                if (announcement.body.isNotEmpty) ...[
                  const SizedBox(height: Insets.xs),
                  Text(
                    announcement.body,
                    style: AppText.bodyMedium.copyWith(color: palette.ink),
                  ),
                ],
                const SizedBox(height: Insets.xs),
                Text(
                  DateFormat.MMMd().format(announcement.createdAt.toLocal()),
                  style: AppText.caption.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An upcoming event on the listing.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final BusinessEvent event;

  @override
  Widget build(BuildContext context) => EventRow(event: event);
}

/// The business's social accounts.
class _SocialRow extends StatelessWidget {
  const _SocialRow({required this.links});

  final List<SocialLink> links;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: [
        for (final link in links)
          InkWell(
            onTap: link.url == null
                ? null
                : () => launchUrl(
                    link.url!,
                    mode: LaunchMode.externalApplication,
                  ),
            borderRadius: BorderRadius.circular(Corners.md),
            child: Container(
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(Corners.md),
                border: Border.all(color: palette.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(link.icon, size: 18, color: palette.red),
                  const SizedBox(width: Insets.sm),
                  Text(
                    link.label,
                    style: AppText.labelMedium.copyWith(color: palette.ink),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Save a business. The same relationship as following, so a bookmarked
/// business's announcements reach the Notices tab (plan.md 4).
///
/// The Bookmarks tab told customers to "tap the bookmark on any business",
/// and no business had one.
class _BookmarkButton extends ConsumerStatefulWidget {
  const _BookmarkButton({required this.businessId});

  final String businessId;

  @override
  ConsumerState<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends ConsumerState<_BookmarkButton> {
  bool _busy = false;

  Future<void> _toggle(bool saved) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(businessContentRepositoryProvider)
          .setFollow(businessId: widget.businessId, follow: !saved);
      ref.invalidate(followedBusinessIdsProvider);
    } on NotSignedInException {
      if (mounted) await context.push<void>('/sign-in');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save. Check your connection.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final saved =
        ref
            .watch(followedBusinessIdsProvider)
            .value
            ?.contains(
              widget.businessId,
            ) ??
        false;

    return IconButton(
      tooltip: saved ? 'Remove from Saved' : 'Save',
      onPressed: _busy ? null : () => _toggle(saved),
      icon: CircleAvatar(
        backgroundColor: palette.surface.withValues(alpha: 0.85),
        child: Icon(
          saved ? Icons.favorite : Icons.favorite_border,
          color: saved ? palette.red : palette.ink,
          size: 20,
        ),
      ),
    );
  }
}

/// Opt in to announcement alerts from this business (plan.md 4: follow,
/// with notification opt-in). Separate from saving: saving is a bookmark,
/// the bell is a request to be told. Push delivery needs Firebase; until
/// then the alert shows as a badge on Home and in the Following feed.
class _AlertButton extends ConsumerStatefulWidget {
  const _AlertButton({required this.businessId});

  final String businessId;

  @override
  ConsumerState<_AlertButton> createState() => _AlertButtonState();
}

class _AlertButtonState extends ConsumerState<_AlertButton> {
  bool _busy = false;

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(businessContentRepositoryProvider)
          .setAlerts(businessId: widget.businessId, notify: !on);
      ref
        ..invalidate(alertBusinessIdsProvider)
        ..invalidate(followedBusinessIdsProvider);
      if (!on) await PushService.enable();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              on
                  ? 'Alerts off for this business.'
                  : 'You will be told when they post an announcement.',
            ),
          ),
        );
      }
    } on NotSignedInException {
      if (mounted) await context.push<void>('/sign-in');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not change alerts.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final on =
        ref
            .watch(alertBusinessIdsProvider)
            .value
            ?.contains(widget.businessId) ??
        false;

    return IconButton(
      tooltip: on ? 'Turn off alerts' : 'Alert me to announcements',
      onPressed: _busy ? null : () => _toggle(on),
      icon: CircleAvatar(
        backgroundColor: palette.surface.withValues(alpha: 0.85),
        child: Icon(
          on ? Icons.notifications_active : Icons.notifications_none,
          color: on ? palette.red : palette.ink,
          size: 20,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.palette});

  final String title;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppText.titleLarge.copyWith(
        color: palette.ink,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.bgColor,
    required this.fgColor,
    this.borderColor,
    this.icon,
  });

  final String label;
  final Color bgColor;
  final Color fgColor;
  final Color? borderColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: Insets.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(Corners.sm),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fgColor),
            const SizedBox(width: Insets.xxs),
          ],
          Text(
            label,
            style: AppText.caption.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.palette});

  final String tag;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final label = KnownBusinessTags.labelFor(tag);
    final icon = _iconFor(tag);

    // An icon over its label, as in the design's amenities row.
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.app,
              borderRadius: BorderRadius.circular(Corners.xl),
              border: Border.all(color: palette.line),
            ),
            child: Icon(icon, size: 22, color: palette.ink),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: AppText.caption.copyWith(color: palette.ink),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String tag) => switch (tag) {
    KnownBusinessTags.cashOnly => Icons.payments_outlined,
    KnownBusinessTags.acceptsCards => Icons.credit_card,
    KnownBusinessTags.acceptsUsd => Icons.attach_money,
    KnownBusinessTags.parking => Icons.local_parking,
    KnownBusinessTags.accessibility => Icons.accessible,
    KnownBusinessTags.familyFriendly => Icons.family_restroom,
    KnownBusinessTags.wifi => Icons.wifi,
    KnownBusinessTags.outdoorSeating => Icons.deck,
    _ => Icons.check_circle_outline,
  };
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.app,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 48, color: palette.line),
            const SizedBox(height: Insets.lg),
            Text(
              'Business not found',
              style: AppText.titleLarge.copyWith(color: palette.ink),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'This listing may have expired or been delisted.',
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.palette, required this.onRetry});

  final AppPalette palette;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.app,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: palette.bad),
            const SizedBox(height: Insets.lg),
            Text(
              'Could not load listing',
              style: AppText.titleLarge.copyWith(color: palette.ink),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'Check your connection and try again.',
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// About · Photos · Reviews, underlined in red like the design.
class _ListingTabs extends StatelessWidget {
  const _ListingTabs({
    required this.selected,
    required this.reviewCount,
    required this.onSelect,
  });

  final int selected;
  final int reviewCount;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final labels = [
      'About',
      'Photos',
      if (reviewCount > 0) 'Reviews ($reviewCount)' else 'Reviews',
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: Insets.lg),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == selected ? palette.red : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: AppText.labelLarge.copyWith(
                      color: i == selected ? palette.red : palette.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Every photo the listing has, with its caption (and so its credit).
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final photos = business.photos
        .where((p) => p.url?.isNotEmpty ?? false)
        .toList();

    if (photos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.giant),
        child: Text(
          'No photos yet. The business or the Dadliplug team adds them.',
          textAlign: TextAlign.center,
          style: AppText.bodyMedium.copyWith(color: palette.muted),
        ),
      );
    }

    return Column(
      children: [
        for (final photo in photos) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(Corners.xl),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CachedNetworkImage(
                imageUrl: photo.url!,
                fit: BoxFit.cover,
                placeholder: (_, _) => ColoredBox(color: palette.line),
                errorWidget: (_, _, _) => ColoredBox(color: palette.line),
              ),
            ),
          ),
          if (photo.caption?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: Text(
                photo.caption!,
                style: AppText.caption.copyWith(color: palette.muted),
              ),
            ),
          const SizedBox(height: Insets.lg),
        ],
      ],
    );
  }
}

/// "Today's special" on a listing, struck through once sold out.
class _SpecialBanner extends StatelessWidget {
  const _SpecialBanner({required this.text, required this.soldOut});

  final String text;
  final bool soldOut;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: soldOut ? palette.surface : palette.warnBg,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: soldOut ? palette.line : palette.warn),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_dining,
            size: 22,
            color: soldOut ? palette.muted : palette.warn,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  soldOut ? "TODAY'S SPECIAL: SOLD OUT" : "TODAY'S SPECIAL",
                  style: AppText.labelMedium.copyWith(
                    color: soldOut ? palette.muted : palette.warn,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: Insets.xxs),
                Text(
                  text,
                  style: AppText.bodyLarge.copyWith(
                    color: soldOut ? palette.muted : palette.ink,
                    decoration: soldOut ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/listing/widgets/report_wrong_info_sheet.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:riverpod/src/providers/future_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Provider fetching a single business listing by ID.
final FutureProviderFamily<Business?, String> singleBusinessProvider =
    FutureProvider.family<Business?, String>((
      ref,
      id,
    ) async {
      final repo = ref.watch(businessRepositoryProvider);
      return repo.getBusinessById(id);
    });

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

    return Scaffold(
      backgroundColor: palette.app,
      body: businessAsync.when(
        data: (business) {
          if (business == null) {
            return _NotFoundView(palette: palette);
          }
          return _ListingContent(business: business);
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
}

class _ListingContent extends StatefulWidget {
  const _ListingContent({required this.business});

  final Business business;

  @override
  State<_ListingContent> createState() => _ListingContentState();
}

class _ListingContentState extends State<_ListingContent> {
  int _activePhotoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final b = widget.business;
    final palette = context.palette;
    final status = openInfo(b);

    return CustomScrollView(
      slivers: [
        // 1. Hero AppBar with Photos or Gradient
        SliverAppBar(
          expandedHeight: b.photos.isNotEmpty ? 280 : 200,
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
            IconButton(
              icon: CircleAvatar(
                backgroundColor: palette.surface.withValues(alpha: 0.85),
                child: Icon(Icons.share_outlined, color: palette.ink, size: 20),
              ),
              onPressed: () => _shareListing(context, b),
              tooltip: 'Share listing',
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

                // Business Name
                Text(
                  b.name,
                  style: AppText.displayMedium.copyWith(color: palette.ink),
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
                        b.seededRating.toStringAsFixed(1),
                        style: AppText.numeric.copyWith(
                          fontSize: 18,
                          color: palette.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: Insets.xs),
                      Text(
                        '(${b.totalReviewCount} verified reviews)',
                        style: AppText.bodyMedium.copyWith(
                          color: palette.muted,
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

                // Action Buttons Strip: Call, WhatsApp, Directions
                _buildActionStrip(context, b, palette),
                const SizedBox(height: Insets.xl),

                // Promotional Offer Card
                if (b.hasOffer) ...[
                  _buildOfferCard(b, palette),
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
    final hasLocation =
        b.hasLocation || (b.address != null && b.address!.isNotEmpty);

    return Row(
      children: [
        if (hasPhone)
          Expanded(
            child: _ActionTile(
              icon: Icons.phone,
              label: 'Call',
              color: palette.ink,
              onTap: () => _launchUrl('tel:${b.phone}'),
            ),
          ),
        if (hasPhone && (hasWhatsApp || hasLocation))
          const SizedBox(width: Insets.sm),
        if (hasWhatsApp)
          Expanded(
            child: _ActionTile(
              icon: Icons.chat,
              label: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: () => _launchWhatsApp(b),
            ),
          ),
        if (hasWhatsApp && hasLocation) const SizedBox(width: Insets.sm),
        if (hasLocation)
          Expanded(
            child: _ActionTile(
              icon: Icons.directions,
              label: 'Directions',
              color: palette.blue,
              onTap: () => _openDirections(b),
            ),
          ),
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
                  'Mention IslandAds when visiting to redeem.',
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
    final verifiedDate = b.lastVerifiedAt ?? DateTime.now();
    final formattedDate = DateFormat('MMM d, yyyy').format(verifiedDate);

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
                'Data verified: $formattedDate',
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
      'Hi, I found you on IslandAds (${b.name}). Are you open today?',
    );
    final uri = Uri.parse('https://wa.me/$clean?text=$prefilled');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _openDirections(Business b) async {
    if (b.hasLocation) {
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${b.latitude},${b.longitude}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (b.address != null && b.address!.isNotEmpty) {
      final query = Uri.encodeComponent('${b.address}, Antigua');
      final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  static void _shareListing(BuildContext context, Business b) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing ${b.name} on IslandAds'),
        duration: const Duration(seconds: 2),
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

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.pill),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.ink),
          const SizedBox(width: Insets.xs),
          Text(
            label,
            style: AppText.bodyMedium.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w500,
            ),
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Corners.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(Corners.md),
          border: Border.all(color: palette.line),
          boxShadow: Shadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: Insets.xs),
            Text(
              label,
              style: AppText.labelMedium.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
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

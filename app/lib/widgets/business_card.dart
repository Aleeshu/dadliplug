import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/ranking_service.dart';
import 'package:antigua_business_map/widgets/business_image.dart';
import 'package:antigua_business_map/widgets/business_list_row.dart';
import 'package:antigua_business_map/widgets/offer_code_chip.dart';
import 'package:antigua_business_map/widgets/verified_badge.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A business as a photo card: Featured on Home, and anywhere a grid of
/// businesses reads better than a list.
///
/// Rating is shown only when there is one, and distance only when the viewer
/// has shared a position, so the card never displays a number it does not
/// have.
class BusinessCard extends StatelessWidget {
  const BusinessCard({
    required this.business,
    this.width = 170,
    this.distanceKm,
    this.hasOffer = false,
    super.key,
  });

  final Business business;
  final double width;
  final double? distanceKm;

  /// Has a running offer: shows the OFFER tag on the photo.
  final bool hasOffer;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final stats = reviewStats(business);
    final badge = VerifiedBadge.forBusiness(business, size: 14);

    return SizedBox(
      width: width,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.xxl),
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: () => context.push('/listing/${business.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BusinessImage(business: business),
                    if (hasOffer)
                      const Positioned(
                        top: Insets.md,
                        left: Insets.md,
                        child: OfferBadge(),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Insets.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            business.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.titleSmall.copyWith(
                              color: palette.ink,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: Insets.xs),
                          badge,
                        ],
                      ],
                    ),
                    const SizedBox(height: Insets.xxs),
                    Text(
                      business.category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: palette.muted),
                    ),
                    const SizedBox(height: Insets.xs),
                    Row(
                      children: [
                        if (stats.count > 0) ...[
                          Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: palette.gold,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${stats.average.toStringAsFixed(1)} '
                            '(${stats.count})',
                            style: AppText.caption.copyWith(
                              color: palette.ink,
                            ),
                          ),
                        ],
                        if (stats.count > 0 && distanceKm != null)
                          const SizedBox(width: Insets.md),
                        if (distanceKm != null) ...[
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: palette.muted,
                          ),
                          Text(
                            formatDistance(distanceKm!),
                            style: AppText.caption.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

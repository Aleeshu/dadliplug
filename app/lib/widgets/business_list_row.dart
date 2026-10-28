import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:antigua_business_map/services/ranking_service.dart';
import 'package:antigua_business_map/widgets/business_image.dart';
import 'package:antigua_business_map/widgets/save_heart.dart';
import 'package:antigua_business_map/widgets/verified_badge.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One business in a list: the Businesses tab, search, the Featured page,
/// collections. The 2026-10-28 redesign: photo, name, rating, distance, tags,
/// an Open Now pill and a heart.
///
/// The rating is left out entirely when there are no ratings, rather than
/// shown as "0.0", which reads as a bad business instead of a new one.
class BusinessListRow extends StatelessWidget {
  const BusinessListRow({
    required this.business,
    this.distanceKm,
    this.onOpen,
    super.key,
  });

  final Business business;

  /// From the viewer, when "near me" has a position. Null otherwise.
  final double? distanceKm;

  /// Called before the listing opens, e.g. to count a view.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final open = openInfo(business);
    final stats = reviewStats(business);
    final badge = VerifiedBadge.forBusiness(business, size: 14);

    final tags = [
      business.category.shortLabel,
      if (business.area.isNotEmpty) business.area,
    ];

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(Corners.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(Corners.xl),
        onTap: () {
          onOpen?.call();
          context.push('/listing/${business.id}');
        },
        child: Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Corners.xl),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Corners.md),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: BusinessImage(business: business, iconSize: 30),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
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
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (stats.count > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFFFC72C),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${stats.average.toStringAsFixed(1)} '
                            '(${stats.count})',
                            style: AppText.caption.copyWith(
                              color: palette.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: Insets.sm),
                        ],
                        if (distanceKm != null) ...[
                          Icon(
                            Icons.near_me_outlined,
                            size: 13,
                            color: palette.muted,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            formatDistance(distanceKm!),
                            style: AppText.caption.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: Insets.xs),
                    Wrap(
                      spacing: Insets.xs,
                      runSpacing: Insets.xs,
                      children: [
                        for (final t in tags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: palette.app,
                              borderRadius: BorderRadius.circular(
                                Corners.pill,
                              ),
                              border: Border.all(color: palette.line),
                            ),
                            child: Text(
                              t,
                              maxLines: 1,
                              style: AppText.caption.copyWith(
                                color: palette.muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SaveHeart(businessId: business.id),
                  const SizedBox(height: Insets.lg),
                  _OpenPill(isOpen: open.isOpen),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenPill extends StatelessWidget {
  const _OpenPill({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = isOpen ? palette.good : palette.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOpen ? palette.goodBg : palette.app,
        borderRadius: BorderRadius.circular(Corners.pill),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 4),
          Text(
            isOpen ? 'Open Now' : 'Closed',
            style: AppText.caption.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// "350 m", "2.4 km", "18 km". Coarse location cannot justify more precision.
String formatDistance(double km) {
  if (km < 1) {
    final metres = ((km * 1000) / 50).round() * 50;
    return metres < 50 ? 'Under 50 m' : '$metres m';
  }
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}

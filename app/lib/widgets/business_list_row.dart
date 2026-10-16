import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:antigua_business_map/services/ranking_service.dart';
import 'package:antigua_business_map/widgets/verified_badge.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One business in a list: search results, the Featured page.
///
/// Shows what decides whether someone goes: open now, how far, and the
/// rating. The rating is left out entirely when there are no ratings, rather
/// than shown as "0.0", which reads as a bad business instead of a new one.
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
    final badge = VerifiedBadge.forBusiness(business);

    final details = [
      business.category.shortLabel,
      if (business.area.isNotEmpty) business.area,
      if (distanceKm != null) formatDistance(distanceKm!),
    ].join(' · ');

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(Corners.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Corners.md),
        onTap: () {
          onOpen?.call();
          context.push('/listing/${business.id}');
        },
        child: Container(
          padding: const EdgeInsets.all(Insets.xl),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Corners.md),
            border: Border.all(color: palette.line),
          ),
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
                      style: AppText.titleMedium.copyWith(color: palette.ink),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: Insets.xs),
                    badge,
                  ],
                  const Spacer(),
                  if (stats.count > 0)
                    Text(
                      '★ ${stats.average.toStringAsFixed(1)}',
                      style: AppText.rating.copyWith(color: palette.ink),
                    ),
                ],
              ),
              const SizedBox(height: Insets.xxs),
              Text(
                details,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(color: palette.muted),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                open.label,
                style: AppText.caption.copyWith(
                  color: open.isOpen ? palette.good : palette.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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

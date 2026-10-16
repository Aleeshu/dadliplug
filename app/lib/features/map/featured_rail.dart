import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:antigua_business_map/widgets/verified_badge.dart';
import 'package:flutter/material.dart';

/// Featured businesses along the bottom of the map, in earned order.
///
/// Tapping a card selects the business on the map, the same as tapping its
/// pin, so the viewer sees where it is before deciding to open it.
class FeaturedRail extends StatelessWidget {
  const FeaturedRail({
    required this.businesses,
    required this.onSelect,
    required this.onSeeAll,
    super.key,
  });

  /// Already filtered to Featured and sorted by rank.
  final List<Business> businesses;
  final ValueChanged<Business> onSelect;
  final VoidCallback onSeeAll;

  /// Total height, so the map screen can lift the recentre button above it.
  static const double height = 124;
  static const double _cardWidth = 210;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.huge),
            child: Row(
              children: [
                _Pill(
                  child: Text(
                    'FEATURED',
                    style: AppText.sectionLabel.copyWith(color: palette.ink),
                  ),
                ),
                const Spacer(),
                _Pill(
                  child: InkWell(
                    onTap: onSeeAll,
                    child: Text(
                      'See all',
                      style: AppText.labelMedium.copyWith(color: palette.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Insets.huge),
              itemCount: businesses.length,
              separatorBuilder: (_, _) => const SizedBox(width: Insets.md),
              itemBuilder: (context, i) => _RailCard(
                business: businesses[i],
                width: _cardWidth,
                onTap: () => onSelect(businesses[i]),
              ),
            ),
          ),
          const SizedBox(height: Insets.md),
        ],
      ),
    );
  }
}

/// A small solid backing so labels stay legible over any map tile.
class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xxs,
      ),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(Corners.pill),
      ),
      child: child,
    );
  }
}

class _RailCard extends StatelessWidget {
  const _RailCard({
    required this.business,
    required this.width,
    required this.onTap,
  });

  final Business business;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final open = openInfo(business);
    final badge = VerifiedBadge.forBusiness(business, size: 14);

    return SizedBox(
      width: width,
      child: Material(
        color: palette.surface,
        elevation: 2,
        borderRadius: BorderRadius.circular(Corners.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(Corners.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        business.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.titleSmall.copyWith(color: palette.ink),
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
                  [
                    business.category.shortLabel,
                    if (business.area.isNotEmpty) business.area,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: palette.muted),
                ),
                const SizedBox(height: Insets.xxs),
                Text(
                  open.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                    color: open.isOpen ? palette.good : palette.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

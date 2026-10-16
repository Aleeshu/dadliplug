import 'package:antigua_business_map/widgets/business_image.dart';
import 'package:antigua_business_map/widgets/verified_badge.dart';
import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/engagement_recorder.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:antigua_business_map/services/ranking_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Floating bottom preview card displayed when a user taps a business marker on the map.
class BusinessPreviewCard extends StatelessWidget {
  const BusinessPreviewCard({
    required this.business,
    required this.onClose,
    this.onEngagement,
    super.key,
  });

  final Business business;
  final VoidCallback onClose;

  /// Told when the customer calls or messages from the card, so the tap is
  /// counted for the business's report. A callback rather than a provider
  /// read, so the card stays a plain widget.
  final void Function(EngagementKind kind)? onEngagement;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = openInfo(business);

    return Container(
      margin: const EdgeInsets.all(Insets.lg),
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.xl),
        border: Border.all(color: palette.line),
        boxShadow: Shadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Category pill + Offer badge + Close button
          Row(
            children: [
              _Badge(
                label: business.category.label,
                bgColor: palette.app,
                fgColor: palette.muted,
              ),
              if (business.hasOffer) ...[
                const SizedBox(width: Insets.sm),
                _Badge(
                  label: 'DEAL',
                  bgColor: palette.goldBg,
                  fgColor: palette.goldInk,
                  icon: Icons.local_offer,
                ),
              ],
              const Spacer(),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 20),
                color: palette.muted,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),

          // Photo beside the name and area, as in the design's map card.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Corners.lg),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: BusinessImage(business: business, iconSize: 26),
                ),
              ),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            business.name,
                            style: AppText.titleLarge.copyWith(
                              color: palette.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (business.tier.isVerified) ...[
                          const SizedBox(width: Insets.xs),
                          const VerifiedBadge(size: 17),
                        ],
                      ],
                    ),
                    if (business.area.isNotEmpty) ...[
                      const SizedBox(height: Insets.xxs),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: palette.muted,
                          ),
                          const SizedBox(width: Insets.xxs),
                          Text(
                            business.area,
                            style: AppText.bodyMedium.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),

          // Promotional offer banner if available
          if (business.hasOffer) ...[
            Container(
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(
                color: palette.goldBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(Corners.md),
                border: Border.all(color: palette.gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.stars, size: 16, color: palette.goldInk),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      business.offer!,
                      style: AppText.labelMedium.copyWith(
                        color: palette.goldInk,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
          ],

          // Hours status & Rating row
          Row(
            children: [
              // Open status pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.xs,
                ),
                decoration: BoxDecoration(
                  color: status.isOpen ? palette.goodBg : palette.badBg,
                  borderRadius: BorderRadius.circular(Corners.sm),
                ),
                child: Text(
                  status.label,
                  style: AppText.caption.copyWith(
                    color: status.isOpen ? palette.good : palette.bad,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),

              // Rating
              // The blended average, not the seeded figure alone, so live
              // reviews move the stars once they exist.
              if (reviewStats(business).count > 0) ...[
                Icon(Icons.star, size: 16, color: palette.gold),
                const SizedBox(width: Insets.xxs),
                Text(
                  reviewStats(business).average.toStringAsFixed(1),
                  style: AppText.numeric.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: Insets.xxs),
                Text(
                  '(${business.totalReviewCount})',
                  style: AppText.caption.copyWith(color: palette.muted),
                ),
              ],
            ],
          ),
          const SizedBox(height: Insets.xl),

          // Action Buttons: Call, WhatsApp, View Details
          Row(
            children: [
              if (business.phone != null && business.phone!.isNotEmpty) ...[
                _ActionButton(
                  icon: Icons.phone,
                  label: 'Call',
                  onTap: () {
                    onEngagement?.call(EngagementKind.call);
                    _launchUrl('tel:${business.phone}');
                  },
                ),
                const SizedBox(width: Insets.sm),
              ],
              if (business.whatsapp != null &&
                  business.whatsapp!.isNotEmpty) ...[
                _ActionButton(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  onTap: () {
                    onEngagement?.call(EngagementKind.whatsapp);
                    _launchWhatsApp(business.whatsapp!);
                  },
                ),
                const SizedBox(width: Insets.sm),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/listing/${business.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.ink,
                    foregroundColor: palette.app,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Corners.md),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: Insets.md),
                  ),
                  child: const Text('View Listing'),
                ),
              ),
            ],
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

  static Future<void> _launchWhatsApp(String rawNumber) async {
    final clean = rawNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.bgColor,
    required this.fgColor,
    this.icon,
  });

  final String label;
  final Color bgColor;
  final Color fgColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: Insets.xxs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(Corners.sm),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: palette.ink),
      label: Text(
        label,
        style: AppText.labelMedium.copyWith(color: palette.ink),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: palette.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.md),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.md,
        ),
      ),
    );
  }
}

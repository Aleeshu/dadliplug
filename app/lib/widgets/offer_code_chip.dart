import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:flutter/material.dart';

/// An offer's code, as the customer shows or says it at the till.
///
/// Large and spaced out: it is read across a counter, often off a phone held
/// up to someone else.
class OfferCodeChip extends StatelessWidget {
  const OfferCodeChip({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xl,
        vertical: Insets.md,
      ),
      decoration: BoxDecoration(
        color: palette.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Corners.lg),
        border: Border.all(color: palette.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_offer, size: 18, color: palette.red),
          const SizedBox(width: Insets.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Say this code at the till',
                style: AppText.caption.copyWith(color: palette.muted),
              ),
              Text(
                code,
                style: AppText.numericLarge.copyWith(
                  color: palette.ink,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The small red "OFFER" tag on a business card or row.
class OfferBadge extends StatelessWidget {
  const OfferBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: BoxDecoration(
        color: palette.red,
        borderRadius: BorderRadius.circular(Corners.sm),
      ),
      child: Text(
        'OFFER',
        style: AppText.caption.copyWith(
          color: palette.onRed,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

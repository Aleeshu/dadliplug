import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:flutter/material.dart';

/// The badge next to a Featured business's name.
///
/// It says the business pays for a Featured listing. It is never a statement
/// about quality or reviews (plan.md section 3), so the tooltip and the
/// screen-reader label say "paid", not "trusted" or "recommended". What
/// "verified" should mean is still an open decision in plan.md section 15.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({this.size = 15, super.key});

  final double size;

  static const String meaning =
      'Premium listing. The business pays for this placement; it is not a '
      'rating of quality.';

  /// The badge for [business], or nothing when its tier does not carry one.
  static Widget? forBusiness(Business business, {double size = 15}) =>
      business.tier.isVerified ? VerifiedBadge(size: size) : null;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: meaning,
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: meaning,
        child: Icon(Icons.verified, size: size, color: context.palette.red),
      ),
    );
  }
}

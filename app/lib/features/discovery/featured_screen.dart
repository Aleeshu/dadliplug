import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/services/listing_filter_service.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/widgets/business_list_row.dart';
import 'package:antigua_business_map/widgets/verified_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Featured page: Featured subscribers only, in earned order.
///
/// Order comes from the ranking, never from price or signup date, and the
/// page says so. The badge is explained as a paid placement, because a
/// customer will otherwise read it as an endorsement (plan.md section 3).
class FeaturedScreen extends ConsumerWidget {
  const FeaturedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final businessesAsync = ref.watch(businessListProvider);

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        backgroundColor: palette.app,
        title: const Text('Featured'),
      ),
      body: businessesAsync.when(
        data: (all) {
          final featured = featuredBusinesses(all);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Insets.huge,
              Insets.xs,
              Insets.huge,
              Insets.giant,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: VerifiedBadge(),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      'These businesses pay for the Premium plan. They are '
                      'ordered by ratings and activity, not by what they '
                      'pay.',
                      style: AppText.bodyMedium.copyWith(color: palette.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xl),
              if (featured.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Insets.giant),
                  child: Text(
                    'No Featured businesses yet.',
                    textAlign: TextAlign.center,
                    style: AppText.bodyMedium.copyWith(color: palette.muted),
                  ),
                )
              else
                for (final b in featured) ...[
                  BusinessListRow(business: b),
                  const SizedBox(height: Insets.md),
                ],
            ],
          );
        },
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (err, _) {
          debugPrint('Featured: listings failed to load: $err');
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load Featured businesses.',
                  style: AppText.bodyMedium.copyWith(color: palette.muted),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(businessListProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

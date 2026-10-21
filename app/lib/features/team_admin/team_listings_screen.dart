import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Every listing, delisted ones included, for the team.
final teamListingsProvider = FutureProvider<List<Business>>(
  (ref) => ref.watch(listingAdminRepositoryProvider).getAllListings(),
);

/// The team's backend for creating and editing listings (plan.md Phase 4).
///
/// The pitch is that the team maintains listings for owners who will not, so
/// this is the screen the team spends its time in. Tapping a listing opens the
/// same business tools an owner gets, scoped to that listing.
class TeamListingsScreen extends ConsumerWidget {
  const TeamListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final listingsAsync = ref.watch(teamListingsProvider);

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Listings'),
        backgroundColor: palette.app,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Notices and collections',
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () => context.push('/team/content'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'team_new_listing',
        onPressed: () async {
          await context.push('/team/listings/new');
          ref.invalidate(teamListingsProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('New listing'),
      ),
      body: listingsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: palette.red),
        ),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load listings.',
                style: AppText.titleMedium.copyWith(color: palette.ink),
              ),
              const SizedBox(height: Insets.md),
              FilledButton(
                onPressed: () => ref.invalidate(teamListingsProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (listings) {
          if (listings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Insets.giant),
                child: Text(
                  'No listings yet. Create the first one.',
                  style: AppText.bodyLarge.copyWith(color: palette.muted),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(teamListingsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.lg,
                Insets.lg,
                96,
              ),
              itemCount: listings.length,
              separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
              itemBuilder: (context, i) =>
                  _ListingRow(business: listings[i], palette: palette),
            ),
          );
        },
      ),
    );
  }
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.business, required this.palette});

  final Business business;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final verified = business.lastVerifiedAt;
    final stale =
        verified == null ||
        DateTime.now().difference(verified) > const Duration(days: 60);

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(Corners.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Corners.md),
        onTap: () => context.go('/business?business=${business.id}'),
        child: Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Corners.md),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: AppText.titleMedium.copyWith(
                        color: business.tier.isVisible
                            ? palette.ink
                            : palette.muted,
                      ),
                    ),
                    const SizedBox(height: Insets.xxs),
                    Text(
                      '${business.category.shortLabel} · ${business.tier.label}'
                      '${business.hasLocation ? '' : ' · no pin'}',
                      style: AppText.caption.copyWith(color: palette.muted),
                    ),
                    // plan.md 9: nudge listings untouched for 60 days. The team
                    // owns accuracy, so the stale ones are flagged here.
                    Text(
                      verified == null
                          ? 'Never verified'
                          : 'Verified ${DateFormat.yMMMd().format(verified.toLocal())}',
                      style: AppText.caption.copyWith(
                        color: stale ? palette.bad : palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

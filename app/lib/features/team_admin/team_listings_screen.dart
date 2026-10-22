import 'package:antigua_business_map/services/seeding_repository.dart';
import 'package:flutter/services.dart';
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
            tooltip: 'Leads',
            icon: const Icon(Icons.person_add_alt_outlined),
            onPressed: () => context.push('/team/leads'),
          ),
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

class _ListingRow extends ConsumerWidget {
  const _ListingRow({required this.business, required this.palette});

  final Business business;
  final AppPalette palette;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(SeedingRepository repo) action,
    String done,
  ) async {
    try {
      await action(ref.read(seedingRepositoryProvider));
      ref
        ..invalidate(teamListingsProvider)
        ..invalidate(businessListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not do that. Try again.')),
        );
      }
    }
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    final id = business.id;
    switch (value) {
      case 'visit' || 'phone':
        await _act(
          context,
          ref,
          (r) => r.verify(id, method: value),
          value == 'visit'
              ? 'Verified in person today.'
              : 'Verified by phone today.',
        );
      case 'hide':
        await _act(
          context,
          ref,
          (r) => r.setProspect(id, prospect: true),
          'Hidden as pre-built. Only the team can see it.',
        );
      case 'publish':
        await _act(
          context,
          ref,
          (r) => r.setProspect(id, prospect: false),
          '${business.name} is now public.',
        );
      case 'preview':
        await _act(context, ref, (r) async {
          final url = await r.previewUrl(id);
          await Clipboard.setData(ClipboardData(text: url));
        }, 'Preview link copied. Send it to the owner.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    if (business.isProspect)
                      Text(
                        'Pre-built, hidden from customers',
                        style: AppText.caption.copyWith(
                          color: palette.warn,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
              PopupMenuButton<String>(
                tooltip: 'Verify, publish, preview',
                onSelected: (v) => _onMenu(context, ref, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'visit',
                    child: Text('Verified in person today'),
                  ),
                  const PopupMenuItem(
                    value: 'phone',
                    child: Text('Verified by phone today'),
                  ),
                  if (business.isProspect) ...[
                    const PopupMenuItem(
                      value: 'preview',
                      child: Text('Copy preview link for the owner'),
                    ),
                    const PopupMenuItem(
                      value: 'publish',
                      child: Text('Publish to customers'),
                    ),
                  ] else
                    const PopupMenuItem(
                      value: 'hide',
                      child: Text('Hide as pre-built'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

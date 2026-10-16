import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/events/event_widgets.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/services/ranking_service.dart';
import 'package:antigua_business_map/widgets/business_image.dart';
import 'package:antigua_business_map/widgets/offer_code_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Saved: businesses, events and offers, as in the Dadliplug design.
///
/// A saved business is also followed, so its announcements reach the
/// Bulletin Board's Following feed. Offers here are the running offers from
/// the businesses you saved: the reason to save a business you like is to
/// hear when it has a deal.
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({required this.isSignedIn, super.key});

  final bool isSignedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    if (!isSignedIn) {
      // A guest cannot save. Saying so up front is better than an empty list
      // that looks like they have saved nothing.
      return Scaffold(
        backgroundColor: palette.surface,
        appBar: AppBar(title: const Text('Saved')),
        body: _Message(
          icon: Icons.favorite_border,
          title: 'Sign in to save places',
          body:
              'You can browse as a guest. Sign in and you can keep the '
              'businesses and events you want to come back to.',
          actionLabel: 'Sign in',
          onAction: () => context.push('/sign-in'),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: palette.surface,
        appBar: AppBar(
          title: const Text('Saved'),
          bottom: TabBar(
            labelColor: palette.red,
            indicatorColor: palette.red,
            unselectedLabelColor: palette.muted,
            tabs: const [
              Tab(text: 'Businesses'),
              Tab(text: 'Events'),
              Tab(text: 'Offers'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_SavedBusinesses(), _SavedEvents(), _SavedOffers()],
        ),
      ),
    );
  }
}

class _SavedBusinesses extends ConsumerWidget {
  const _SavedBusinesses();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final idsAsync = ref.watch(followedBusinessIdsProvider);
    final businessesAsync = ref.watch(businessListProvider);

    return _load(
      context,
      [idsAsync, businessesAsync],
      onRetry: () => ref
        ..invalidate(followedBusinessIdsProvider)
        ..invalidate(businessListProvider),
      builder: () {
        final ids = idsAsync.value!;
        final saved = businessesAsync.value!
            .where((b) => ids.contains(b.id))
            .toList();
        if (ids.isEmpty) {
          return const _Message(
            icon: Icons.favorite_border,
            title: 'Nothing saved yet',
            body:
                'Tap the heart on any business to keep it here and hear its '
                'announcements.',
          );
        }
        if (saved.isEmpty) {
          // The ids are real but nothing came back: almost always a business
          // that is no longer listed. Say that rather than show nothing.
          return const _Message(
            icon: Icons.info_outline,
            title: 'Nothing to show',
            body: 'The businesses you saved are no longer listed.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(Insets.huge),
          itemCount: saved.length,
          separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
          itemBuilder: (context, i) =>
              _SavedBusinessRow(business: saved[i], palette: palette),
        );
      },
    );
  }
}

class _SavedBusinessRow extends ConsumerWidget {
  const _SavedBusinessRow({required this.business, required this.palette});

  final Business business;
  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = reviewStats(business);

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(Corners.xxl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/listing/${business.id}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Corners.xxl),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: BusinessImage(business: business, iconSize: 28),
              ),
              const SizedBox(width: Insets.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.titleSmall.copyWith(color: palette.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      business.category.label,
                      style: AppText.caption.copyWith(color: palette.muted),
                    ),
                    if (stats.count > 0) ...[
                      const SizedBox(height: Insets.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: palette.gold,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${stats.average.toStringAsFixed(1)} (${stats.count})',
                            style: AppText.caption.copyWith(color: palette.ink),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove from Saved',
                icon: Icon(Icons.favorite, color: palette.red),
                onPressed: () async {
                  await ref
                      .read(businessContentRepositoryProvider)
                      .setFollow(businessId: business.id, follow: false);
                  ref.invalidate(followedBusinessIdsProvider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedEvents extends ConsumerWidget {
  const _SavedEvents();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idsAsync = ref.watch(savedEventIdsProvider);
    final eventsAsync = ref.watch(upcomingEventsProvider);

    return _load(
      context,
      [idsAsync, eventsAsync],
      onRetry: () => ref
        ..invalidate(savedEventIdsProvider)
        ..invalidate(upcomingEventsProvider),
      builder: () {
        final ids = idsAsync.value!;
        final saved = eventsAsync.value!
            .where((e) => ids.contains(e.id))
            .toList();
        if (saved.isEmpty) {
          return const _Message(
            icon: Icons.event_outlined,
            title: 'No saved events',
            body:
                'Tap "Save Event" on anything coming up and it waits here. '
                'Past events drop off by themselves.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(Insets.huge),
          itemCount: saved.length,
          separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
          itemBuilder: (_, i) => EventRow(event: saved[i]),
        );
      },
    );
  }
}

class _SavedOffers extends ConsumerWidget {
  const _SavedOffers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final idsAsync = ref.watch(followedBusinessIdsProvider);
    final offersAsync = ref.watch(offersProvider);

    return _load(
      context,
      [idsAsync, offersAsync],
      onRetry: () => ref
        ..invalidate(followedBusinessIdsProvider)
        ..invalidate(offersProvider),
      builder: () {
        final ids = idsAsync.value!;
        final offers = offersAsync.value!
            .where((o) => ids.contains(o.businessId))
            .toList();
        if (offers.isEmpty) {
          return _Message(
            icon: Icons.local_offer_outlined,
            title: 'No offers from your saved places',
            body:
                'When a business you saved runs an offer, its code shows up '
                'here.',
            actionLabel: 'See all offers',
            onAction: () => context.push('/offers'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(Insets.huge),
          itemCount: offers.length,
          separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
          itemBuilder: (context, i) {
            final o = offers[i];
            return InkWell(
              onTap: () => context.push('/listing/${o.businessId}'),
              borderRadius: BorderRadius.circular(Corners.xxl),
              child: Container(
                padding: const EdgeInsets.all(Insets.huge),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Corners.xxl),
                  border: Border.all(color: palette.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.businessName,
                      style: AppText.caption.copyWith(color: palette.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      o.title,
                      style: AppText.titleMedium.copyWith(color: palette.ink),
                    ),
                    const SizedBox(height: Insets.md),
                    OfferCodeChip(code: o.offerCode!),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Loading, then an error if any source failed (never an empty list during
/// an outage), then [builder].
Widget _load(
  BuildContext context,
  List<AsyncValue<Object?>> sources, {
  required VoidCallback onRetry,
  required Widget Function() builder,
}) {
  final palette = context.palette;
  if (sources.any((s) => s.hasError)) {
    return _Message(
      icon: Icons.cloud_off_outlined,
      title: 'Could not load',
      body: 'Check your connection and try again.',
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
  if (sources.any((s) => !s.hasValue)) {
    return Center(child: CircularProgressIndicator(color: palette.red));
  }
  return builder();
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Insets.giant),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
        Icon(icon, size: 44, color: palette.muted),
        const SizedBox(height: Insets.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppText.titleLarge.copyWith(color: palette.ink),
        ),
        const SizedBox(height: Insets.sm),
        Text(
          body,
          textAlign: TextAlign.center,
          style: AppText.bodyMedium.copyWith(color: palette.muted),
        ),
        if (onAction != null && actionLabel != null) ...[
          const SizedBox(height: Insets.lg),
          Center(
            child: FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ),
        ],
      ],
    );
  }
}

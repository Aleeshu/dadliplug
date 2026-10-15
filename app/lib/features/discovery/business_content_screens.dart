import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Messages from businesses to their customers.
///
/// Customer tab and business tab land on the same screen with different
/// behaviour: a customer reads and follows, a business posts and watches the
/// read receipts.
class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({
    this.businessId,
    this.isSignedIn = false,
    super.key,
  });

  /// Set when a business opens this for their own listing. Empty when the
  /// account has no listing linked.
  final String? businessId;

  /// A signed-in customer sees the businesses they follow.
  final bool isSignedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsProvider);
    final palette = context.palette;
    final isOwner = businessId != null;

    if (isOwner && businessId!.isEmpty) {
      return Scaffold(
        backgroundColor: palette.app,
        appBar: AppBar(title: const Text('Announcements')),
        body: const ContentMessage(
          icon: Icons.storefront_outlined,
          title: 'No listing linked yet',
          body: 'Your account is not linked to a business yet, so there is '
              'nowhere to post announcements.',
        ),
      );
    }

    // plan.md 4: announcements go to the customers who follow a business.
    // Someone following nobody sees everything, because an empty feed on a new
    // app is a worse first impression than a busy one and nothing is private.
    final followed = isOwner || !isSignedIn
        ? const <String>[]
        : ref.watch(followedBusinessIdsProvider).value ?? const <String>[];

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: palette.app,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (businessId != null)
            IconButton(
              tooltip: 'New announcement',
              icon: const Icon(Icons.add),
              onPressed: () =>
                  context.push('/business/announcements/new?business=$businessId'),
            ),
        ],
      ),
      body: announcementsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: palette.red),
        ),
        error: (error, _) => ContentMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load announcements',
          body: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(announcementsProvider),
        ),
        data: (all) {
          final items = isOwner
              ? all.where((a) => a.businessId == businessId).toList()
              : followed.isEmpty
              ? all
              : all.where((a) => followed.contains(a.businessId)).toList();

          if (items.isEmpty) {
            return ContentMessage(
              icon: isOwner ? Icons.campaign_outlined : Icons.notifications_none,
              title: 'No announcements yet',
              body: isOwner
                  ? 'Post a notice and your customers who follow you will be '
                      'told about it.'
                  : 'Businesses post closures, offers and notices here.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(announcementsProvider);
              await ref.read(announcementsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(Insets.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
              itemBuilder: (context, index) {
                final announcement = items[index];
                return Container(
                  padding: const EdgeInsets.all(Insets.md),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(Corners.md),
                    border: Border.all(color: palette.line),
                  ),
                  child: InkWell(
                    onTap: () {
                      // Records the read receipt so an owner can tell a message
                      // was seen, not merely posted.
                      ref
                          .read(businessContentRepositoryProvider)
                          .markAnnouncementRead(announcement.id);
                      context.push('/listing/${announcement.businessId}');
                    },
                    borderRadius: BorderRadius.circular(Corners.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          announcement.title,
                          style: AppText.titleMedium.copyWith(color: palette.ink),
                        ),
                        const SizedBox(height: Insets.xxs),
                        Text(
                          '${announcement.businessName} · '
                          '${DateFormat.MMMd().add_jm().format(announcement.createdAt.toLocal())}',
                          style: AppText.caption.copyWith(color: palette.muted),
                        ),
                        if (announcement.body.isNotEmpty) ...[
                          const SizedBox(height: Insets.sm),
                          Text(
                            announcement.body,
                            style: AppText.bodyMedium.copyWith(
                              color: palette.ink,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// A business's running advertisements.
class BusinessAdsScreen extends ConsumerWidget {
  const BusinessAdsScreen({required this.businessId, super.key});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adsAsync = ref.watch(businessAdsProvider(businessId));
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Advertisements'),
        backgroundColor: palette.app,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (businessId.isNotEmpty)
            IconButton(
              tooltip: 'New advertisement',
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/business/ads/new?business=$businessId'),
            ),
        ],
      ),
      // No linked listing means there is nothing to show and nothing to invent.
      // Saying so is the only honest option; showing an empty ad list would
      // read as "you have never advertised" rather than "we do not know which
      // business this is yet".
      body: businessId.isEmpty
          ? const ContentMessage(
              icon: Icons.storefront_outlined,
              title: 'No listing linked yet',
              body: 'Your account is not linked to a business yet, so there is '
                  'nowhere to post advertisements.',
            )
          : adsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: palette.red),
        ),
        error: (error, _) => ContentMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load advertisements',
          body: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(businessAdsProvider(businessId)),
        ),
        data: (ads) {
          if (ads.isEmpty) {
            return const ContentMessage(
              icon: Icons.campaign_outlined,
              title: 'No advertisements yet',
              body: 'Advertisements you post appear here with a count of how '
                  'many people have viewed each one.',
            );
          }

          final now = DateTime.now();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(businessAdsProvider(businessId));
              await ref.read(businessAdsProvider(businessId).future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(Insets.lg),
              itemCount: ads.length,
              separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
              itemBuilder: (context, index) {
                final ad = ads[index];
                final live = ad.isLiveAt(now);

                return Container(
                  padding: const EdgeInsets.all(Insets.md),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(Corners.md),
                    border: Border.all(
                      color: live ? palette.line : palette.line.withValues(alpha: 0.5),
                    ),
                  ),
                  child: InkWell(
                    onTap: () => context.push('/listing/${ad.businessId}'),
                    borderRadius: BorderRadius.circular(Corners.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                ad.title,
                                style: AppText.titleMedium.copyWith(
                                  // A finished ad stays visible but recedes, so
                                  // an owner can see what ran without it
                                  // looking current to a customer.
                                  color: live ? palette.ink : palette.muted,
                                ),
                              ),
                            ),
                            if (!live)
                              Text('ENDED', style: AppText.sectionLabel)
                            else
                              TextButton(
                                onPressed: () => _confirmEnd(context, ref, ad),
                                child: const Text('End'),
                              ),
                          ],
                        ),
                        if (ad.body.isNotEmpty) ...[
                          const SizedBox(height: Insets.xs),
                          Text(
                            ad.body,
                            style: AppText.bodyMedium.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ],
                        const SizedBox(height: Insets.sm),
                        Text(
                          '${DateFormat.yMMMd().format(ad.startsAt.toLocal())}'
                          ' · ${ad.views} views',
                          style: AppText.caption.copyWith(color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Upcoming events across every business, or one business's own.
///
/// Sorted soonest first, because the only question a customer opens this with
/// is "what is happening and when".
class EventsCalendarScreen extends ConsumerWidget {
  const EventsCalendarScreen({this.businessId, super.key});

  /// Set when a business opens this for its own events. It then sees only
  /// those, with a way to post one; it used to get the whole island's
  /// calendar and no way to add to it.
  final String? businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final palette = context.palette;
    final ownerId = businessId;

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: Text(ownerId == null ? "What's on" : 'Your events'),
        backgroundColor: palette.app,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (ownerId != null && ownerId.isNotEmpty)
            IconButton(
              tooltip: 'New event',
              icon: const Icon(Icons.add),
              onPressed: () =>
                  context.push('/business/events/new?business=$ownerId'),
            ),
        ],
      ),
      body: eventsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: palette.red),
        ),
        error: (error, _) => ContentMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load events',
          body: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(upcomingEventsProvider),
        ),
        data: (all) {
          final events = ownerId == null
              ? all
              : all.where((e) => e.businessId == ownerId).toList();

          if (events.isEmpty) {
            return ContentMessage(
              icon: Icons.event_outlined,
              title: 'Nothing coming up yet',
              body: ownerId == null
                  ? 'When businesses post events they show up here. Carnival '
                      'and sailing week are usually the first.'
                  : 'Post an event and it appears on your listing and in the '
                      'island calendar.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(upcomingEventsProvider);
              await ref.read(upcomingEventsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(Insets.lg),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
              itemBuilder: (context, index) {
                final event = events[index];
                return Container(
                  padding: const EdgeInsets.all(Insets.md),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(Corners.md),
                    border: Border.all(color: palette.line),
                  ),
                  child: InkWell(
                    onTap: () => context.push('/listing/${event.businessId}'),
                    borderRadius: BorderRadius.circular(Corners.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DateBlock(date: event.startsAt),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: AppText.titleMedium.copyWith(
                                  color: palette.ink,
                                ),
                              ),
                              const SizedBox(height: Insets.xxs),
                              Text(
                                event.businessName,
                                style: AppText.caption.copyWith(
                                  color: palette.muted,
                                ),
                              ),
                              if (event.locationNote?.isNotEmpty ?? false) ...[
                                const SizedBox(height: Insets.xxs),
                                Text(
                                  event.locationNote!,
                                  style: AppText.caption.copyWith(
                                    color: palette.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Ends a running ad after confirming. Ending sets an end date rather than
/// deleting, so the views it earned stay in the monthly report.
Future<void> _confirmEnd(
  BuildContext context,
  WidgetRef ref,
  BusinessAd ad,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('End this advertisement?'),
      content: const Text(
        'It comes off your listing now. Its views stay in your reports.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('End it'),
        ),
      ],
    ),
  );
  if (!(confirmed ?? false)) return;

  try {
    await ref.read(businessContentRepositoryProvider).endAd(ad.id);
    ref.invalidate(businessAdsProvider(ad.businessId));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not end it. Check your connection.')),
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final local = date.toLocal();

    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      decoration: BoxDecoration(
        color: palette.app,
        borderRadius: BorderRadius.circular(Corners.sm),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Text(
            DateFormat.MMM().format(local).toUpperCase(),
            style: AppText.sectionLabel.copyWith(color: palette.red),
          ),
          Text(
            '${local.day}',
            style: AppText.numericLarge.copyWith(color: palette.ink),
          ),
        ],
      ),
    );
  }
}

/// The shared empty, error and retry state for business content screens.
///
/// A ListView rather than a Column, so pull-to-refresh still works when there
/// is nothing to show.
class ContentMessage extends StatelessWidget {
  const ContentMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
        Icon(icon, size: 44, color: palette.muted),
        const SizedBox(height: Insets.lg),
        Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.displayMedium.copyWith(color: palette.ink),
          ),
        ),
        const SizedBox(height: Insets.sm),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: Insets.lg),
          Center(
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
        ],
      ],
    );
  }
}
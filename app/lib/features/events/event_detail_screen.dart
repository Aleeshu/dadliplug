import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/events/event_widgets.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// One event's page, from the design: picture, date, venue and time, tags,
/// description, Save Event and Get Directions, and the organiser's details.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final eventAsync = ref.watch(eventProvider(eventId));

    return Scaffold(
      backgroundColor: palette.surface,
      body: eventAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (err, _) {
          debugPrint('Event $eventId failed to load: $err');
          return _Message(
            text: 'Could not load this event. Check your connection.',
            onRetry: () => ref.invalidate(eventProvider(eventId)),
          );
        },
        data: (event) => event == null
            ? const _Message(text: 'This event has been removed.')
            : _EventBody(event: event),
      ),
    );
  }
}

class _EventBody extends ConsumerWidget {
  const _EventBody({required this.event});

  final BusinessEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final saved =
        ref.watch(savedEventIdsProvider).value?.contains(event.id) ?? false;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: palette.surface,
          leading: _RoundButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            onTap: () => context.pop(),
          ),
          actions: [
            _RoundButton(
              icon: Icons.ios_share,
              tooltip: 'Share on WhatsApp',
              onTap: () => _share(event),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: EventImage(event: event, iconSize: 64),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(Insets.huge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EventDateBadge(date: event.startsAt, filled: true),
                    const SizedBox(width: Insets.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: AppText.displayMedium.copyWith(
                              color: palette.ink,
                            ),
                          ),
                          if (event.locationNote?.isNotEmpty ?? false)
                            _IconLine(
                              icon: Icons.location_on_outlined,
                              text: event.locationNote!,
                            ),
                          _IconLine(
                            icon: Icons.schedule,
                            text: eventTimeRange(event),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (event.tags.isNotEmpty) ...[
                  const SizedBox(height: Insets.xl),
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: [
                      for (final t in event.tags) EventTagChip(tag: t),
                    ],
                  ),
                ],
                if (event.body.isNotEmpty) ...[
                  const SizedBox(height: Insets.xl),
                  Text(
                    event.body,
                    style: AppText.bodyLarge.copyWith(color: palette.ink),
                  ),
                ],
                const SizedBox(height: Insets.giant),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _toggleSave(context, ref, saved),
                        icon: Icon(
                          saved ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                        ),
                        label: Text(saved ? 'Saved' : 'Save Event'),
                      ),
                    ),
                    if (event.hasLocation) ...[
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.go('/map?focus=${event.businessId}'),
                          icon: const Icon(Icons.directions, size: 18),
                          label: const Text('Get Directions'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Insets.giant),
                Text(
                  'Event Details',
                  style: AppText.titleLarge.copyWith(color: palette.ink),
                ),
                const SizedBox(height: Insets.md),
                _DetailRow(
                  icon: Icons.groups_outlined,
                  label: 'Organizer',
                  value: event.organizerName,
                  onTap: () => context.push('/listing/${event.businessId}'),
                ),
                if (event.website?.isNotEmpty ?? false)
                  _DetailRow(
                    icon: Icons.language,
                    label: 'Website',
                    value: event.website!,
                    onTap: () => _open(event.website!),
                  ),
                if (event.phone?.isNotEmpty ?? false)
                  _DetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: event.phone!,
                    onTap: () =>
                        launchUrl(Uri(scheme: 'tel', path: event.phone)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleSave(
    BuildContext context,
    WidgetRef ref,
    bool saved,
  ) async {
    try {
      await ref
          .read(businessContentRepositoryProvider)
          .setEventSaved(eventId: event.id, saved: !saved);
      ref.invalidate(savedEventIdsProvider);
    } on NotSignedInException {
      if (context.mounted) await context.push<void>('/sign-in');
    } catch (error) {
      debugPrint('Could not save event: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save. Check your connection.'),
          ),
        );
      }
    }
  }

  static Future<void> _open(String raw) async {
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _share(BusinessEvent e) {
    final local = islandTime(e.startsAt);
    final lines = [
      e.title,
      '${local.day}/${local.month} · ${eventTimeRange(e)}',
      if (e.locationNote?.isNotEmpty ?? false) e.locationNote!,
      'Found on Dadliplug',
    ];
    return launchUrl(
      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(lines.join('\n'))}'),
      mode: LaunchMode.externalApplication,
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: palette.muted),
          const SizedBox(width: Insets.xs),
          Flexible(
            child: Text(
              text,
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        child: Row(
          children: [
            Icon(icon, color: palette.ink, size: 22),
            const SizedBox(width: Insets.xl),
            SizedBox(
              width: 90,
              child: Text(
                label,
                style: AppText.titleSmall.copyWith(color: palette.ink),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: AppText.bodyMedium.copyWith(color: palette.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.all(Insets.xs),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: CircleAvatar(
          backgroundColor: palette.surface.withValues(alpha: 0.9),
          child: Icon(icon, color: palette.ink, size: 20),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: AppText.bodyMedium.copyWith(color: palette.muted),
                  ),
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('Try again'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

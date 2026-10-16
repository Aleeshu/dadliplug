import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// [instant] on the island's clock. Events happen in Antigua, so a phone set
/// to another timezone must not move an event to the wrong day or hour.
DateTime islandTime(DateTime instant) => AntiguaClock.antiguaTimeOf(instant);

/// "6:00 PM – 11:00 PM", in Antigua time.
String eventTimeRange(BusinessEvent e) {
  final f = DateFormat.jm();
  final start = f.format(islandTime(e.startsAt));
  final end = e.endsAt;
  return end == null ? start : '$start – ${f.format(islandTime(end))}';
}

/// An event's picture, or a sunset-coloured placeholder with an event icon.
/// Never a stock photo: a picture of some other party would be the first
/// untrue thing on the page.
class EventImage extends StatelessWidget {
  const EventImage({required this.event, this.iconSize = 32, super.key});

  final BusinessEvent event;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B1E6E), Color(0xFFE8253F), Color(0xFFF59E0B)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.celebration,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
    final url = event.imageUrl;
    if (url == null || url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

/// The "AUG / 22" block from the design.
class EventDateBadge extends StatelessWidget {
  const EventDateBadge({required this.date, this.filled = false, super.key});

  final DateTime date;

  /// Red with white text (event page) rather than outlined (lists).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final local = islandTime(date);
    final fg = filled ? palette.onRed : palette.red;

    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      decoration: BoxDecoration(
        color: filled ? palette.red : palette.surface,
        borderRadius: BorderRadius.circular(Corners.lg),
        border: filled
            ? null
            : Border.all(color: palette.red.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            DateFormat.MMM().format(local).toUpperCase(),
            style: AppText.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${local.day}',
            style: AppText.numericLarge.copyWith(
              color: filled ? palette.onRed : palette.ink,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A coloured tag pill: Music, Food, Family Friendly…
class EventTagChip extends StatelessWidget {
  const EventTagChip({required this.tag, super.key});

  final String tag;

  static const _colors = {
    'music': Color(0xFFEC4899),
    'food': Color(0xFFF59E0B),
    'entertainment': Color(0xFF2E7CF6),
    'family friendly': Color(0xFF16A34A),
    'shopping': Color(0xFFE8253F),
    'art': Color(0xFF8B5CF6),
    'local': Color(0xFF16A34A),
    'sports': Color(0xFF2563EB),
    'nightlife': Color(0xFF7C3AED),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[tag.toLowerCase()] ?? context.palette.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Corners.pill),
      ),
      child: Text(
        tag,
        style: AppText.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One event in a list: picture, date, title, venue, time and tags.
class EventRow extends StatelessWidget {
  const EventRow({required this.event, super.key});

  final BusinessEvent event;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(Corners.xxl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/event/${event.id}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Corners.xxl),
            border: Border.all(color: palette.line),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 104, child: EventImage(event: event)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EventDateBadge(date: event.startsAt),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.titleSmall.copyWith(
                                  color: palette.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                event.locationNote?.isNotEmpty ?? false
                                    ? event.locationNote!
                                    : event.organizerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption.copyWith(
                                  color: palette.muted,
                                ),
                              ),
                              Text(
                                eventTimeRange(event),
                                style: AppText.caption.copyWith(
                                  color: palette.muted,
                                ),
                              ),
                              if (event.tags.isNotEmpty) ...[
                                const SizedBox(height: Insets.sm),
                                Wrap(
                                  spacing: Insets.xs,
                                  runSpacing: Insets.xs,
                                  children: [
                                    for (final t in event.tags.take(3))
                                      EventTagChip(tag: t),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
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

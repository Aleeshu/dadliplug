import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/events/event_widgets.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Events: a month calendar with event days marked, and the list below.
///
/// With no day picked the list is Featured Events (or all upcoming ones when
/// none are featured, rather than an empty section). Picking a day lists
/// that day's events. Dates are Antigua dates whatever the phone's timezone.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  late DateTime _month = _monthOf(AntiguaClock.nowInAntigua());
  DateTime? _day;

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);
  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final eventsAsync = ref.watch(upcomingEventsProvider);

    return Scaffold(
      backgroundColor: palette.surface,
      appBar: AppBar(title: const Text('Events')),
      body: eventsAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (err, _) {
          debugPrint('Events failed to load: $err');
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load events.',
                  style: AppText.bodyMedium.copyWith(color: palette.muted),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(upcomingEventsProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        },
        data: (events) {
          final byDay = <DateTime, List<BusinessEvent>>{};
          for (final e in events) {
            byDay.putIfAbsent(_dayOf(islandTime(e.startsAt)), () => []).add(e);
          }

          final day = _day;
          final List<BusinessEvent> listed;
          final String heading;
          if (day != null) {
            listed = byDay[day] ?? const [];
            heading = 'Events on ${DateFormat.MMMMd().format(day)}';
          } else {
            final featured = events.where((e) => e.featured).toList();
            listed = featured.isNotEmpty ? featured : events;
            heading = featured.isNotEmpty
                ? 'Featured Events'
                : 'Upcoming Events';
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(upcomingEventsProvider);
              await ref.read(upcomingEventsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Insets.huge,
                0,
                Insets.huge,
                Insets.giant,
              ),
              children: [
                _MonthCalendar(
                  month: _month,
                  selected: day,
                  eventDays: byDay.keys.toSet(),
                  onMonth: (m) => setState(() => _month = m),
                  onDay: (d) => setState(() => _day = (d == _day) ? null : d),
                ),
                const SizedBox(height: Insets.giant),
                Row(
                  children: [
                    Text(
                      heading,
                      style: AppText.titleLarge.copyWith(color: palette.ink),
                    ),
                    const Spacer(),
                    if (day != null)
                      TextButton(
                        onPressed: () => setState(() => _day = null),
                        child: Text(
                          'Show all',
                          style: AppText.labelMedium.copyWith(
                            color: palette.red,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                if (listed.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Insets.giant),
                    child: Text(
                      day != null
                          ? 'Nothing on that day.'
                          : 'Nothing coming up yet. When businesses post '
                                'events they show up here.',
                      textAlign: TextAlign.center,
                      style: AppText.bodyMedium.copyWith(color: palette.muted),
                    ),
                  )
                else
                  for (final e in listed) ...[
                    EventRow(event: e),
                    const SizedBox(height: Insets.md),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selected,
    required this.eventDays,
    required this.onMonth,
    required this.onDay,
  });

  final DateTime month;
  final DateTime? selected;
  final Set<DateTime> eventDays;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final today = AntiguaClock.nowInAntigua();
    final todayDay = DateTime(today.year, today.month, today.day);

    // Sunday-first, as in the design. DateTime.weekday is 1 (Mon)..7 (Sun).
    final first = DateTime(month.year, month.month);
    final leading = first.weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((leading + daysInMonth) / 7).ceil() * 7;

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.xxl),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(month),
                  textAlign: TextAlign.center,
                  style: AppText.titleMedium.copyWith(color: palette.ink),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              for (final d in const [
                'Sun',
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
              ])
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: AppText.caption.copyWith(color: palette.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          for (var row = 0; row < cells / 7; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _DayCell(
                      day: () {
                        final n = row * 7 + col - leading + 1;
                        return (n < 1 || n > daysInMonth)
                            ? null
                            : DateTime(month.year, month.month, n);
                      }(),
                      selected: selected,
                      today: todayDay,
                      eventDays: eventDays,
                      onDay: onDay,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.eventDays,
    required this.onDay,
  });

  final DateTime? day;
  final DateTime? selected;
  final DateTime today;
  final Set<DateTime> eventDays;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final d = day;
    if (d == null) return const SizedBox(height: 44);

    final palette = context.palette;
    final isSelected = d == selected;
    final hasEvent = eventDays.contains(d);
    final isToday = d == today;

    return InkResponse(
      onTap: () => onDay(d),
      radius: 22,
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? palette.red : null,
                shape: BoxShape.circle,
                border: isToday && !isSelected
                    ? Border.all(color: palette.red)
                    : null,
              ),
              child: Text(
                '${d.day}',
                style: AppText.bodyMedium.copyWith(
                  color: isSelected ? palette.onRed : palette.ink,
                  fontWeight: hasEvent ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
            ),
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: hasEvent && !isSelected
                    ? palette.red
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

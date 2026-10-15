/// Opening-hours logic, ported from the prototype's `openInfo`/`fmt`.
///
/// One thing the prototype gets right that is easy to lose: hours are always
/// evaluated in Antigua time (`America/Antigua`), not device time. A phone on
/// a Caribbean vacation showing a business as closed would be a small but very
/// visible failure for an app whose whole job is "is this place open right
/// now".
library;

import 'package:antigua_business_map/models/business.dart';

/// Result of asking whether a business is open.
class OpenInfo {
  const OpenInfo({
    required this.isOpen,
    required this.label,
    this.isTemporary = false,
  });

  final bool isOpen;

  /// "Open until 6pm", "Closed, opens Fri 6pm", "Open 24 hours", "Closed today (temporary)".
  final String label;

  /// True if closed due to temporary one-tap status (hurricane season, Carnival, holiday).
  final bool isTemporary;
}

abstract final class AntiguaClock {
  static const String timeZone = 'America/Antigua';

  /// Weekday and fractional hour in Antigua time.
  ///
  /// Derived from UTC, never from the device's local time. The previous version
  /// subtracted four hours from *local* time, which was only right on a phone
  /// set to UTC: on a phone in Antigua it subtracted the offset twice and every
  /// open/closed label was four hours out.
  static ({int weekday, double hour}) now() {
    final island = nowInAntigua();
    return (
      weekday: island.weekday,
      hour: island.hour + island.minute / 60,
    );
  }

  /// The current time in Antigua, for use with [OpeningHours.isOpenAt].
  ///
  /// Antigua is UTC-4 year round — no daylight saving since 1971 — so a fixed
  /// offset is correct and avoids a timezone database package.
  static DateTime nowInAntigua() => antiguaTimeOf(DateTime.now());

  /// [instant] as Antigua wall-clock time. Exposed so tests can pin the clock.
  static DateTime antiguaTimeOf(DateTime instant) {
    final shifted = instant.toUtc().add(const Duration(hours: -4));
    // Rebuilt as a non-UTC value so `weekday` and `hour` read as Antigua
    // wall-clock fields rather than being reinterpreted.
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
    );
  }
}

/// "6pm", "9:30am", "12pm".
String formatHour(double hour) {
  final h = hour % 24;
  final hh = h.floor();
  final minutes = ((h - hh) * 60).round();
  final mm = minutes == 0 ? null : minutes.toString().padLeft(2, '0');
  final suffix = h >= 12 ? 'pm' : 'am';
  final display = hh % 12 == 0 ? 12 : hh % 12;
  return mm == null ? '$display $suffix' : '$display:$mm $suffix';
}

/// Whether a business is open right now, and the label to show.
///
/// [now] is Antigua wall-clock time and defaults to the real clock. Openness
/// itself is decided by [OpeningHours.isOpenAt], so the label and the
/// open-now filter cannot disagree — they used to be two implementations, and
/// only one of them understood a bar that closes after midnight.
OpenInfo openInfo(Business b, {DateTime? now}) {
  if (b.isClosedToday) {
    return const OpenInfo(
      isOpen: false,
      label: 'Closed today (temporary)',
      isTemporary: true,
    );
  }

  final h = b.hours;

  if (h.is24Hours) {
    return const OpenInfo(isOpen: true, label: 'Open 24 hours');
  }

  final island = now ?? AntiguaClock.nowInAntigua();
  final weekday = island.weekday;
  final hour = island.hour + island.minute / 60;

  if (h.isOpenAt(island)) {
    return OpenInfo(
      isOpen: true,
      label: 'Open until ${formatHour(h.closesAt)}',
    );
  }

  if (h.days.contains(weekday) && hour < h.opensAt) {
    return OpenInfo(
      isOpen: false,
      label: 'Closed, opens ${formatHour(h.opensAt)}',
    );
  }

  final next = h.nextOpenDay(weekday);
  if (next != null) {
    return OpenInfo(
      isOpen: false,
      label: 'Closed, opens ${_dayName(next)} ${formatHour(h.opensAt)}',
    );
  }

  return const OpenInfo(isOpen: false, label: 'Closed');
}

String _dayName(int weekday) => switch (weekday) {
  DateTime.monday => 'Mon',
  DateTime.tuesday => 'Tue',
  DateTime.wednesday => 'Wed',
  DateTime.thursday => 'Thu',
  DateTime.friday => 'Fri',
  DateTime.saturday => 'Sat',
  _ => 'Sun',
};

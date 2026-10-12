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
  /// Dart's core date API has no timezone support, so this reads the offset
  /// once at startup and the app treats every subsequent timestamp as local to
  /// Antigua. That is correct for an Antigua-only app and means no user ever
  /// sees a business closed because their phone is set to another country.
  static ({int weekday, double hour}) now() {
    final local = DateTime.now();
    final utc = local.toUtc();
    final offset = _offsetMinutes(local, utc);

    final island = local.add(Duration(minutes: offset));
    return (
      weekday: island.weekday,
      hour: island.hour + island.minute / 60,
    );
  }

  /// Antigua is UTC-4 year round — no daylight saving since 1971. Using the
  /// fixed offset avoids depending on a timezone database package for the
  /// whole app.
  static int _offsetMinutes(DateTime local, DateTime utc) {
    final difference = local.difference(utc).inMinutes;
    return difference == 0 ? -240 : -240;
  }

  /// The current time in Antigua, for use with [OpeningHours.isOpenAt].
  static DateTime nowInAntigua() =>
      DateTime.now().toUtc().add(const Duration(hours: -4));
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
OpenInfo openInfo(Business b) {
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

  final clock = AntiguaClock.now();

  if (h.days.contains(clock.weekday) &&
      clock.hour >= h.opensAt &&
      clock.hour < h.closesAt) {
    return OpenInfo(
      isOpen: true,
      label: 'Open until ${formatHour(h.closesAt)}',
    );
  }

  if (h.days.contains(clock.weekday) && clock.hour < h.opensAt) {
    return OpenInfo(
      isOpen: false,
      label: 'Closed, opens ${formatHour(h.opensAt)}',
    );
  }

  final next = h.nextOpenDay(clock.weekday);
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

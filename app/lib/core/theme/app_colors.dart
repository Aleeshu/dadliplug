/// App colour palette.
///
/// Tokens mirrored 1:1 from the design prototype
/// (`Antigua Business Map.html`, `:root`). Both light and dark are defined
/// because the prototype specifies both, and a business app gets used outdoors
/// in the sun and indoors at night.
///
/// Antigua's flag red is the accent, not a generic blue. Gold marks premium.
library;

import 'package:flutter/material.dart';

@immutable
class AppPalette {
  const AppPalette({
    required this.bg,
    required this.app,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.sea,
    required this.shallow,
    required this.land,
    required this.landLine,
    required this.road,
    required this.red,
    required this.onRed,
    required this.pin,
    required this.pinEdge,
    required this.gold,
    required this.goldBg,
    required this.goldInk,
    required this.trial,
    required this.blue,
    required this.blueBg,
    required this.good,
    required this.goodBg,
    required this.warn,
    required this.warnBg,
    required this.bad,
    required this.badBg,
    required this.bezel,
    required this.isDark,
  });

  final Color bg;
  final Color app;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;

  // Map fills. The prototype hand-draws the island rather than using a tile
  // layer, which is a decision worth revisiting — see docs/design.
  final Color sea;
  final Color shallow;
  final Color land;
  final Color landLine;
  final Color road;

  final Color red;
  final Color onRed;
  final Color pin;
  final Color pinEdge;

  final Color gold;
  final Color goldBg;
  final Color goldInk;

  /// Trial state. Deliberately distinct from [gold] so a 3-day trial does not
  /// look like a permanent premium badge on the map.
  final Color trial;

  final Color blue;
  final Color blueBg;

  final Color good;
  final Color goodBg;
  final Color warn;
  final Color warnBg;
  final Color bad;
  final Color badBg;

  final Color bezel;
  final bool isDark;

  // The 2026-10-28 redesign: navy and yellow. The main action colour (still
  // named `red` from the first design, so every screen picks it up) is blue
  // in light mode and yellow in dark, as in the mockups: yellow text on
  // white cannot be read, and blue on navy disappears.
  static const AppPalette light = AppPalette(
    bg: Color(0xFFEFF3F9),
    app: Color(0xFFF5F7FB),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF0A1F44),
    muted: Color(0xFF5B6B85),
    line: Color(0xFFDDE4EF),
    sea: Color(0xFFBFE3EB),
    shallow: Color(0xFFD8F0F4),
    land: Color(0xFFE8EAD2),
    landLine: Color(0xFFBDC39C),
    road: Color(0xFFFFFFFF),
    red: Color(0xFF1565C0),
    onRed: Color(0xFFFFFFFF),
    pin: Color(0xFF0A1F44),
    pinEdge: Color(0xFFFFFFFF),
    gold: Color(0xFFFFC72C),
    goldBg: Color(0xFFFFF3CC),
    goldInk: Color(0xFF6A4800),
    trial: Color(0xFFE9A23B),
    blue: Color(0xFF1565C0),
    blueBg: Color(0xFFDCE9FA),
    good: Color(0xFF1D7A4D),
    goodBg: Color(0xFFDAF1E3),
    warn: Color(0xFF8F5600),
    warnBg: Color(0xFFFBE9C4),
    bad: Color(0xFFB3261E),
    badBg: Color(0xFFF8DCD9),
    bezel: Color(0xFF0A1F44),
    isDark: false,
  );

  static const AppPalette dark = AppPalette(
    bg: Color(0xFF06142B),
    app: Color(0xFF0A1F3D),
    surface: Color(0xFF12294D),
    ink: Color(0xFFF2F5FA),
    muted: Color(0xFF9DB0CC),
    line: Color(0xFF223B63),
    sea: Color(0xFF0D3140),
    shallow: Color(0xFF12475A),
    land: Color(0xFF1B3A36),
    landLine: Color(0xFF2C5851),
    road: Color(0xFF2E5D57),
    red: Color(0xFFFFC72C),
    onRed: Color(0xFF0A1F44),
    pin: Color(0xFFF2F5FA),
    pinEdge: Color(0xFF0A1F3D),
    gold: Color(0xFFFFC72C),
    goldBg: Color(0xFF3A300C),
    goldInk: Color(0xFFFFD45C),
    trial: Color(0xFFF0B35A),
    blue: Color(0xFF5BA4FF),
    blueBg: Color(0xFF13305C),
    good: Color(0xFF5FD39B),
    goodBg: Color(0xFF12372A),
    warn: Color(0xFFF0B35A),
    warnBg: Color(0xFF3A2A0C),
    bad: Color(0xFFFF8D84),
    badBg: Color(0xFF40191A),
    bezel: Color(0xFF02090C),
    isDark: true,
  );
}

/// Exposed through `Theme.of(context).extension`. Prefer `context.palette`
/// over reaching for this class directly.
class AppPaletteTheme extends ThemeExtension<AppPaletteTheme> {
  const AppPaletteTheme(this.palette);

  final AppPalette palette;

  @override
  AppPaletteTheme copyWith() => this;

  @override
  AppPaletteTheme lerp(covariant AppPaletteTheme? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPaletteTheme>()?.palette ?? AppPalette.light;
}

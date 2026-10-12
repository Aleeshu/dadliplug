/// Type scale.
///
/// Mirrors the prototype's three families:
///   --f-display  Gabarito        business names, screen headings
///   --f-body     Hanken Grotesk  everything else
///   --f-mono     IBM Plex Mono   numbers, ratings, section labels
///
/// The mono family matters more than it looks: KPIs, review counts, menu
/// prices, and ranking scores all need tabular figures so columns of numbers
/// line up instead of jittering.
///
/// Colour is deliberately absent. These are theme-agnostic shapes; ink and
/// muted are applied by `AppTheme` so light and dark both work.
library;

import 'package:flutter/material.dart';

abstract final class AppText {
  // Display — Gabarito

  /// Page title. `clamp(28px, 4.4vw, 42px)` in the prototype.
  static TextStyle get displayLarge => const TextStyle(
    fontFamily: _display,
    fontFamilyFallback: ['Trebuchet MS', 'sans-serif'],
    fontSize: 30,
    fontWeight: FontWeight.w600,
    height: 1.02,
    letterSpacing: -0.3,
  );

  /// Listing / overlay heading.
  static TextStyle get displayMedium => const TextStyle(
    fontFamily: _display,
    fontFamilyFallback: ['Trebuchet MS', 'sans-serif'],
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: -0.25,
  );

  /// Business name on a listing.
  static TextStyle get titleLarge => const TextStyle(
    fontFamily: _display,
    fontFamilyFallback: ['Trebuchet MS', 'sans-serif'],
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Result card business name, `.res b`.
  static TextStyle get titleMedium => const TextStyle(
    fontFamily: _body,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Small label. Added for the listing screen's section headers; sits between
  /// `titleMedium` and `caption` rather than duplicating either.
  static TextStyle get titleSmall => const TextStyle(
    fontFamily: _body,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.2,
  );

  // Body — Hanken Grotesk

  static TextStyle get bodyLarge => const TextStyle(
    fontFamily: _body,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static TextStyle get bodyMedium => const TextStyle(
    fontFamily: _body,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// Buttons and chips.
  static TextStyle get labelLarge => const TextStyle(
    fontFamily: _body,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static TextStyle get labelMedium => const TextStyle(
    fontFamily: _body,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static TextStyle get caption => const TextStyle(
    fontFamily: _body,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // Mono — IBM Plex Mono

  /// `.card h3, .sec` — uppercase section labels.
  static TextStyle get sectionLabel => const TextStyle(
    fontFamily: _mono,
    fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.9,
  );

  /// KPI numbers, ranking scores, rank badges. Tabular so columns align.
  static TextStyle get numeric => const TextStyle(
    fontFamily: _mono,
    fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static TextStyle get numericLarge => const TextStyle(
    fontFamily: _mono,
    fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
    fontSize: 26,
    fontWeight: FontWeight.w500,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Star rating row.
  static TextStyle get rating => const TextStyle(
    fontFamily: _body,
    fontSize: 13,
    letterSpacing: 1,
    height: 1.2,
  );

  static const String _display = 'Gabarito';
  static const String _body = 'HankenGrotesk';
  static const String _mono = 'IBMPlexMono';
}

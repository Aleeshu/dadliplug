/// Spacing, radii, and elevation tokens.
///
/// Values taken from the prototype's CSS. One scale — if a number is not on
/// it, it does not go in the app.
library;

import 'package:flutter/material.dart';

abstract final class Insets {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double xxl = 14;
  static const double huge = 16;
  static const double giant = 24;
}

abstract final class Corners {
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double xxl = 14;
  static const double pill = 999;
}

/// The prototype's `--shadow`. Two layers: a tight contact shadow and a wide
/// ambient one. Cards do not float without both.
abstract final class Shadows {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: const Color(0xFF0E2530).withValues(alpha: 0.08),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0xFF0E2530).withValues(alpha: 0.14),
      blurRadius: 40,
      spreadRadius: -14,
      offset: const Offset(0, 14),
    ),
  ];

  /// Maps and floating controls sitting over the map need a tighter shadow,
  /// since the prototype uses a 1-3px blur over the sea fill.
  static List<BoxShadow> get overlay => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.18),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get raised => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.22),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
}

/// Minimum tap target. Small island, thumbs, phones held in bright sun.
abstract final class Touch {
  static const double minimum = 44;
  static const double mapButton = 36;
}

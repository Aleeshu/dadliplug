import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// The Dadliplug mark: the app icon (the D with the palm over the sea).
///
/// `assets/images/logo_mark.png` is generated from the app icon by
/// `scripts/make_brand_assets.py`, so the in-app mark and the launcher icon
/// can never drift apart.
class DadliplugMark extends StatelessWidget {
  const DadliplugMark({this.size = 40, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_mark.png',
      width: size,
      height: size,
      semanticLabel: 'Dadliplug',
    );
  }
}

/// Wordmark colours from the design.
abstract final class DadliplugColors {
  static const Color navy = Color(0xFF0A1F44);
  static const Color green = Color(0xFF3CB043);
  static const Color lightGreen = Color(0xFF9BE15D);
}

/// The mark with the wordmark and tagline, as in the Home header.
class DadliplugLogo extends StatelessWidget {
  const DadliplugLogo({this.showTagline = true, super.key});

  final bool showTagline;

  static const String tagline = 'Plug Into Local.';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DadliplugMark(size: 54),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Dadli',
                    style: TextStyle(
                      color: palette.isDark
                          ? palette.ink
                          : DadliplugColors.navy,
                    ),
                  ),
                  const TextSpan(
                    text: 'plug',
                    style: TextStyle(color: DadliplugColors.green),
                  ),
                ],
              ),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            if (showTagline)
              Text(
                tagline,
                style: TextStyle(fontSize: 13, color: palette.muted),
              ),
          ],
        ),
      ],
    );
  }
}

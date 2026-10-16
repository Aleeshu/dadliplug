import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A business's first photo, or a placeholder in its category colour.
///
/// The placeholder is plainly a placeholder — the category icon on its
/// colour — never a stock photo. A stock photo of food on a listing would be
/// a picture of somebody else's food, which is the kind of invented detail
/// the accuracy pitch rules out.
class BusinessImage extends StatelessWidget {
  const BusinessImage({required this.business, this.iconSize = 36, super.key});

  final Business business;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final url = business.photos
        .map((p) => p.url)
        .firstWhere((u) => u != null && u.isNotEmpty, orElse: () => null);

    final placeholder = _Placeholder(
      category: business.category,
      iconSize: iconSize,
    );

    if (url == null) return placeholder;

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.category, required this.iconSize});

  final BusinessCategory category;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final base = HSLColor.fromColor(category.color);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withLightness((base.lightness + 0.12).clamp(0, 1)).toColor(),
            base.withLightness((base.lightness - 0.12).clamp(0, 1)).toColor(),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          category.icon,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

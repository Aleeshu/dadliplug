import 'package:antigua_business_map/models/business_category.dart';
import 'package:flutter/material.dart';

/// A category's icon in a filled circle of its colour.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({required this.category, this.size = 56, super.key});

  final BusinessCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: category.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: category.color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(category.icon, color: Colors.white, size: size * 0.48),
    );
  }
}

/// Opens search filtered to [category].
String categoryRoute(BusinessCategory category) =>
    '/search?category=${category.dbName}';

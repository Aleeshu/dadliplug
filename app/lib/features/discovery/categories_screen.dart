import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Every category, each opening search filtered to it.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.surface,
      appBar: AppBar(title: const Text('Categories')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          Insets.huge,
          Insets.xs,
          Insets.huge,
          Insets.giant,
        ),
        itemCount: BusinessCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
        itemBuilder: (context, i) {
          final c = BusinessCategory.values[i];
          return Material(
            color: palette.surface,
            borderRadius: BorderRadius.circular(Corners.xxl),
            child: InkWell(
              borderRadius: BorderRadius.circular(Corners.xxl),
              onTap: () => context.push(categoryRoute(c)),
              child: Container(
                padding: const EdgeInsets.all(Insets.xl),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Corners.xxl),
                  border: Border.all(color: palette.line),
                ),
                child: Row(
                  children: [
                    CategoryIcon(category: c, size: 46),
                    const SizedBox(width: Insets.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.label,
                            style: AppText.titleMedium.copyWith(
                              color: palette.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.examples,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: palette.muted),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:flutter/material.dart';

/// Horizontally scrollable chip bar for filtering map pins by category & open status.
class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({
    required this.selectedCategories,
    required this.openNowOnly,
    required this.onCategoryToggled,
    required this.onOpenNowToggled,
    this.onClearAll,
    super.key,
  });

  final Set<BusinessCategory> selectedCategories;
  final bool openNowOnly;
  final ValueChanged<BusinessCategory> onCategoryToggled;
  final ValueChanged<bool> onOpenNowToggled;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.sm,
      ),
      child: Row(
        children: [
          // "Open now" status toggle chip
          _FilterChip(
            label: 'Open now',
            icon: Icons.access_time_filled,
            isSelected: openNowOnly,
            onTap: () => onOpenNowToggled(!openNowOnly),
            activeColor: palette.good,
            activeBgColor: palette.goodBg,
          ),
          const SizedBox(width: Insets.sm),

          // "All" chip when categories are selected
          if (selectedCategories.isNotEmpty && onClearAll != null) ...[
            _FilterChip(
              label: 'All',
              isSelected: false,
              onTap: onClearAll!,
            ),
            const SizedBox(width: Insets.sm),
          ],

          // Category chips
          for (final category in BusinessCategory.values) ...[
            _FilterChip(
              label: category.shortLabel,
              isSelected: selectedCategories.contains(category),
              onTap: () => onCategoryToggled(category),
            ),
            const SizedBox(width: Insets.sm),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.activeColor,
    this.activeBgColor,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? activeColor;
  final Color? activeBgColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final bgColor = isSelected
        ? (activeBgColor ?? palette.ink)
        : palette.surface;
    final fgColor = isSelected ? (activeColor ?? palette.app) : palette.ink;
    final borderColor = isSelected
        ? (activeColor ?? palette.ink)
        : palette.line;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(Corners.pill),
      elevation: isSelected ? 2 : 0,
      shadowColor: palette.ink.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Corners.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: Insets.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Corners.pill),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fgColor),
                const SizedBox(width: Insets.xs),
              ],
              Text(
                label,
                style: AppText.labelMedium.copyWith(
                  color: fgColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

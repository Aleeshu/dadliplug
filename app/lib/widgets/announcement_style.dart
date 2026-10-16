import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:flutter/material.dart';

/// Label, icon and colour for each kind of Bulletin Board post, from the
/// Dadliplug design.
({String label, IconData icon, Color color}) announcementStyle(
  AnnouncementKind kind,
) => switch (kind) {
  AnnouncementKind.important => (
    label: 'Important Update',
    icon: Icons.campaign,
    color: const Color(0xFFE8253F),
  ),
  AnnouncementKind.offer => (
    label: 'Special Offer',
    icon: Icons.local_offer,
    color: const Color(0xFF16A34A),
  ),
  AnnouncementKind.community => (
    label: 'Community',
    icon: Icons.groups,
    color: const Color(0xFF2E7CF6),
  ),
  AnnouncementKind.business => (
    label: 'Business',
    icon: Icons.storefront,
    color: const Color(0xFF8B5CF6),
  ),
};

/// The coloured circle and label at the top of a Bulletin Board card.
class AnnouncementKindLabel extends StatelessWidget {
  const AnnouncementKindLabel({required this.kind, super.key});

  final AnnouncementKind kind;

  @override
  Widget build(BuildContext context) {
    final style = announcementStyle(kind);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
          child: Icon(style.icon, size: 17, color: Colors.white),
        ),
        const SizedBox(width: Insets.md),
        Text(
          style.label,
          style: AppText.labelMedium.copyWith(
            color: style.color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/user.dart';
import 'package:flutter/material.dart';

/// Temporary role switcher.
///
/// Phase 1 has no real authentication, so this lets the team switch between the
/// three roles and see all three tab sets. It is a development affordance and
/// gets replaced by the signed-in user's role in Phase 2 — do not let it ship.
class RoleSwitcher extends StatelessWidget {
  const RoleSwitcher({required this.role, required this.onChanged, super.key});

  final UserRole role;
  final ValueChanged<UserRole> onChanged;

  static const Map<UserRole, String> _labels = {
    UserRole.user: 'User',
    UserRole.businessAdmin: 'Business',
    UserRole.teamAdmin: 'Team',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.pill),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in _labels.entries)
            GestureDetector(
              onTap: () => onChanged(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.xl,
                  vertical: Insets.sm,
                ),
                decoration: BoxDecoration(
                  color: entry.key == role ? palette.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(Corners.pill),
                ),
                child: Text(
                  entry.value,
                  style: AppText.labelMedium.copyWith(
                    fontSize: 12,
                    color: entry.key == role ? palette.app : palette.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Placeholder header for a stub screen.
///
/// Screens are stubs in Phase 1, so this gives each one a title and a
/// consistent frame. It disappears as real screens land in Phases 2–7.
class StubScaffold extends StatelessWidget {
  const StubScaffold({
    required this.title,
    this.phase,
    super.key,
  });

  final String title;

  /// Which phase builds this for real. Shown so the team knows what is missing.
  final String? phase;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Insets.xl),
            child: Center(
              child: Text(
                'Phase ${phase ?? '—'}',
                style: AppText.numeric.copyWith(color: palette.muted),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.giant),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_outlined, size: 40, color: palette.line),
              const SizedBox(height: Insets.xl),
              Text(title, style: AppText.displayMedium),
              const SizedBox(height: Insets.sm),
              Text(
                'Built in ${phase ?? 'a later phase'}.',
                style: AppText.bodyMedium.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

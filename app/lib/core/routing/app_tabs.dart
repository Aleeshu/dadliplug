import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/user.dart';
import 'package:antigua_business_map/services/auth_factory.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:flutter/material.dart';

/// A tab in the bottom bar.
class AppTab {
  const AppTab({required this.path, required this.label, required this.icon});

  final String path;
  final String label;
  final IconData icon;
}

/// Bottom tab sets, per section 6a of plan.md.
///
/// **Customers** get Home, Categories, Map, Saved, More (Dadliplug design).
/// **Businesses** get Home, Profile, Reviews, Announcements, Ads.
///
/// The split is structural, not cosmetic. A business owner is managing a
/// listing; a customer is choosing where to eat. Cramming both into one bar
/// makes the business tabs noise to a customer and buries the owner's own
/// profile under browse tools.
///
/// Hiding a tab is not access control. `app_router.dart` also redirects anyone
/// who reaches a guarded path without the role, and RLS is the real enforcement.
abstract final class AppTabs {
  /// Customer navigation.
  static const List<AppTab> user = [
    // The Dadliplug design (2026-10-15). Events and the Bulletin Board moved
    // under More to make room for Categories and Map.
    AppTab(path: '/', label: 'Home', icon: Icons.home_outlined),
    AppTab(path: '/categories', label: 'Categories', icon: Icons.grid_view),
    AppTab(path: '/map', label: 'Map', icon: Icons.map_outlined),
    AppTab(path: '/bookmarks', label: 'Saved', icon: Icons.favorite_border),
    AppTab(path: '/more', label: 'More', icon: Icons.more_horiz),
  ];

  /// Business navigation.
  ///
  /// Five tabs is the most a bottom bar holds comfortably at this label size.
  static const List<AppTab> businessAdmin = [
    AppTab(
      path: '/business',
      label: 'Home',
      icon: Icons.bar_chart_outlined,
    ),
    AppTab(
      path: '/business/listing',
      label: 'Profile',
      icon: Icons.storefront_outlined,
    ),
    AppTab(
      path: '/business/reviews',
      label: 'Reviews',
      icon: Icons.chat_bubble_outline,
    ),
    AppTab(
      path: '/business/announcements',
      label: 'Notices',
      icon: Icons.notifications_none,
    ),
    AppTab(
      path: '/business/ads',
      label: 'Ads',
      icon: Icons.campaign_outlined,
    ),
  ];

  static const List<AppTab> teamAdmin = [
    // First, because maintaining listings is the team's main job.
    AppTab(
      path: '/team/listings',
      label: 'Listings',
      icon: Icons.storefront_outlined,
    ),
    AppTab(path: '/team', label: 'Moderation', icon: Icons.shield_outlined),
    AppTab(
      path: '/team/billing',
      label: 'Billing',
      icon: Icons.credit_card_outlined,
    ),
    AppTab(path: '/team/ranking', label: 'Ranking', icon: Icons.trending_up),
    AppTab(path: '/team/spotlight', label: 'Spotlight', icon: Icons.sync),
  ];

  static List<AppTab> forRole(UserRole role) => switch (role) {
    UserRole.user => user,
    UserRole.businessAdmin => businessAdmin,
    UserRole.teamAdmin => teamAdmin,
  };

  static UserRole roleForLocation(String location) =>
      location.startsWith('/team')
      ? UserRole.teamAdmin
      : location.startsWith('/business')
      ? UserRole.businessAdmin
      : UserRole.user;

  /// The tab set the signed-in user is allowed to see.
  ///
  /// Falls back to the user tabs when the account's role does not match the
  /// area they are currently in, so a signed-out visitor deep-linking to
  /// `/team` sees the map tab bar rather than an empty one.
  static List<AppTab> forSession(AuthSession session, String currentPath) {
    final role = roleForLocation(currentPath);

    final isAllowed = switch (role) {
      UserRole.teamAdmin => session.canAccessTeamDashboard(),
      UserRole.businessAdmin => session.canAccessBusinessDashboard(),
      UserRole.user => true,
    };

    return forRole(isAllowed ? role : UserRole.user);
  }
}

/// The bottom tab bar.
///
/// Styled from the prototype: surface background, hairline top border, no
/// Material indicator pill — the selected icon turns flag red instead.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    required this.currentPath,
    required this.session,
    required this.onSelect,
    super.key,
  });

  final String currentPath;
  final AuthSession session;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tabs = AppTabs.forSession(session, currentPath);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      padding: const EdgeInsets.only(top: Insets.sm, bottom: Insets.md),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final tab in tabs)
              Expanded(
                child: _TabButton(
                  tab: tab,
                  isSelected: tab.path == _selectedPath(tabs, currentPath),
                  onTap: () => onSelect(tab.path),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The most specific tab containing [currentPath].
  ///
  /// A nested path keeps its parent tab lit, so `/business/ads/new` lights
  /// Ads. Longest match wins, otherwise `/team` (Moderation) would also light
  /// up on `/team/listings` and `/business` (Home) on every business screen.
  static String? _selectedPath(List<AppTab> tabs, String currentPath) {
    String? best;
    for (final tab in tabs) {
      // `/` is excluded from prefix matching or it would contain every path.
      final matches =
          tab.path == currentPath ||
          (tab.path != '/' && currentPath.startsWith('${tab.path}/'));
      if (matches && (best == null || tab.path.length > best.length)) {
        best = tab.path;
      }
    }
    return best;
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  final AppTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = isSelected ? palette.red : palette.muted;

    return Semantics(
      selected: isSelected,
      button: true,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Corners.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Insets.xs,
            horizontal: Insets.xxs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: 22, color: color),
              const SizedBox(height: Insets.xxs),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.labelMedium.copyWith(
                  fontSize: 11,
                  color: isSelected ? palette.ink : palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Development-only role switcher.
///
/// Exists because Phase 2 runs against the mock service, where there is no
/// backend to grant roles. Hidden whenever the app is pointed at Supabase,
/// where a client-side role change would be meaningless and misleading.
class RoleSwitcher extends StatelessWidget {
  const RoleSwitcher({
    required this.session,
    required this.controller,
    super.key,
  });

  final AuthSession session;
  final RoleSwitcherController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.isEnabled) return const SizedBox.shrink();

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
          for (final entry in const {
            UserRole.user: 'User',
            UserRole.businessAdmin: 'Business',
            UserRole.teamAdmin: 'Team',
          }.entries)
            GestureDetector(
              onTap: () => controller.setRole(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.xl,
                  vertical: Insets.sm,
                ),
                decoration: BoxDecoration(
                  color: session.role == entry.key
                      ? palette.ink
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(Corners.pill),
                ),
                child: Text(
                  entry.value,
                  style: AppText.labelMedium.copyWith(
                    fontSize: 12,
                    color: session.role == entry.key
                        ? palette.app
                        : palette.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

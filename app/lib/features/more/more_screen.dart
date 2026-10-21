import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/reviews/check_in_sheet.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:antigua_business_map/widgets/dadliplug_logo.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Everything that is not one of the four main tabs.
///
/// Events and the Bulletin Board lost their tabs to Categories and Map in the
/// Dadliplug design, so they live here, along with the account and, for
/// admins, the way into their tools.
class MoreScreen extends StatelessWidget {
  const MoreScreen({required this.session, super.key});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Scaffold(
        backgroundColor: palette.surface,
        appBar: AppBar(title: const Text('More')),
        body: ListView(
          padding: const EdgeInsets.only(bottom: Insets.giant),
          children: [
            _Item(
              icon: Icons.event,
              label: 'Events',
              onTap: () => context.go('/events'),
            ),
            _Item(
              icon: Icons.campaign_outlined,
              label: 'Bulletin Board',
              onTap: () => context.go('/announcements'),
            ),
            _Item(
              icon: Icons.qr_code_scanner,
              label: 'Check in at a business',
              onTap: () => session.isSignedIn
                  ? CheckInSheet.show(context)
                  : context.push('/sign-in'),
            ),
            _Item(
              icon: Icons.local_offer_outlined,
              label: 'Offers',
              onTap: () => context.push('/offers'),
            ),
            _Item(
              icon: Icons.verified_outlined,
              label: 'Featured businesses',
              onTap: () => context.push('/featured'),
            ),
            _Item(
              icon: Icons.emoji_events_outlined,
              label: 'Top businesses',
              onTap: () => context.go('/leaderboard'),
            ),
            const Divider(height: Insets.giant),
            _Item(
              icon: Icons.person_outline,
              label: session.isSignedIn ? 'Your account' : 'Sign in',
              onTap: () => context.push(
                session.isSignedIn ? '/profile' : '/sign-in',
              ),
            ),
            if (session.canAccessBusinessDashboard())
              _Item(
                icon: Icons.storefront_outlined,
                label: 'Business tools',
                onTap: () => context.go('/business'),
              ),
            if (session.canAccessTeamDashboard())
              _Item(
                icon: Icons.shield_outlined,
                label: 'Team tools',
                onTap: () => context.go('/team/listings'),
              ),
            const Divider(height: Insets.giant),
            _Item(
              icon: Icons.info_outline,
              label: 'About, privacy and terms',
              onTap: () => context.push('/about'),
            ),
            const SizedBox(height: Insets.giant),
            Center(
              child: Column(
                children: [
                  const DadliplugMark(size: 28),
                  const SizedBox(height: Insets.sm),
                  Text(
                    DadliplugLogo.tagline,
                    style: AppText.caption.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListTile(
      leading: Icon(icon, color: palette.red),
      title: Text(
        label,
        style: AppText.titleMedium.copyWith(color: palette.ink),
      ),
      trailing: Icon(Icons.chevron_right, color: palette.muted),
      onTap: onTap,
    );
  }
}

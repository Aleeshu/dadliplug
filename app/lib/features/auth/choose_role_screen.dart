import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The first question for someone opening the app.
///
/// Asked once, on a first run, because the two answers lead to genuinely
/// different navigation (plan.md 6a). Sending a business owner into a customer
/// feed, or a customer into a listing editor, is the worst possible first
/// impression, and most Antigua businesses have never used a directory before.
///
/// Shown before sign-in, since a guest browsing businesses is a normal state
/// and forcing an account would contradict the guest browsing decision.
class ChooseRoleScreen extends StatefulWidget {
  const ChooseRoleScreen({required this.onChosen, super.key});

  /// Receives the chosen audience. [Audience.business] also sends the visitor
  /// to sign in, since running a business requires an account.
  final void Function(Audience audience) onChosen;

  @override
  State<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

enum Audience {
  /// Runs or works for a business. Wants to advertise and manage a listing.
  business,

  /// Looking for somewhere to go, eat, or buy.
  customer,
}

class _ChooseRoleScreenState extends State<ChooseRoleScreen> {
  Audience? _selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.app,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Insets.giant),
          children: [
            const SizedBox(height: Insets.xl),
            Text(
              'IslandAds',
              style: AppText.displayLarge.copyWith(color: palette.ink),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'Businesses in Antigua, on a map. What brings you here?',
              style: AppText.bodyLarge.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.giant),

            _Choice(
              icon: Icons.storefront_outlined,
              title: 'I run a business',
              body: 'Advertise to people nearby, post events and announcements, '
                  'and see how many people are looking.',
              selected: _selected == Audience.business,
              onTap: () => setState(() => _selected = Audience.business),
            ),
            const SizedBox(height: Insets.md),
            _Choice(
              icon: Icons.explore_outlined,
              title: "I'm looking for somewhere",
              body: 'Find food, beauty, trades and more near you, and save the '
                  'places you like.',
              selected: _selected == Audience.customer,
              onTap: () => setState(() => _selected = Audience.customer),
            ),

            const SizedBox(height: Insets.giant),
            FilledButton(
              // Disabled until chosen, rather than guessing on the visitor's
              // behalf. Sending them somewhere they did not ask for is the
              // thing this screen exists to prevent.
              onPressed: _selected == null
                  ? null
                  : () => widget.onChosen(_selected!),
              child: Text(
                _selected == Audience.business
                    ? 'Continue as a business'
                    : 'Continue',
              ),
            ),
            const SizedBox(height: Insets.md),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Just have a look around'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Corners.lg),
      child: Container(
        padding: const EdgeInsets.all(Insets.lg),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(Corners.lg),
          border: Border.all(
            color: selected ? palette.red : palette.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26, color: selected ? palette.red : palette.ink),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.titleLarge.copyWith(color: palette.ink),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    body,
                    style: AppText.bodyMedium.copyWith(color: palette.muted),
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
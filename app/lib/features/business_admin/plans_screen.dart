import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/listing/listing_screen.dart'
    show singleBusinessProvider;
import 'package:antigua_business_map/models/business.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// One plan as an owner sees it on the plans screen.
class PlanOffer {
  const PlanOffer({
    required this.tier,
    required this.pitch,
    required this.features,
    this.icon = Icons.spa_outlined,
    this.popular = false,
  });

  final SubscriptionTier tier;
  final String pitch;
  final List<String> features;
  final IconData icon;
  final bool popular;
}

/// What each plan includes (2026-10-28 redesign; the plans decided
/// 2026-10-22). Kept beside the screen and checked by a test against the
/// rules the app and database enforce, so the screen never promises what
/// the plan does not allow.
const kPlanOffers = [
  PlanOffer(
    tier: SubscriptionTier.growing,
    pitch: 'Get started and get noticed.',
    features: [
      'Business profile, photos, hours and menu',
      'Phone, WhatsApp and social links',
      'Your pin on the map',
      '1 running advertisement',
      'Reviews from verified visits',
    ],
  ),
  PlanOffer(
    tier: SubscriptionTier.basic,
    pitch: 'More exposure. More customers.',
    icon: Icons.rocket_launch_outlined,
    popular: true,
    features: [
      'Everything in Starter, plus:',
      '5 running advertisements',
      'Deals with claimable codes',
      'Results: views, opens, enquiries, redemptions',
      'Move your pin and use a photo as the pin',
    ],
  ),
  PlanOffer(
    tier: SubscriptionTier.featured,
    pitch: 'Maximum exposure. Bigger impact.',
    icon: Icons.workspace_premium_outlined,
    features: [
      'Everything in Growth, plus:',
      'Unlimited advertisements',
      'A place on the Featured page',
      'Spotlight on Home, in turn',
      'Sponsored slots in the Fresh in Antigua feed',
      'The Premium badge',
    ],
  ),
];

/// "Subscription Plans" from the redesign: the three plans side by side,
/// the current one marked. Payment is by bank transfer, recorded by the team
/// (plan.md 3), so choosing a plan asks the team on WhatsApp rather than
/// taking a card.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({required this.businessId, super.key});

  final String businessId;

  Future<void> _choose(Business? b, PlanOffer offer) async {
    final text =
        'Hi Dadliplug team, I would like the ${offer.tier.label} plan '
        '(EC\$${offer.tier.monthlyPrice} a month)'
        '${b == null ? '' : ' for ${b.name}'}. How do I pay?';
    const number = AppConfig.teamWhatsApp;
    await launchUrl(
      Uri.parse(
        number.isEmpty
            ? 'https://wa.me/?text=${Uri.encodeComponent(text)}'
            : 'https://wa.me/$number?text=${Uri.encodeComponent(text)}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final b = ref.watch(singleBusinessProvider(businessId)).value;
    final current = b == null ? null : (b.plan ?? b.tier);

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Subscription Plans'),
        backgroundColor: palette.app,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          0,
          Insets.lg,
          Insets.giant,
        ),
        children: [
          Text(
            "Choose the plan that's right for you",
            style: AppText.displayMedium.copyWith(color: palette.ink),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            'Every plan starts with a free 3-day trial with all tools '
            'unlocked. Pay monthly by bank transfer; the team confirms it '
            'the same day.',
            style: AppText.bodyMedium.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.lg),
          for (final offer in kPlanOffers) ...[
            _PlanCard(
              offer: offer,
              isCurrent: current == offer.tier,
              onChoose: () => _choose(b, offer),
            ),
            const SizedBox(height: Insets.md),
          ],
          Text(
            'Rank is earned, never bought: no plan moves you up the '
            'leaderboard or search. Paid placements are always labelled.',
            style: AppText.caption.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.offer,
    required this.isCurrent,
    required this.onChoose,
  });

  final PlanOffer offer;
  final bool isCurrent;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = offer.popular ? palette.red : palette.line;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.xl),
        border: Border.all(color: accent, width: offer.popular ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (offer.popular)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: palette.red,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(Corners.xl - 2),
                ),
              ),
              child: Text(
                'Most Popular',
                textAlign: TextAlign.center,
                style: AppText.labelMedium.copyWith(color: palette.onRed),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: palette.app,
                      child: Icon(offer.icon, color: palette.red),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.tier.label,
                            style: AppText.titleLarge.copyWith(
                              color: palette.ink,
                            ),
                          ),
                          Text(
                            offer.pitch,
                            style: AppText.caption.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'EC\$${offer.tier.monthlyPrice}',
                          style: AppText.displayMedium.copyWith(
                            color: palette.ink,
                          ),
                        ),
                        Text(
                          'per month',
                          style: AppText.caption.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                for (final f in offer.features)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check, size: 18, color: palette.good),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: Text(
                            f,
                            style: AppText.bodyMedium.copyWith(
                              color: palette.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: Insets.md),
                if (isCurrent)
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Your current plan'),
                  )
                else if (offer.popular)
                  FilledButton(
                    onPressed: onChoose,
                    child: Text('Choose ${offer.tier.label}'),
                  )
                else
                  OutlinedButton(
                    onPressed: onChoose,
                    child: Text('Choose ${offer.tier.label}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

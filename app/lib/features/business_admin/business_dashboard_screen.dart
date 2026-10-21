import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/listing/listing_screen.dart'
    show singleBusinessProvider;
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:antigua_business_map/services/billing.dart';
import 'package:antigua_business_map/services/push_service.dart';
import 'package:antigua_business_map/services/rank_explainer.dart';
import 'package:antigua_business_map/services/specials.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The business Home tab: one listing, and every tool that acts on it.
///
/// Analytics and the review verification queue arrive in Phases 6–7. Until
/// then this is the way into the Phase 4 tools — the monthly report and the
/// event poster had no route in from the tab bar at all, so they were only
/// reachable by typing a URL.
class BusinessDashboardScreen extends ConsumerWidget {
  const BusinessDashboardScreen({
    required this.businessId,
    this.otherBusinessIds = const [],
    super.key,
  });

  /// The listing in focus. Empty when the account has none linked.
  final String businessId;

  /// Every listing this account manages, for switching between them. The team
  /// and multi-site owners have more than one.
  final List<String> otherBusinessIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    PushService.enableForBusiness();
    final palette = context.palette;

    if (businessId.isEmpty) {
      return Scaffold(
        backgroundColor: palette.app,
        appBar: AppBar(title: const Text('Your business')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.giant),
            child: Text(
              'No listing is linked to your account yet. The Dadliplug team '
              'links it once your listing is set up.',
              textAlign: TextAlign.center,
              style: AppText.bodyLarge.copyWith(color: palette.muted),
            ),
          ),
        ),
      );
    }

    final businessAsync = ref.watch(singleBusinessProvider(businessId));
    final q = '?business=$businessId';

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Your business'),
        backgroundColor: palette.app,
        surfaceTintColor: Colors.transparent,
      ),
      body: businessAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: palette.red),
        ),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.giant),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load your listing.',
                  style: AppText.titleMedium.copyWith(color: palette.ink),
                ),
                const SizedBox(height: Insets.md),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(singleBusinessProvider(businessId)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (business) => ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            if (business == null)
              Text(
                'This listing could not be found. It may have been removed.',
                style: AppText.bodyLarge.copyWith(color: palette.muted),
              )
            else ...[
              _PlanBanner(business: business),
              const SizedBox(height: Insets.md),
              _SpecialCard(business: business),
              const SizedBox(height: Insets.md),
              _RankCard(business: business),
              const SizedBox(height: Insets.md),
              _Summary(business: business, palette: palette),
            ],
            if (otherBusinessIds.length > 1) ...[
              const SizedBox(height: Insets.md),
              _Switcher(
                ids: otherBusinessIds,
                current: businessId,
              ),
            ],
            const SizedBox(height: Insets.xl),
            _Tool(
              icon: Icons.edit_outlined,
              title: 'Edit listing',
              body: 'Hours, contact details, menu, tags, closed today.',
              onTap: () => context.go('/business/listing$q'),
            ),
            _Tool(
              icon: Icons.campaign_outlined,
              title: 'Advertisements',
              body: 'Post an ad, end one, see views per ad.',
              onTap: () => context.go('/business/ads$q'),
            ),
            _Tool(
              icon: Icons.notifications_none,
              title: 'Announcements',
              body: 'Closures, notices and offers for your followers.',
              onTap: () => context.go('/business/announcements$q'),
            ),
            _Tool(
              icon: Icons.event_outlined,
              title: 'Events',
              body: 'Put something on the island calendar.',
              onTap: () => context.go('/business/events$q'),
            ),
            _Tool(
              icon: Icons.qr_code_2,
              title: 'Visit QR for the till',
              body: 'Customers scan it to check in, which lets them review.',
              onTap: () => context.push('/business/visit-code$q'),
            ),
            _Tool(
              icon: Icons.insert_chart_outlined,
              title: 'Monthly report',
              body: 'Views, calls, WhatsApp taps and reviews this month.',
              onTap: () => context.push('/business/report$q'),
            ),
            _Tool(
              icon: Icons.visibility_outlined,
              title: 'See it as a customer',
              body: 'Your public listing, exactly as it appears.',
              onTap: () => context.push('/listing/$businessId'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.business, required this.palette});

  final Business business;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final status = openInfo(business);

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            business.name,
            style: AppText.titleLarge.copyWith(color: palette.ink),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            '${business.tier.label} plan · ${status.label}',
            style: AppText.bodyMedium.copyWith(
              color: status.isOpen ? palette.good : palette.muted,
            ),
          ),
          if (business.tier == SubscriptionTier.overdue) ...[
            const SizedBox(height: Insets.sm),
            Text(
              'Payment is overdue. Your listing stays up for 7 days, then it '
              'is removed. Contact the Dadliplug team to settle it.',
              style: AppText.bodyMedium.copyWith(color: palette.bad),
            ),
          ],
        ],
      ),
    );
  }
}

class _Switcher extends ConsumerWidget {
  const _Switcher({required this.ids, required this.current});

  final List<String> ids;
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: [
        for (final id in ids)
          ChoiceChip(
            selected: id == current,
            label: Text(
              ref.watch(singleBusinessProvider(id)).value?.name ?? '…',
              style: AppText.labelMedium.copyWith(
                color: id == current ? palette.app : palette.ink,
              ),
            ),
            selectedColor: palette.ink,
            onSelected: (_) => context.go('/business?business=$id'),
          ),
      ],
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Corners.md),
          child: Container(
            padding: const EdgeInsets.all(Insets.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Corners.md),
              border: Border.all(color: palette.line),
            ),
            child: Row(
              children: [
                Icon(icon, color: palette.red),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.titleMedium.copyWith(color: palette.ink),
                      ),
                      const SizedBox(height: Insets.xxs),
                      Text(
                        body,
                        style: AppText.caption.copyWith(color: palette.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: palette.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the subscription stands, at the top of the owner's dashboard:
/// trial days left, renewal coming, or the hold before delisting. Payment is
/// by bank transfer to the team, which records it.
class _PlanBanner extends StatelessWidget {
  const _PlanBanner({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = billingStatus(business);
    final (fg, bg) = switch (status.tone) {
      BillingTone.ok => (palette.good, palette.goodBg),
      BillingTone.warn => (palette.warn, palette.warnBg),
      BillingTone.bad => (palette.bad, palette.badBg),
    };

    return Container(
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Corners.xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            status.tone == BillingTone.ok
                ? Icons.check_circle_outline
                : Icons.schedule,
            color: fg,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.title,
                  style: AppText.titleSmall.copyWith(color: fg),
                ),
                const SizedBox(height: 2),
                Text(
                  status.detail,
                  style: AppText.bodyMedium.copyWith(color: palette.ink),
                ),
                if (status.tone != BillingTone.ok) ...[
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Pay by bank transfer and message the Dadliplug team; we '
                    'record it the same day.',
                    style: AppText.caption.copyWith(color: palette.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's special: post it, mark it sold out, take it down.
///
/// On the dashboard rather than in the listing editor because it changes
/// daily and should take seconds. It expires on its own at midnight.
class _SpecialCard extends ConsumerStatefulWidget {
  const _SpecialCard({required this.business});

  final Business business;

  @override
  ConsumerState<_SpecialCard> createState() => _SpecialCardState();
}

class _SpecialCardState extends ConsumerState<_SpecialCard> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function(SpecialsRepository repo) write,
  ) async {
    setState(() => _busy = true);
    try {
      await write(ref.read(specialsRepositoryProvider));
      _text.clear();
      ref
        ..invalidate(singleBusinessProvider(widget.business.id))
        ..invalidate(businessListProvider);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update the special. Check your signal.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final id = widget.business.id;
    final special = todaysSpecial(widget.business);

    return Container(
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.xl),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Today's special",
            style: AppText.titleMedium.copyWith(color: palette.ink),
          ),
          Text(
            'Shown on your listing until midnight. Locals check back for it.',
            style: AppText.caption.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.md),
          if (special != null) ...[
            Text(
              special.text,
              style: AppText.bodyLarge.copyWith(
                color: special.soldOut ? palette.muted : palette.ink,
                decoration: special.soldOut ? TextDecoration.lineThrough : null,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sold out'),
              value: special.soldOut,
              onChanged: _busy
                  ? null
                  : (v) => _run((r) => r.setSoldOut(id, soldOut: v)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : () => _run((r) => r.clear(id)),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Take it down'),
              ),
            ),
          ] else ...[
            TextField(
              controller: _text,
              maxLength: kSpecialMaxLength,
              decoration: const InputDecoration(
                hintText: r'e.g. Catch of the day: grilled snapper, EC$45',
              ),
            ),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      final text = _text.text.trim();
                      if (text.isNotEmpty) _run((r) => r.post(id, text));
                    },
              child: const Text('Post special'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Where the listing ranks in its category, and what would move it.
class _RankCard extends ConsumerWidget {
  const _RankCard({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final all = ref.watch(businessListProvider).value;
    if (all == null || !all.any((b) => b.id == business.id)) {
      // Not listed publicly right now (held or delisted): no rank to show.
      return const SizedBox.shrink();
    }
    final r = explainRank(business, all);

    return Container(
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.xl),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ordinal(r.position)} of ${r.of} in ${business.category.label}',
            style: AppText.titleMedium.copyWith(color: palette.ink),
          ),
          Text(
            r.pointsToNext == null
                ? 'Top of your category, with ${r.total} points.'
                : '${r.total} points; ${r.pointsToNext} behind the next place.',
            style: AppText.caption.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.md),
          for (final f in r.factors) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${f.name} (${f.weightPercent}%)',
                    style: AppText.labelMedium.copyWith(color: palette.ink),
                  ),
                ),
                Text(
                  '${(f.score * 100).round()}%',
                  style: AppText.caption.copyWith(color: palette.muted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(Corners.sm),
              child: LinearProgressIndicator(
                value: f.score,
                minHeight: 6,
                backgroundColor: palette.line,
                valueColor: AlwaysStoppedAnimation(palette.red),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              f.explanation,
              style: AppText.caption.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.md),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.trending_up, size: 18, color: palette.good),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  r.suggestion,
                  style: AppText.bodyMedium.copyWith(color: palette.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Rank is earned, never bought: a Featured plan puts you on the '
            'Featured page, not higher here.',
            style: AppText.caption.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

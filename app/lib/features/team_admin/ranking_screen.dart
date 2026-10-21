import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/leaderboard_service.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/services/ranking_repository.dart';
import 'package:antigua_business_map/services/ranking_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// A listing whose numbers deserve a second look before anyone trusts its rank.
///
/// Owner and team taps are already excluded server-side, and a signed-in
/// customer counts once an hour. What remains is guests: someone calling a
/// listing over and over without opening it. Real customers open a listing
/// far more often than they call it, so intent outrunning views is the tell.
String? engagementWarning(Business b) {
  final intent = b.calls + b.whatsappTaps;
  if (intent >= 20 && intent > b.views) {
    return '$intent calls and taps against ${b.views} views. Check for '
        'repeated taps before trusting this rank.';
  }
  return null;
}

/// The team's view of the ranking: every listing in a category, its score and
/// the parts behind it, who is held back and why, and who has moved.
///
/// Being transparent about the score is the point (plan.md section 5): a
/// business paying EC$100 can be shown exactly what it needs to improve.
class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  BusinessCategory _category = BusinessCategory.food;
  bool _busy = false;

  Future<void> _snapshot() async {
    setState(() => _busy = true);
    try {
      final rows = await ref.read(rankingRepositoryProvider).snapshotNow();
      ref.invalidate(teamRankHistoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Today's snapshot saved: $rows listings.")),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the snapshot.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final all = ref.watch(businessListProvider);
    final history = ref.watch(teamRankHistoryProvider).value ?? const {};

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Ranking'),
        backgroundColor: palette.app,
        actions: [
          IconButton(
            tooltip: "Save today's snapshot now",
            onPressed: _busy ? null : _snapshot,
            icon: const Icon(Icons.camera_alt_outlined),
          ),
        ],
      ),
      body: all.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(businessListProvider),
            child: const Text('Could not load listings. Try again'),
          ),
        ),
        data: (businesses) {
          final board = const LeaderboardService().build(
            businesses: businesses,
            category: _category,
            now: DateTime.now(),
          );
          final everyone =
              businesses.where((b) => b.category == _category).toList()
                ..sort(compareByRank);

          return ListView(
            padding: const EdgeInsets.all(Insets.lg),
            children: [
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in BusinessCategory.values)
                      Padding(
                        padding: const EdgeInsets.only(right: Insets.sm),
                        child: ChoiceChip(
                          label: Text(
                            '${c.label} '
                            '(${businesses.where((b) => b.category == c).length})',
                          ),
                          selected: c == _category,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.md),
              Text(
                board.entries.isEmpty
                    ? 'No public board for ${_category.label}: nothing is '
                          'eligible yet.'
                    : 'Public board shows ${board.entries.length} of '
                          '${board.totalEligible} eligible.',
                style: AppText.bodyMedium.copyWith(color: palette.muted),
              ),
              const SizedBox(height: Insets.md),
              if (everyone.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Insets.giant),
                  child: Text(
                    'No listings in this category.',
                    textAlign: TextAlign.center,
                    style: AppText.bodyMedium.copyWith(color: palette.muted),
                  ),
                ),
              for (final (i, b) in everyone.indexed) ...[
                _RankRow(
                  position: i + 1,
                  business: b,
                  excluded: board.excluded
                      .where((e) => e.business.id == b.id)
                      .firstOrNull,
                  movement: weeklyMovement(history[b.id] ?? const []),
                ),
                const SizedBox(height: Insets.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.position,
    required this.business,
    required this.excluded,
    required this.movement,
  });

  final int position;
  final Business business;
  final ExcludedBusiness? excluded;
  final int? movement;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final score = scoreBusiness(business);
    final stats = reviewStats(business);
    final warning = engagementWarning(business);
    final caption = AppText.caption.copyWith(color: palette.muted);
    final exclusion = excluded;

    return InkWell(
      onTap: () => context.push('/listing/${business.id}'),
      borderRadius: BorderRadius.circular(Corners.md),
      child: Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(Corners.md),
          border: Border.all(
            color: warning == null ? palette.line : palette.warn,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '$position',
                    style: AppText.titleMedium.copyWith(color: palette.muted),
                  ),
                ),
                Expanded(
                  child: Text(
                    business.name,
                    style: AppText.titleSmall.copyWith(color: palette.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (movement case final m? when m != 0)
                  Padding(
                    padding: const EdgeInsets.only(right: Insets.sm),
                    child: Text(
                      m > 0 ? '▲$m' : '▼${-m}',
                      style: AppText.labelMedium.copyWith(
                        color: m > 0 ? palette.good : palette.bad,
                      ),
                    ),
                  ),
                Text(
                  '${score.total}',
                  style: AppText.titleMedium.copyWith(color: palette.ink),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rating ${(score.rating * 100).round()}% · '
                    'Reviews ${(score.volume * 100).round()}% · '
                    'Activity ${(score.engagement * 100).round()}%   '
                    '${stats.average.toStringAsFixed(1)}★ from ${stats.count}, '
                    '${business.views} views, '
                    '${business.calls + business.whatsappTaps} calls/taps',
                    style: caption,
                  ),
                  if (exclusion != null)
                    Text(
                      switch (exclusion.reason) {
                        LeaderboardExclusion.withinGracePeriod =>
                          'Off the public board until '
                              '${DateFormat.MMMd().format(exclusion.eligibleFrom!.toLocal())} '
                              '(first month)',
                        LeaderboardExclusion.notRankable =>
                          'Online only: never on the public board',
                      },
                      style: AppText.caption.copyWith(color: palette.warn),
                    ),
                  if (warning != null)
                    Text(
                      warning,
                      style: AppText.caption.copyWith(color: palette.bad),
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

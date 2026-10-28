import 'package:antigua_business_map/widgets/verified_badge.dart';
import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/leaderboard_service.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/services/ranking_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Which category's board is being shown.
class LeaderboardCategoryNotifier extends Notifier<BusinessCategory> {
  @override
  BusinessCategory build() => BusinessCategory.food;

  BusinessCategory get category => state;
  set category(BusinessCategory category) => state = category;
}

/// Which measure the board ranks by.
class LeaderboardModeNotifier extends Notifier<LeaderboardMode> {
  @override
  LeaderboardMode build() => LeaderboardMode.top;

  LeaderboardMode get mode => state;
  set mode(LeaderboardMode mode) => state = mode;
}

final leaderboardModeProvider =
    NotifierProvider<LeaderboardModeNotifier, LeaderboardMode>(
      LeaderboardModeNotifier.new,
    );

final leaderboardCategoryProvider =
    NotifierProvider<LeaderboardCategoryNotifier, BusinessCategory>(
      LeaderboardCategoryNotifier.new,
    );

/// The board for the selected category.
///
/// Returns null when the category has nothing to rank, so the screen can
/// explain why rather than rendering an empty "Top 10".
final leaderboardProvider = Provider<AsyncValue<Leaderboard?>>((ref) {
  final businesses = ref.watch(businessListProvider);
  final category = ref.watch(leaderboardCategoryProvider);

  return businesses.whenData((list) {
    // Every eligible listing, so the other tabs can re-rank them.
    final board = const LeaderboardService(defaultSize: 1000).build(
      businesses: list,
      category: category,
      // Read the clock once so every business in one build is judged against
      // the same instant. A business listed at 23:59 must not age differently
      // from one listed at 00:01 during the same render.
      now: DateTime.now(),
    );
    return board.isEmpty ? null : board;
  });
});

/// Categories that currently have a board worth showing.
final leaderboardCategoriesProvider =
    Provider<AsyncValue<List<BusinessCategory>>>((ref) {
      final businesses = ref.watch(businessListProvider);
      return businesses.whenData(
        (list) => const LeaderboardService().categoriesWithEntries(
          businesses: list,
          now: DateTime.now(),
        ),
      );
    });

/// "Top 10 Food businesses by popularity".
///
/// Built on earned score, never on who paid. A Featured business with no
/// reviews appears nowhere near the top, which is the point.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(leaderboardProvider);
    final categoriesAsync = ref.watch(leaderboardCategoriesProvider);
    final mode = ref.watch(leaderboardModeProvider);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: palette.app,
        surfaceTintColor: Colors.transparent,
      ),
      body: boardAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: palette.red),
        ),
        error: (error, _) => _Message(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load the leaderboard',
          body: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(businessListProvider),
        ),
        data: (board) {
          if (board == null) {
            return const _Message(
              icon: Icons.emoji_events_outlined,
              title: 'No businesses to rank yet',
              body:
                  'A listing joins the leaderboard a month after it goes '
                  'live, so there is time to collect real reviews and views '
                  'first.',
            );
          }

          final categories =
              categoriesAsync.value ?? const <BusinessCategory>[];
          final entries = rankBy([
            for (final e in board.entries) e.business,
          ], mode);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(businessListProvider);
              await ref.read(businessListProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(Insets.lg),
              children: [
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final m in LeaderboardMode.values)
                        Padding(
                          padding: const EdgeInsets.only(right: Insets.sm),
                          child: ChoiceChip(
                            label: Text(m.label),
                            selected: m == mode,
                            onSelected: (_) =>
                                ref
                                        .read(leaderboardModeProvider.notifier)
                                        .mode =
                                    m,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.md),
                Text(
                  'TOP ${entries.length} '
                  '${board.category.label.toUpperCase()} BUSINESSES',
                  style: AppText.sectionLabel,
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  mode == LeaderboardMode.top
                      ? 'By reviews from people who visited, and views.'
                      : '${mode.label}, among businesses listed a month or '
                            'more. Nobody pays for a place here.',
                  style: AppText.bodyMedium.copyWith(color: palette.muted),
                ),
                const SizedBox(height: Insets.lg),

                if (categories.length > 1) ...[
                  _CategoryChips(
                    selected: board.category,
                    available: categories,
                  ),
                  const SizedBox(height: Insets.lg),
                ],

                for (final entry in entries)
                  _EntryRow(
                    entry: entry,
                    palette: palette,
                    metric: mode.describe(entry.business),
                  ),

                if (board.totalEligible > entries.length) ...[
                  const SizedBox(height: Insets.md),
                  Text(
                    '${board.totalEligible} businesses qualify. Showing the '
                    'top ${entries.length}.',
                    style: AppText.caption.copyWith(color: palette.muted),
                  ),
                ],

                if (board.excluded.isNotEmpty) ...[
                  const SizedBox(height: Insets.xl),
                  _WaitingRoom(excluded: board.excluded, palette: palette),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.palette,
    required this.metric,
  });

  final LeaderboardEntry entry;
  final AppPalette palette;

  /// The figure this tab ranks by, e.g. "1240 views".
  final String metric;

  @override
  Widget build(BuildContext context) {
    final b = entry.business;
    // The star average a customer recognises. `entry.score.rating` is the
    // normalised 0–1 ranking component, which rendered as "0.8 · 42 reviews"
    // beside a business averaging 4.6 stars.
    final stats = reviewStats(b);

    return InkWell(
      // The id was missing, so every row opened a route that matched nothing.
      onTap: () => context.push('/listing/${b.id}'),
      borderRadius: BorderRadius.circular(Corners.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: Insets.sm),
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(Corners.md),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${entry.position}',
                style: AppText.numericLarge.copyWith(
                  color: entry.position <= 3 ? palette.gold : palette.muted,
                ),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          b.name,
                          style: AppText.titleMedium.copyWith(
                            color: palette.ink,
                          ),
                        ),
                      ),
                      // Featured buys a slot and a badge. It does not buy a
                      // position here, which is why the badge sits beside the
                      // name rather than pushing it up the table.
                      if (b.tier.isVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: Insets.xs),
                          child: VerifiedBadge(),
                        ),
                    ],
                  ),
                  const SizedBox(height: Insets.xxs),
                  Text(
                    stats.count == 0
                        ? 'No reviews yet'
                        : '${stats.average.toStringAsFixed(1)} · '
                              '${stats.count} '
                              '${stats.count == 1 ? 'rating' : 'ratings'}',
                    style: AppText.caption.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
            Text(
              metric,
              style: AppText.caption.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(Icons.chevron_right, color: palette.muted),
          ],
        ),
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.selected, required this.available});

  final BusinessCategory selected;
  final List<BusinessCategory> available;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final category in available) ...[
            InkWell(
              onTap: () =>
                  ref.read(leaderboardCategoryProvider.notifier).category =
                      category,
              borderRadius: BorderRadius.circular(Corners.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.sm,
                ),
                decoration: BoxDecoration(
                  color: category == selected ? palette.ink : palette.surface,
                  borderRadius: BorderRadius.circular(Corners.pill),
                  border: Border.all(color: palette.line),
                ),
                child: Text(
                  category.shortLabel,
                  style: AppText.labelMedium.copyWith(
                    color: category == selected ? palette.app : palette.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Insets.sm),
          ],
        ],
      ),
    );
  }
}

/// Explains the businesses that are on the map but not on the board.
///
/// Without this the leaderboard looks broken to anyone who just listed, and to
/// every customer wondering why a shop they can see is missing.
class _WaitingRoom extends StatelessWidget {
  const _WaitingRoom({required this.excluded, required this.palette});

  final List<ExcludedBusiness> excluded;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat.MMMd();
    final waiting = excluded
        .where((e) => e.reason == LeaderboardExclusion.withinGracePeriod)
        .toList();

    if (waiting.isEmpty) return const SizedBox.shrink();

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
            'JOINING SOON',
            style: AppText.sectionLabel.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'A new listing needs a month to collect reviews and views before '
            'it is ranked, so the board reflects real custom rather than who '
            'signed up first.',
            style: AppText.bodyMedium.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.md),
          for (final entry in waiting)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.xs),
              child: Text(
                // Never show a business whose eligibility date cannot be
                // established. "Joining soon" with no date is vague enough to
                // be unhelpful.
                entry.eligibleFrom == null
                    ? '${entry.business.name} — joining soon'
                    : '${entry.business.name} — joins '
                          '${format.format(entry.eligibleFrom!.toLocal())}',
                style: AppText.bodyMedium.copyWith(color: palette.ink),
              ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
        Icon(icon, size: 44, color: palette.muted),
        const SizedBox(height: Insets.lg),
        Center(
          child: Text(
            title,
            style: AppText.displayMedium.copyWith(color: palette.ink),
          ),
        ),
        const SizedBox(height: Insets.sm),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: Insets.lg),
          Center(
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
        ],
      ],
    );
  }
}

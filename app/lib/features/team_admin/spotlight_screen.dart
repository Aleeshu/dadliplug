import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:antigua_business_map/services/ranking_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The next Monday 00:10 in Antigua, when the board turns over, as a local
/// Antigua wall-clock date.
DateTime nextSpotlightTurnover(DateTime now) {
  final island = AntiguaClock.antiguaTimeOf(now);
  final today = DateTime(island.year, island.month, island.day);
  final daysAhead = (DateTime.monday - today.weekday) % 7;
  final monday = today.add(Duration(days: daysAhead == 0 ? 7 : daysAhead));
  return monday;
}

/// Who holds the ten Spotlight slots this week, who is next, and when it
/// turns over (plan.md section 3: least-recently-featured first, weekly).
class SpotlightScreen extends ConsumerStatefulWidget {
  const SpotlightScreen({super.key});

  @override
  ConsumerState<SpotlightScreen> createState() => _SpotlightScreenState();
}

class _SpotlightScreenState extends ConsumerState<SpotlightScreen> {
  bool _busy = false;

  Future<void> _rotate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rotate now?'),
        content: const Text(
          "This replaces this week's board with the next businesses in line. "
          'It also runs by itself every Monday at 00:10.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Rotate'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(rankingRepositoryProvider).rotateSpotlightNow();
      ref
        ..invalidate(spotlightProvider)
        ..invalidate(businessListProvider);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not rotate the board.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final board = ref.watch(spotlightProvider);
    final all = ref.watch(businessListProvider).value ?? const <Business>[];
    final caption = AppText.caption.copyWith(color: palette.muted);

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Spotlight'),
        backgroundColor: palette.app,
        actions: [
          TextButton(
            onPressed: _busy ? null : _rotate,
            child: const Text('Rotate now'),
          ),
        ],
      ),
      body: board.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(spotlightProvider),
            child: const Text('Could not load the board. Try again'),
          ),
        ),
        data: (slots) {
          final onBoard = {for (final b in slots) b.id};
          // In line: everyone eligible not on the board, oldest turn first.
          final waiting =
              all
                  .where(
                    (b) =>
                        !onBoard.contains(b.id) &&
                        (b.plan == SubscriptionTier.featured ||
                            b.plan == SubscriptionTier.basic),
                  )
                  .toList()
                ..sort((a, b) {
                  final band =
                      (a.plan == SubscriptionTier.featured ? 0 : 1) -
                      (b.plan == SubscriptionTier.featured ? 0 : 1);
                  if (band != 0) return band;
                  return a.lastSpotlightWeek.compareTo(b.lastSpotlightWeek);
                });

          return ListView(
            padding: const EdgeInsets.all(Insets.lg),
            children: [
              Text(
                '${slots.length} of 10 slots filled. Turns over Monday '
                '${DateFormat.MMMd().format(nextSpotlightTurnover(DateTime.now()))}, '
                '00:10.',
                style: AppText.bodyMedium.copyWith(color: palette.ink),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                'Featured plans go first, least recently shown first; Basic '
                'plans fill empty slots. Score only breaks ties.',
                style: caption,
              ),
              const SizedBox(height: Insets.lg),
              for (final (i, b) in slots.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: palette.goldBg,
                    child: Text(
                      '${i + 1}',
                      style: AppText.labelMedium.copyWith(
                        color: palette.goldInk,
                      ),
                    ),
                  ),
                  title: Text(b.name),
                  subtitle: Text((b.plan ?? b.tier).label, style: caption),
                ),
              if (waiting.isNotEmpty) ...[
                const Divider(height: Insets.xxl),
                Text(
                  'Next in line',
                  style: AppText.titleMedium.copyWith(color: palette.ink),
                ),
                for (final b in waiting)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(b.name),
                    subtitle: Text(
                      '${(b.plan ?? b.tier).label} · '
                      '${b.lastSpotlightWeek < 0 ? 'never shown' : 'last shown in week ${b.lastSpotlightWeek}'}',
                      style: caption,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

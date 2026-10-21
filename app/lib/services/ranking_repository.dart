import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One listing's rank on one day, from the nightly snapshot.
class RankSnapshot {
  const RankSnapshot({
    required this.day,
    required this.businessId,
    required this.score,
    required this.position,
    required this.of,
  });

  factory RankSnapshot.fromMap(Map<String, dynamic> m) => RankSnapshot(
    day: DateTime.parse('${m['day']}'),
    businessId: '${m['business_id']}',
    score: (m['score'] as num).toInt(),
    position: (m['position'] as num).toInt(),
    of: (m['of_count'] as num).toInt(),
  );

  final DateTime day;
  final String businessId;
  final int score;
  final int position;
  final int of;
}

/// Places gained (positive) or lost over about a week, or null when there is
/// not yet a week of history to compare against.
///
/// Compares the newest snapshot with the newest one at least six days older,
/// so a missed nightly run does not turn "this week" into "since yesterday".
int? weeklyMovement(List<RankSnapshot> history) {
  if (history.length < 2) return null;
  final sorted = [...history]..sort((a, b) => b.day.compareTo(a.day));
  final latest = sorted.first;
  for (final s in sorted.skip(1)) {
    if (latest.day.difference(s.day).inDays >= 6) {
      return s.position - latest.position;
    }
  }
  return null;
}

/// The Spotlight board and the rank snapshots (plan.md Phase 8).
///
/// Both are computed by the database on a schedule (Spotlight on Monday,
/// snapshots nightly); this only reads them, plus the team's "run it now".
class RankingRepository {
  RankingRepository({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _db {
    final client = _client;
    if (client != null) return client;
    if (!AppConfig.supabaseConfigured) throw const BackendNotConfigured();
    return Supabase.instance.client;
  }

  /// This week's Spotlight, as business ids in slot order.
  Future<List<String>> spotlightIds() async {
    final rows = await _db
        .from('spotlight')
        .select('week, business_id, rank')
        .order('week', ascending: false)
        .order('rank')
        .limit(20);
    if (rows.isEmpty) return const [];
    final week = rows.first['week'];
    return [
      for (final r in rows)
        if (r['week'] == week) '${r['business_id']}',
    ];
  }

  /// A listing's snapshots over the last [days], oldest first. Owner or team.
  Future<List<RankSnapshot>> history(String businessId, {int days = 30}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await _db
        .from('rank_snapshots')
        .select()
        .eq('business_id', businessId)
        .gte('day', since.toIso8601String().substring(0, 10))
        .order('day');
    return rows.map(RankSnapshot.fromMap).toList(growable: false);
  }

  /// Every listing's last two weeks of snapshots, for the team. Keyed by id.
  Future<Map<String, List<RankSnapshot>>> recentForAll() async {
    final since = DateTime.now().subtract(const Duration(days: 14));
    final rows = await _db
        .from('rank_snapshots')
        .select()
        .gte('day', since.toIso8601String().substring(0, 10))
        .order('day');
    final out = <String, List<RankSnapshot>>{};
    for (final s in rows.map(RankSnapshot.fromMap)) {
      (out[s.businessId] ??= []).add(s);
    }
    return out;
  }

  Future<int> rotateSpotlightNow() => _db.rpc<int>('rotate_spotlight');

  Future<int> snapshotNow() => _db.rpc<int>('snapshot_ranks');
}

final rankingRepositoryProvider = Provider<RankingRepository>(
  (ref) => RankingRepository(),
);

/// This week's Spotlight listings, in slot order. Listings no longer visible
/// drop out rather than leaving a gap.
final spotlightProvider = FutureProvider<List<Business>>((ref) async {
  final ids = await ref.watch(rankingRepositoryProvider).spotlightIds();
  final all = await ref.watch(businessListProvider.future);
  final byId = {for (final b in all) b.id: b};
  return [
    for (final id in ids)
      if (byId[id] case final b?) b,
  ];
});

// Inferred: the family type is only nameable via riverpod/src.
// ignore: specify_nonobvious_property_types
final rankHistoryProvider = FutureProvider.family<List<RankSnapshot>, String>(
  (ref, businessId) => ref.watch(rankingRepositoryProvider).history(businessId),
);

final teamRankHistoryProvider = FutureProvider<Map<String, List<RankSnapshot>>>(
  (ref) => ref.watch(rankingRepositoryProvider).recentForAll(),
);

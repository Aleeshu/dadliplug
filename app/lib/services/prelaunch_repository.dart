import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A team notice across the top of the app: a storm watch, an island-wide
/// closure (plan.md 14c, "storm banner").
class AppNotice {
  const AppNotice({
    required this.id,
    required this.isStorm,
    required this.title,
    required this.body,
    required this.linkUrl,
    required this.startsAt,
    required this.endsAt,
  });

  factory AppNotice.fromMap(Map<String, dynamic> m) => AppNotice(
    id: '${m['id']}',
    isStorm: m['kind'] == 'storm',
    title: '${m['title']}',
    body: (m['body'] as String?) ?? '',
    linkUrl: m['link_url'] as String?,
    startsAt: DateTime.parse('${m['starts_at']}'),
    endsAt: m['ends_at'] == null ? null : DateTime.parse('${m['ends_at']}'),
  );

  final String id;
  final bool isStorm;
  final String title;
  final String body;
  final String? linkUrl;
  final DateTime startsAt;
  final DateTime? endsAt;

  bool isLiveAt(DateTime now) =>
      !startsAt.isAfter(now) && (endsAt == null || endsAt!.isAfter(now));
}

/// A team-written list: "Best pepperpot", "Open on Sunday".
class Collection {
  const Collection({
    required this.id,
    required this.title,
    required this.blurb,
    required this.coverUrl,
    required this.published,
    required this.businessIds,
  });

  factory Collection.fromMap(Map<String, dynamic> m) {
    final items = [
      ...((m['collection_items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>(),
    ]..sort((a, b) => (a['position'] as num).compareTo(b['position'] as num));
    return Collection(
      id: '${m['id']}',
      title: '${m['title']}',
      blurb: (m['blurb'] as String?) ?? '',
      coverUrl: m['cover_url'] as String?,
      published: (m['published'] as bool?) ?? false,
      businessIds: [for (final i in items) '${i['business_id']}'],
    );
  }

  final String id;
  final String title;
  final String blurb;
  final String? coverUrl;
  final bool published;
  final List<String> businessIds;

  /// The listings in this collection still visible, in the team's order.
  List<Business> resolve(List<Business> all) {
    final byId = {for (final b in all) b.id: b};
    return [
      for (final id in businessIds)
        if (byId[id] case final b?) b,
    ];
  }
}

/// Notices, collections, blocks and account deletion: what the stores and
/// plan.md 14c ask for before launch.
class PrelaunchRepository {
  PrelaunchRepository({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _db {
    final client = _client;
    if (client != null) return client;
    if (!AppConfig.supabaseConfigured) throw const BackendNotConfigured();
    return Supabase.instance.client;
  }

  String? get _uid => _db.auth.currentUser?.id;

  // Notices ------------------------------------------------------------------

  /// Live notices, storms first. RLS returns only live ones to customers.
  Future<List<AppNotice>> liveNotices() async {
    final rows = await _db
        .from('app_notices')
        .select()
        .order('created_at', ascending: false);
    final now = DateTime.now();
    return rows.map(AppNotice.fromMap).where((n) => n.isLiveAt(now)).toList()
      ..sort((a, b) => (b.isStorm ? 1 : 0) - (a.isStorm ? 1 : 0));
  }

  /// Every notice, for the team.
  Future<List<AppNotice>> allNotices() async {
    final rows = await _db
        .from('app_notices')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(AppNotice.fromMap).toList(growable: false);
  }

  Future<void> postNotice({
    required bool isStorm,
    required String title,
    required String body,
    String? linkUrl,
    DateTime? endsAt,
  }) => _db.from('app_notices').insert({
    'kind': isStorm ? 'storm' : 'info',
    'title': title.trim(),
    'body': body.trim(),
    'link_url': (linkUrl?.trim().isEmpty ?? true) ? null : linkUrl!.trim(),
    'ends_at': endsAt?.toUtc().toIso8601String(),
    'created_by': _uid,
  });

  Future<void> endNotice(String id) => _db
      .from('app_notices')
      .update({'ends_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id);

  // Collections --------------------------------------------------------------

  Future<List<Collection>> collections() async {
    final rows = await _db
        .from('collections')
        .select('*, collection_items(business_id, position)')
        .order('position');
    return rows.map(Collection.fromMap).toList(growable: false);
  }

  Future<String> createCollection(String title, String blurb) async {
    final row = await _db
        .from('collections')
        .insert({'title': title.trim(), 'blurb': blurb.trim()})
        .select('id')
        .single();
    return '${row['id']}';
  }

  Future<void> setPublished(String id, {required bool published}) =>
      _db.from('collections').update({'published': published}).eq('id', id);

  Future<void> deleteCollection(String id) =>
      _db.from('collections').delete().eq('id', id);

  /// Replaces the collection's listings with [businessIds], in that order.
  Future<void> setItems(String collectionId, List<String> businessIds) async {
    await _db
        .from('collection_items')
        .delete()
        .eq('collection_id', collectionId);
    if (businessIds.isEmpty) return;
    await _db.from('collection_items').insert([
      for (final (i, id) in businessIds.indexed)
        {'collection_id': collectionId, 'business_id': id, 'position': i},
    ]);
  }

  // Blocks -------------------------------------------------------------------

  Future<Set<String>> blockedUserIds() async {
    if (_uid == null) return const {};
    final rows = await _db.from('user_blocks').select('blocked_user_id');
    return {for (final r in rows) '${r['blocked_user_id']}'};
  }

  Future<void> block(String userId) => _db.from('user_blocks').upsert({
    'user_id': _uid,
    'blocked_user_id': userId,
  });

  Future<void> unblock(String userId) => _db
      .from('user_blocks')
      .delete()
      .eq('user_id', _uid ?? '')
      .eq('blocked_user_id', userId);

  // Account ------------------------------------------------------------------

  /// Deletes the signed-in account and everything tied to it, then signs out.
  Future<void> deleteMyAccount() async {
    await _db.rpc<void>('delete_my_account');
    await _db.auth.signOut();
  }

  /// Whether the island has no team admin yet: the only time the
  /// "become a team admin" bootstrap should be offered.
  Future<bool> bootstrapOpen() async =>
      (await _db.rpc<bool?>('bootstrap_open')) ?? false;

  /// The signed-in user's id, or null when signed out or with no backend.
  String? get currentUserId {
    try {
      return _uid;
    } on BackendNotConfigured {
      return null;
    }
  }
}

final prelaunchRepositoryProvider = Provider<PrelaunchRepository>(
  (ref) => PrelaunchRepository(),
);

final liveNoticesProvider = FutureProvider<List<AppNotice>>(
  (ref) => ref.watch(prelaunchRepositoryProvider).liveNotices(),
);

final allNoticesProvider = FutureProvider<List<AppNotice>>(
  (ref) => ref.watch(prelaunchRepositoryProvider).allNotices(),
);

final collectionsProvider = FutureProvider<List<Collection>>(
  (ref) => ref.watch(prelaunchRepositoryProvider).collections(),
);

/// Published collections with at least one visible listing, resolved.
final homeCollectionsProvider =
    FutureProvider<List<(Collection, List<Business>)>>((ref) async {
      final cols = await ref.watch(collectionsProvider.future);
      final all = await ref.watch(businessListProvider.future);
      return [
        for (final c in cols.where((c) => c.published))
          if (c.resolve(all) case final list when list.isNotEmpty) (c, list),
      ];
    });

final blockedUsersProvider = FutureProvider<Set<String>>(
  (ref) => ref.watch(prelaunchRepositoryProvider).blockedUserIds(),
);

final bootstrapOpenProvider = FutureProvider<bool>(
  (ref) => ref.watch(prelaunchRepositoryProvider).bootstrapOpen(),
);

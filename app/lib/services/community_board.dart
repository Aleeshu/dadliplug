import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The board's sections (Business Plan 2).
enum PostKind {
  job('job', 'Jobs', Icons.work_outline),
  forSale('for_sale', 'For Sale', Icons.sell_outlined),
  notice('notice', 'Community Notices', Icons.campaign_outlined),
  opportunity(
    'opportunity',
    'Business Opportunities',
    Icons.handshake_outlined,
  );

  const PostKind(this.dbName, this.label, this.icon);
  final String dbName;
  final String label;
  final IconData icon;

  static PostKind fromDb(String raw) =>
      PostKind.values.where((k) => k.dbName == raw).firstOrNull ??
      PostKind.notice;
}

/// One post on the community board.
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.priceEc,
    required this.area,
    required this.contact,
    required this.imageUrl,
    required this.authorId,
    required this.status,
    required this.statusNote,
    required this.featured,
    required this.createdAt,
    required this.expiresAt,
  });

  factory CommunityPost.fromMap(Map<String, dynamic> m) => CommunityPost(
    id: '${m['id']}',
    kind: PostKind.fromDb('${m['kind']}'),
    title: '${m['title']}',
    body: '${m['body']}',
    priceEc: (m['price_ec'] as num?)?.toDouble(),
    area: (m['area'] as String?) ?? '',
    contact: '${m['contact']}',
    imageUrl: m['image_url'] as String?,
    authorId: '${m['author_id']}',
    status: '${m['status']}',
    statusNote: m['status_note'] as String?,
    featured: (m['featured'] as bool?) ?? false,
    createdAt: DateTime.parse('${m['created_at']}'),
    expiresAt: DateTime.parse('${m['expires_at']}'),
  );

  final String id;
  final PostKind kind;
  final String title;
  final String body;
  final double? priceEc;
  final String area;

  /// A phone or WhatsApp number, as the poster gave it.
  final String contact;
  final String? imageUrl;
  final String authorId;

  /// pending, live, rejected or removed.
  final String status;
  final String? statusNote;
  final bool featured;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isLive => status == 'live';

  /// Digits for a wa.me or tel: link.
  String get contactDigits => contact.replaceAll(RegExp('[^0-9]'), '');
}

/// The board, newest first, featured posts on top. Pure, for tests.
List<CommunityPost> orderBoard(List<CommunityPost> posts) =>
    [...posts]..sort((a, b) {
      if (a.featured != b.featured) return a.featured ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });

/// Reads and writes the community board. Moderation is enforced by the
/// database: new posts start pending, the team decides, five open at most.
class CommunityBoardRepository {
  CommunityBoardRepository({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _db {
    final client = _client;
    if (client != null) return client;
    if (!AppConfig.supabaseConfigured) throw const BackendNotConfigured();
    return Supabase.instance.client;
  }

  String? get currentUserId {
    try {
      return _db.auth.currentUser?.id;
    } on BackendNotConfigured {
      return null;
    }
  }

  /// Live posts (RLS hides the rest from customers).
  Future<List<CommunityPost>> live() async {
    final rows = await _db
        .from('community_posts')
        .select()
        .eq('status', 'live')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(200);
    return orderBoard(rows.map(CommunityPost.fromMap).toList());
  }

  /// The signed-in person's own posts, any status.
  Future<List<CommunityPost>> mine() async {
    final uid = currentUserId;
    if (uid == null) return const [];
    final rows = await _db
        .from('community_posts')
        .select()
        .eq('author_id', uid)
        .order('created_at', ascending: false);
    return rows.map(CommunityPost.fromMap).toList(growable: false);
  }

  /// Posts waiting for the team, oldest first.
  Future<List<CommunityPost>> pending() async {
    final rows = await _db
        .from('community_posts')
        .select()
        .eq('status', 'pending')
        .order('created_at');
    return rows.map(CommunityPost.fromMap).toList(growable: false);
  }

  /// Live posts someone reported, with the reasons, for the team.
  Future<List<(CommunityPost, List<String>)>> reported() async {
    final rows = await _db
        .from('community_post_reports')
        .select('reason, community_posts(*)')
        .order('created_at', ascending: false);
    final byPost = <String, (CommunityPost, List<String>)>{};
    for (final r in rows) {
      final p = r['community_posts'];
      if (p is! Map<String, dynamic>) continue;
      final post = CommunityPost.fromMap(p);
      if (!post.isLive) continue;
      final entry = byPost[post.id] ??= (post, <String>[]);
      entry.$2.add('${r['reason']}');
    }
    return byPost.values.toList(growable: false);
  }

  Future<void> submit({
    required PostKind kind,
    required String title,
    required String body,
    required String contact,
    String area = '',
    double? priceEc,
    String? imageUrl,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw const AuthException('Sign in to post');
    await _db.from('community_posts').insert({
      'kind': kind.dbName,
      'title': title.trim(),
      'body': body.trim(),
      'contact': contact.trim(),
      'area': area.trim(),
      'price_ec': priceEc,
      'image_url': imageUrl,
      'author_id': uid,
    });
  }

  Future<void> remove(String postId) =>
      _db.from('community_posts').delete().eq('id', postId);

  Future<void> report(String postId, String reason) async {
    final uid = currentUserId;
    if (uid == null) throw const AuthException('Sign in to report');
    await _db.from('community_post_reports').upsert({
      'post_id': postId,
      'user_id': uid,
      'reason': reason.trim(),
    });
  }

  Future<void> decide(String postId, String status, {String? note}) =>
      _db.rpc<void>(
        'decide_community_post',
        params: {'p_post': postId, 'p_status': status, 'p_note': note},
      );

  Future<void> setFeatured(String postId, {required bool featured}) => _db
      .from('community_posts')
      .update({'featured': featured})
      .eq('id', postId);
}

String boardErrorMessage(Object error) => switch (error) {
  PostgrestException(:final message) when message.isNotEmpty => message,
  AuthException(:final message) => message,
  _ => 'Could not reach Dadliplug. Check your signal and try again.',
};

final communityBoardRepositoryProvider = Provider<CommunityBoardRepository>(
  (ref) => CommunityBoardRepository(),
);

final liveBoardProvider = FutureProvider<List<CommunityPost>>(
  (ref) => ref.watch(communityBoardRepositoryProvider).live(),
);

final myBoardPostsProvider = FutureProvider<List<CommunityPost>>(
  (ref) => ref.watch(communityBoardRepositoryProvider).mine(),
);

final pendingBoardProvider = FutureProvider<List<CommunityPost>>(
  (ref) => ref.watch(communityBoardRepositoryProvider).pending(),
);

final reportedBoardProvider =
    FutureProvider<List<(CommunityPost, List<String>)>>(
      (ref) => ref.watch(communityBoardRepositoryProvider).reported(),
    );

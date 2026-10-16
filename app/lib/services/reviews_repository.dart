import 'dart:convert';

import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/models/review.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Verified visits and reviews (plan.md sections 7 and 8).
///
/// Every write goes through a database function that applies the rules:
/// checking in needs today's code from the till, reviewing needs a checked-in
/// visit (or a request the business approved), and declining a request needs
/// a reason. The tables themselves refuse direct writes.
class ReviewsRepository {
  ReviewsRepository({this._client, this._prefs});

  final SupabaseClient? _client;
  final SharedPreferences? _prefs;

  SupabaseClient get _db {
    final client = _client;
    if (client != null) return client;
    if (!AppConfig.supabaseConfigured) {
      throw const BackendNotConfigured();
    }
    return Supabase.instance.client;
  }

  String? get _uid => _db.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Visit codes
  // ---------------------------------------------------------------------------

  /// Today's code for the business to show at the till. Changes at Antigua
  /// midnight, so a photo of yesterday's QR is worthless.
  Future<String> currentVisitCode(String businessId) async =>
      await _db.rpc<String>(
        'current_visit_code',
        params: {'p_business': businessId},
      );

  /// Checks in with a scanned or typed code.
  ///
  /// With no signal the check-in is kept on the phone and sent later with the
  /// time it was made, which the server accepts for three days. Returns
  /// whether it was recorded now ([CheckInResult.recorded]) or queued.
  Future<CheckInResult> checkIn({
    required String businessId,
    required String code,
    DateTime? scannedAt,
  }) async {
    final at = (scannedAt ?? DateTime.now()).toUtc();
    try {
      await _checkInNow(businessId, code, at);
      return CheckInResult.recorded;
    } on PostgrestException {
      // The server answered and said no (wrong code, too old, own business).
      // That is a real refusal, not a connection problem; never queue it.
      rethrow;
    } on AuthException {
      rethrow;
    } catch (error) {
      debugPrint('Check-in queued for later: $error');
      await _queue(PendingCheckIn(businessId, normaliseVisitCode(code), at));
      return CheckInResult.queued;
    }
  }

  Future<void> _checkInNow(String businessId, String code, DateTime at) =>
      _db.rpc<void>(
        'check_in',
        params: {
          'p_business': businessId,
          'p_code': normaliseVisitCode(code),
          'p_scanned_at': at.toIso8601String(),
        },
      );

  static const _queueKey = 'pending_check_ins';

  Future<SharedPreferences> get _store async =>
      _prefs ?? await SharedPreferences.getInstance();

  Future<void> _queue(PendingCheckIn item) async {
    final store = await _store;
    final list = (store.getStringList(_queueKey) ?? [])
      ..add(jsonEncode(item.toJson()));
    await store.setStringList(_queueKey, list);
  }

  /// Sends check-ins made offline. Ones the server refuses are dropped (they
  /// will never succeed); ones that still cannot connect stay queued.
  Future<int> syncPendingCheckIns() async {
    if (_uid == null) return 0;
    final store = await _store;
    final raw = store.getStringList(_queueKey) ?? [];
    if (raw.isEmpty) return 0;

    var sent = 0;
    final keep = <String>[];
    for (final entry in raw) {
      final item = PendingCheckIn.fromJson(
        jsonDecode(entry) as Map<String, dynamic>,
      );
      try {
        await _checkInNow(item.businessId, item.code, item.scannedAt);
        sent++;
      } on PostgrestException catch (e) {
        debugPrint('Queued check-in refused, dropping: ${e.message}');
      } catch (_) {
        keep.add(entry);
      }
    }
    await store.setStringList(_queueKey, keep);
    return sent;
  }

  // ---------------------------------------------------------------------------
  // The viewer's standing with one business
  // ---------------------------------------------------------------------------

  Future<ReviewEligibility> eligibility(String businessId) async {
    final uid = _uid;
    if (uid == null) return ReviewEligibility.signedOut;

    final reviewed = await _db
        .from('reviews')
        .select('id')
        .eq('user_id', uid)
        .eq('business_id', businessId)
        .maybeSingle();
    if (reviewed != null) return ReviewEligibility.alreadyReviewed;

    final visit = await _db
        .from('visits')
        .select('id')
        .eq('user_id', uid)
        .eq('business_id', businessId)
        .eq('confirmed_by_business', true)
        .limit(1);
    if ((visit as List).isNotEmpty) return ReviewEligibility.canReview;

    final approved = await _db
        .from('review_requests')
        .select('id')
        .eq('user_id', uid)
        .eq('business_id', businessId)
        .eq('status', 'approved')
        .limit(1);
    return (approved as List).isNotEmpty
        ? ReviewEligibility.canReview
        : ReviewEligibility.needsVisit;
  }

  // ---------------------------------------------------------------------------
  // Reviews
  // ---------------------------------------------------------------------------

  Future<void> submitReview({
    required String businessId,
    required int rating,
    required String body,
  }) => _db.rpc<void>(
    'submit_review',
    params: {'p_business': businessId, 'p_rating': rating, 'p_body': body},
  );

  /// Reviews on a listing. The public sees verified ones; the business sees
  /// all of its own, including reported and disputed ones.
  Future<List<Review>> loadReviews(String businessId) async {
    final rows = await _db
        .from('reviews')
        .select(
          'id, business_id, user_id, rating, body, status, reply, '
          'replied_at, is_reported, is_disputed, created_at',
        )
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(200);
    return [for (final r in rows as List<dynamic>) ?_review(r)];
  }

  /// Reported or disputed reviews, for the team queue.
  Future<List<Review>> loadModerationQueue() async {
    final rows = await _db
        .from('reviews')
        .select(
          'id, business_id, user_id, rating, body, status, reply, '
          'replied_at, is_reported, is_disputed, created_at',
        )
        .or('is_reported.eq.true,is_disputed.eq.true')
        .neq('status', 'removed')
        .order('created_at', ascending: false);
    return [for (final r in rows as List<dynamic>) ?_review(r)];
  }

  Future<void> reply(String reviewId, String text) =>
      _db.from('reviews').update({'reply': text.trim()}).eq('id', reviewId);

  Future<void> setDisputed(String reviewId, {required bool disputed}) =>
      _db.from('reviews').update({'is_disputed': disputed}).eq('id', reviewId);

  Future<void> report(String reviewId, String reason) => _db.rpc<void>(
    'report_review',
    params: {'p_review': reviewId, 'p_reason': reason},
  );

  /// Team only: take a review down, or clear its flags and keep it.
  Future<void> moderate(String reviewId, {required bool remove}) => _db
      .from('reviews')
      .update(
        remove
            ? {'status': 'removed'}
            : {'is_reported': false, 'is_disputed': false},
      )
      .eq('id', reviewId);

  // ---------------------------------------------------------------------------
  // Review requests (the fallback for businesses that cannot show a QR)
  // ---------------------------------------------------------------------------

  Future<void> requestToReview(String businessId) async {
    final uid = _uid;
    if (uid == null) throw const AuthException('Sign in first');
    await _db.from('review_requests').insert({
      'user_id': uid,
      'business_id': businessId,
    });
  }

  Future<List<ReviewRequest>> loadRequests(String businessId) async {
    final rows = await _db
        .from('review_requests')
        .select('id, user_id, status, decline_reason, requested_at')
        .eq('business_id', businessId)
        .order('requested_at', ascending: false);
    return [
      for (final r in rows as List<dynamic>)
        if (r is Map)
          ReviewRequest(
            id: '${r['id']}',
            status: '${r['status']}',
            declineReason: r['decline_reason']?.toString(),
            requestedAt:
                DateTime.tryParse('${r['requested_at']}') ?? DateTime.now(),
          ),
    ];
  }

  Future<void> respond(
    String requestId, {
    required bool approve,
    String? reason,
  }) => _db.rpc<void>(
    'respond_to_review_request',
    params: {
      'p_request': requestId,
      'p_approve': approve,
      'p_reason': reason,
    },
  );

  // ---------------------------------------------------------------------------
  // Team audit
  // ---------------------------------------------------------------------------

  Future<List<ReviewAuditRow>> audit() async {
    final rows = await _db.rpc<List<dynamic>>('review_audit');
    return [
      for (final r in rows)
        if (r is Map)
          ReviewAuditRow(
            businessId: '${r['business_id']}',
            businessName: '${r['business_name']}',
            requests: (r['requests'] as num?)?.toInt() ?? 0,
            approved: (r['approved'] as num?)?.toInt() ?? 0,
            declined: (r['declined'] as num?)?.toInt() ?? 0,
            checkedInVisits: (r['checked_in_visits'] as num?)?.toInt() ?? 0,
            reviews: (r['reviews'] as num?)?.toInt() ?? 0,
            recentDeclineReasons: [
              for (final s in (r['recent_decline_reasons'] as List? ?? []))
                '$s',
            ],
          ),
    ];
  }

  static Review? _review(Object? raw) {
    if (raw is! Map) return null;
    final created = DateTime.tryParse('${raw['created_at']}');
    if (created == null) return null;
    return Review(
      id: '${raw['id']}',
      businessId: '${raw['business_id']}',
      userId: '${raw['user_id']}',
      rating: (raw['rating'] as num?)?.toInt() ?? 0,
      body: raw['body']?.toString() ?? '',
      createdAt: created,
      status: ReviewStatus.values.firstWhere(
        (s) => s.name == raw['status'],
        orElse: () => ReviewStatus.locked,
      ),
      reply: raw['reply']?.toString(),
      repliedAt: DateTime.tryParse('${raw['replied_at']}'),
      isReported: raw['is_reported'] == true,
      isDisputed: raw['is_disputed'] == true,
    );
  }
}

enum CheckInResult { recorded, queued }

enum ReviewEligibility { signedOut, needsVisit, canReview, alreadyReviewed }

@immutable
class PendingCheckIn {
  const PendingCheckIn(this.businessId, this.code, this.scannedAt);

  factory PendingCheckIn.fromJson(Map<String, dynamic> j) => PendingCheckIn(
    '${j['b']}',
    '${j['c']}',
    DateTime.parse('${j['t']}'),
  );

  final String businessId;
  final String code;
  final DateTime scannedAt;

  Map<String, dynamic> toJson() => {
    'b': businessId,
    'c': code,
    't': scannedAt.toIso8601String(),
  };
}

@immutable
class ReviewRequest {
  const ReviewRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.declineReason,
  });

  final String id;
  final String status;
  final DateTime requestedAt;
  final String? declineReason;
}

@immutable
class ReviewAuditRow {
  const ReviewAuditRow({
    required this.businessId,
    required this.businessName,
    required this.requests,
    required this.approved,
    required this.declined,
    required this.checkedInVisits,
    required this.reviews,
    required this.recentDeclineReasons,
  });

  final String businessId;
  final String businessName;
  final int requests;
  final int approved;
  final int declined;
  final int checkedInVisits;
  final int reviews;
  final List<String> recentDeclineReasons;

  /// "approved 9 of 10" — the number plan.md section 7 asks the team to watch.
  double? get approvalRate => requests == 0 ? null : approved / requests;
}

/// Upper-case, no spaces: what the till shows and the server compares.
String normaliseVisitCode(String raw) =>
    raw.trim().toUpperCase().replaceAll(' ', '');

/// The QR payload for a business's code: `dadliplug:visit:<id>:<code>`.
String visitQrPayload(String businessId, String code) =>
    'dadliplug:visit:$businessId:$code';

/// The business id and code from a scanned QR, or null if it is not ours.
({String businessId, String code})? parseVisitQr(String raw) {
  final parts = raw.trim().split(':');
  if (parts.length != 4 || parts[0] != 'dadliplug' || parts[1] != 'visit') {
    return null;
  }
  if (parts[2].isEmpty || parts[3].isEmpty) return null;
  return (businessId: parts[2], code: normaliseVisitCode(parts[3]));
}

/// The message a refused check-in or review shows: the database raises
/// readable ones on purpose ("That code does not match this business today").
String reviewErrorMessage(Object error) => switch (error) {
  PostgrestException(:final message) => message,
  AuthException() => 'Sign in first.',
  _ => 'Something went wrong. Check your connection and try again.',
};

final reviewsRepositoryProvider = Provider<ReviewsRepository>(
  (ref) => ReviewsRepository(),
);

// Inferred: the family type is only nameable via riverpod/src.
// ignore: specify_nonobvious_property_types
final reviewsForBusinessProvider = FutureProvider.family<List<Review>, String>(
  (ref, businessId) =>
      ref.watch(reviewsRepositoryProvider).loadReviews(businessId),
);

// Inferred: the family type is only nameable via riverpod/src.
// ignore: specify_nonobvious_property_types
final reviewEligibilityProvider =
    FutureProvider.family<ReviewEligibility, String>((ref, businessId) async {
      try {
        return await ref
            .watch(reviewsRepositoryProvider)
            .eligibility(businessId);
      } on BackendNotConfigured {
        return ReviewEligibility.signedOut;
      }
    });

// Inferred: the family type is only nameable via riverpod/src.
// ignore: specify_nonobvious_property_types
final visitCodeProvider = FutureProvider.family<String, String>(
  (ref, businessId) =>
      ref.watch(reviewsRepositoryProvider).currentVisitCode(businessId),
);

// Inferred: the family type is only nameable via riverpod/src.
// ignore: specify_nonobvious_property_types
final reviewRequestsProvider =
    FutureProvider.family<List<ReviewRequest>, String>(
      (ref, businessId) =>
          ref.watch(reviewsRepositoryProvider).loadRequests(businessId),
    );

final moderationQueueProvider = FutureProvider<List<Review>>(
  (ref) => ref.watch(reviewsRepositoryProvider).loadModerationQueue(),
);

final reviewAuditProvider = FutureProvider<List<ReviewAuditRow>>(
  (ref) => ref.watch(reviewsRepositoryProvider).audit(),
);

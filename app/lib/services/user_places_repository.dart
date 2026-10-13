import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/models/review.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A place the signed-in user has been, joined with enough of the business to
/// render a row without a second round trip.
class UserPlace {
  const UserPlace({
    required this.visitId,
    required this.businessId,
    required this.businessName,
    required this.visitedAt,
    this.category,
    this.confirmedByBusiness = false,
    this.reviewStatus,
  });

  final String visitId;
  final String businessId;
  final String businessName;

  /// Null when the stored category is one this build does not know about.
  ///
  /// Deliberately not defaulted to some other category: that would put a
  /// business under an industry it is not in, which is the exact class of
  /// wrong information this app is supposed to avoid. The row renders as
  /// "Other" instead.
  final BusinessCategory? category;
  final DateTime visitedAt;

  /// The business approved this visitor, so a review can be written.
  final bool confirmedByBusiness;

  /// Where the review request for this visit currently stands, if any.
  final ReviewStatus? reviewStatus;

  /// True once the user can actually write a review for this visit.
  ///
  /// Deliberately requires business confirmation, not just a visit. A visit on
  /// its own is self-reported, and an app whose whole claim is that ratings are
  /// earned cannot let anyone review anywhere they claim to have been.
  bool get canReview => confirmedByBusiness;
}

/// Raised when the user's own data is needed but nobody is signed in.
///
/// A distinct type rather than a bare [StateError] so the providers can tell
/// "nobody is signed in, show a prompt" apart from "the query failed". Catching
/// [Error] to make that distinction does not work: `StateError` is an `Error`,
/// and a failure that should surface as an error message then gets swallowed
/// into an empty list.
class NotSignedInException implements Exception {
  const NotSignedInException();

  @override
  String toString() => 'NotSignedInException: your places needs a signed-in user.';
}

/// Reads the signed-in user's own history.
///
/// Scoped to `auth.uid()` rather than taking a user id, so a caller cannot ask
/// for somebody else's visits. Row Level Security enforces the same thing on
/// the server; this is belt and braces, not the control.
class UserPlacesRepository {
  UserPlacesRepository({this._client, this._userId});

  final SupabaseClient? _client;
  final String? _userId;

  SupabaseClient get _require {
    final client = _client;
    if (client != null) return client;
    if (!AppConfig.supabaseConfigured) {
      throw StateError(AppConfig.supabaseMissingBuildHint);
    }
    return Supabase.instance.client;
  }

  String get _uid => requireUserId();

  /// The signed-in user id, or a throw when there is nobody signed in.
  ///
  /// Exposed so the providers can distinguish "signed out, show a prompt" from
  /// "signed in, the query failed" without duplicating the lookup.
  String requireUserId() {
    final id = _userId;
    if (id != null && id.isNotEmpty) return id;
    final current = _require.auth.currentUser;
    if (current == null) {
      throw const NotSignedInException();
    }
    return current.id;
  }

  /// Visits, newest first, joined to the business name.
  ///
  /// A missing business row is skipped rather than thrown: a visit to a
  /// delisted business should not be able to break the whole screen.
  Future<List<UserPlace>> loadPlaces() async {
    final rows = await _require
        .from('visits')
        .select('id, business_id, visited_at, confirmed_by_business, '
            'businesses (id, name, category)')
        .eq('user_id', _uid)
        .order('visited_at', ascending: false);

    return _fold(rows);
  }

  /// Review requests for this user, newest first.
  ///
  /// `review_requests` has its own lifecycle (`pending`/`approved`/`declined`)
  /// that is not the same vocabulary as [ReviewStatus], so it is translated
  /// here rather than leaked into the UI.
  Future<List<ReviewRequestSummary>> loadReviewRequests() async {
    final rows = await _require
        .from('review_requests')
        .select('id, business_id, status, requested_at, '
            'businesses (id, name)')
        .eq('user_id', _uid)
        .order('requested_at', ascending: false);

    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(_requestFrom)
        .whereType<ReviewRequestSummary>()
        .toList();
  }

  ReviewRequestSummary? _requestFrom(Map<String, dynamic> row) {
    final business = row['businesses'];
    final businessId = row['business_id'] as String?;
    if (business is! Map || businessId == null) return null;

    final requestedAt = DateTime.tryParse(row['requested_at']?.toString() ?? '');
    if (requestedAt == null) return null;

    return ReviewRequestSummary(
      id: row['id']?.toString() ?? '',
      businessId: businessId,
      businessName: business['name'] as String? ?? 'a business',
      status: switch (row['status']?.toString()) {
        'approved' => ReviewRequestStatus.approved,
        'declined' => ReviewRequestStatus.declined,
        _ => ReviewRequestStatus.pending,
      },
      requestedAt: requestedAt,
    );
  }

  List<UserPlace> _fold(List<dynamic> rows) {
    final places = <UserPlace>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final business = raw['businesses'];
      final businessId = raw['business_id'] as String?;
      final visitedAt = DateTime.tryParse(raw['visited_at']?.toString() ?? '');
      if (business is! Map || businessId == null || visitedAt == null) continue;

      places.add(
        UserPlace(
          visitId: raw['id']?.toString() ?? '',
          businessId: businessId,
          businessName: business['name'] as String? ?? 'a business',
          category: _categoryFrom(business['category']?.toString()),
          visitedAt: visitedAt,
          confirmedByBusiness:
              raw['confirmed_by_business'] == true ||
                  raw['confirmed_by_business'] == 'true',
        ),
      );
    }
    return places;
  }

  /// Unknown categories must not throw and must not be guessed at. A listing
  /// saved before a category was renamed still renders, as "Other".
  BusinessCategory? _categoryFrom(String? raw) {
    if (raw == null) return null;
    final normalised = raw.replaceAll('_', '').replaceAll(' ', '').toLowerCase();
    for (final category in BusinessCategory.values) {
      final name = category.name.replaceAll('_', '').toLowerCase();
      if (name == normalised) return category;
    }
    return null;
  }
}

/// The lifecycle of a request to review a business.
enum ReviewRequestStatus {
  /// Asked the business for permission. No answer yet.
  pending,

  /// The business confirmed the visit. A review can be written.
  approved,

  /// The business said no.
  declined,
}

/// A pending, approved or declined review request.
class ReviewRequestSummary {
  const ReviewRequestSummary({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.status,
    required this.requestedAt,
  });

  final String id;
  final String businessId;
  final String businessName;
  final ReviewRequestStatus status;
  final DateTime requestedAt;
}

final userPlacesRepositoryProvider = Provider<UserPlacesRepository>(
  (ref) => UserPlacesRepository(),
);

/// The signed-in user's visit history.
///
/// Returns empty when signed out rather than throwing, so a signed-out user
/// sees a sign-in prompt instead of an error screen.
final userPlacesProvider = FutureProvider<List<UserPlace>>((ref) async {
  final repo = ref.watch(userPlacesRepositoryProvider);
  if (!_signedIn(repo)) return const [];
  try {
    return await repo.loadPlaces();
  } catch (error) {
    debugPrint('Could not load your places: $error');
    rethrow;
  }
});

final reviewRequestsProvider =
    FutureProvider<List<ReviewRequestSummary>>((ref) async {
  final repo = ref.watch(userPlacesRepositoryProvider);
  if (!_signedIn(repo)) return const [];
  return repo.loadReviewRequests();
});

/// True when there is a user to load data for.
bool _signedIn(UserPlacesRepository repo) {
  try {
    repo.requireUserId();
    return true;
  } on NotSignedInException {
    return false;
  }
}

/// Reviews, and the request to write one.
///
/// The gate is the point: a review only counts once the business has confirmed
/// the reviewer actually used them. That makes bought ratings structurally
/// hard, because a fake reviewer needs the business's cooperation — and if
/// they cooperate, the business is part of the problem.
library;

/// Lifecycle of a review or review request.
enum ReviewStatus {
  /// Reviewer asked for permission. The business has not answered.
  pending,

  /// Business confirmed the customer. Review is unlocked and live.
  verified,

  /// Review exists but is not yet counted. Reserved for the edge case where a
  /// review lands before verification is granted.
  locked,

  /// Team removed it after a report or dispute.
  removed,
}

/// A review, or a request for one. One type, two states, because they share
/// almost every field and separating them doubles the read paths.
class Review {
  const Review({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.rating,
    required this.body,
    required this.createdAt,
    this.status = ReviewStatus.locked,
    this.reply,
    this.repliedAt,
    this.userName,
    this.isReported = false,
    this.isDisputed = false,
  });

  final String id;
  final String businessId;
  final String userId;

  /// 1–5.
  final int rating;
  final String body;
  final DateTime createdAt;
  final ReviewStatus status;

  /// Business response. Businesses replying to reviews is a selling point, so
  /// it lives on the review rather than in a separate thread.
  final String? reply;
  final DateTime? repliedAt;

  final String? userName;

  final bool isReported;
  final bool isDisputed;

  /// Only verified, non-removed reviews count toward a business's rating.
  bool get isVisible => status == ReviewStatus.verified;

  bool get hasReply => reply != null && reply!.isNotEmpty;

  /// A request with no review written yet. Rendered in the business's
  /// verification queue.
  bool get isRequestOnly =>
      status == ReviewStatus.pending && body.trim().isEmpty;

  Review copyWith({
    ReviewStatus? status,
    String? reply,
    DateTime? repliedAt,
    String? body,
    bool? isReported,
    bool? isDisputed,
  }) => Review(
    id: id,
    businessId: businessId,
    userId: userId,
    rating: rating,
    body: body ?? this.body,
    createdAt: createdAt,
    status: status ?? this.status,
    reply: reply ?? this.reply,
    repliedAt: repliedAt ?? this.repliedAt,
    userName: userName,
    isReported: isReported ?? this.isReported,
    isDisputed: isDisputed ?? this.isDisputed,
  );
}

/// A user's visit to a business.
///
/// Tracked so the app can tell who actually went somewhere. This is the
/// evidence behind the review gate, and it also powers "your places" on the
/// profile.
class Visit {
  const Visit({
    required this.id,
    required this.userId,
    required this.businessId,
    required this.visitedAt,
    this.confirmedByBusiness = false,
  });

  final String id;
  final String userId;
  final String businessId;
  final DateTime visitedAt;

  /// Set when the business approved this visitor for a review. Without it, a
  /// visit alone does not unlock a review.
  final bool confirmedByBusiness;
}

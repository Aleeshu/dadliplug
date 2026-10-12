import 'package:antigua_business_map/models/business.dart';

/// Who is using the app. One app, three roles.
enum UserRole {
  /// Regular person browsing the map.
  user,

  /// Business owner or staff. Can edit their own listing, see analytics,
  /// verify customers, and reply to reviews.
  businessAdmin,

  /// Team. Creates and edits any listing, moderates reviews, manages
  /// subscription status when a transfer lands.
  teamAdmin,
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.role = UserRole.user,
    this.businessIds = const [],
  });

  final String id;
  final String email;
  final String? displayName;
  final UserRole role;

  /// Businesses this user administers. Empty for regular users.
  final List<String> businessIds;

  bool get isBusinessAdmin => role == UserRole.businessAdmin;
  bool get isTeamAdmin => role == UserRole.teamAdmin;
  bool get canModerate => isTeamAdmin;

  AppUser copyWith({
    String? displayName,
    UserRole? role,
    List<String>? businessIds,
  }) => AppUser(
    id: id,
    email: email,
    displayName: displayName ?? this.displayName,
    role: role ?? this.role,
    businessIds: businessIds ?? this.businessIds,
  );
}

/// How a business is paying, tracked internally since payment is by transfer
/// rather than through the app store.
class Subscription {
  const Subscription({
    required this.businessId,
    required this.tier,
    required this.startedAt,
    this.renewsAt,
    this.endedAt,
    this.isActive = true,
  });

  final String businessId;
  final SubscriptionTier tier;
  final DateTime startedAt;
  final DateTime? renewsAt;
  final DateTime? endedAt;
  final bool isActive;

  /// Inside the grace period but past due. The listing stays up, the business
  /// sees a warning in their dashboard.
  bool get isGracePeriod =>
      !isActive && endedAt != null && DateTime.now().isBefore(endedAt!);
}

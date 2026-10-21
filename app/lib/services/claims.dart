import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where the viewer stands with claiming one listing.
enum ClaimStanding {
  /// Not signed in: claiming needs an account the listing can be tied to.
  signedOut,

  /// Signed in and free to claim.
  canClaim,

  /// A claim is with the team.
  pending,

  /// Already manages this listing.
  owns,
}

/// A request to manage a listing, as the team sees it.
class ListingClaim {
  const ListingClaim({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.listedPhone,
    required this.contactName,
    required this.contactPhone,
    required this.roleAtBusiness,
    required this.note,
    required this.createdAt,
  });

  factory ListingClaim.fromMap(Map<String, dynamic> m) {
    final business = (m['businesses'] as Map<String, dynamic>?) ?? const {};
    return ListingClaim(
      id: '${m['id']}',
      businessId: '${m['business_id']}',
      businessName: (business['name'] as String?) ?? 'Unknown listing',
      listedPhone:
          (business['phone'] as String?) ?? (business['whatsapp'] as String?),
      contactName: '${m['contact_name']}',
      contactPhone: '${m['contact_phone']}',
      roleAtBusiness: '${m['role_at_business']}',
      note: m['note'] as String?,
      createdAt: DateTime.parse('${m['created_at']}'),
    );
  }

  final String id;
  final String businessId;
  final String businessName;

  /// The number already on the listing. The team calls this one to verify:
  /// [contactPhone] is whatever the claimant typed.
  final String? listedPhone;
  final String contactName;
  final String contactPhone;
  final String roleAtBusiness;
  final String? note;
  final DateTime createdAt;
}

/// Claim and verify a listing (plan.md Phase 7).
///
/// Claiming changes nothing by itself. The team checks the claim by calling
/// the business on the number already listed, and only its approval makes
/// the claimant a business admin. Both steps are database functions.
class ClaimsRepository {
  ClaimsRepository({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _db {
    final client = _client;
    if (client != null) return client;
    if (!AppConfig.supabaseConfigured) throw const BackendNotConfigured();
    return Supabase.instance.client;
  }

  Future<ClaimStanding> standing(String businessId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return ClaimStanding.signedOut;
    final profile = await _db
        .from('profiles')
        .select('business_ids')
        .eq('id', uid)
        .maybeSingle();
    final owned = (profile?['business_ids'] as List?) ?? const [];
    if (owned.map((e) => '$e').contains(businessId)) return ClaimStanding.owns;
    final pending = await _db
        .from('listing_claims')
        .select('id')
        .eq('business_id', businessId)
        .eq('user_id', uid)
        .eq('status', 'pending')
        .limit(1);
    return pending.isEmpty ? ClaimStanding.canClaim : ClaimStanding.pending;
  }

  Future<void> request({
    required String businessId,
    required String name,
    required String phone,
    required String role,
    String? note,
  }) => _db.rpc<void>(
    'request_claim',
    params: {
      'p_business': businessId,
      'p_name': name,
      'p_phone': phone,
      'p_role': role,
      'p_note': note,
    },
  );

  /// Open claims, oldest first. Team only (RLS shows others only their own).
  Future<List<ListingClaim>> pending() async {
    final rows = await _db
        .from('listing_claims')
        .select('*, businesses(name, phone, whatsapp)')
        .eq('status', 'pending')
        .order('created_at');
    return rows.map(ListingClaim.fromMap).toList(growable: false);
  }

  Future<void> decide(String claimId, {required bool approve, String? note}) =>
      _db.rpc<void>(
        'decide_claim',
        params: {'p_claim': claimId, 'p_approve': approve, 'p_note': note},
      );
}

/// Words for a failed claim call, from the database's own messages.
String claimErrorMessage(Object error) => switch (error) {
  PostgrestException(:final message) when message.isNotEmpty => message,
  _ => 'Could not reach Dadliplug. Check your signal and try again.',
};

final claimsRepositoryProvider = Provider<ClaimsRepository>(
  (ref) => ClaimsRepository(),
);

// Inferred: the family type is only nameable via riverpod/src.
// ignore: specify_nonobvious_property_types
final claimStandingProvider = FutureProvider.family<ClaimStanding, String>(
  (ref, businessId) => ref.watch(claimsRepositoryProvider).standing(businessId),
);

final pendingClaimsProvider = FutureProvider<List<ListingClaim>>(
  (ref) => ref.watch(claimsRepositoryProvider).pending(),
);

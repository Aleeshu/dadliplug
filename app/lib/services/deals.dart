import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dadliplug Deals: a resident claims an offer and gets their own code; the
/// business redeems it at the till (Business Plan 2).
///
/// One code per person per deal, each redeemable once, so a redemption count
/// is a count of real visits. The shared offer code still prints on the ad;
/// the claimed code is what proves a particular person came.
class DealsRepository {
  DealsRepository({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _db {
    final client = _client;
    if (client != null) return client;
    if (!AppConfig.supabaseConfigured) throw const BackendNotConfigured();
    return Supabase.instance.client;
  }

  bool get isSignedIn {
    try {
      return _db.auth.currentUser != null;
    } on BackendNotConfigured {
      return false;
    }
  }

  /// The signed-in resident's code for [adId], claiming it on first call.
  Future<String> claim(String adId) async =>
      await _db.rpc<String>('claim_deal', params: {'p_ad': adId});

  /// The resident's existing code for [adId], or null if not claimed yet.
  Future<String?> existingClaim(String adId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;
    final rows = await _db
        .from('deal_claims')
        .select('code')
        .eq('ad_id', adId)
        .eq('user_id', uid)
        .limit(1);
    return rows.isEmpty ? null : '${rows.first['code']}';
  }

  /// Redeems a resident's code at the till. Returns the deal's title.
  Future<String> redeem(String code) async =>
      await _db.rpc<String>('redeem_deal', params: {'p_code': code});
}

/// The message for a failed claim or redemption, in the database's words.
String dealErrorMessage(Object error) => switch (error) {
  PostgrestException(:final message) when message.isNotEmpty => message,
  _ => 'Could not reach Dadliplug. Check your signal and try again.',
};

/// A code typed at the till: letters and digits only, upper case. Staff read
/// it off a phone, so spaces and lower case are forgiven.
String normaliseDealCode(String raw) =>
    raw.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

final dealsRepositoryProvider = Provider<DealsRepository>(
  (ref) => DealsRepository(),
);

// Inferred: the family type is only nameable via riverpod/src.
// ignore: specify_nonobvious_property_types
final myDealCodeProvider = FutureProvider.family<String?, String>(
  (ref, adId) => ref.watch(dealsRepositoryProvider).existingClaim(adId),
);

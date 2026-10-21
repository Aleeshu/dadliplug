import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The longest special the database accepts, so the field can say so first.
const kSpecialMaxLength = 140;

/// [b]'s special if it was posted today, island time, or null.
///
/// A special is for the day it was posted: yesterday's catch of the day is
/// gone, and showing it would send someone across the island for nothing.
/// Expiring it here means no owner has to remember to take it down.
({String text, bool soldOut})? todaysSpecial(Business b, {DateTime? now}) {
  final text = b.special?.trim();
  final posted = b.specialPostedAt;
  if (text == null || text.isEmpty || posted == null) return null;
  final today = AntiguaClock.antiguaTimeOf(now ?? DateTime.now());
  final day = AntiguaClock.antiguaTimeOf(posted);
  if (day.year != today.year ||
      day.month != today.month ||
      day.day != today.day) {
    return null;
  }
  return (text: text, soldOut: b.specialSoldOut);
}

/// Posts, marks sold out, and clears a business's special.
///
/// Its own class rather than part of `BusinessRepository`: a special is
/// posted in a few taps from the dashboard, without saving the whole listing.
/// The server stamps the time; the client cannot backdate or extend it.
class SpecialsRepository {
  SpecialsRepository({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _db {
    final client = _client;
    if (client != null) return client;
    if (!AppConfig.supabaseConfigured) throw const BackendNotConfigured();
    return Supabase.instance.client;
  }

  /// Posts [text] as today's special, replacing any other.
  Future<void> post(String businessId, String text) => _db
      .from('businesses')
      .update({'special': text.trim()})
      .eq('id', businessId);

  Future<void> setSoldOut(String businessId, {required bool soldOut}) => _db
      .from('businesses')
      .update({'special_sold_out': soldOut})
      .eq('id', businessId);

  Future<void> clear(String businessId) =>
      _db.from('businesses').update({'special': null}).eq('id', businessId);
}

final specialsRepositoryProvider = Provider<SpecialsRepository>(
  (ref) => SpecialsRepository(),
);

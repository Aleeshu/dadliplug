import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A table booking request (2026-10-28 redesign, "Book a Table").
class Booking {
  const Booking({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.at,
    required this.partySize,
    required this.name,
    required this.phone,
    required this.note,
    required this.status,
    required this.businessNote,
  });

  factory Booking.fromMap(Map<String, dynamic> m) {
    final business = m['businesses'];
    return Booking(
      id: '${m['id']}',
      businessId: '${m['business_id']}',
      businessName: business is Map ? '${business['name']}' : '',
      at: DateTime.parse('${m['at']}'),
      partySize: (m['party_size'] as num).toInt(),
      name: '${m['name']}',
      phone: '${m['phone']}',
      note: m['note'] as String?,
      status: '${m['status']}',
      businessNote: m['business_note'] as String?,
    );
  }

  final String id;
  final String businessId;
  final String businessName;
  final DateTime at;
  final int partySize;
  final String name;
  final String phone;
  final String? note;

  /// pending, confirmed, declined or cancelled.
  final String status;
  final String? businessNote;

  bool get isPending => status == 'pending';
  bool get isOpen => status == 'pending' || status == 'confirmed';
}

/// Booking requests. The rules (signed in, 30 minutes to 60 days ahead,
/// three pending per business, only the business answers) live in the
/// database functions.
class BookingsRepository {
  BookingsRepository({this._client});

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

  Future<void> request({
    required String businessId,
    required DateTime at,
    required int partySize,
    required String name,
    required String phone,
    String? note,
  }) => _db.rpc<void>(
    'request_booking',
    params: {
      'p_business': businessId,
      'p_at': at.toUtc().toIso8601String(),
      'p_party': partySize,
      'p_name': name,
      'p_phone': phone,
      'p_note': note,
    },
  );

  Future<List<Booking>> mine() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _db
        .from('bookings')
        .select('*, businesses(name)')
        .eq('customer_id', uid)
        .order('at', ascending: false)
        .limit(100);
    return rows.map(Booking.fromMap).toList(growable: false);
  }

  /// A business's bookings from today on, soonest first.
  Future<List<Booking>> forBusiness(String businessId) async {
    final since = DateTime.now().subtract(const Duration(hours: 12));
    final rows = await _db
        .from('bookings')
        .select('*, businesses(name)')
        .eq('business_id', businessId)
        .gte('at', since.toUtc().toIso8601String())
        .order('at');
    return rows.map(Booking.fromMap).toList(growable: false);
  }

  Future<void> answer(
    String bookingId, {
    required bool confirm,
    String? note,
  }) => _db.rpc<void>(
    'answer_booking',
    params: {'p_booking': bookingId, 'p_confirm': confirm, 'p_note': note},
  );

  Future<void> cancel(String bookingId) =>
      _db.rpc<void>('cancel_booking', params: {'p_booking': bookingId});

  /// The owner's switch for taking bookings in the app.
  Future<void> setAccepting(String businessId, {required bool accepting}) => _db
      .from('businesses')
      .update({'accepts_bookings': accepting})
      .eq('id', businessId);
}

String bookingErrorMessage(Object error) => switch (error) {
  PostgrestException(:final message) when message.isNotEmpty => message,
  _ => 'Could not reach Dadliplug. Check your signal and try again.',
};

final bookingsRepositoryProvider = Provider<BookingsRepository>(
  (ref) => BookingsRepository(),
);

final myBookingsProvider = FutureProvider<List<Booking>>(
  (ref) => ref.watch(bookingsRepositoryProvider).mine(),
);

// Inferred: the family type is only nameable via riverpod/src.
// ignore: specify_nonobvious_property_types
final businessBookingsProvider = FutureProvider.family<List<Booking>, String>(
  (ref, businessId) =>
      ref.watch(bookingsRepositoryProvider).forBusiness(businessId),
);

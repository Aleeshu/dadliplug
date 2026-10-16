import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Something a customer did that a business is paying to see.
enum EngagementKind {
  view('view'),
  call('call'),
  whatsapp('whatsapp'),
  adView('ad_view');

  const EngagementKind(this.wire);

  /// The value `record_engagement` expects.
  final String wire;
}

/// Records views, calls, WhatsApp taps and ad views.
///
/// These feed the month-end report and the ranking score, which are the two
/// things a renewal is argued over. Until this existed nothing incremented
/// them, so every listing's numbers stood still at whatever was seeded.
///
/// The rules — owners and the team do not count, a signed-in customer counts
/// once an hour — live in the `record_engagement` database function rather
/// than here, because a client can be modified and the server cannot.
class EngagementRecorder {
  EngagementRecorder({this._client});

  final SupabaseClient? _client;

  /// Records one event. Never throws.
  ///
  /// A failed count must not stop a customer calling a business, opening a
  /// listing, or seeing an advert, so every failure is logged and swallowed —
  /// including a build with no backend at all.
  Future<void> record(
    String businessId,
    EngagementKind kind, {
    String? adId,
  }) async {
    try {
      final client =
          _client ??
          (AppConfig.supabaseConfigured ? Supabase.instance.client : null);
      if (client == null) return;

      await client.rpc<dynamic>(
        'record_engagement',
        params: {
          'p_business_id': businessId,
          'p_kind': kind.wire,
          if (adId != null) 'p_ad_id': adId,
        },
      );
    } catch (error) {
      debugPrint('Could not record ${kind.wire} for $businessId: $error');
    }
  }
}

final engagementRecorderProvider = Provider<EngagementRecorder>(
  (ref) => EngagementRecorder(),
);

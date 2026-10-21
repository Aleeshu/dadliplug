import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How urgent a listing's billing state is, for colouring.
enum BillingTone { ok, warn, bad }

/// Where a listing stands with its subscription, in words for the owner and
/// the team (plan.md section 3: trial, paid, held for 7 days, delisted).
///
/// Pure, so the wording for every state is pinned by tests.
({String title, String detail, BillingTone tone}) billingStatus(
  Business b, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final date = DateFormat.MMMd();
  // Deadlines are stated in Antigua time, whatever the phone is set to, so
  // "held until Oct 28" means the same day to the owner and the team.
  DateTime island(DateTime t) => AntiguaClock.antiguaTimeOf(t);
  String days(DateTime until) {
    final n = until.difference(at).inHours / 24;
    final whole = n.ceil();
    if (whole <= 0) return 'today';
    return whole == 1 ? 'in 1 day' : 'in $whole days';
  }

  final planName = (b.plan ?? b.tier).label;

  switch (b.tier) {
    case SubscriptionTier.trial:
      final end = b.trialEndsAt;
      return (
        title: 'Free trial',
        detail: end == null
            ? 'Every $planName tool is unlocked.'
            : 'Every $planName tool is unlocked. Ends ${days(end)} '
                  '(${date.format(island(end))}).',
        tone: BillingTone.warn,
      );
    case SubscriptionTier.overdue:
      final hold = b.holdUntil;
      return (
        title: 'Payment due',
        detail: hold == null
            ? 'Your listing is held. Pay to keep it live.'
            : 'Your listing is held until ${date.format(island(hold))}. '
                  'Pay before then and nothing is lost; after it, the listing '
                  'is hidden.',
        tone: BillingTone.bad,
      );
    case SubscriptionTier.delisted:
      return (
        title: 'Delisted',
        detail:
            'Hidden from customers. Your listing and its content are kept: '
            'pay and it comes back as it was.',
        tone: BillingTone.bad,
      );
    case SubscriptionTier.growing ||
        SubscriptionTier.basic ||
        SubscriptionTier.featured:
      final until = b.paidUntil;
      if (until == null) {
        return (
          title: '$planName plan',
          detail: 'No renewal date recorded.',
          tone: BillingTone.ok,
        );
      }
      final soon = until.difference(at) <= const Duration(days: 5);
      return (
        title: '$planName plan',
        detail: soon
            ? 'Renews ${days(until)} (${date.format(island(until))}). '
                  'Pay by then to stay live.'
            : 'Paid until ${date.format(island(until))}.',
        tone: soon ? BillingTone.warn : BillingTone.ok,
      );
  }
}

/// A payment the team recorded.
class Payment {
  const Payment({
    required this.tier,
    required this.months,
    required this.amountEc,
    required this.reference,
    required this.paidUntil,
    required this.recordedAt,
  });

  final SubscriptionTier tier;
  final int months;
  final double amountEc;
  final String reference;
  final DateTime paidUntil;
  final DateTime recordedAt;
}

/// Team billing actions. Every write is a database function that checks the
/// caller is the team and logs who recorded it.
class BillingRepository {
  BillingRepository({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _db {
    final client = _client;
    if (client != null) return client;
    if (!AppConfig.supabaseConfigured) throw const BackendNotConfigured();
    return Supabase.instance.client;
  }

  /// Records a bank transfer. Returns the new paid-until date.
  Future<DateTime> recordPayment({
    required String businessId,
    required SubscriptionTier tier,
    required int months,
    required double amountEc,
    required String reference,
  }) async {
    final until = await _db.rpc<String>(
      'record_payment',
      params: {
        'p_business': businessId,
        'p_tier': tier.name,
        'p_months': months,
        'p_amount_ec': amountEc,
        'p_reference': reference,
      },
    );
    return DateTime.parse(until);
  }

  Future<void> startTrial(String businessId, SubscriptionTier tier) =>
      _db.rpc<void>(
        'start_trial',
        params: {'p_business': businessId, 'p_tier': tier.name},
      );

  /// Runs the daily step now (it also runs on its own at 00:05 Antigua time).
  Future<({int held, int delisted})> advanceNow() async {
    final rows = await _db.rpc<List<dynamic>>('advance_subscriptions');
    final row = rows.isEmpty
        ? const <String, Object?>{}
        : rows.first as Map<String, Object?>;
    return (
      held: (row['held'] as num?)?.toInt() ?? 0,
      delisted: (row['delisted'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<Payment>> payments(String businessId) async {
    final rows = await _db
        .from('payments')
        .select('tier, months, amount_ec, reference, paid_until, recorded_at')
        .eq('business_id', businessId)
        .order('recorded_at', ascending: false);
    return [
      for (final r in rows as List<dynamic>)
        if (r is Map)
          Payment(
            tier: SubscriptionTierX.fromName('${r['tier']}'),
            months: (r['months'] as num).toInt(),
            amountEc: (r['amount_ec'] as num).toDouble(),
            reference: '${r['reference']}',
            paidUntil: DateTime.parse('${r['paid_until']}'),
            recordedAt: DateTime.parse('${r['recorded_at']}'),
          ),
    ];
  }
}

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(),
);

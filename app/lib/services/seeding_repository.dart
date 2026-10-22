import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How an owner reaches customers today. Stored by [name].
enum AdChannel {
  facebook('Facebook'),
  instagram('Instagram'),
  whatsappStatus('WhatsApp status'),
  radio('Radio'),
  flyers('Flyers or signs'),
  wordOfMouth('Word of mouth'),
  nothing('Nothing yet');

  const AdChannel(this.label);
  final String label;

  String get dbName => switch (this) {
    AdChannel.whatsappStatus => 'whatsapp_status',
    AdChannel.wordOfMouth => 'word_of_mouth',
    _ => name,
  };

  static AdChannel? fromDb(String raw) =>
      AdChannel.values.where((c) => c.dbName == raw).firstOrNull;
}

/// Monthly marketing spend today, in EC$ bands.
enum SpendBand {
  none('Nothing'),
  under50(r'Under EC$50'),
  from50to150(r'EC$50–150'),
  from150to500(r'EC$150–500'),
  over500(r'Over EC$500');

  const SpendBand(this.label);
  final String label;

  String get dbName => switch (this) {
    SpendBand.none => 'none',
    SpendBand.under50 => 'under_50',
    SpendBand.from50to150 => '50_150',
    SpendBand.from150to500 => '150_500',
    SpendBand.over500 => 'over_500',
  };

  static SpendBand fromDb(String raw) =>
      SpendBand.values.where((b) => b.dbName == raw).firstOrNull ??
      SpendBand.none;
}

/// Where a lead is in the pipeline.
enum LeadStatus {
  newLead('New'),
  contacted('Contacted'),
  trial('On trial'),
  paying('Paying'),
  declined('Declined');

  const LeadStatus(this.label);
  final String label;

  String get dbName => this == LeadStatus.newLead ? 'new' : name;

  static LeadStatus fromDb(String raw) =>
      LeadStatus.values.where((s) => s.dbName == raw).firstOrNull ??
      LeadStatus.newLead;
}

/// A business owner who asked to be listed, or one the team interviewed.
class Lead {
  const Lead({
    required this.id,
    required this.businessName,
    required this.category,
    required this.area,
    required this.contactName,
    required this.phone,
    required this.advertisesOn,
    required this.spend,
    required this.planInterest,
    required this.maintenance,
    required this.note,
    required this.source,
    required this.status,
    required this.teamNote,
    required this.createdAt,
  });

  factory Lead.fromMap(Map<String, dynamic> m) => Lead(
    id: '${m['id']}',
    businessName: '${m['business_name']}',
    category: BusinessCategoryX.fromName('${m['category']}'),
    area: (m['area'] as String?) ?? '',
    contactName: '${m['contact_name']}',
    phone: '${m['phone']}',
    advertisesOn: [
      for (final raw in (m['advertises_on'] as List?) ?? const [])
        if (AdChannel.fromDb('$raw') case final c?) c,
    ],
    spend: SpendBand.fromDb('${m['spend_band']}'),
    planInterest: '${m['plan_interest']}',
    maintenance: '${m['maintenance']}',
    note: m['note'] as String?,
    source: '${m['source']}',
    status: LeadStatus.fromDb('${m['status']}'),
    teamNote: m['team_note'] as String?,
    createdAt: DateTime.parse('${m['created_at']}'),
  );

  final String id;
  final String businessName;
  final BusinessCategory category;
  final String area;
  final String contactName;
  final String phone;
  final List<AdChannel> advertisesOn;
  final SpendBand spend;

  /// growing, basic, featured or unsure.
  final String planInterest;

  /// team, self or unsure: plan.md section 15, decision 1.
  final String maintenance;
  final String? note;

  /// app, interview or import.
  final String source;
  final LeadStatus status;
  final String? teamNote;
  final DateTime createdAt;
}

/// The Phase 9 answers so far, counted. What the interviews are for.
class LeadSummary {
  const LeadSummary({
    required this.total,
    required this.byPlan,
    required this.byMaintenance,
    required this.bySpend,
    required this.byChannel,
    required this.byStatus,
  });

  factory LeadSummary.of(List<Lead> leads) {
    Map<K, int> count<K>(Iterable<K> keys) {
      final out = <K, int>{};
      for (final k in keys) {
        out[k] = (out[k] ?? 0) + 1;
      }
      return out;
    }

    return LeadSummary(
      total: leads.length,
      byPlan: count(leads.map((l) => l.planInterest)),
      byMaintenance: count(leads.map((l) => l.maintenance)),
      bySpend: count(leads.map((l) => l.spend)),
      byChannel: count(leads.expand((l) => l.advertisesOn)),
      byStatus: count(leads.map((l) => l.status)),
    );
  }

  final int total;
  final Map<String, int> byPlan;
  final Map<String, int> byMaintenance;
  final Map<SpendBand, int> bySpend;
  final Map<AdChannel, int> byChannel;
  final Map<LeadStatus, int> byStatus;

  /// Share of leads that would pay at least [tier]'s price, out of those who
  /// named a plan. Null when nobody has named one yet.
  double? shareAtLeast(String tier) {
    const order = ['growing', 'basic', 'featured'];
    final named = order.fold<int>(0, (n, t) => n + (byPlan[t] ?? 0));
    if (named == 0) return null;
    final from = order.indexOf(tier);
    final atLeast = order
        .skip(from)
        .fold<int>(0, (n, t) => n + (byPlan[t] ?? 0));
    return atLeast / named;
  }
}

/// Leads (Phase 9), pre-built listings and in-person verification (Phase 10).
class SeedingRepository {
  SeedingRepository({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _db {
    final client = _client;
    if (client != null) return client;
    if (!AppConfig.supabaseConfigured) throw const BackendNotConfigured();
    return Supabase.instance.client;
  }

  /// "Get your business listed". Anyone, signed in or not. Insert only: the
  /// submitter cannot read leads back, theirs or anyone's.
  Future<void> submitLead({
    required String businessName,
    required BusinessCategory category,
    required String area,
    required String contactName,
    required String phone,
    required Set<AdChannel> advertisesOn,
    required SpendBand spend,
    required String planInterest,
    required String maintenance,
    String? note,
  }) => _db.from('business_leads').insert({
    'business_name': businessName.trim(),
    'category': category.dbName,
    'area': area.trim(),
    'contact_name': contactName.trim(),
    'phone': phone.trim(),
    'advertises_on': [for (final c in advertisesOn) c.dbName],
    'spend_band': spend.dbName,
    'plan_interest': planInterest,
    'maintenance': maintenance,
    'note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
  });

  Future<List<Lead>> leads() async {
    final rows = await _db
        .from('business_leads')
        .select()
        .order('created_at', ascending: false);
    return rows.map(Lead.fromMap).toList(growable: false);
  }

  Future<void> updateLead(String id, {LeadStatus? status, String? teamNote}) =>
      _db
          .from('business_leads')
          .update({
            if (status != null) 'status': status.dbName,
            if (teamNote != null) 'team_note': teamNote,
          })
          .eq('id', id);

  /// Records a check of the listing and stamps it verified now.
  Future<void> verify(
    String businessId, {
    required String method,
    String? note,
  }) => _db.rpc<void>(
    'verify_listing',
    params: {'p_business': businessId, 'p_method': method, 'p_note': note},
  );

  /// Hides a listing as pre-built, or publishes it.
  Future<void> setProspect(String businessId, {required bool prospect}) => _db
      .from('businesses')
      .update({'is_prospect': prospect})
      .eq('id', businessId);

  /// The owner's private preview of a pre-built listing.
  Future<String> previewUrl(String businessId) async {
    final row = await _db
        .from('businesses')
        .select('preview_token')
        .eq('id', businessId)
        .single();
    return AppConfig.prospectPreviewUrl('${row['preview_token']}');
  }
}

final seedingRepositoryProvider = Provider<SeedingRepository>(
  (ref) => SeedingRepository(),
);

final leadsProvider = FutureProvider<List<Lead>>(
  (ref) => ref.watch(seedingRepositoryProvider).leads(),
);

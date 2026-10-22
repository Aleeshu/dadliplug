import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/seeding_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Owners who asked to be listed, and what they said (plan.md Phase 9).
///
/// The Answers tab is the point of Phase 9: will owners pay, which plan, and
/// do they want the team keeping their listing or to do it themselves. It is
/// counted from the leads rather than kept in a spreadsheet, so it is never
/// out of date.
class LeadsScreen extends ConsumerWidget {
  const LeadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final leads = ref.watch(leadsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: palette.app,
        appBar: AppBar(
          title: const Text('Leads'),
          backgroundColor: palette.app,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pipeline'),
              Tab(text: 'Answers'),
            ],
          ),
        ),
        body: leads.when(
          loading: () =>
              Center(child: CircularProgressIndicator(color: palette.red)),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(leadsProvider),
              child: const Text('Could not load leads. Try again'),
            ),
          ),
          data: (list) => TabBarView(
            children: [
              _Pipeline(leads: list),
              _Answers(summary: LeadSummary.of(list)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pipeline extends ConsumerWidget {
  const _Pipeline({required this.leads});

  final List<Lead> leads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    if (leads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.huge),
          child: Text(
            'No leads yet. Owners reach this from More, "Get your business '
            'listed". Phase 9 needs twenty conversations: log interviews '
            'through the same form.',
            textAlign: TextAlign.center,
            style: AppText.bodyMedium.copyWith(color: palette.muted),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(leadsProvider.future),
      child: ListView.separated(
        padding: const EdgeInsets.all(Insets.lg),
        itemCount: leads.length,
        separatorBuilder: (_, _) => const Divider(height: Insets.xl),
        itemBuilder: (context, i) => _LeadTile(lead: leads[i]),
      ),
    );
  }
}

class _LeadTile extends ConsumerWidget {
  const _LeadTile({required this.lead});

  final Lead lead;

  Future<void> _set(
    BuildContext context,
    WidgetRef ref, {
    LeadStatus? status,
    String? note,
  }) async {
    try {
      await ref
          .read(seedingRepositoryProvider)
          .updateLead(lead.id, status: status, teamNote: note);
      ref.invalidate(leadsProvider);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not save.')));
      }
    }
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController(text: lead.teamNote);
    final note = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Team note'),
        content: TextField(
          controller: c,
          maxLength: 500,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'What they said, what was agreed, when to follow up',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, c.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    if (note != null && context.mounted) {
      await _set(context, ref, note: note.trim());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final muted = AppText.caption.copyWith(color: palette.muted);
    final digits = lead.phone.replaceAll(RegExp('[^0-9]'), '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                lead.businessName,
                style: AppText.titleMedium.copyWith(color: palette.ink),
              ),
            ),
            DropdownButton<LeadStatus>(
              value: lead.status,
              underline: const SizedBox.shrink(),
              items: [
                for (final s in LeadStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (s) => _set(context, ref, status: s),
            ),
          ],
        ),
        Text(
          '${lead.category.label}'
          '${lead.area.isEmpty ? '' : ' · ${lead.area}'} · '
          '${lead.contactName} · ${lead.phone}',
          style: AppText.bodyMedium.copyWith(color: palette.ink),
        ),
        Text(
          'Plan: ${lead.planInterest} · Keeps listing: ${lead.maintenance} · '
          'Spends: ${lead.spend.label}',
          style: muted,
        ),
        if (lead.advertisesOn.isNotEmpty)
          Text(
            'Advertises on: ${lead.advertisesOn.map((c) => c.label).join(', ')}',
            style: muted,
          ),
        if (lead.note case final note?) Text('“$note”', style: muted),
        if (lead.teamNote case final note? when note.isNotEmpty)
          Text(
            'Team: $note',
            style: AppText.caption.copyWith(color: palette.blue),
          ),
        Text(
          '${lead.source == 'app' ? 'From the app' : lead.source}, '
          '${DateFormat.MMMd().add_jm().format(lead.createdAt.toLocal())}',
          style: muted,
        ),
        Wrap(
          spacing: Insets.xs,
          children: [
            TextButton.icon(
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: lead.phone)),
              icon: const Icon(Icons.call, size: 16),
              label: const Text('Call'),
            ),
            if (digits.length >= 7)
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://wa.me/$digits?text=${Uri.encodeComponent('Hi ${lead.contactName}, this is the Dadliplug team about listing ${lead.businessName}.')}',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.chat, size: 16),
                label: const Text('WhatsApp'),
              ),
            TextButton.icon(
              onPressed: () => _editNote(context, ref),
              icon: const Icon(Icons.edit_note, size: 16),
              label: const Text('Note'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Answers extends StatelessWidget {
  const _Answers({required this.summary});

  final LeadSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final muted = AppText.bodyMedium.copyWith(color: palette.muted);
    String pct(double? v) => v == null ? '—' : '${(v * 100).round()}%';

    Widget bars(String title, Map<String, int> counts) {
      final total = counts.values.fold<int>(0, (a, b) => a + b);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Insets.xl),
          Text(title, style: AppText.titleSmall.copyWith(color: palette.ink)),
          const SizedBox(height: Insets.sm),
          for (final e
              in counts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(e.key, style: AppText.caption),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Corners.sm),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : e.value / total,
                        minHeight: 10,
                        backgroundColor: palette.line,
                        valueColor: AlwaysStoppedAnimation(palette.red),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${e.value}',
                      textAlign: TextAlign.right,
                      style: AppText.caption,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    if (summary.total == 0) {
      return Center(
        child: Text('Answers appear as leads come in.', style: muted),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        Text(
          '${summary.total} of 20 conversations',
          style: AppText.titleLarge.copyWith(color: palette.ink),
        ),
        Text(
          'Of those who named a plan: ${pct(summary.shareAtLeast('basic'))} '
          'would take Growth or above, ${pct(summary.shareAtLeast('featured'))} '
          'Premium.',
          style: muted,
        ),
        // Stored as growing/basic/featured; shown by the plans' names.
        bars('Plan they lean to', {
          for (final e in summary.byPlan.entries)
            switch (e.key) {
              'growing' => 'Starter',
              'basic' => 'Growth',
              'featured' => 'Premium',
              _ => 'Not sure',
            }: e.value,
        }),
        bars(
          'Who keeps the listing (plan.md 15, decision 1)',
          summary.byMaintenance,
        ),
        bars('Spends on advertising a month', {
          for (final e in summary.bySpend.entries) e.key.label: e.value,
        }),
        bars('Advertises on', {
          for (final e in summary.byChannel.entries) e.key.label: e.value,
        }),
        bars('Pipeline', {
          for (final e in summary.byStatus.entries) e.key.label: e.value,
        }),
      ],
    );
  }
}

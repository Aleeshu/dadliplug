import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/team_admin/team_listings_screen.dart'
    show teamListingsProvider;
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/billing.dart';
import 'package:antigua_business_map/services/reviews_repository.dart'
    show reviewErrorMessage;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The team's billing desk (plan.md Phase 7).
///
/// Payment is a bank transfer, so when one lands someone records it here:
/// plan, months, amount and the transfer reference. Every payment is logged
/// with who recorded it. Trials start here too. The daily step (trial or
/// paid period over -> held 7 days -> delisted) runs by itself at 00:05
/// Antigua time; "Run daily check" runs it now.
class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final listingsAsync = ref.watch(teamListingsProvider);

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Billing'),
        actions: [
          IconButton(
            tooltip: 'Run daily check now',
            icon: const Icon(Icons.update),
            onPressed: () => _advance(context, ref),
          ),
        ],
      ),
      body: listingsAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (err, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(teamListingsProvider),
            child: const Text('Could not load listings. Try again'),
          ),
        ),
        data: (all) {
          // Most urgent first: what needs chasing, then trials, then the rest.
          int rank(Business b) => switch (b.tier) {
            SubscriptionTier.overdue => 0,
            SubscriptionTier.trial => 1,
            SubscriptionTier.delisted => 3,
            _ => 2,
          };
          final sorted = [...all]..sort((a, b) => rank(a).compareTo(rank(b)));
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(teamListingsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(Insets.lg),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
              itemBuilder: (context, i) => _ListingRow(business: sorted[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _advance(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ref.read(billingRepositoryProvider).advanceNow();
      ref.invalidate(teamListingsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Daily check done: ${r.held} newly held, ${r.delisted} delisted.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(reviewErrorMessage(error))),
      );
    }
  }
}

class _ListingRow extends ConsumerWidget {
  const _ListingRow({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final status = billingStatus(business);
    final color = switch (status.tone) {
      BillingTone.ok => palette.good,
      BillingTone.warn => palette.warn,
      BillingTone.bad => palette.bad,
    };

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(Corners.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(Corners.xl),
        onTap: () => _BillingSheet.show(context, business),
        child: Container(
          padding: const EdgeInsets.all(Insets.xl),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Corners.xl),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: AppText.titleSmall.copyWith(color: palette.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.title,
                      style: AppText.labelMedium.copyWith(color: color),
                    ),
                    Text(
                      status.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Record a payment, start a trial, and see past payments for one listing.
class _BillingSheet extends ConsumerStatefulWidget {
  const _BillingSheet({required this.business});

  final Business business;

  static Future<void> show(BuildContext context, Business business) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _BillingSheet(business: business),
      );

  @override
  ConsumerState<_BillingSheet> createState() => _BillingSheetState();
}

class _BillingSheetState extends ConsumerState<_BillingSheet> {
  static const List<SubscriptionTier> _plans = [
    SubscriptionTier.growing,
    SubscriptionTier.basic,
    SubscriptionTier.featured,
  ];

  late SubscriptionTier _tier =
      widget.business.plan ??
      (_plans.contains(widget.business.tier)
          ? widget.business.tier
          : SubscriptionTier.basic);
  int _months = 1;
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  bool _busy = false;
  String? _error;
  List<Payment>? _history;

  @override
  void initState() {
    super.initState();
    _syncAmount();
    ref
        .read(billingRepositoryProvider)
        .payments(widget.business.id)
        .then((p) {
          if (mounted) setState(() => _history = p);
        })
        .catchError((Object _) {
          if (mounted) setState(() => _history = const []);
        });
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  /// The plan's price for the chosen months, which is what a transfer
  /// normally is. Editable: discounts and part payments happen.
  void _syncAmount() =>
      _amount.text = (_tier.monthlyPrice * _months).toString();

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(teamListingsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          // Our own checks say exactly what is missing; anything else is
          // the database's message, or a connection problem.
          _error = error is FormatException
              ? error.message
              : reviewErrorMessage(error);
        });
      }
    }
  }

  Future<void> _record() => _run(() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount < 0) {
      throw const FormatException('Enter the amount received in EC dollars.');
    }
    if (_reference.text.trim().isEmpty) {
      throw const FormatException(
        'Enter the transfer reference, so the payment can be matched to the '
        'bank statement.',
      );
    }
    final until = await ref
        .read(billingRepositoryProvider)
        .recordPayment(
          businessId: widget.business.id,
          tier: _tier,
          months: _months,
          amountEc: amount,
          reference: _reference.text,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recorded. ${widget.business.name} is paid until '
            '${DateFormat.yMMMd().format(until.toLocal())}.',
          ),
        ),
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = billingStatus(widget.business);

    return Padding(
      padding: EdgeInsets.only(
        left: Insets.huge,
        right: Insets.huge,
        top: Insets.huge,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Insets.huge,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.business.name,
              style: AppText.titleLarge.copyWith(color: palette.ink),
            ),
            Text(
              '${status.title}. ${status.detail}',
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.xl),
            Text('Record a payment', style: AppText.sectionLabel),
            const SizedBox(height: Insets.sm),
            SegmentedButton<SubscriptionTier>(
              segments: [
                for (final t in _plans)
                  ButtonSegment(
                    value: t,
                    label: Text('${t.label} EC\$${t.monthlyPrice}'),
                  ),
              ],
              selected: {_tier},
              onSelectionChanged: (s) => setState(() {
                _tier = s.first;
                _syncAmount();
              }),
            ),
            const SizedBox(height: Insets.md),
            Wrap(
              spacing: Insets.sm,
              children: [
                for (final m in const [1, 3, 6, 12])
                  ChoiceChip(
                    label: Text(m == 1 ? '1 month' : '$m months'),
                    selected: _months == m,
                    onSelected: (_) => setState(() {
                      _months = m;
                      _syncAmount();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: r'Amount received (EC$)',
              ),
            ),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _reference,
              decoration: const InputDecoration(
                labelText: 'Transfer reference',
                hintText: 'As it appears on the bank statement',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: Insets.md),
              Text(
                _error!,
                style: AppText.bodyMedium.copyWith(color: palette.red),
              ),
            ],
            const SizedBox(height: Insets.lg),
            FilledButton(
              onPressed: _busy ? null : _record,
              child: Text(_busy ? 'Recording…' : 'Record payment'),
            ),
            const SizedBox(height: Insets.sm),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => ref
                          .read(billingRepositoryProvider)
                          .startTrial(widget.business.id, _tier),
                    ),
              child: Text('Start 3-day ${_tier.label} trial'),
            ),
            const SizedBox(height: Insets.xl),
            Text('Payments', style: AppText.sectionLabel),
            const SizedBox(height: Insets.sm),
            if (_history == null)
              const LinearProgressIndicator()
            else if (_history!.isEmpty)
              Text(
                'None recorded yet.',
                style: AppText.bodyMedium.copyWith(color: palette.muted),
              )
            else
              for (final p in _history!)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'EC\$${p.amountEc.toStringAsFixed(2)} · ${p.tier.label} '
                    '× ${p.months}',
                  ),
                  subtitle: Text(
                    '${DateFormat.yMMMd().format(p.recordedAt.toLocal())} · '
                    'ref ${p.reference} · to '
                    '${DateFormat.yMMMd().format(p.paidUntil.toLocal())}',
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

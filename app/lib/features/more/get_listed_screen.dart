import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/seeding_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Get your business listed": the way in for an owner, and the record of
/// what they told us (plan.md Phase 9). Short on purpose. Every question here
/// is one the business model needs answered; nothing is asked for its own
/// sake.
class GetListedScreen extends ConsumerStatefulWidget {
  const GetListedScreen({super.key});

  @override
  ConsumerState<GetListedScreen> createState() => _GetListedScreenState();
}

class _GetListedScreenState extends ConsumerState<GetListedScreen> {
  final _form = GlobalKey<FormState>();
  final _business = TextEditingController();
  final _area = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  BusinessCategory? _category;
  final _channels = <AdChannel>{};
  SpendBand _spend = SpendBand.none;
  String _plan = 'unsure';
  String _maintenance = 'unsure';
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_business, _area, _name, _phone, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_category == null) {
      setState(() => _error = 'Pick the kind of business.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(seedingRepositoryProvider)
          .submitLead(
            businessName: _business.text,
            category: _category!,
            area: _area.text,
            contactName: _name.text,
            phone: _phone.text,
            advertisesOn: _channels,
            spend: _spend,
            planInterest: _plan,
            maintenance: _maintenance,
            note: _note.text,
          );
      if (mounted) setState(() => _sent = true);
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not send. Check your signal and try again.';
        });
      }
    }
  }

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? 'Needed so we can reach you' : null;

  Widget _section(String title, {String? hint}) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.xl, bottom: Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.titleSmall.copyWith(color: palette.ink)),
          if (hint != null)
            Text(hint, style: AppText.caption.copyWith(color: palette.muted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (_sent) {
      return Scaffold(
        backgroundColor: palette.app,
        appBar: AppBar(backgroundColor: palette.app),
        body: Padding(
          padding: const EdgeInsets.all(Insets.huge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle, color: palette.good, size: 48),
              const SizedBox(height: Insets.lg),
              Text(
                'Thanks. We will be in touch.',
                style: AppText.titleLarge.copyWith(color: palette.ink),
              ),
              const SizedBox(height: Insets.sm),
              Text(
                'Someone from the Dadliplug team will call or WhatsApp '
                '${_phone.text.trim()} to set up your listing and a free '
                '3-day trial.',
                style: AppText.bodyLarge.copyWith(color: palette.muted),
              ),
              const SizedBox(height: Insets.xl),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Get your business listed'),
        backgroundColor: palette.app,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Insets.huge,
            0,
            Insets.huge,
            Insets.giant,
          ),
          children: [
            Text(
              'Tell us about your business. The team builds your listing '
              'with you, and you try it free for 3 days.',
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
            _section('Your business'),
            TextFormField(
              controller: _business,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Business name'),
              validator: _required,
            ),
            DropdownButtonFormField<BusinessCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kind of business'),
              items: [
                for (final c in BusinessCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _area,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Area',
                hintText: "e.g. St. John's, English Harbour, online only",
              ),
            ),
            _section('You'),
            TextFormField(
              controller: _name,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Your name'),
              validator: _required,
            ),
            TextFormField(
              controller: _phone,
              maxLength: 30,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone or WhatsApp',
                hintText: '+1 268 …',
              ),
              validator: (v) =>
                  (v ?? '').replaceAll(RegExp('[^0-9]'), '').length < 7
                  ? 'Enter a phone number'
                  : null,
            ),
            _section(
              'How do customers find you now?',
              hint: 'Pick all that apply.',
            ),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final c in AdChannel.values)
                  FilterChip(
                    label: Text(c.label),
                    selected: _channels.contains(c),
                    onSelected: (on) => setState(
                      () => on ? _channels.add(c) : _channels.remove(c),
                    ),
                  ),
              ],
            ),
            _section('What do you spend on advertising a month?'),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final b in SpendBand.values)
                  ChoiceChip(
                    label: Text(b.label),
                    selected: _spend == b,
                    onSelected: (_) => setState(() => _spend = b),
                  ),
              ],
            ),
            _section(
              'Which plan sounds right?',
              hint: 'Not a commitment. It helps us set prices that work.',
            ),
            RadioGroup<String>(
              groupValue: _plan,
              onChanged: (v) => setState(() => _plan = v ?? 'unsure'),
              child: Column(
                children: [
                  for (final (value, title, detail) in const [
                    (
                      'growing',
                      r'Starter, EC$25 a month',
                      'Your listing, pin, photos, hours, reviews and one running ad.',
                    ),
                    (
                      'basic',
                      r'Growth, EC$50 a month',
                      'Five running ads, deals, results tracking, and your own pin.',
                    ),
                    (
                      'featured',
                      r'Premium, EC$100 a month',
                      'Unlimited ads, the Featured page, Spotlight and a badge.',
                    ),
                    ('unsure', 'Not sure yet', 'We can talk it through.'),
                  ])
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: value,
                      title: Text(title),
                      subtitle: Text(detail),
                    ),
                ],
              ),
            ),
            _section('Who should keep your listing up to date?'),
            RadioGroup<String>(
              groupValue: _maintenance,
              onChanged: (v) => setState(() => _maintenance = v ?? 'unsure'),
              child: Column(
                children: [
                  for (final (value, title) in const [
                    ('team', 'The Dadliplug team: I will message changes'),
                    ('self', 'Me: I want to edit it myself'),
                    ('unsure', 'Not sure'),
                  ])
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: value,
                      title: Text(title),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _note,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Anything else? (optional)',
                hintText: 'Best time to call, what you want customers to know',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Text(
                  _error!,
                  style: AppText.bodyMedium.copyWith(color: palette.bad),
                ),
              ),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Sending…' : 'Send to the team'),
            ),
          ],
        ),
      ),
    );
  }
}

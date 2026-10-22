import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/listing/listing_screen.dart'
    show singleBusinessProvider;
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:antigua_business_map/widgets/announcement_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// A business posting an advertisement.
///
/// What the owner is promised on the sign-up path, delivered: the trial
/// includes every paid tool, and posting an ad is the tool the pitch is about.
class PostAdScreen extends ConsumerStatefulWidget {
  const PostAdScreen({required this.businessId, super.key});

  final String businessId;

  @override
  ConsumerState<PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends ConsumerState<PostAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _link = TextEditingController();
  final _code = TextEditingController();
  final _terms = TextEditingController();
  DateTime? _endsAt;
  bool _posting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    _code.dispose();
    _terms.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _posting = true;
      _error = null;
    });

    try {
      await ref
          .read(businessContentRepositoryProvider)
          .postAd(
            businessId: widget.businessId,
            title: _title.text,
            body: _body.text,
            linkUrl: _link.text,
            endsAt: _endsAt,
            offerCode: _code.text,
            offerTerms: _terms.text,
          );
      if (!mounted) return;
      ref.invalidate(businessAdsProvider(widget.businessId));
      Navigator.of(context).pop(true);
    } on InvalidContentException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _posting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not post this advertisement. Check your connection.';
        _posting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Deals are Growth and Premium; the database enforces it too. Hidden
    // until the listing has loaded rather than shown and then refused.
    final business = ref.watch(singleBusinessProvider(widget.businessId)).value;
    final canOffer = business?.canPostDeals ?? false;
    final limit = business?.liveAdLimit;
    final running =
        (ref.watch(businessAdsProvider(widget.businessId)).value ??
                const <BusinessAd>[])
            .where((a) => a.endsAt == null || a.endsAt!.isAfter(DateTime.now()))
            .length;

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('New advertisement'),
        backgroundColor: palette.app,
        surfaceTintColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            Text(
              'Advertisements sit at the top of your listing, above your '
              'description, and in the Fresh in Antigua feed.',
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
            if (business != null && limit != null) ...[
              const SizedBox(height: Insets.sm),
              Text(
                '$running of $limit running '
                '${limit == 1 ? 'advertisement' : 'advertisements'} on '
                '${(business.plan ?? business.tier).label}.'
                '${running >= limit ? ' End one to post another, or move up a plan.' : ''}',
                style: AppText.bodyMedium.copyWith(
                  color: running >= limit ? palette.bad : palette.muted,
                ),
              ),
            ],
            const SizedBox(height: Insets.lg),
            _Field(
              controller: _title,
              label: 'Title',
              hint: 'Lunch special this week',
              maxLength: 120,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Give the advertisement a title.'
                  : null,
            ),
            const SizedBox(height: Insets.md),
            _Field(
              controller: _body,
              label: 'Details',
              hint: 'What is on offer, and any conditions',
              maxLines: 4,
            ),
            const SizedBox(height: Insets.md),
            _Field(
              controller: _link,
              label: 'Link (optional)',
              hint: 'https://',
              keyboardType: TextInputType.url,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return null;
                final uri = Uri.tryParse(trimmed);
                // Rejects a bare word like "menu" that would render as a
                // dead tap target on the public listing.
                if (uri == null ||
                    !uri.hasScheme ||
                    (uri.scheme != 'http' && uri.scheme != 'https')) {
                  return 'That does not look like a web address.';
                }
                return null;
              },
            ),
            if (canOffer) ...[
              const SizedBox(height: Insets.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Field(
                      controller: _code,
                      label: 'Offer code (optional)',
                      hint: 'LUNCH10',
                      validator: (value) {
                        final code = normaliseOfferCode(value);
                        if (code == null || isValidOfferCode(code)) return null;
                        return '4 to 10 letters and numbers.';
                      },
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: Insets.xs),
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _code.text = generateOfferCode()),
                      child: const Text('Generate'),
                    ),
                  ),
                ],
              ),
              Text(
                'With a code this becomes a deal. Customers claim it in the '
                'app for their own code, which you redeem at the till (Redeem '
                'a deal), so every visit counts in your monthly report.',
                style: AppText.caption.copyWith(color: palette.muted),
              ),
              const SizedBox(height: Insets.md),
              _Field(
                controller: _terms,
                label: 'Deal terms (optional)',
                hint: 'Mon to Thu lunch, one per person',
                maxLength: 200,
              ),
            ],
            const SizedBox(height: Insets.lg),
            _EndDatePicker(
              value: _endsAt,
              onChanged: (value) => setState(() => _endsAt = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: Insets.md),
              Text(
                _error!,
                style: AppText.bodyMedium.copyWith(color: palette.red),
              ),
            ],
            const SizedBox(height: Insets.xl),
            FilledButton(
              onPressed: _posting ? null : _post,
              child: Text(_posting ? 'Posting…' : 'Publish advertisement'),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'Published straight away. You can end it at any time.',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A business posting an announcement.
class PostAnnouncementScreen extends ConsumerStatefulWidget {
  const PostAnnouncementScreen({required this.businessId, super.key});

  final String businessId;

  @override
  ConsumerState<PostAnnouncementScreen> createState() =>
      _PostAnnouncementScreenState();
}

class _PostAnnouncementScreenState
    extends ConsumerState<PostAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  AnnouncementKind _kind = AnnouncementKind.business;
  bool _posting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _posting = true;
      _error = null;
    });

    try {
      await ref
          .read(businessContentRepositoryProvider)
          .postAnnouncement(
            businessId: widget.businessId,
            title: _title.text,
            body: _body.text,
            kind: _kind,
          );
      if (!mounted) return;
      ref.invalidate(announcementsProvider);
      Navigator.of(context).pop(true);
    } on InvalidContentException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _posting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not post this announcement.';
        _posting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('New announcement'),
        backgroundColor: palette.app,
        surfaceTintColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            Text(
              'Announcements go to customers who follow you, and the most '
              'recent one appears on your listing. Use them for closures, '
              'notices and offers.',
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.lg),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final kind in AnnouncementKind.values)
                  ChoiceChip(
                    avatar: Icon(announcementStyle(kind).icon, size: 16),
                    label: Text(announcementStyle(kind).label),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            _Field(
              controller: _title,
              label: 'Title',
              hint: 'Closed on Saturday',
              maxLength: 120,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Give the announcement a title.'
                  : null,
            ),
            const SizedBox(height: Insets.md),
            _Field(
              controller: _body,
              label: 'Message',
              hint: 'What should customers know?',
              maxLines: 5,
            ),
            if (_error != null) ...[
              const SizedBox(height: Insets.md),
              Text(
                _error!,
                style: AppText.bodyMedium.copyWith(color: palette.red),
              ),
            ],
            const SizedBox(height: Insets.xl),
            FilledButton(
              onPressed: _posting ? null : _post,
              child: Text(_posting ? 'Posting…' : 'Publish announcement'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A business posting an event.
class PostEventScreen extends ConsumerStatefulWidget {
  const PostEventScreen({required this.businessId, super.key});

  final String businessId;

  @override
  ConsumerState<PostEventScreen> createState() => _PostEventScreenState();
}

class _PostEventScreenState extends ConsumerState<PostEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _location = TextEditingController();
  final _tags = TextEditingController();
  final _image = TextEditingController();
  final _organizer = TextEditingController();
  final _website = TextEditingController();
  final _phone = TextEditingController();
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _posting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _location.dispose();
    for (final c in [_tags, _image, _organizer, _website, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _post() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _posting = true;
      _error = null;
    });

    try {
      await ref
          .read(businessContentRepositoryProvider)
          .postEvent(
            imageUrl: _image.text,
            tags: _tags.text.split(','),
            organizer: _organizer.text,
            website: _website.text,
            phone: _phone.text,
            businessId: widget.businessId,
            title: _title.text,
            body: _body.text,
            startsAt: _startsAt!,
            endsAt: _endsAt,
            locationNote: _location.text,
          );
      if (!mounted) return;
      ref.invalidate(upcomingEventsProvider);
      Navigator.of(context).pop(true);
    } on InvalidContentException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _posting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not post this event.';
        _posting = false;
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startsAt : _endsAt) ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );
    // The screen can be closed while a picker is open; both awaits need the
    // check or the next line uses a dead context.
    if (picked == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
    );
    if (!mounted) return;

    final when = DateTime(
      picked.year,
      picked.month,
      picked.day,
      time?.hour ?? 19,
      time?.minute ?? 0,
    );

    setState(() {
      if (isStart) {
        _startsAt = when;
        // Moving the start past the end would leave the event finishing before
        // it begins, which the repository rejects. Clearing the end is kinder
        // than silently keeping an impossible pairing.
        if (_endsAt != null && _endsAt!.isBefore(when)) _endsAt = null;
      } else {
        _endsAt = when;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final format = DateFormat.yMMMd().add_jm();

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('New event'),
        backgroundColor: palette.app,
        surfaceTintColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            Text(
              'Events show on your listing and in the calendar tab for '
              'customers across the island.',
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.lg),
            _Field(
              controller: _title,
              label: 'Title',
              hint: 'Cuisine night',
              maxLength: 120,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Give the event a title.'
                  : null,
            ),
            const SizedBox(height: Insets.md),
            _DateRow(
              label: 'Starts',
              value: _startsAt == null
                  ? null
                  : format.format(_startsAt!.toLocal()),
              onTap: () => _pickDate(isStart: true),
              errorText: _startsAt == null ? 'Pick when it starts.' : null,
            ),
            const SizedBox(height: Insets.md),
            _DateRow(
              label: 'Ends (optional)',
              value: _endsAt == null ? null : format.format(_endsAt!.toLocal()),
              onTap: () => _pickDate(isStart: false),
            ),
            const SizedBox(height: Insets.md),
            _Field(
              controller: _body,
              label: 'Details',
              hint: 'What happens, and anything people should bring',
              maxLines: 4,
            ),
            const SizedBox(height: Insets.md),
            _Field(
              controller: _location,
              label: 'Venue (optional)',
              hint: 'Dickenson Bay',
            ),
            const SizedBox(height: Insets.md),
            _Field(
              controller: _tags,
              label: 'Tags (optional)',
              hint: 'Music, Food, Family Friendly',
            ),
            const SizedBox(height: Insets.md),
            _Field(
              controller: _image,
              label: 'Picture link (optional)',
              hint: 'https://',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: Insets.md),
            _Field(
              controller: _organizer,
              label: 'Organizer (optional)',
              hint: 'Leave blank to show your business',
            ),
            const SizedBox(height: Insets.md),
            _Field(
              controller: _website,
              label: 'Website (optional)',
              hint: 'antiguaevents.com',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: Insets.md),
            _Field(
              controller: _phone,
              label: 'Phone (optional)',
              hint: '+1 268 …',
              keyboardType: TextInputType.phone,
            ),
            if (_error != null) ...[
              const SizedBox(height: Insets.md),
              Text(
                _error!,
                style: AppText.bodyMedium.copyWith(color: palette.red),
              ),
            ],
            const SizedBox(height: Insets.xl),
            FilledButton(
              onPressed: _posting ? null : _post,
              child: Text(_posting ? 'Posting…' : 'Publish event'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared labelled text field. One implementation so the three posting forms
/// behave identically, including validation timing.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppText.sectionLabel),
        const SizedBox(height: Insets.xs),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.bodyMedium.copyWith(color: palette.muted),
            filled: true,
            fillColor: palette.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Corners.md),
              borderSide: BorderSide(color: palette.line),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppText.sectionLabel),
        const SizedBox(height: Insets.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Corners.md),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(Corners.md),
              border: Border.all(
                color: errorText != null ? palette.red : palette.line,
              ),
            ),
            child: Text(
              value ?? 'Tap to choose',
              style: AppText.bodyLarge.copyWith(
                color: value == null ? palette.muted : palette.ink,
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: Text(
              errorText!,
              style: AppText.caption.copyWith(color: palette.red),
            ),
          ),
      ],
    );
  }
}

class _EndDatePicker extends StatelessWidget {
  const _EndDatePicker({required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('END DATE (OPTIONAL)', style: AppText.sectionLabel),
        const SizedBox(height: Insets.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                value == null
                    ? 'Runs until you end it'
                    : 'Ends ${DateFormat.yMMMd().format(value!.toLocal())}',
                style: AppText.bodyLarge.copyWith(
                  color: value == null ? palette.muted : palette.ink,
                ),
              ),
            ),
            TextButton(
              onPressed: value == null ? null : () => onChanged(null),
              child: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }
}

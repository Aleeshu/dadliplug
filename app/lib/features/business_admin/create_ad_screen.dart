import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/listing/listing_screen.dart'
    show singleBusinessProvider;
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:antigua_business_map/services/photo_upload.dart';
import 'package:antigua_business_map/widgets/offer_code_chip.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// An advertisement's type, the first choice in the wizard.
enum AdKind {
  specialOffer('special_offer', 'Special Offer', Icons.campaign_outlined),
  newProduct('new_product', 'New Product', Icons.inventory_2_outlined),
  event('event', 'Event', Icons.event_outlined),
  general('general', 'General Ad', Icons.article_outlined);

  const AdKind(this.dbName, this.label, this.icon);
  final String dbName;
  final String label;
  final IconData icon;
}

/// Create an advertisement in three steps, as in the redesign: create,
/// review (exactly as customers see it), post.
class CreateAdScreen extends ConsumerStatefulWidget {
  const CreateAdScreen({required this.businessId, super.key});

  final String businessId;

  @override
  ConsumerState<CreateAdScreen> createState() => _CreateAdScreenState();
}

class _CreateAdScreenState extends ConsumerState<CreateAdScreen> {
  int _step = 0;
  AdKind _kind = AdKind.specialOffer;
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _code = TextEditingController();
  final _terms = TextEditingController();
  String? _imageUrl;
  DateTime? _endsAt;
  bool _uploading = false;
  bool _posting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _body, _code, _terms]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addPhoto(ImageSource source) async {
    setState(() => _uploading = true);
    try {
      final url = await ref
          .read(photoUploaderProvider)
          .pickAndUpload(widget.businessId, source: source);
      if (url != null && mounted) setState(() => _imageUrl = url);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload the photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _endsAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day != null && mounted) {
      setState(() => _endsAt = DateTime(day.year, day.month, day.day, 23, 59));
    }
  }

  String? _validate(bool canDeal) {
    if (_title.text.trim().isEmpty) return 'Give the advertisement a title.';
    if (_title.text.trim().length > 60) {
      return 'Keep the title to 60 characters.';
    }
    final code = normaliseOfferCode(_code.text);
    if (code != null && !isValidOfferCode(code)) {
      return 'A deal code is 4 to 10 letters and numbers, like LUNCH10.';
    }
    if (code != null && !canDeal) {
      return 'Deals are part of the Growth and Premium plans.';
    }
    return null;
  }

  Future<void> _post() async {
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
            imageUrl: _imageUrl,
            endsAt: _endsAt,
            offerCode: _kind == AdKind.specialOffer ? _code.text : null,
            offerTerms: _kind == AdKind.specialOffer ? _terms.text : null,
            kind: _kind.dbName,
          );
      ref
        ..invalidate(businessAdsProvider(widget.businessId))
        ..invalidate(liveAdsProvider);
      if (mounted) setState(() => _step = 2);
    } on InvalidContentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Could not post. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final business = ref.watch(singleBusinessProvider(widget.businessId)).value;
    final canDeal = business?.canPostDeals ?? false;
    final limit = business?.liveAdLimit;
    final running =
        (ref.watch(businessAdsProvider(widget.businessId)).value ??
                const <BusinessAd>[])
            .where((a) => a.endsAt == null || a.endsAt!.isAfter(DateTime.now()))
            .length;
    final full = limit != null && running >= limit;

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Create Advertisement'),
        backgroundColor: palette.app,
      ),
      body: Column(
        children: [
          _StepHeader(step: _step),
          Expanded(
            child: switch (_step) {
              0 => _create(palette, business, canDeal, limit, running, full),
              1 => _review(palette, business),
              _ => _done(palette),
            },
          ),
        ],
      ),
    );
  }

  Widget _create(
    AppPalette palette,
    Business? business,
    bool canDeal,
    int? limit,
    int running,
    bool full,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.giant),
      children: [
        Text(
          'Ad type',
          style: AppText.titleMedium.copyWith(color: palette.ink),
        ),
        const SizedBox(height: Insets.sm),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Insets.sm,
          crossAxisSpacing: Insets.sm,
          childAspectRatio: 0.9,
          children: [
            for (final k in AdKind.values)
              _KindTile(
                kind: k,
                selected: k == _kind,
                onTap: () => setState(() => _kind = k),
              ),
          ],
        ),
        if (_kind == AdKind.event) ...[
          const SizedBox(height: Insets.md),
          Container(
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: palette.blueBg,
              borderRadius: BorderRadius.circular(Corners.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'An event with a date and venue goes on the island '
                    'calendar. Post it there for reminders and the Events tab.',
                    style: AppText.bodyMedium.copyWith(color: palette.ink),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(
                    '/business/events/new?business=${widget.businessId}',
                  ),
                  child: const Text('Post event'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Insets.lg),
        TextField(
          controller: _title,
          maxLength: 60,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: '20% off all main meals this weekend',
          ),
        ),
        TextField(
          controller: _body,
          maxLength: 500,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'What is on offer, and anything customers should know',
          ),
        ),
        Text('Photo', style: AppText.titleSmall.copyWith(color: palette.ink)),
        const SizedBox(height: Insets.sm),
        if (_imageUrl case final url?)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Corners.md),
                child: CachedNetworkImage(
                  imageUrl: url,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: IconButton.filled(
                  tooltip: 'Remove photo',
                  onPressed: () => setState(() => _imageUrl = null),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading
                      ? null
                      : () => _addPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(_uploading ? 'Uploading…' : 'Choose photo'),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading
                      ? null
                      : () => _addPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Take photo'),
                ),
              ),
            ],
          ),
        if (_kind == AdKind.specialOffer) ...[
          const SizedBox(height: Insets.lg),
          Text(
            'Offer details (optional)',
            style: AppText.titleSmall.copyWith(color: palette.ink),
          ),
          const SizedBox(height: Insets.sm),
          if (canDeal) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Deal code',
                      hintText: 'LUNCH10',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _code.text = generateOfferCode()),
                  child: const Text('Generate'),
                ),
              ],
            ),
            TextField(
              controller: _terms,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Conditions',
                hintText: 'Mon to Thu lunch, one per person',
              ),
            ),
          ] else
            Text(
              'Deal codes customers claim and redeem at your till come with '
              'the Growth and Premium plans.',
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
        ],
        const SizedBox(height: Insets.md),
        OutlinedButton.icon(
          onPressed: _pickEnd,
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(
            _endsAt == null
                ? 'Runs until you end it (set an end date)'
                : 'Ends ${DateFormat.yMMMd().format(_endsAt!)}',
          ),
        ),
        const SizedBox(height: Insets.lg),
        if (business != null)
          _PlanBox(business: business, limit: limit, running: running),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: Insets.md),
            child: Text(
              _error!,
              style: AppText.bodyMedium.copyWith(color: palette.bad),
            ),
          ),
        const SizedBox(height: Insets.lg),
        FilledButton.icon(
          onPressed: full
              ? null
              : () {
                  final problem = _validate(canDeal);
                  setState(() => _error = problem);
                  if (problem == null) setState(() => _step = 1);
                },
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Continue to review'),
        ),
      ],
    );
  }

  Widget _review(AppPalette palette, Business? business) {
    final code = normaliseOfferCode(_code.text);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.giant),
      children: [
        Text(
          'This is how your ad will appear in the app.',
          style: AppText.bodyMedium.copyWith(color: palette.muted),
        ),
        const SizedBox(height: Insets.md),
        Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(Corners.xl),
            border: Border.all(color: palette.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: business?.category.color ?? palette.red,
                  child: Icon(
                    business?.category.icon ?? Icons.storefront,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(business?.name ?? ''),
                subtitle: Text(
                  [
                    business?.category.label ?? '',
                    business?.area ?? '',
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
                trailing: Chip(label: Text(_kind.label)),
              ),
              if (_imageUrl case final url?)
                CachedNetworkImage(
                  imageUrl: url,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              Padding(
                padding: const EdgeInsets.all(Insets.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title.text.trim(),
                      style: AppText.titleLarge.copyWith(color: palette.ink),
                    ),
                    if (_body.text.trim().isNotEmpty) ...[
                      const SizedBox(height: Insets.xs),
                      Text(
                        _body.text.trim(),
                        style: AppText.bodyMedium.copyWith(color: palette.ink),
                      ),
                    ],
                    if (_kind == AdKind.specialOffer && code != null) ...[
                      const SizedBox(height: Insets.md),
                      OfferCodeChip(code: code),
                      if (_terms.text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: Insets.xs),
                          child: Text(
                            _terms.text.trim(),
                            style: AppText.caption.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ),
                    ],
                    if (_endsAt != null) ...[
                      const SizedBox(height: Insets.sm),
                      Text(
                        'Valid until ${DateFormat.yMMMd().format(_endsAt!)}',
                        style: AppText.caption.copyWith(color: palette.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: Insets.md),
            child: Text(
              _error!,
              style: AppText.bodyMedium.copyWith(color: palette.bad),
            ),
          ),
        const SizedBox(height: Insets.xl),
        FilledButton.icon(
          onPressed: _posting ? null : _post,
          icon: const Icon(Icons.send, size: 18),
          label: Text(_posting ? 'Posting…' : 'Post advertisement'),
        ),
        const SizedBox(height: Insets.sm),
        TextButton(
          onPressed: _posting ? null : () => setState(() => _step = 0),
          child: const Text('Back to edit'),
        ),
      ],
    );
  }

  Widget _done(AppPalette palette) => Padding(
    padding: const EdgeInsets.all(Insets.huge),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle, size: 72, color: palette.good),
        const SizedBox(height: Insets.lg),
        Text(
          'Your ad is live',
          style: AppText.titleLarge.copyWith(color: palette.ink),
        ),
        const SizedBox(height: Insets.sm),
        Text(
          'It is on your listing and in the Fresh in Antigua feed. Your '
          'dashboard counts its views, opens and shares.',
          textAlign: TextAlign.center,
          style: AppText.bodyMedium.copyWith(color: palette.muted),
        ),
        const SizedBox(height: Insets.xl),
        FilledButton(
          onPressed: () =>
              context.go('/business?business=${widget.businessId}'),
          child: const Text('Back to dashboard'),
        ),
      ],
    ),
  );
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const labels = ['Create Ad', 'Review', 'Post'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.lg),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: i <= step ? palette.red : palette.line,
              child: Text(
                '${i + 1}',
                style: AppText.labelMedium.copyWith(
                  color: i <= step ? palette.onRed : palette.muted,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              labels[i],
              style: AppText.labelMedium.copyWith(
                color: i == step ? palette.ink : palette.muted,
              ),
            ),
            if (i < labels.length - 1)
              Expanded(
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: palette.line,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final AdKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: selected ? palette.blueBg : palette.surface,
      borderRadius: BorderRadius.circular(Corners.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Corners.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Corners.md),
            border: Border.all(
              color: selected ? palette.red : palette.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(kind.icon, color: selected ? palette.red : palette.ink),
              const SizedBox(height: 4),
              Text(
                kind.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppText.caption.copyWith(
                  color: palette.ink,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanBox extends StatelessWidget {
  const _PlanBox({
    required this.business,
    required this.limit,
    required this.running,
  });

  final Business business;
  final int? limit;
  final int running;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final plan = (business.plan ?? business.tier).label;
    final full = limit != null && running >= limit!;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: full ? palette.badBg : palette.surface,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: full ? palette.bad : palette.line),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_outlined, color: palette.red),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              limit == null
                  ? 'Your plan: $plan. Unlimited running ads.'
                  : 'Your plan: $plan. $running of $limit running ads.'
                        '${full ? ' End one, or move up a plan, to post another.' : ''}',
              style: AppText.bodyMedium.copyWith(
                color: full ? palette.bad : palette.ink,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                context.push('/business/plans?business=${business.id}'),
            child: const Text('Plans'),
          ),
        ],
      ),
    );
  }
}

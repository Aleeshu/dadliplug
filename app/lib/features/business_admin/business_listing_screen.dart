import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/services/opening_hours_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The listing editor, for owners and for the team.
///
/// Edits everything a customer sees on the listing (plan.md Phase 4). The team
/// additionally creates listings here and sets which plan one is on; an owner
/// never sees those controls, and the database refuses them from an owner
/// regardless.
///
/// Opened with a [businessId] to edit, or with [createNew] to start a fresh
/// listing. With neither, there is nothing to edit and the screen says so —
/// it used to fall back to the first business in the table, which put an
/// owner in front of somebody else's listing.
class BusinessListingScreen extends ConsumerStatefulWidget {
  const BusinessListingScreen({
    this.businessId,
    this.createNew = false,
    this.isTeam = false,
    super.key,
  });

  final String? businessId;
  final bool createNew;

  /// Shows the team-only plan control.
  final bool isTeam;

  @override
  ConsumerState<BusinessListingScreen> createState() =>
      _BusinessListingScreenState();
}

class _BusinessListingScreenState extends ConsumerState<BusinessListingScreen> {
  final _formKey = GlobalKey<FormState>();

  Business? _current;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  final _name = TextEditingController();
  final _area = TextEditingController();
  final _description = TextEditingController();
  final _offer = TextEditingController();
  final _priceRange = TextEditingController();
  final _howToFindUs = TextEditingController();
  final _address = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _whatsappBusiness = TextEditingController();
  final _website = TextEditingController();
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();
  final _tiktok = TextEditingController();

  BusinessCategory _category = BusinessCategory.food;
  SubscriptionTier _tier = SubscriptionTier.trial;
  bool _isClosedToday = false;
  final Set<String> _tags = {};
  final Set<int> _days = {};
  double _opensAt = 9;
  double _closesAt = 17;
  final List<_MenuRow> _menu = [];

  bool get _isCreating => widget.createNew;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _area,
      _description,
      _offer,
      _priceRange,
      _howToFindUs,
      _address,
      _latitude,
      _longitude,
      _phone,
      _whatsapp,
      _whatsappBusiness,
      _website,
      _instagram,
      _facebook,
      _tiktok,
    ]) {
      c.dispose();
    }
    for (final row in _menu) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (_isCreating) {
      setState(() => _isLoading = false);
      return;
    }

    final id = widget.businessId;
    if (id == null || id.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final b = await ref.read(businessRepositoryProvider).getBusinessById(id);
      if (!mounted) return;
      if (b != null) _fill(b);
      setState(() => _isLoading = false);
    } catch (error) {
      // An error is not "no listing". Saying "nothing assigned" when the
      // database is unreachable would send an owner to the team for nothing.
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Could not load this listing. Check your connection.';
      });
    }
  }

  void _fill(Business b) {
    _current = b;
    _name.text = b.name;
    _area.text = b.area;
    _description.text = b.description;
    _offer.text = b.offer ?? '';
    _priceRange.text = b.priceRange ?? '';
    _howToFindUs.text = b.howToFindUs ?? '';
    _address.text = b.address ?? '';
    _latitude.text = b.latitude?.toString() ?? '';
    _longitude.text = b.longitude?.toString() ?? '';
    _phone.text = b.phone ?? '';
    _whatsapp.text = b.whatsapp ?? '';
    _whatsappBusiness.text = b.whatsappBusiness ?? '';
    _website.text = b.website ?? '';
    _instagram.text = b.instagram ?? '';
    _facebook.text = b.facebook ?? '';
    _tiktok.text = b.tiktok ?? '';
    _category = b.category;
    _tier = b.tier;
    _isClosedToday = b.isClosedToday;
    _tags
      ..clear()
      ..addAll(b.tags);
    _days
      ..clear()
      ..addAll(b.hours.days);
    _opensAt = b.hours.opensAt;
    _closesAt = b.hours.closesAt;
    for (final row in _menu) {
      row.dispose();
    }
    _menu
      ..clear()
      ..addAll(b.menu.map(_MenuRow.from));
  }

  Business _collect() {
    final base =
        _current ??
        Business(
          id: '',
          name: '',
          category: _category,
          tier: _tier,
          area: '',
          description: '',
        );

    return base.copyWith(
      name: _name.text.trim(),
      category: _category,
      tier: _tier,
      area: _area.text.trim(),
      description: _description.text.trim(),
      offer: _offer.text.trim(),
      priceRange: _priceRange.text.trim(),
      howToFindUs: _howToFindUs.text.trim(),
      address: _address.text.trim(),
      latitude: double.tryParse(_latitude.text.trim()),
      longitude: double.tryParse(_longitude.text.trim()),
      phone: _phone.text.trim(),
      whatsapp: _whatsapp.text.trim(),
      whatsappBusiness: _whatsappBusiness.text.trim(),
      website: _website.text.trim(),
      instagram: normaliseHandle(_instagram.text),
      facebook: normaliseHandle(_facebook.text),
      tiktok: normaliseHandle(_tiktok.text),
      tags: _tags.toList(),
      isClosedToday: _isClosedToday,
      hours: OpeningHours(
        days: Set.of(_days),
        opensAt: _opensAt,
        closesAt: _closesAt,
      ),
      menu: [
        for (final row in _menu)
          if (row.name.text.trim().isNotEmpty) row.toItem(),
      ],
    );
  }

  Future<void> _toggleClosedToday(bool value) async {
    final b = _current;
    if (b == null) {
      // Not saved yet; the value goes in with the first save.
      setState(() => _isClosedToday = value);
      return;
    }

    setState(() => _isClosedToday = value);
    try {
      await ref
          .read(businessRepositoryProvider)
          .toggleClosedToday(b.id, isClosed: value);
      ref.invalidate(businessListProvider);
      _snack(value ? 'Marked as closed today.' : 'Back to normal hours.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isClosedToday = !value);
      _snack('Could not update. Check your connection.', isError: true);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    final updated = _collect();

    try {
      if (_isCreating && _current == null) {
        final id = await ref
            .read(listingAdminRepositoryProvider)
            .createBusiness(updated);
        _current = updated.copyWith(id: id);
        _snack('Listing created.');
      } else {
        await ref.read(businessRepositoryProvider).updateBusiness(updated);
        final previousTier = _current?.tier;
        if (widget.isTeam && previousTier != _tier) {
          await ref
              .read(listingAdminRepositoryProvider)
              .setSubscription(updated.id, _tier);
        }
        _current = updated;
        _snack('Listing saved and marked verified today.');
      }
      ref.invalidate(businessListProvider);
    } catch (_) {
      _snack(
        'Could not save the listing. Check your connection and try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? context.palette.bad : null,
      ),
    );
  }

  Future<void> _pickTime({required bool opening}) async {
    final current = opening ? _opensAt : _closesAt;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current.floor() % 24,
        minute: ((current - current.floor()) * 60).round(),
      ),
    );
    if (picked == null) return;
    var value = picked.hour + picked.minute / 60;
    // Midnight as a closing time means "end of the day", not "before opening".
    if (!opening && value == 0) value = 24;
    setState(() => opening ? _opensAt = value : _closesAt = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final title = _isCreating && _current == null
        ? 'New listing'
        : 'Manage listing';

    if (_isLoading) {
      return Scaffold(
        backgroundColor: palette.app,
        appBar: AppBar(title: Text(title)),
        body: Center(child: CircularProgressIndicator(color: palette.red)),
      );
    }

    if (_loadError != null || (!_isCreating && _current == null)) {
      return Scaffold(
        backgroundColor: palette.app,
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.giant),
            child: Text(
              _loadError ??
                  'No listing is linked to your account yet. The Dadliplug '
                      'team links it once your listing is set up.',
              style: AppText.bodyLarge.copyWith(color: palette.muted),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: palette.surface,
        foregroundColor: palette.ink,
        elevation: 0,
        actions: [
          if (_current != null && _current!.id.isNotEmpty)
            IconButton(
              tooltip: 'View as a customer',
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () => context.push('/listing/${_current!.id}'),
            ),
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              'Save',
              style: TextStyle(
                color: palette.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            _closedTodayCard(palette),
            const SizedBox(height: Insets.xl),

            if (widget.isTeam) ...[
              _Header('Plan (team only)', palette),
              const SizedBox(height: Insets.md),
              DropdownButtonFormField<SubscriptionTier>(
                initialValue: _tier,
                decoration: _decoration('Plan', palette),
                items: [
                  for (final tier in SubscriptionTier.values)
                    DropdownMenuItem(
                      value: tier,
                      child: Text(
                        tier.monthlyPrice > 0
                            ? '${tier.label} — EC\$${tier.monthlyPrice}/mo'
                            : tier.label,
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _tier = v);
                },
              ),
              const SizedBox(height: Insets.xl),
            ],

            _Header('General', palette),
            const SizedBox(height: Insets.md),
            _field(
              _name,
              'Business name',
              palette,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required.' : null,
            ),
            DropdownButtonFormField<BusinessCategory>(
              initialValue: _category,
              decoration: _decoration('Category', palette),
              items: [
                for (final cat in BusinessCategory.values)
                  DropdownMenuItem(value: cat, child: Text(cat.label)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: Insets.md),
            _field(_area, 'Area (e.g. Dickenson Bay)', palette),
            _field(_description, 'Description', palette, maxLines: 4),
            _field(_priceRange, r'Price range (e.g. EC$15–30)', palette),
            _field(
              _offer,
              'Current offer (optional)',
              palette,
              hint: '10% off catch of the day',
            ),
            const SizedBox(height: Insets.md),

            _Header('Hours', palette),
            const SizedBox(height: Insets.md),
            _hoursEditor(palette),
            const SizedBox(height: Insets.xl),

            _Header('Location', palette),
            const SizedBox(height: Insets.md),
            _field(
              _howToFindUs,
              'How to find us',
              palette,
              hint: 'Past the roundabout, opposite the market',
              maxLines: 2,
            ),
            _field(_address, 'Address (if there is one)', palette),
            // Left blank for a business with no walk-in location; it then
            // has no pin.
            Row(
              children: [
                Expanded(
                  child: _field(
                    _latitude,
                    'Latitude',
                    palette,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) => _coordinate(v, 16.9, 17.8),
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: _field(
                    _longitude,
                    'Longitude',
                    palette,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) => _coordinate(v, -62.0, -61.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),

            _Header('Contact', palette),
            const SizedBox(height: Insets.md),
            _field(
              _phone,
              'Phone (+1 268 …)',
              palette,
              keyboardType: TextInputType.phone,
            ),
            _field(
              _whatsapp,
              'WhatsApp (+1 268 …)',
              palette,
              keyboardType: TextInputType.phone,
            ),
            _field(
              _whatsappBusiness,
              'WhatsApp for bookings (if different)',
              palette,
              keyboardType: TextInputType.phone,
            ),
            _field(
              _website,
              'Website',
              palette,
              keyboardType: TextInputType.url,
            ),
            _field(
              _instagram,
              'Instagram handle',
              palette,
              hint: 'yourbusiness',
            ),
            _field(_facebook, 'Facebook page', palette, hint: 'yourbusiness'),
            _field(_tiktok, 'TikTok handle', palette, hint: 'yourbusiness'),
            const SizedBox(height: Insets.md),

            _Header('Practical info', palette),
            const SizedBox(height: Insets.md),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final tag in KnownBusinessTags.all)
                  FilterChip(
                    label: Text(KnownBusinessTags.labelFor(tag)),
                    selected: _tags.contains(tag),
                    onSelected: (on) => setState(
                      () => on ? _tags.add(tag) : _tags.remove(tag),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Insets.xl),

            _Header(
              _category == BusinessCategory.food ? 'Menu' : 'Services',
              palette,
            ),
            const SizedBox(height: Insets.md),
            for (var i = 0; i < _menu.length; i++) _menuRow(i, palette),
            TextButton.icon(
              onPressed: () => setState(() => _menu.add(_MenuRow.empty())),
              icon: const Icon(Icons.add),
              label: Text(
                _category == BusinessCategory.food
                    ? 'Add a menu item'
                    : 'Add a service',
              ),
            ),
            const SizedBox(height: Insets.xl),

            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isCreating && _current == null
                          ? 'Create listing'
                          : 'Save and mark verified',
                    ),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'Saving stamps today as the "last verified" date customers see.',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.giant),
          ],
        ),
      ),
    );
  }

  Widget _closedTodayCard(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: _isClosedToday ? palette.badBg : palette.surface,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: _isClosedToday ? palette.bad : palette.line),
      ),
      child: SwitchListTile(
        value: _isClosedToday,
        onChanged: _toggleClosedToday,
        activeThumbColor: palette.bad,
        contentPadding: EdgeInsets.zero,
        title: Text(
          'Closed today',
          style: AppText.titleSmall.copyWith(
            color: _isClosedToday ? palette.bad : palette.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'One tap for storms, holidays and Carnival. Takes effect straight '
          'away.',
          style: AppText.caption.copyWith(color: palette.muted),
        ),
      ),
    );
  }

  Widget _hoursEditor(AppPalette palette) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                label: Text(names[d - 1]),
                selected: _days.contains(d),
                onSelected: (on) =>
                    setState(() => on ? _days.add(d) : _days.remove(d)),
              ),
          ],
        ),
        const SizedBox(height: Insets.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickTime(opening: true),
                child: Text('Opens ${formatHour(_opensAt)}'),
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickTime(opening: false),
                child: Text(
                  _closesAt >= 24
                      ? 'Closes midnight'
                      : 'Closes ${formatHour(_closesAt)}',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.xs),
        Text(
          _days.isEmpty
              ? 'No days selected: customers will see this listing as closed.'
              : 'A closing time earlier than opening means open past midnight.',
          style: AppText.caption.copyWith(color: palette.muted),
        ),
      ],
    );
  }

  Widget _menuRow(int index, AppPalette palette) {
    final row = _menu[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _field(row.name, 'Name', palette),
                _field(row.detail, 'Detail', palette),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(flex: 2, child: _field(row.price, 'Price', palette)),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _menu.removeAt(index).dispose()),
          ),
        ],
      ),
    );
  }

  /// Empty is fine (the team may not have a pin yet). Otherwise it must be a
  /// number on Antigua or Barbuda, so a swapped latitude and longitude cannot
  /// drop a pin in the Atlantic.
  String? _coordinate(String? value, double min, double max) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final n = double.tryParse(text);
    if (n == null || n < min || n > max) return 'Not on Antigua or Barbuda.';
    return null;
  }

  Widget _field(
    TextEditingController controller,
    String label,
    AppPalette palette, {
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: AppText.bodyMedium.copyWith(color: palette.ink),
        decoration: _decoration(label, palette, hint: hint),
      ),
    );
  }

  InputDecoration _decoration(
    String label,
    AppPalette palette, {
    String? hint,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Corners.md),
      borderSide: BorderSide(color: palette.line),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: palette.surface,
      border: border,
      enabledBorder: border,
    );
  }
}

/// Strips what people paste around a handle: "@name", or a full profile URL.
///
/// Handles are stored bare (`20261012140000_social_accounts.sql`) and the app
/// builds the link, so a pasted URL would otherwise become
/// `instagram.com/https://instagram.com/name`.
@visibleForTesting
String normaliseHandle(String raw) {
  var value = raw.trim();
  final url = Uri.tryParse(value);
  if (url != null && url.hasScheme && url.pathSegments.isNotEmpty) {
    value = url.pathSegments.firstWhere(
      (s) => s.isNotEmpty,
      orElse: () => value,
    );
  }
  return value.replaceFirst(RegExp('^@+'), '');
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.palette);

  final String title;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: AppText.titleMedium.copyWith(
      color: palette.ink,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _MenuRow {
  _MenuRow(this.name, this.detail, this.price);

  factory _MenuRow.empty() => _MenuRow(
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  );

  factory _MenuRow.from(MenuItem item) => _MenuRow(
    TextEditingController(text: item.name ?? ''),
    TextEditingController(text: item.detail ?? ''),
    TextEditingController(text: item.price ?? ''),
  );

  final TextEditingController name;
  final TextEditingController detail;
  final TextEditingController price;

  MenuItem toItem() => MenuItem(
    name: name.text.trim(),
    detail: detail.text.trim().isEmpty ? null : detail.text.trim(),
    price: price.text.trim().isEmpty ? null : price.text.trim(),
  );

  void dispose() {
    name.dispose();
    detail.dispose();
    price.dispose();
  }
}

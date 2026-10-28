import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/listing/listing_screen.dart'
    show singleBusinessProvider;
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/bookings.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

String _when(DateTime at) =>
    DateFormat('EEE d MMM, h:mm a').format(at.toLocal());

/// "Book a Table" from a business page.
class BookTableSheet extends ConsumerStatefulWidget {
  const BookTableSheet({required this.business, super.key});

  final Business business;

  static Future<void> show(BuildContext context, Business business) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BookTableSheet(business: business),
    );
    if ((ok ?? false) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request sent to ${business.name}. You will see their answer in '
            'My bookings.',
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<BookTableSheet> createState() => _BookTableSheetState();
}

class _BookTableSheetState extends ConsumerState<BookTableSheet> {
  DateTime? _day;
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);
  int _party = 2;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime? get _at => _day == null
      ? null
      : DateTime(_day!.year, _day!.month, _day!.day, _time.hour, _time.minute);

  Future<void> _send() async {
    final at = _at;
    if (at == null) {
      setState(() => _error = 'Choose a day.');
      return;
    }
    if (_name.text.trim().isEmpty || _phone.text.trim().length < 7) {
      setState(() => _error = 'Add your name and a phone number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(bookingsRepositoryProvider)
          .request(
            businessId: widget.business.id,
            at: at,
            partySize: _party,
            name: _name.text,
            phone: _phone.text,
            note: _note.text,
          );
      ref.invalidate(myBookingsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = bookingErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();

    return Padding(
      padding: EdgeInsets.only(
        left: Insets.huge,
        right: Insets.huge,
        top: Insets.huge,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Insets.huge,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Book a table',
              style: AppText.titleLarge.copyWith(color: palette.ink),
            ),
            Text(
              '${widget.business.name} confirms or declines in the app.',
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _day ?? now,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 60)),
                      );
                      if (d != null) setState(() => _day = d);
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      _day == null
                          ? 'Day'
                          : DateFormat('EEE d MMM').format(_day!),
                    ),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (t != null) setState(() => _time = t);
                    },
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(_time.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Row(
              children: [
                Text(
                  'People',
                  style: AppText.titleSmall.copyWith(color: palette.ink),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _party > 1 ? () => setState(() => _party--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_party', style: AppText.titleLarge),
                IconButton(
                  onPressed: _party < 30
                      ? () => setState(() => _party++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            TextField(
              controller: _note,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Anything else? (optional)',
                hintText: 'Birthday, high chair, outside table…',
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
            FilledButton.icon(
              onPressed: _busy ? null : _send,
              icon: const Icon(Icons.event_seat_outlined, size: 18),
              label: Text(_busy ? 'Sending…' : 'Request booking'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _statusChip(BuildContext context, Booking b) {
  final palette = context.palette;
  final (label, fg, bg) = switch (b.status) {
    'confirmed' => ('Confirmed', palette.good, palette.goodBg),
    'pending' => ('Waiting', palette.warn, palette.warnBg),
    'declined' => ('Declined', palette.bad, palette.badBg),
    _ => ('Cancelled', palette.muted, palette.app),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(Corners.pill),
    ),
    child: Text(
      label,
      style: AppText.caption.copyWith(color: fg, fontWeight: FontWeight.w700),
    ),
  );
}

/// A customer's bookings and their answers.
class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final bookings = ref.watch(myBookingsProvider);
    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('My bookings'),
        backgroundColor: palette.app,
      ),
      body: bookings.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (_, _) => const Center(child: Text('Could not load bookings.')),
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.huge),
                  child: Text(
                    'No bookings yet. Restaurants that take bookings show '
                    '"Book a Table" on their page.',
                    textAlign: TextAlign.center,
                    style: AppText.bodyMedium.copyWith(color: palette.muted),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(Insets.lg),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, i) {
                  final b = list[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => context.push('/listing/${b.businessId}'),
                    title: Text(b.businessName),
                    subtitle: Text(
                      '${_when(b.at)} · ${b.partySize} '
                      '${b.partySize == 1 ? 'person' : 'people'}'
                      '${b.businessNote == null ? '' : '\n“${b.businessNote}”'}',
                    ),
                    isThreeLine: b.businessNote != null,
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _statusChip(context, b),
                        if (b.isOpen && b.at.isAfter(DateTime.now()))
                          InkWell(
                            onTap: () async {
                              try {
                                await ref
                                    .read(bookingsRepositoryProvider)
                                    .cancel(b.id);
                                ref.invalidate(myBookingsProvider);
                              } on Object catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(bookingErrorMessage(e)),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Cancel',
                                style: AppText.caption.copyWith(
                                  color: palette.bad,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// The owner's bookings: confirm or decline, call or WhatsApp the guest,
/// and switch bookings on or off.
class BusinessBookingsScreen extends ConsumerWidget {
  const BusinessBookingsScreen({required this.businessId, super.key});

  final String businessId;

  Future<void> _answer(
    BuildContext context,
    WidgetRef ref,
    Booking b, {
    required bool confirm,
  }) async {
    String? note;
    if (!confirm) {
      final c = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Decline booking'),
          content: TextField(
            controller: c,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Message to the guest (optional)',
              hintText: 'Fully booked that night; 8pm is free',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, c.text),
              child: const Text('Decline'),
            ),
          ],
        ),
      );
      c.dispose();
      if (note == null) return;
    }
    try {
      await ref
          .read(bookingsRepositoryProvider)
          .answer(b.id, confirm: confirm, note: note);
      ref.invalidate(businessBookingsProvider(businessId));
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(bookingErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final business = ref.watch(singleBusinessProvider(businessId)).value;
    final bookings = ref.watch(businessBookingsProvider(businessId));

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Bookings'),
        backgroundColor: palette.app,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: [
          if (business != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Take table bookings in the app'),
              subtitle: const Text(
                'Shows "Book a Table" on your page. You confirm each one.',
              ),
              value: business.acceptsBookings,
              onChanged: (v) async {
                await ref
                    .read(bookingsRepositoryProvider)
                    .setAccepting(businessId, accepting: v);
                ref
                  ..invalidate(singleBusinessProvider(businessId))
                  ..invalidate(businessListProvider);
              },
            ),
          const Divider(),
          ...bookings.when(
            loading: () => [
              Center(child: CircularProgressIndicator(color: palette.red)),
            ],
            error: (_, _) => [const Text('Could not load bookings.')],
            data: (list) => list.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(Insets.xl),
                      child: Text(
                        'No upcoming bookings.',
                        textAlign: TextAlign.center,
                        style: AppText.bodyMedium.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ]
                : [
                    for (final b in list)
                      Card(
                        margin: const EdgeInsets.only(bottom: Insets.sm),
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${_when(b.at)} · ${b.partySize} '
                                      '${b.partySize == 1 ? 'person' : 'people'}',
                                      style: AppText.titleSmall.copyWith(
                                        color: palette.ink,
                                      ),
                                    ),
                                  ),
                                  _statusChip(context, b),
                                ],
                              ),
                              Text(
                                '${b.name} · ${b.phone}',
                                style: AppText.bodyMedium.copyWith(
                                  color: palette.ink,
                                ),
                              ),
                              if (b.note case final note?)
                                Text(
                                  '“$note”',
                                  style: AppText.caption.copyWith(
                                    color: palette.muted,
                                  ),
                                ),
                              Wrap(
                                spacing: Insets.xs,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => launchUrl(
                                      Uri(scheme: 'tel', path: b.phone),
                                    ),
                                    icon: const Icon(Icons.call, size: 16),
                                    label: const Text('Call'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => launchUrl(
                                      Uri.parse(
                                        'https://wa.me/${b.phone.replaceAll(RegExp('[^0-9]'), '')}',
                                      ),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                    icon: const Icon(Icons.chat, size: 16),
                                    label: const Text('WhatsApp'),
                                  ),
                                  if (b.isPending) ...[
                                    TextButton(
                                      onPressed: () => _answer(
                                        context,
                                        ref,
                                        b,
                                        confirm: false,
                                      ),
                                      child: const Text('Decline'),
                                    ),
                                    FilledButton(
                                      onPressed: () => _answer(
                                        context,
                                        ref,
                                        b,
                                        confirm: true,
                                      ),
                                      child: const Text('Confirm'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}

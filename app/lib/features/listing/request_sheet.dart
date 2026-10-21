import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/requests.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ask for a quote or a slot, sent to the business on WhatsApp.
///
/// No booking system: the request is a WhatsApp message the business answers
/// the way it already answers customers (plan.md section 11).
class RequestSheet extends StatefulWidget {
  const RequestSheet({
    required this.business,
    required this.kind,
    required this.onSent,
    super.key,
  });

  final Business business;
  final RequestKind kind;

  /// Called as WhatsApp opens, so the tap is counted for the business.
  final VoidCallback onSent;

  static Future<void> show(
    BuildContext context,
    Business business, {
    required VoidCallback onSent,
  }) async {
    final kind = requestKindFor(business.category);
    if (kind == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          RequestSheet(business: business, kind: kind, onSent: onSent),
    );
  }

  @override
  State<RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<RequestSheet> {
  final _details = TextEditingController();
  DateTime? _when;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _when ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (!mounted) return;
    setState(
      () => _when = DateTime(
        day.year,
        day.month,
        day.day,
        time?.hour ?? 10,
        time?.minute ?? 0,
      ),
    );
  }

  Future<void> _send() async {
    final number = (widget.business.whatsapp ?? '').replaceAll(
      RegExp('[^0-9]'),
      '',
    );
    final text = requestMessage(
      business: widget.business,
      kind: widget.kind,
      details: _details.text,
      when: _when,
    );
    widget.onSent();
    await launchUrl(
      Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(text)}'),
      mode: LaunchMode.externalApplication,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isQuote = widget.kind == RequestKind.quote;

    return Padding(
      padding: EdgeInsets.only(
        left: Insets.huge,
        right: Insets.huge,
        top: Insets.huge,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Insets.huge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            requestLabel(widget.business),
            style: AppText.titleLarge.copyWith(color: palette.ink),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            isQuote
                ? 'Say what you need. It goes to ${widget.business.name} on '
                      'WhatsApp, where you can add a photo too.'
                : 'Pick a time and say what for. It goes to '
                      '${widget.business.name} on WhatsApp to confirm.',
            style: AppText.bodyMedium.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.lg),
          TextField(
            controller: _details,
            maxLines: isQuote ? 4 : 2,
            decoration: InputDecoration(
              labelText: isQuote ? 'What do you need?' : 'What for? (optional)',
              hintText: isQuote
                  ? "e.g. Leaking kitchen tap, St. John's"
                  : 'e.g. Box braids',
            ),
          ),
          if (!isQuote) ...[
            const SizedBox(height: Insets.md),
            OutlinedButton.icon(
              onPressed: _pickWhen,
              icon: const Icon(Icons.event, size: 18),
              label: Text(
                _when == null
                    ? 'Choose a day and time'
                    : '${MaterialLocalizations.of(context).formatFullDate(_when!)}'
                          ', ${TimeOfDay.fromDateTime(_when!).format(context)}',
              ),
            ),
          ],
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            onPressed: _send,
            icon: const Icon(Icons.chat, size: 18),
            label: const Text('Send on WhatsApp'),
          ),
        ],
      ),
    );
  }
}

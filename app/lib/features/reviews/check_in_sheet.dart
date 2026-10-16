import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/services/reviews_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Check in at a business: scan the till QR, or type its code.
///
/// Opened from a listing ([businessId] known, so typing the code is enough)
/// or from More (scan only: the QR carries which business it is).
class CheckInSheet extends ConsumerStatefulWidget {
  const CheckInSheet({this.businessId, super.key});

  final String? businessId;

  /// Shows the sheet; resolves to true when a check-in was recorded or
  /// queued.
  static Future<bool> show(BuildContext context, {String? businessId}) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => CheckInSheet(businessId: businessId),
      ) ??
      false;

  @override
  ConsumerState<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends ConsumerState<CheckInSheet> {
  final _code = TextEditingController();
  late bool _scanning = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit(String businessId, String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(reviewsRepositoryProvider)
          .checkIn(businessId: businessId, code: code);
      ref.invalidate(reviewEligibilityProvider(businessId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == CheckInResult.recorded
                ? 'Checked in. You can now review this business.'
                : 'No signal: your check-in is saved and will count once '
                      'you reconnect.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = reviewErrorMessage(error);
      });
    }
  }

  void _onScan(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final parsed = parseVisitQr(barcode.rawValue ?? '');
      if (parsed == null) continue;
      final expected = widget.businessId;
      if (expected != null && parsed.businessId != expected) {
        setState(() => _error = 'That code belongs to a different business.');
        return;
      }
      _submit(parsed.businessId, parsed.code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final businessId = widget.businessId;
    final canType = businessId != null;

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
            'Check in',
            style: AppText.titleLarge.copyWith(color: palette.ink),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            'Ask for the Dadliplug code at the till. Checking in proves you '
            'were here, which is what lets you leave a review.',
            style: AppText.bodyMedium.copyWith(color: palette.muted),
          ),
          if (canType) ...[
            const SizedBox(height: Insets.lg),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Scan QR')),
                ButtonSegment(value: false, label: Text('Type code')),
              ],
              selected: {_scanning},
              onSelectionChanged: (s) => setState(() => _scanning = s.first),
            ),
          ],
          const SizedBox(height: Insets.lg),
          if (_scanning || !canType)
            ClipRRect(
              borderRadius: BorderRadius.circular(Corners.xxl),
              child: SizedBox(
                height: 280,
                child: _busy
                    ? Center(
                        child: CircularProgressIndicator(color: palette.red),
                      )
                    : MobileScanner(
                        onDetect: _onScan,
                        errorBuilder: (context, error) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(Insets.huge),
                            child: Text(
                              'The camera is not available. '
                              '${canType ? 'Type the code instead.' : ''}',
                              textAlign: TextAlign.center,
                              style: AppText.bodyMedium.copyWith(
                                color: palette.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            )
          else ...[
            TextField(
              controller: _code,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: AppText.numericLarge.copyWith(letterSpacing: 6),
              decoration: const InputDecoration(hintText: 'A1B2C3'),
              onSubmitted: (v) => _submit(businessId, v),
            ),
            const SizedBox(height: Insets.md),
            FilledButton(
              onPressed: _busy ? null : () => _submit(businessId, _code.text),
              child: Text(_busy ? 'Checking in…' : 'Check in'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: Insets.md),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppText.bodyMedium.copyWith(color: palette.red),
            ),
          ],
        ],
      ),
    );
  }
}

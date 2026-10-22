import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/services/deals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// At the till: confirm a resident's deal code (Business Plan 2, Dadliplug
/// Deals). Type it, or scan the QR code on their phone. Each code works once,
/// and only for this business's deals.
class RedeemDealScreen extends ConsumerStatefulWidget {
  const RedeemDealScreen({super.key});

  @override
  ConsumerState<RedeemDealScreen> createState() => _RedeemDealScreenState();
}

class _RedeemDealScreenState extends ConsumerState<RedeemDealScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  ({bool ok, String message})? _result;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _redeem(String raw) async {
    final code = normaliseDealCode(raw);
    if (code.length != 6) {
      setState(
        () => _result = (ok: false, message: 'Deal codes are 6 characters.'),
      );
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final title = await ref.read(dealsRepositoryProvider).redeem(code);
      _code.clear();
      setState(() => _result = (ok: true, message: 'Redeemed: $title'));
    } on Object catch (e) {
      setState(() => _result = (ok: false, message: dealErrorMessage(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _DealScanner()),
    );
    if (scanned != null && mounted) {
      _code.text = normaliseDealCode(scanned);
      await _redeem(scanned);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final result = _result;

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Redeem a deal'),
        backgroundColor: palette.app,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Insets.huge),
        children: [
          Text(
            "Enter the customer's 6-character code, or scan the QR on their "
            'phone. It confirms the deal and counts in your monthly report.',
            style: AppText.bodyMedium.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.xl),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: AppText.numericLarge.copyWith(
              color: palette.ink,
              letterSpacing: 6,
            ),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(hintText: 'ABC234'),
            onSubmitted: _redeem,
          ),
          const SizedBox(height: Insets.md),
          FilledButton(
            onPressed: _busy ? null : () => _redeem(_code.text),
            child: Text(_busy ? 'Checking…' : 'Redeem'),
          ),
          const SizedBox(height: Insets.sm),
          OutlinedButton.icon(
            onPressed: _busy ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('Scan their code'),
          ),
          if (result != null) ...[
            const SizedBox(height: Insets.xl),
            Container(
              padding: const EdgeInsets.all(Insets.lg),
              decoration: BoxDecoration(
                color: result.ok ? palette.goodBg : palette.badBg,
                borderRadius: BorderRadius.circular(Corners.md),
              ),
              child: Row(
                children: [
                  Icon(
                    result.ok ? Icons.check_circle : Icons.error_outline,
                    color: result.ok ? palette.good : palette.bad,
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      result.message,
                      style: AppText.titleSmall.copyWith(
                        color: result.ok ? palette.good : palette.bad,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DealScanner extends StatefulWidget {
  const _DealScanner();

  @override
  State<_DealScanner> createState() => _DealScannerState();
}

class _DealScannerState extends State<_DealScanner> {
  bool _done = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan the deal code')),
    body: MobileScanner(
      onDetect: (capture) {
        if (_done) return;
        final value = capture.barcodes
            .map((b) => b.rawValue)
            .whereType<String>()
            .firstOrNull;
        if (value == null) return;
        _done = true;
        Navigator.of(context).pop(value);
      },
    ),
  );
}

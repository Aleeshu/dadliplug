import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/services/reviews_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The business's visit QR, to show at the till (plan.md section 8).
///
/// A customer scans it with their own signed-in phone to record a verified
/// visit, which is what lets them review. The business does not choose who
/// may scan, which is the point: it cannot approve only its happy customers.
/// The code changes at Antigua midnight.
class VisitCodeScreen extends ConsumerWidget {
  const VisitCodeScreen({required this.businessId, super.key});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final codeAsync = ref.watch(visitCodeProvider(businessId));

    return Scaffold(
      backgroundColor: palette.surface,
      appBar: AppBar(title: const Text('Visit code')),
      body: codeAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.giant),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reviewErrorMessage(err),
                  textAlign: TextAlign.center,
                  style: AppText.bodyMedium.copyWith(color: palette.muted),
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(visitCodeProvider(businessId)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (code) => ListView(
          padding: const EdgeInsets.all(Insets.giant),
          children: [
            Text(
              'Customers scan this at the till to check in. A check-in lets '
              'them review you.',
              textAlign: TextAlign.center,
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.giant),
            Center(
              child: Container(
                padding: const EdgeInsets.all(Insets.huge),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Corners.xxl),
                  border: Border.all(color: palette.line),
                ),
                child: QrImageView(
                  data: visitQrPayload(businessId, code),
                  size: 240,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: Insets.giant),
            Text(
              'Or they type',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: palette.muted),
            ),
            Text(
              code,
              textAlign: TextAlign.center,
              style: AppText.numericLarge.copyWith(
                color: palette.ink,
                fontSize: 40,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: Insets.giant),
            Text(
              'A new code every day at midnight, so a photo of today’s code '
              'stops working tomorrow. Customers with no signal can still '
              'scan; it counts once they reconnect.',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

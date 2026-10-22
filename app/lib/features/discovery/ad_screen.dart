import 'dart:async';

import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:antigua_business_map/services/deals.dart';
import 'package:antigua_business_map/services/engagement_recorder.dart';
import 'package:antigua_business_map/widgets/offer_code_chip.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// The WhatsApp message for sharing an ad: what it is, who, and a link that
/// opens in a browser for someone without the app (Business Plan 2).
String adShareText(BusinessAd ad) => [
  if (ad.isOffer)
    'Deal at ${ad.businessName}: ${ad.title}'
  else
    '${ad.businessName}: ${ad.title}',
  if (ad.offerTerms case final terms? when terms.isNotEmpty) terms,
  AppConfig.publicAdUrl(ad.id),
].join('\n');

/// One advertisement or deal on its own page. Opening it counts as an ad
/// open for the business; claiming a deal gives the resident their own code
/// to show at the till.
class AdScreen extends ConsumerStatefulWidget {
  const AdScreen({required this.adId, super.key});

  final String adId;

  @override
  ConsumerState<AdScreen> createState() => _AdScreenState();
}

class _AdScreenState extends ConsumerState<AdScreen> {
  bool _counted = false;
  bool _claiming = false;

  void _countOpen(BusinessAd ad) {
    if (_counted) return;
    _counted = true;
    unawaited(
      ref
          .read(engagementRecorderProvider)
          .record(ad.businessId, EngagementKind.adOpen, adId: ad.id),
    );
  }

  Future<void> _share(BusinessAd ad) async {
    // Counted without waiting: a slow count must not delay the share.
    unawaited(
      ref
          .read(engagementRecorderProvider)
          .record(ad.businessId, EngagementKind.adShare, adId: ad.id),
    );
    await launchUrl(
      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(adShareText(ad))}'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _claim(BusinessAd ad) async {
    final deals = ref.read(dealsRepositoryProvider);
    if (!deals.isSignedIn) {
      await context.push('/sign-in');
      return;
    }
    setState(() => _claiming = true);
    try {
      await deals.claim(ad.id);
      ref.invalidate(myDealCodeProvider(ad.id));
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(dealErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ad = ref.watch(adProvider(widget.adId));

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(backgroundColor: palette.app),
      body: ad.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(adProvider(widget.adId)),
            child: const Text('Could not load this. Try again'),
          ),
        ),
        data: (ad) {
          if (ad == null || !ad.isLiveAt(DateTime.now())) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Insets.huge),
                child: Text(
                  'This advertisement has ended.',
                  style: AppText.bodyLarge.copyWith(color: palette.muted),
                ),
              ),
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) => _countOpen(ad));
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Insets.huge,
              0,
              Insets.huge,
              Insets.giant,
            ),
            children: [
              if (ad.imageUrl case final url? when url.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(Corners.xl),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: Insets.lg),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () => context.push('/listing/${ad.businessId}'),
                child: Text(
                  '${ad.businessName} ›',
                  style: AppText.labelLarge.copyWith(color: palette.red),
                ),
              ),
              Text(
                ad.title,
                style: AppText.displayMedium.copyWith(color: palette.ink),
              ),
              if (ad.body.isNotEmpty) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  ad.body,
                  style: AppText.bodyLarge.copyWith(color: palette.ink),
                ),
              ],
              if (ad.endsAt case final ends?) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  'Until ${DateFormat.MMMd().format(ends.toLocal())}',
                  style: AppText.caption.copyWith(color: palette.muted),
                ),
              ],
              if (ad.isOffer) ...[
                const SizedBox(height: Insets.xl),
                _DealPanel(
                  ad: ad,
                  claiming: _claiming,
                  onClaim: () => _claim(ad),
                ),
              ],
              const SizedBox(height: Insets.xl),
              OutlinedButton.icon(
                onPressed: () => _share(ad),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share on WhatsApp'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The offer's terms and the resident's own code, or the button to get one.
class _DealPanel extends ConsumerWidget {
  const _DealPanel({
    required this.ad,
    required this.claiming,
    required this.onClaim,
  });

  final BusinessAd ad;
  final bool claiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final code = ref.watch(myDealCodeProvider(ad.id)).value;

    return Container(
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        color: palette.goldBg,
        borderRadius: BorderRadius.circular(Corners.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dadliplug Deal',
            style: AppText.titleMedium.copyWith(color: palette.goldInk),
          ),
          if (ad.offerTerms case final terms? when terms.isNotEmpty)
            Text(
              terms,
              style: AppText.bodyMedium.copyWith(color: palette.goldInk),
            ),
          const SizedBox(height: Insets.md),
          if (code == null) ...[
            FilledButton(
              onPressed: claiming ? null : onClaim,
              child: Text(claiming ? 'Claiming…' : 'Claim this deal'),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'You get your own code to show at ${ad.businessName}. '
              'Or say ${ad.offerCode} at the till.',
              style: AppText.caption.copyWith(color: palette.goldInk),
            ),
          ] else ...[
            Text(
              'Show this at the till',
              textAlign: TextAlign.center,
              style: AppText.labelMedium.copyWith(color: palette.goldInk),
            ),
            const SizedBox(height: Insets.sm),
            Center(child: OfferCodeChip(code: code)),
            const SizedBox(height: Insets.md),
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(Insets.sm),
                child: QrImageView(data: code, size: 140),
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'Staff enter this code in Dadliplug to confirm your deal. It '
              'works once.',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: palette.goldInk),
            ),
          ],
        ],
      ),
    );
  }
}

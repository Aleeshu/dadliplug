import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:antigua_business_map/widgets/offer_code_chip.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Every running offer on the island, each with its till code.
///
/// Offers are what Featured businesses are paying to put in front of people,
/// so this lists only live ones: an expired code shown here would send
/// someone to a till that will not honour it.
class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final offersAsync = ref.watch(offersProvider);

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(title: const Text('Offers')),
      body: offersAsync.when(
        data: (offers) {
          if (offers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Insets.giant),
                child: Text(
                  'No offers running right now. Businesses post them from '
                  'their Ads tab.',
                  textAlign: TextAlign.center,
                  style: AppText.bodyMedium.copyWith(color: palette.muted),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(offersProvider);
              await ref.read(offersProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(Insets.huge),
              itemCount: offers.length,
              separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
              itemBuilder: (context, i) {
                final offer = offers[i];
                return Material(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(Corners.xxl),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Corners.xxl),
                    onTap: () => context.push('/listing/${offer.businessId}'),
                    child: Container(
                      padding: const EdgeInsets.all(Insets.huge),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Corners.xxl),
                        border: Border.all(color: palette.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (offer.imageUrl?.isNotEmpty ?? false) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(Corners.lg),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: CachedNetworkImage(
                                  imageUrl: offer.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                            const SizedBox(height: Insets.md),
                          ],
                          Row(
                            children: [
                              const OfferBadge(),
                              const SizedBox(width: Insets.md),
                              Expanded(
                                child: Text(
                                  offer.businessName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.labelMedium.copyWith(
                                    color: palette.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Insets.sm),
                          Text(
                            offer.title,
                            style: AppText.titleMedium.copyWith(
                              color: palette.ink,
                            ),
                          ),
                          if (offer.body.isNotEmpty) ...[
                            const SizedBox(height: Insets.xs),
                            Text(
                              offer.body,
                              style: AppText.bodyMedium.copyWith(
                                color: palette.ink,
                              ),
                            ),
                          ],
                          const SizedBox(height: Insets.md),
                          OfferCodeChip(code: offer.offerCode!),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (err, _) {
          debugPrint('Offers failed to load: $err');
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load offers.',
                  style: AppText.bodyMedium.copyWith(color: palette.muted),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(offersProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

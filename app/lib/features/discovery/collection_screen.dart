import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/services/prelaunch_repository.dart';
import 'package:antigua_business_map/widgets/business_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// One team-written collection, such as "Best pepperpot".
///
/// Says it is the team's pick: a collection is an editorial choice, not a
/// ranking, and a customer should be able to tell the two apart.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({required this.collectionId, super.key});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final collections = ref.watch(collectionsProvider);
    final all = ref.watch(businessListProvider).value ?? const [];

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(backgroundColor: palette.app),
      body: collections.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(collectionsProvider),
            child: const Text('Could not load this list. Try again'),
          ),
        ),
        data: (list) {
          final c = list.where((c) => c.id == collectionId).firstOrNull;
          if (c == null) {
            return Center(
              child: Text(
                'This list is no longer available.',
                style: AppText.bodyMedium.copyWith(color: palette.muted),
              ),
            );
          }
          final businesses = c.resolve(all);
          final shareText = [
            '${c.title}, on Dadliplug:',
            for (final b in businesses) '- ${b.name}, ${b.area}',
          ].join('\n');

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Insets.huge,
              0,
              Insets.huge,
              Insets.giant,
            ),
            children: [
              Text(
                c.title,
                style: AppText.displayMedium.copyWith(color: palette.ink),
              ),
              const SizedBox(height: Insets.xs),
              if (c.blurb.isNotEmpty)
                Text(
                  c.blurb,
                  style: AppText.bodyLarge.copyWith(color: palette.muted),
                ),
              const SizedBox(height: Insets.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Picked by the Dadliplug team. Not a ranking, and '
                      'nobody pays to be on it.',
                      style: AppText.caption.copyWith(color: palette.muted),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Share on WhatsApp',
                    icon: const Icon(Icons.share_outlined),
                    // WhatsApp, as listings and events share: most word of
                    // mouth on the island runs there (plan.md section 11).
                    onPressed: () => launchUrl(
                      Uri.parse(
                        'https://wa.me/?text=${Uri.encodeComponent(shareText)}',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.lg),
              for (final b in businesses) ...[
                BusinessListRow(business: b),
                const SizedBox(height: Insets.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

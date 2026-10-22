import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/feed.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// "Fresh in Antigua": every new ad, deal, special, announcement and this
/// week's events, newest first, filterable by category (Business Plan 2).
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  BusinessCategory? _category;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final feed = ref.watch(feedProvider(_category));

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Fresh in Antigua'),
        backgroundColor: palette.app,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: Insets.sm),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                ),
                for (final c in BusinessCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: Insets.sm),
                    child: ChoiceChip(
                      label: Text(c.shortLabel),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: feed.when(
              loading: () =>
                  Center(child: CircularProgressIndicator(color: palette.red)),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(feedProvider(_category)),
                  child: const Text('Could not load the feed. Try again'),
                ),
              ),
              data: (items) => items.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing new here yet.',
                        style: AppText.bodyMedium.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.refresh(feedProvider(_category).future),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(Insets.lg),
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Insets.md),
                        itemBuilder: (_, i) => FeedCard(item: items[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One post in the feed, on Home and the Feed screen.
class FeedCard extends StatelessWidget {
  const FeedCard({required this.item, super.key});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (label, color, bg) = switch (item.kind) {
      FeedKind.deal => ('DEAL', palette.red, palette.badBg),
      FeedKind.ad => ('NEW', palette.blue, palette.blueBg),
      FeedKind.special => ('TODAY', palette.warn, palette.warnBg),
      FeedKind.announcement => ('NEWS', palette.good, palette.goodBg),
      FeedKind.event => (
        DateFormat('EEE d MMM').format(item.at.toLocal()).toUpperCase(),
        palette.goldInk,
        palette.goldBg,
      ),
    };
    final image = item.imageUrl;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(Corners.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(Corners.xl),
        onTap: () => context.push(item.route),
        child: Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Corners.xl),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Corners.md),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: image != null && image.isNotEmpty
                      ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
                      : ColoredBox(
                          color: item.business.category.color,
                          child: Icon(
                            item.business.category.icon,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(Corners.sm),
                          ),
                          child: Text(
                            label,
                            style: AppText.caption.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (item.sponsored) ...[
                          const SizedBox(width: Insets.xs),
                          Text(
                            'Sponsored',
                            style: AppText.caption.copyWith(
                              color: palette.muted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.titleSmall.copyWith(color: palette.ink),
                    ),
                    Text(
                      item.business.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: palette.red),
                    ),
                    if (item.subtitle.isNotEmpty)
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(color: palette.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

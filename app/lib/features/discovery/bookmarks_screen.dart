import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Businesses the viewer has saved.
///
/// Same relationship as following, which is why they are not two lists. A
/// customer who bookmarks somewhere probably wants its announcements too, and
/// offering a separate "follow" switch would be a distinction without a
/// difference.
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({required this.isSignedIn, super.key});

  final bool isSignedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    if (!isSignedIn) {
      // A guest cannot bookmark. Saying so up front is better than showing an
      // empty list that looks like they have saved nothing.
      return Scaffold(
        backgroundColor: palette.app,
        appBar: AppBar(
          title: const Text('Bookmarks'),
          backgroundColor: palette.app,
          surfaceTintColor: Colors.transparent,
        ),
        body: _Message(
          icon: Icons.bookmark_border,
          title: 'Sign in to save places',
          body: 'You can browse as a guest. Sign in and you can keep the '
              'businesses you want to come back to.',
          actionLabel: 'Sign in',
          onAction: () => context.push('/sign-in'),
        ),
      );
    }

    return const _BookmarksBody();
  }
}

class _BookmarksBody extends ConsumerWidget {
  const _BookmarksBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idsAsync = ref.watch(followedBusinessIdsProvider);
    final businessesAsync = ref.watch(businessListProvider);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Bookmarks'),
        backgroundColor: palette.app,
        surfaceTintColor: Colors.transparent,
      ),
      body: idsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: palette.red),
        ),
        error: (error, _) => _Message(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load bookmarks',
          body: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(followedBusinessIdsProvider),
        ),
        data: (ids) {
          if (ids.isEmpty) {
            return const _Message(
              icon: Icons.bookmark_border,
              title: 'Nothing saved yet',
              body: 'Tap the bookmark on any business to keep it here and hear '
                  'its announcements.',
            );
          }

          return businessesAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: palette.red),
            ),
            error: (error, _) => _Message(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load bookmarks',
              body: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(businessListProvider),
            ),
            data: (all) {
              final saved = all.where((b) => ids.contains(b.id)).toList();

              if (saved.isEmpty) {
                // The ids are real but nothing came back. Almost always a
                // delisted business. Say that rather than showing nothing.
                return const _Message(
                  icon: Icons.info_outline,
                  title: 'Nothing to show',
                  body: 'The businesses you saved are no longer listed.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref
                    ..invalidate(followedBusinessIdsProvider)
                    ..invalidate(businessListProvider);
                  await ref.read(followedBusinessIdsProvider.future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(Insets.lg),
                  itemCount: saved.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
                  itemBuilder: (context, index) =>
                      _BusinessRow(business: saved[index], palette: palette),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BusinessRow extends ConsumerWidget {
  const _BusinessRow({required this.business, required this.palette});

  final Business business;
  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.push('/listing/${business.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name,
                    style: AppText.titleMedium.copyWith(color: palette.ink),
                  ),
                  const SizedBox(height: Insets.xxs),
                  Text(
                    business.category.shortLabel,
                    style: AppText.caption.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove bookmark',
            icon: Icon(Icons.bookmark, color: palette.red, size: 20),
            onPressed: () async {
              await ref
                  .read(businessContentRepositoryProvider)
                  .setFollow(businessId: business.id, follow: false);
              ref.invalidate(followedBusinessIdsProvider);
            },
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
        Icon(icon, size: 44, color: palette.muted),
        const SizedBox(height: Insets.lg),
        Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.displayMedium.copyWith(color: palette.ink),
          ),
        ),
        const SizedBox(height: Insets.sm),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
          ),
        ),
        if (onAction != null && actionLabel != null) ...[
          const SizedBox(height: Insets.lg),
          Center(
            child: FilledButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}
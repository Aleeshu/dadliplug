import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/reviews/reviews_section.dart';
import 'package:antigua_business_map/services/reviews_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The team's review moderation: reported and disputed reviews, and the
/// audit plan.md section 7 asks for — how selectively each business answers
/// review requests, and the reasons it gives for declining.
class ModerationScreen extends StatelessWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _Bar(),
        body: TabBarView(children: [_QueueTab(), _AuditTab()]),
      ),
    );
  }
}

class _Bar extends StatelessWidget implements PreferredSizeWidget {
  const _Bar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 48);

  @override
  Widget build(BuildContext context) => AppBar(
    title: const Text('Moderation'),
    bottom: const TabBar(
      tabs: [
        Tab(text: 'Queue'),
        Tab(text: 'Audit'),
      ],
    ),
  );
}

class _QueueTab extends ConsumerWidget {
  const _QueueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final async = ref.watch(moderationQueueProvider);

    return async.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: palette.red)),
      error: (err, _) => Center(child: Text(reviewErrorMessage(err))),
      data: (queue) {
        if (queue.isEmpty) {
          return Center(
            child: Text(
              'Nothing reported or disputed.',
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(Insets.lg),
          itemCount: queue.length,
          separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
          itemBuilder: (context, i) {
            final r = queue[i];
            return ReviewCard(
              review: r,
              trailing: Wrap(
                spacing: Insets.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    [
                      if (r.isReported) 'Reported',
                      if (r.isDisputed) 'Disputed by business',
                    ].join(' · '),
                    style: AppText.caption.copyWith(color: palette.warn),
                  ),
                  TextButton(
                    onPressed: () =>
                        _moderate(context, ref, r.id, remove: false),
                    child: const Text('Keep'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        _moderate(context, ref, r.id, remove: true),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _moderate(
    BuildContext context,
    WidgetRef ref,
    String id, {
    required bool remove,
  }) async {
    try {
      await ref.read(reviewsRepositoryProvider).moderate(id, remove: remove);
      ref.invalidate(moderationQueueProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(reviewErrorMessage(error))));
      }
    }
  }
}

class _AuditTab extends ConsumerWidget {
  const _AuditTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final async = ref.watch(reviewAuditProvider);

    return async.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: palette.red)),
      error: (err, _) => Center(child: Text(reviewErrorMessage(err))),
      data: (rows) => ListView.separated(
        padding: const EdgeInsets.all(Insets.lg),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, i) {
          final row = rows[i];
          final rate = row.approvalRate;
          // Watch a business that approves nearly everything it is asked
          // about while declining the rest with thin reasons.
          final selective = rate != null && row.requests >= 5 && rate >= 0.9;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.businessName,
                style: AppText.titleMedium.copyWith(color: palette.ink),
              ),
              const SizedBox(height: Insets.xxs),
              Text(
                '${row.checkedInVisits} QR check-ins · ${row.reviews} reviews · '
                '${row.requests == 0 ? 'no requests' : 'approved ${row.approved} of ${row.requests} requests'}',
                style: AppText.bodyMedium.copyWith(
                  color: selective ? palette.warn : palette.muted,
                ),
              ),
              for (final reason in row.recentDeclineReasons)
                Padding(
                  padding: const EdgeInsets.only(top: Insets.xxs),
                  child: Text(
                    'Declined: “$reason”',
                    style: AppText.caption.copyWith(color: palette.muted),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

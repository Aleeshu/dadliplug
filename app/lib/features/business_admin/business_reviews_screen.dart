import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/reviews/reviews_section.dart';
import 'package:antigua_business_map/models/review.dart';
import 'package:antigua_business_map/services/reviews_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The business's reviews: reply, dispute, and answer review requests.
///
/// Requests are the fallback for a business that cannot show a visit QR, and
/// the weaker path (plan.md section 7): declining needs a written reason,
/// which the team can audit.
class BusinessReviewsScreen extends StatelessWidget {
  const BusinessReviewsScreen({required this.businessId, super.key});

  final String businessId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (businessId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reviews')),
        body: Center(
          child: Text(
            'No listing linked to your account yet.',
            style: AppText.bodyMedium.copyWith(color: palette.muted),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: palette.app,
        appBar: AppBar(
          title: const Text('Reviews'),
          actions: [
            IconButton(
              tooltip: 'Visit QR for the till',
              icon: const Icon(Icons.qr_code_2),
              onPressed: () =>
                  context.push('/business/visit-code?business=$businessId'),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Reviews'),
              Tab(text: 'Requests'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ReviewsTab(businessId: businessId),
            _RequestsTab(businessId: businessId),
          ],
        ),
      ),
    );
  }
}

class _ReviewsTab extends ConsumerWidget {
  const _ReviewsTab({required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final async = ref.watch(reviewsForBusinessProvider(businessId));

    return async.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: palette.red)),
      error: (err, _) => Center(child: Text(reviewErrorMessage(err))),
      data: (reviews) {
        if (reviews.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.giant),
              child: Text(
                'No reviews yet. Show your visit QR at the till: customers '
                'who check in can review you.',
                textAlign: TextAlign.center,
                style: AppText.bodyMedium.copyWith(color: palette.muted),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(Insets.lg),
          itemCount: reviews.length,
          separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
          itemBuilder: (context, i) {
            final r = reviews[i];
            return ReviewCard(
              review: r,
              trailing: Wrap(
                spacing: Insets.sm,
                children: [
                  if (r.status == ReviewStatus.removed)
                    Text(
                      'Removed by the team',
                      style: AppText.caption.copyWith(color: palette.bad),
                    ),
                  TextButton(
                    onPressed: () => _reply(context, ref, r),
                    child: Text(r.hasReply ? 'Edit reply' : 'Reply'),
                  ),
                  TextButton(
                    onPressed: () => _dispute(context, ref, r),
                    child: Text(r.isDisputed ? 'Disputed' : 'Dispute'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _reply(BuildContext context, WidgetRef ref, Review r) async {
    final text = await askForText(
      context,
      title: 'Reply publicly',
      hint: 'Thank them, or put your side',
      action: 'Post reply',
      initial: r.reply,
    );
    if (text == null || !context.mounted) return;
    await _run(context, ref, () {
      return ref.read(reviewsRepositoryProvider).reply(r.id, text);
    });
  }

  Future<void> _dispute(BuildContext context, WidgetRef ref, Review r) async {
    await _run(context, ref, () {
      return ref
          .read(reviewsRepositoryProvider)
          .setDisputed(r.id, disputed: !r.isDisputed);
    });
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(reviewsForBusinessProvider(businessId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(reviewErrorMessage(error))));
      }
    }
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab({required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final async = ref.watch(reviewRequestsProvider(businessId));

    return async.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: palette.red)),
      error: (err, _) => Center(child: Text(reviewErrorMessage(err))),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.giant),
              child: Text(
                'No requests. Customers who check in with your QR do not need '
                'one.',
                textAlign: TextAlign.center,
                style: AppText.bodyMedium.copyWith(color: palette.muted),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(Insets.lg),
          itemCount: requests.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, i) {
            final req = requests[i];
            return ListTile(
              title: Text(
                'Request ${DateFormat.yMMMd().format(req.requestedAt.toLocal())}',
              ),
              subtitle: Text(
                req.status == 'declined'
                    ? 'Declined: ${req.declineReason ?? ''}'
                    : req.status == 'approved'
                    ? 'Approved'
                    : 'Waiting for you',
              ),
              trailing: req.status != 'pending'
                  ? null
                  : Wrap(
                      spacing: Insets.xs,
                      children: [
                        TextButton(
                          onPressed: () =>
                              _respond(context, ref, req.id, approve: false),
                          child: const Text('Decline'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              _respond(context, ref, req.id, approve: true),
                          child: const Text('Approve'),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    String id, {
    required bool approve,
  }) async {
    String? reason;
    if (!approve) {
      // plan.md section 7: a written reason, so a pattern of thin ones is
      // visible to the team.
      reason = await askForText(
        context,
        title: 'Why decline?',
        hint: 'e.g. We have no record of this visit',
        action: 'Decline',
        minLength: 5,
      );
      if (reason == null) return;
    }
    try {
      await ref
          .read(reviewsRepositoryProvider)
          .respond(id, approve: approve, reason: reason);
      ref.invalidate(reviewRequestsProvider(businessId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(reviewErrorMessage(error))));
      }
    }
  }
}

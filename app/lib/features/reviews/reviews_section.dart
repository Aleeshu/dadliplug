import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/reviews/check_in_sheet.dart';
import 'package:antigua_business_map/models/review.dart';
import 'package:antigua_business_map/services/prelaunch_repository.dart';
import 'package:antigua_business_map/services/reviews_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Reviews on a listing, and the way to leave one.
///
/// Every review shown passed the visit gate, and each says so. The action
/// above them depends on where the viewer stands: sign in, check in, write,
/// or nothing (already reviewed).
class ReviewsSection extends ConsumerWidget {
  const ReviewsSection({
    required this.businessId,
    required this.acceptsReviews,
    super.key,
  });

  final String businessId;
  final bool acceptsReviews;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final reviewsAsync = ref.watch(reviewsForBusinessProvider(businessId));
    final eligibility = ref.watch(reviewEligibilityProvider(businessId)).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reviews',
          style: AppText.titleLarge.copyWith(
            color: palette.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Insets.xs),
        Text(
          'Only from customers who checked in at the till.',
          style: AppText.caption.copyWith(color: palette.muted),
        ),
        const SizedBox(height: Insets.md),
        if (!acceptsReviews)
          Text(
            'This business does not take reviews.',
            style: AppText.bodyMedium.copyWith(color: palette.muted),
          )
        else
          _Action(businessId: businessId, eligibility: eligibility),
        const SizedBox(height: Insets.lg),
        reviewsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (err, _) => Text(
            'Could not load reviews.',
            style: AppText.bodyMedium.copyWith(color: palette.muted),
          ),
          data: (all) {
            // Reviews from people this viewer blocked are hidden from them
            // (App Store guideline 1.2). Still counted in the rating.
            final blocked =
                ref.watch(blockedUsersProvider).value ?? const <String>{};
            final visible = all
                .where((r) => r.isVisible && !blocked.contains(r.userId))
                .toList();
            if (visible.isEmpty) {
              return Text(
                'No reviews yet.',
                style: AppText.bodyMedium.copyWith(color: palette.muted),
              );
            }
            return Column(
              children: [
                for (final r in visible) ...[
                  ReviewCard(review: r),
                  const SizedBox(height: Insets.md),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Action extends ConsumerWidget {
  const _Action({required this.businessId, required this.eligibility});

  final String businessId;
  final ReviewEligibility? eligibility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return switch (eligibility) {
      null => const SizedBox.shrink(),
      ReviewEligibility.signedOut => OutlinedButton.icon(
        onPressed: () => context.push('/sign-in'),
        icon: const Icon(Icons.login, size: 18),
        label: const Text('Sign in to review'),
      ),
      ReviewEligibility.needsVisit => OutlinedButton.icon(
        onPressed: () => CheckInSheet.show(context, businessId: businessId),
        icon: const Icon(Icons.qr_code_scanner, size: 18),
        label: const Text('Check in to review'),
      ),
      ReviewEligibility.canReview => FilledButton.icon(
        onPressed: () => WriteReviewSheet.show(context, businessId),
        icon: const Icon(Icons.rate_review_outlined, size: 18),
        label: const Text('Write a review'),
      ),
      ReviewEligibility.alreadyReviewed => Text(
        'Thanks — you reviewed this business.',
        style: AppText.bodyMedium.copyWith(color: palette.good),
      ),
    };
  }
}

/// One review: stars, text, date, the business's reply, and a report link.
class ReviewCard extends ConsumerWidget {
  const ReviewCard({required this.review, this.trailing, super.key});

  final Review review;

  /// Owner or team controls, in place of the report link.
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.xl),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= review.rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 18,
                  color: palette.gold,
                ),
              const SizedBox(width: Insets.sm),
              Icon(Icons.verified, size: 14, color: palette.good),
              const SizedBox(width: 2),
              Text(
                'Verified visit',
                style: AppText.caption.copyWith(color: palette.good),
              ),
              const Spacer(),
              Text(
                DateFormat.yMMMd().format(review.createdAt.toLocal()),
                style: AppText.caption.copyWith(color: palette.muted),
              ),
            ],
          ),
          if (review.body.isNotEmpty) ...[
            const SizedBox(height: Insets.sm),
            Text(
              review.body,
              style: AppText.bodyMedium.copyWith(color: palette.ink),
            ),
          ],
          if (review.hasReply) ...[
            const SizedBox(height: Insets.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(
                color: palette.app,
                borderRadius: BorderRadius.circular(Corners.md),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Reply from the business: ',
                      style: AppText.labelMedium.copyWith(color: palette.ink),
                    ),
                    TextSpan(text: review.reply),
                  ],
                ),
                style: AppText.bodyMedium.copyWith(color: palette.ink),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child:
                trailing ??
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Not on your own review, and not signed out: a block
                    // belongs to an account.
                    if (ref.read(prelaunchRepositoryProvider).currentUserId
                        case final me? when me != review.userId)
                      TextButton(
                        onPressed: () => _block(context, ref),
                        child: Text(
                          'Hide this person',
                          style: AppText.caption.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => _report(context, ref),
                      child: Text(
                        'Report',
                        style: AppText.caption.copyWith(color: palette.muted),
                      ),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Hide this person's reviews?"),
        content: const Text(
          'You will no longer see reviews they write, on any listing. '
          'If a review is abusive, report it too so the team can act.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hide'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(prelaunchRepositoryProvider).block(review.userId);
      ref.invalidate(blockedUsersProvider);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not hide them. Try again.')),
        );
      }
    }
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final reason = await askForText(
      context,
      title: 'Report this review',
      hint: 'What is wrong with it?',
      action: 'Report',
    );
    if (reason == null || !context.mounted) return;
    try {
      await ref.read(reviewsRepositoryProvider).report(review.id, reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reported. The team will look at it.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(reviewErrorMessage(error))));
      }
    }
  }
}

/// A one-field dialog. Null when cancelled or left blank.
Future<String?> askForText(
  BuildContext context, {
  required String title,
  required String hint,
  required String action,
  int minLength = 1,
  String? initial,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: controller.text.trim().length < minLength
                ? null
                : () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(action),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}

/// Stars and words. Only reachable once the viewer has checked in.
class WriteReviewSheet extends ConsumerStatefulWidget {
  const WriteReviewSheet({required this.businessId, super.key});

  final String businessId;

  static Future<void> show(BuildContext context, String businessId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => WriteReviewSheet(businessId: businessId),
      );

  @override
  ConsumerState<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<WriteReviewSheet> {
  final _body = TextEditingController();
  int _rating = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(reviewsRepositoryProvider)
          .submitReview(
            businessId: widget.businessId,
            rating: _rating,
            body: _body.text,
          );
      ref
        ..invalidate(reviewsForBusinessProvider(widget.businessId))
        ..invalidate(reviewEligibilityProvider(widget.businessId));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = reviewErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
            'Your review',
            style: AppText.titleLarge.copyWith(color: palette.ink),
          ),
          const SizedBox(height: Insets.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                  iconSize: 36,
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: palette.gold,
                  ),
                ),
            ],
          ),
          TextField(
            controller: _body,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: 'What was it like? (optional)',
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: AppText.bodyMedium.copyWith(color: palette.red),
            ),
          const SizedBox(height: Insets.md),
          FilledButton(
            onPressed: _rating == 0 || _busy ? null : _submit,
            child: Text(_busy ? 'Posting…' : 'Post review'),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'One review per business. It shows as a verified visit.',
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

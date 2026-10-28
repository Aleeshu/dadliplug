import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/services/business_content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The heart on a business card or row: save it, or unsave it. Saving is
/// the same as following, so the business's announcements reach Notices
/// (plan.md 4). Signed out, it asks the customer to sign in.
class SaveHeart extends ConsumerStatefulWidget {
  const SaveHeart({required this.businessId, this.size = 22, super.key});

  final String businessId;
  final double size;

  @override
  ConsumerState<SaveHeart> createState() => _SaveHeartState();
}

class _SaveHeartState extends ConsumerState<SaveHeart> {
  bool _busy = false;

  Future<void> _toggle(bool saved) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(businessContentRepositoryProvider)
          .setFollow(businessId: widget.businessId, follow: !saved);
      ref.invalidate(followedBusinessIdsProvider);
    } on NotSignedInException {
      if (mounted) await context.push<void>('/sign-in');
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save. Check your connection.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final saved =
        ref
            .watch(followedBusinessIdsProvider)
            .value
            ?.contains(widget.businessId) ??
        false;
    return IconButton(
      tooltip: saved ? 'Remove from Saved' : 'Save',
      visualDensity: VisualDensity.compact,
      onPressed: _busy ? null : () => _toggle(saved),
      icon: Icon(
        saved ? Icons.favorite : Icons.favorite_border,
        size: widget.size,
        color: saved ? const Color(0xFFE53950) : palette.muted,
      ),
    );
  }
}

import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/discovery/community_board_screen.dart';
import 'package:antigua_business_map/services/community_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The team's side of the community board: approve or reject what is
/// waiting, deal with reports, and mark paid posts as Featured.
class BoardModerationTab extends ConsumerWidget {
  const BoardModerationTab({super.key});

  Future<String?> _reason(BuildContext context, String title) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Reason (the poster sees this)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, c.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ).whenComplete(c.dispose);
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    CommunityPost post,
    String status,
  ) async {
    String? note;
    if (status != 'live') {
      note = await _reason(
        context,
        status == 'rejected' ? 'Reject post' : 'Remove post',
      );
      if (note == null) return;
    }
    try {
      await ref
          .read(communityBoardRepositoryProvider)
          .decide(post.id, status, note: note);
      ref
        ..invalidate(pendingBoardProvider)
        ..invalidate(reportedBoardProvider)
        ..invalidate(liveBoardProvider);
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(boardErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final pending = ref.watch(pendingBoardProvider).value ?? const [];
    final reported = ref.watch(reportedBoardProvider).value ?? const [];
    final live = ref.watch(liveBoardProvider).value ?? const [];

    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: Insets.lg, bottom: Insets.sm),
      child: Text(text, style: AppText.sectionLabel),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(pendingBoardProvider)
          ..invalidate(reportedBoardProvider)
          ..invalidate(liveBoardProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: [
          header('WAITING FOR APPROVAL (${pending.length})'),
          if (pending.isEmpty)
            Text(
              'Nothing waiting.',
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
          for (final p in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: PostCard(
                post: p,
                trailing: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _decide(context, ref, p, 'rejected'),
                      child: const Text('Reject'),
                    ),
                    FilledButton(
                      onPressed: () => _decide(context, ref, p, 'live'),
                      child: const Text('Approve'),
                    ),
                  ],
                ),
              ),
            ),
          header('REPORTED (${reported.length})'),
          if (reported.isEmpty)
            Text(
              'No reports.',
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
          for (final (p, reasons) in reported)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: PostCard(
                post: p,
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in reasons)
                      Text(
                        'Reported: “$r”',
                        style: AppText.caption.copyWith(color: palette.bad),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => _decide(context, ref, p, 'removed'),
                        child: const Text('Remove'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          header('LIVE (${live.length})'),
          for (final p in live)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: PostCard(
                post: p,
                trailing: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Featured',
                      style: AppText.caption.copyWith(color: palette.muted),
                    ),
                    Switch(
                      value: p.featured,
                      onChanged: (v) async {
                        await ref
                            .read(communityBoardRepositoryProvider)
                            .setFeatured(p.id, featured: v);
                        ref.invalidate(liveBoardProvider);
                      },
                    ),
                    TextButton(
                      onPressed: () => _decide(context, ref, p, 'removed'),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

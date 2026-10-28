import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/services/community_board.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:url_launcher/url_launcher.dart';

/// The community bulletin board (Business Plan 2): Jobs, For Sale,
/// Community Notices and Business Opportunities, plus the businesses' own
/// announcements one tap away. Every post was approved by the team.
class CommunityBoardScreen extends ConsumerStatefulWidget {
  const CommunityBoardScreen({super.key});

  @override
  ConsumerState<CommunityBoardScreen> createState() =>
      _CommunityBoardScreenState();
}

class _CommunityBoardScreenState extends ConsumerState<CommunityBoardScreen> {
  PostKind? _kind;

  void _newPost() {
    if (ref.read(communityBoardRepositoryProvider).currentUserId == null) {
      context.push('/sign-in');
      return;
    }
    context.push('/board/new');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final posts = ref.watch(liveBoardProvider);

    Widget chip(
      String label, {
      required bool selected,
      required VoidCallback onTap,
    }) => Padding(
      padding: const EdgeInsets.only(right: Insets.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Bulletin Board'),
        backgroundColor: palette.app,
        actions: [
          TextButton(
            onPressed: () => context.push('/board/mine'),
            child: const Text('My posts'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'board_new',
        onPressed: _newPost,
        icon: const Icon(Icons.add),
        label: const Text('Post'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              children: [
                chip(
                  'All',
                  selected: _kind == null,
                  onTap: () => setState(() => _kind = null),
                ),
                for (final k in PostKind.values)
                  chip(
                    k.label,
                    selected: _kind == k,
                    onTap: () => setState(() => _kind = k),
                  ),
                chip(
                  'Business news',
                  selected: false,
                  onTap: () => context.push('/announcements'),
                ),
              ],
            ),
          ),
          Expanded(
            child: posts.when(
              loading: () =>
                  Center(child: CircularProgressIndicator(color: palette.red)),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(liveBoardProvider),
                  child: const Text('Could not load the board. Try again'),
                ),
              ),
              data: (all) {
                final shown = [
                  for (final p in all)
                    if (_kind == null || p.kind == _kind) p,
                ];
                if (shown.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.huge),
                      child: Text(
                        'Nothing here yet. Selling something, hiring, or '
                        'have news for the community? Post it.',
                        textAlign: TextAlign.center,
                        style: AppText.bodyMedium.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(liveBoardProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      Insets.sm,
                      Insets.lg,
                      96,
                    ),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Insets.sm),
                    itemBuilder: (_, i) => PostCard(post: shown[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One post on the board.
class PostCard extends StatelessWidget {
  const PostCard({required this.post, this.trailing, super.key});

  final CommunityPost post;

  /// Team or owner controls, shown under the post.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final image = post.imageUrl;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(Corners.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(Corners.xl),
        onTap: () => PostSheet.show(context, post),
        child: Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Corners.xl),
            border: Border.all(
              color: post.featured ? palette.gold : palette.line,
              width: post.featured ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (image != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Corners.md),
                      child: CachedNetworkImage(
                        imageUrl: image,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const SizedBox(
                          width: 72,
                          height: 72,
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(post.kind.icon, size: 14, color: palette.red),
                            const SizedBox(width: 4),
                            Text(
                              post.kind.label.toUpperCase(),
                              style: AppText.caption.copyWith(
                                color: palette.red,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            if (post.featured) ...[
                              const SizedBox(width: Insets.sm),
                              Text(
                                'Featured',
                                style: AppText.caption.copyWith(
                                  color: palette.goldInk,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          post.title,
                          style: AppText.titleSmall.copyWith(
                            color: palette.ink,
                          ),
                        ),
                        Text(
                          post.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                            color: palette.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (post.priceEc != null)
                              'EC\$${post.priceEc!.toStringAsFixed(post.priceEc! % 1 == 0 ? 0 : 2)}',
                            if (post.area.isNotEmpty) post.area,
                            DateFormat.MMMd().format(post.createdAt.toLocal()),
                          ].join(' · '),
                          style: AppText.caption.copyWith(
                            color: palette.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// A post in full, with ways to get in touch and to report it.
class PostSheet extends ConsumerWidget {
  const PostSheet({required this.post, super.key});

  final CommunityPost post;

  static Future<void> show(BuildContext context, CommunityPost post) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => PostSheet(post: post),
      );

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Report this post'),
        content: TextField(
          controller: reason,
          maxLength: 300,
          decoration: const InputDecoration(
            hintText: 'Scam, misleading, offensive…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(communityBoardRepositoryProvider).report(post.id, text);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reported. The team will look at it.')),
        );
      }
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
    final me = ref.read(communityBoardRepositoryProvider).currentUserId;
    final digits = post.contactDigits;
    final image = post.imageUrl;

    return Padding(
      padding: const EdgeInsets.all(Insets.huge),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              post.kind.label.toUpperCase(),
              style: AppText.sectionLabel.copyWith(color: palette.red),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              post.title,
              style: AppText.titleLarge.copyWith(color: palette.ink),
            ),
            if (image != null) ...[
              const SizedBox(height: Insets.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(Corners.md),
                child: CachedNetworkImage(
                  imageUrl: image,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: Insets.md),
            Text(
              post.body,
              style: AppText.bodyLarge.copyWith(color: palette.ink),
            ),
            const SizedBox(height: Insets.md),
            Text(
              [
                if (post.priceEc != null)
                  'EC\$${post.priceEc!.toStringAsFixed(2)}',
                if (post.area.isNotEmpty) post.area,
                'Posted ${DateFormat.yMMMd().format(post.createdAt.toLocal())}',
              ].join(' · '),
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.lg),
            if (digits.length >= 7)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://wa.me/$digits?text=${Uri.encodeComponent('Hi, I saw "${post.title}" on the Dadliplug board.')}',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          launchUrl(Uri(scheme: 'tel', path: post.contact)),
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: const Text('Call'),
                    ),
                  ),
                ],
              )
            else
              Text(
                'Contact: ${post.contact}',
                style: AppText.bodyMedium.copyWith(color: palette.ink),
              ),
            const SizedBox(height: Insets.md),
            Text(
              'Posts are checked by the Dadliplug team before they appear, '
              'but meet in public and never pay in advance for something '
              'you have not seen.',
              style: AppText.caption.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.sm),
            if (me != null && me == post.authorId)
              TextButton.icon(
                onPressed: () async {
                  await ref
                      .read(communityBoardRepositoryProvider)
                      .remove(post.id);
                  ref
                    ..invalidate(liveBoardProvider)
                    ..invalidate(myBoardPostsProvider);
                  if (context.mounted) Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(foregroundColor: palette.bad),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Take my post down'),
              )
            else if (me != null && post.isLive)
              TextButton.icon(
                onPressed: () => _report(context, ref),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Report'),
              ),
          ],
        ),
      ),
    );
  }
}

/// The signed-in person's posts and where each one stands.
class MyBoardPostsScreen extends ConsumerWidget {
  const MyBoardPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final posts = ref.watch(myBoardPostsProvider);
    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('My posts'),
        backgroundColor: palette.app,
      ),
      body: posts.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (_, _) =>
            const Center(child: Text('Could not load your posts.')),
        data: (list) => list.isEmpty
            ? Center(
                child: Text(
                  'You have not posted yet.',
                  style: AppText.bodyMedium.copyWith(color: palette.muted),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(Insets.lg),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
                itemBuilder: (_, i) {
                  final p = list[i];
                  final (label, color) = switch (p.status) {
                    'live' => (
                      'Live until ${DateFormat.MMMd().format(p.expiresAt.toLocal())}',
                      palette.good,
                    ),
                    'pending' => ('Waiting for the team', palette.warn),
                    'rejected' => (
                      'Not approved${p.statusNote == null ? '' : ': ${p.statusNote}'}',
                      palette.bad,
                    ),
                    _ => (
                      'Removed${p.statusNote == null ? '' : ': ${p.statusNote}'}',
                      palette.bad,
                    ),
                  };
                  return PostCard(
                    post: p,
                    trailing: Padding(
                      padding: const EdgeInsets.only(top: Insets.sm),
                      child: Text(
                        label,
                        style: AppText.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Write a post. It goes to the team, then onto the board.
class NewBoardPostScreen extends ConsumerStatefulWidget {
  const NewBoardPostScreen({super.key});

  @override
  ConsumerState<NewBoardPostScreen> createState() => _NewBoardPostScreenState();
}

class _NewBoardPostScreenState extends ConsumerState<NewBoardPostScreen> {
  final _form = GlobalKey<FormState>();
  PostKind _kind = PostKind.forSale;
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _price = TextEditingController();
  final _area = TextEditingController();
  final _contact = TextEditingController();
  String? _imageUrl;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _body, _price, _area, _contact]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (file == null) return;
    final uid = ref.read(communityBoardRepositoryProvider).currentUserId;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      final path = 'board/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storage = Supabase.instance.client.storage.from('media');
      await storage.uploadBinary(path, await file.readAsBytes());
      if (mounted) setState(() => _imageUrl = storage.getPublicUrl(path));
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload the photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(communityBoardRepositoryProvider)
          .submit(
            kind: _kind,
            title: _title.text,
            body: _body.text,
            contact: _contact.text,
            area: _area.text,
            priceEc: double.tryParse(_price.text.trim()),
            imageUrl: _imageUrl,
          );
      ref.invalidate(myBoardPostsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sent to the team. It appears once approved, usually the same day.',
          ),
        ),
      );
    } on Object catch (e) {
      if (mounted) setState(() => _error = boardErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    String? need(String? v, int min) =>
        (v ?? '').trim().length < min ? 'A little more, please' : null;

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('New post'),
        backgroundColor: palette.app,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            0,
            Insets.lg,
            Insets.giant,
          ),
          children: [
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final k in PostKind.values)
                  ChoiceChip(
                    avatar: Icon(k.icon, size: 16),
                    label: Text(k.label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _title,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => need(v, 3),
            ),
            TextFormField(
              controller: _body,
              maxLength: 1000,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Details',
                hintText: 'What, condition, when, any requirements',
              ),
              validator: (v) => need(v, 10),
            ),
            if (_kind == PostKind.forSale || _kind == PostKind.job)
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _kind == PostKind.job
                      ? r'Pay in EC$ (optional)'
                      : r'Price in EC$ (optional)',
                ),
              ),
            TextFormField(
              controller: _area,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Area (optional)',
                hintText: "e.g. St. John's",
              ),
            ),
            TextFormField(
              controller: _contact,
              maxLength: 60,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone or WhatsApp',
                hintText: '+1 268 …',
              ),
              validator: (v) => need(v, 5),
            ),
            const SizedBox(height: Insets.sm),
            if (_imageUrl case final url?)
              ClipRRect(
                borderRadius: BorderRadius.circular(Corners.md),
                child: CachedNetworkImage(
                  imageUrl: url,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _busy ? null : _addPhoto,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Add a photo (optional)'),
              ),
            const SizedBox(height: Insets.md),
            Text(
              'The team checks every post before it appears. No scams, '
              'nothing illegal, nothing misleading. Posts last 30 days.',
              style: AppText.caption.copyWith(color: palette.muted),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: Insets.sm),
                child: Text(
                  _error!,
                  style: AppText.bodyMedium.copyWith(color: palette.bad),
                ),
              ),
            const SizedBox(height: Insets.md),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Sending…' : 'Send for approval'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/services/prelaunch_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The Antigua and Barbuda Meteorological Service, the link a storm notice
/// should carry (plan.md 14c). Prefilled, not forced.
const kMetServiceUrl = 'https://www.antiguamet.com/';

/// What the team publishes beyond listings: notices across the top of the
/// app, and curated collections on Home.
class ContentScreen extends StatelessWidget {
  const ContentScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      backgroundColor: context.palette.app,
      appBar: AppBar(
        title: const Text('Notices and collections'),
        backgroundColor: context.palette.app,
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Notices'),
            Tab(text: 'Collections'),
          ],
        ),
      ),
      body: const TabBarView(children: [_NoticesTab(), _CollectionsTab()]),
    ),
  );
}

void _snack(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

// ---------------------------------------------------------------------------
// Notices
// ---------------------------------------------------------------------------

class _NoticesTab extends ConsumerWidget {
  const _NoticesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final notices = ref.watch(allNoticesProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: palette.app,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new_notice',
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => const _NoticeForm(),
        ),
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('New notice'),
      ),
      body: notices.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(allNoticesProvider),
            child: const Text('Could not load notices. Try again'),
          ),
        ),
        data: (list) => list.isEmpty
            ? Center(
                child: Text(
                  'No notices. Post one when a storm is coming or the island '
                  'shuts down.',
                  textAlign: TextAlign.center,
                  style: AppText.bodyMedium.copyWith(color: palette.muted),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.lg,
                  Insets.lg,
                  96,
                ),
                children: [
                  for (final n in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        n.isStorm ? Icons.storm : Icons.campaign_outlined,
                        color: n.isLiveAt(now) ? palette.bad : palette.muted,
                      ),
                      title: Text(n.title),
                      subtitle: Text(
                        n.isLiveAt(now)
                            ? (n.endsAt == null
                                  ? 'Live until ended'
                                  : 'Live until ${DateFormat.MMMd().add_jm().format(n.endsAt!.toLocal())}')
                            : 'Ended',
                      ),
                      trailing: n.isLiveAt(now)
                          ? TextButton(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(prelaunchRepositoryProvider)
                                      .endNotice(n.id);
                                  ref
                                    ..invalidate(allNoticesProvider)
                                    ..invalidate(liveNoticesProvider);
                                } on Object {
                                  if (context.mounted) {
                                    _snack(context, 'Could not end it.');
                                  }
                                }
                              },
                              child: const Text('End now'),
                            )
                          : null,
                    ),
                ],
              ),
      ),
    );
  }
}

class _NoticeForm extends ConsumerStatefulWidget {
  const _NoticeForm();

  @override
  ConsumerState<_NoticeForm> createState() => _NoticeFormState();
}

class _NoticeFormState extends ConsumerState<_NoticeForm> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _link = TextEditingController(text: kMetServiceUrl);
  bool _storm = true;
  int? _hours = 48;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final link = _link.text.trim();
    if (_title.text.trim().isEmpty) {
      _snack(context, 'Give the notice a title.');
      return;
    }
    if (link.isNotEmpty && !link.startsWith('https://')) {
      _snack(context, 'Links must start with https://');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(prelaunchRepositoryProvider)
          .postNotice(
            isStorm: _storm,
            title: _title.text,
            body: _body.text,
            linkUrl: link,
            endsAt: _hours == null
                ? null
                : DateTime.now().add(Duration(hours: _hours!)),
          );
      ref
        ..invalidate(allNoticesProvider)
        ..invalidate(liveNoticesProvider);
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() => _busy = false);
        _snack(context, 'Could not post the notice.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Insets.huge,
        right: Insets.huge,
        top: Insets.huge,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Insets.huge,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New notice',
              style: AppText.titleLarge.copyWith(color: context.palette.ink),
            ),
            const SizedBox(height: Insets.md),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Storm'),
                  icon: Icon(Icons.storm),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('General'),
                  icon: Icon(Icons.campaign_outlined),
                ),
              ],
              selected: {_storm},
              onSelectionChanged: (s) => setState(() {
                _storm = s.first;
                if (!_storm && _link.text == kMetServiceUrl) _link.clear();
                if (_storm && _link.text.isEmpty) _link.text = kMetServiceUrl;
              }),
            ),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _title,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Tropical storm watch: check before you travel',
              ),
            ),
            TextField(
              controller: _body,
              maxLength: 400,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                hintText: 'Many businesses will close early today.',
              ),
            ),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Link (optional, https)',
              ),
            ),
            const SizedBox(height: Insets.md),
            Wrap(
              spacing: Insets.sm,
              children: [
                for (final (label, hours) in const [
                  ('12 hours', 12),
                  ('2 days', 48),
                  ('1 week', 168),
                  ('Until I end it', null),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _hours == hours,
                    onSelected: (_) => setState(() => _hours = hours),
                  ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            FilledButton(
              onPressed: _busy ? null : _post,
              child: Text(_busy ? 'Posting…' : 'Post to everyone'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collections
// ---------------------------------------------------------------------------

class _CollectionsTab extends ConsumerWidget {
  const _CollectionsTab();

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final blurb = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New collection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Best pepperpot',
              ),
            ),
            TextField(
              controller: blurb,
              maxLength: 300,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'One line about it'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    final t = title.text.trim();
    final b = blurb.text;
    title.dispose();
    blurb.dispose();
    if (ok != true || t.isEmpty) return;
    try {
      await ref.read(prelaunchRepositoryProvider).createCollection(t, b);
      ref.invalidate(collectionsProvider);
    } on Object {
      if (context.mounted) _snack(context, 'Could not create it.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final collections = ref.watch(collectionsProvider);

    return Scaffold(
      backgroundColor: palette.app,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new_collection',
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.playlist_add),
        label: const Text('New collection'),
      ),
      body: collections.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(collectionsProvider),
            child: const Text('Could not load collections. Try again'),
          ),
        ),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.lg,
            Insets.lg,
            96,
          ),
          children: [
            Text(
              'Team-written lists on Home. Local knowledge Google does not '
              'have, and easy to share on WhatsApp.',
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
            for (final c in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(c.title),
                subtitle: Text(
                  '${c.businessIds.length} listings · '
                  '${c.published ? 'Published' : 'Draft'}',
                ),
                trailing: Switch(
                  value: c.published,
                  onChanged: (v) async {
                    try {
                      await ref
                          .read(prelaunchRepositoryProvider)
                          .setPublished(c.id, published: v);
                      ref.invalidate(collectionsProvider);
                    } on Object {
                      if (context.mounted) _snack(context, 'Could not save.');
                    }
                  },
                ),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => _CollectionEditor(collection: c),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tick the listings in a collection; the order is the order ticked.
class _CollectionEditor extends ConsumerStatefulWidget {
  const _CollectionEditor({required this.collection});

  final Collection collection;

  @override
  ConsumerState<_CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends ConsumerState<_CollectionEditor> {
  late final List<String> _ids = [...widget.collection.businessIds];
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(prelaunchRepositoryProvider)
          .setItems(widget.collection.id, _ids);
      ref.invalidate(collectionsProvider);
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() => _busy = false);
        _snack(context, 'Could not save the collection.');
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${widget.collection.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(prelaunchRepositoryProvider)
          .deleteCollection(widget.collection.id);
      ref.invalidate(collectionsProvider);
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) _snack(context, 'Could not delete it.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final all = [
      ...ref.watch(businessListProvider).value ?? const <Business>[],
    ]..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      children: [
        ListTile(
          title: Text(
            widget.collection.title,
            style: AppText.titleLarge.copyWith(color: palette.ink),
          ),
          subtitle: Text('${_ids.length} selected, in the order ticked'),
          trailing: IconButton(
            tooltip: 'Delete collection',
            icon: Icon(Icons.delete_outline, color: palette.bad),
            onPressed: _delete,
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final b in all)
                CheckboxListTile(
                  value: _ids.contains(b.id),
                  title: Text(b.name),
                  subtitle: Text('${b.category.label} · ${b.area}'),
                  secondary: _ids.contains(b.id)
                      ? Text('${_ids.indexOf(b.id) + 1}')
                      : null,
                  onChanged: (v) => setState(
                    () => (v ?? false) ? _ids.add(b.id) : _ids.remove(b.id),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/listing_filter_service.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/services/viewer_location.dart';
import 'package:antigua_business_map/widgets/business_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Search and sort across every visible listing.
///
/// Order defaults to the earned ranking, which is the only thing that governs
/// search order: Featured buys the Featured page, not a higher place here
/// (plan.md section 15).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    this.initialSort = ListingSort.ranked,
    this.initialCategory,
    this.location = const ViewerLocation(),
    super.key,
  });

  /// `/search?sort=nearest` opens straight into "near me".
  final ListingSort initialSort;

  /// `/search?category=food` opens filtered to one category.
  final BusinessCategory? initialCategory;

  /// Injected so tests do not touch the platform location plugin.
  final ViewerLocation location;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  var _query = const ListingQuery();

  /// The viewer's position, held only while this screen is open.
  GeoPoint? _origin;
  bool _locating = false;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory case final category?) {
      _query = _query.copyWith(categories: {category});
    }
    if (widget.initialSort == ListingSort.nearest) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _setSort(ListingSort.nearest),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _setSort(ListingSort sort) async {
    setState(() {
      _query = _query.copyWith(sort: sort);
      _locationMessage = null;
    });
    if (sort != ListingSort.nearest || _origin != null) return;

    setState(() => _locating = true);
    final result = await widget.location.current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      switch (result) {
        case LocationFound(:final point):
          _origin = point;
        case LocationUnavailable(:final problem):
          _locationMessage = describeLocationProblem(problem);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final businessesAsync = ref.watch(businessListProvider);

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        backgroundColor: palette.app,
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus:
              widget.initialSort != ListingSort.nearest &&
              widget.initialCategory == null,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search businesses, food, services…',
            border: InputBorder.none,
          ),
          onChanged: (text) =>
              setState(() => _query = _query.copyWith(search: text)),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _controller.clear();
                _query = _query.copyWith(search: '');
              }),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_query.categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.huge,
                Insets.md,
                Insets.huge,
                0,
              ),
              child: Wrap(
                spacing: Insets.md,
                children: [
                  for (final c in _query.categories)
                    InputChip(
                      avatar: Icon(c.icon, size: 16, color: c.color),
                      label: Text(c.label),
                      onDeleted: () => setState(
                        () => _query = _query.copyWith(categories: {}),
                      ),
                    ),
                ],
              ),
            ),
          // When-is-it-open filters. Late and Sunday beat a bare "open now"
          // on an island where most places shut early and on Sundays.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              Insets.huge,
              Insets.md,
              Insets.huge,
              0,
            ),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Open now'),
                  selected: _query.openNowOnly,
                  onSelected: (v) => setState(
                    () => _query = _query.copyWith(openNowOnly: v),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                FilterChip(
                  label: const Text('Open late'),
                  selected: _query.openLateOnly,
                  onSelected: (v) => setState(
                    () => _query = _query.copyWith(openLateOnly: v),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                FilterChip(
                  label: const Text('Open Sunday'),
                  selected: _query.openSundayOnly,
                  onSelected: (v) => setState(
                    () => _query = _query.copyWith(openSundayOnly: v),
                  ),
                ),
              ],
            ),
          ),
          _SortBar(
            selected: _query.sort,
            locating: _locating,
            onSelected: _setSort,
          ),
          if (_locationMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.huge,
                0,
                Insets.huge,
                Insets.md,
              ),
              child: Text(
                _locationMessage!,
                style: AppText.caption.copyWith(color: palette.muted),
              ),
            ),
          Expanded(
            child: businessesAsync.when(
              data: (all) => _Results(
                businesses: ListingFilter.apply(all, _query, origin: _origin),
                origin: _query.sort == ListingSort.nearest ? _origin : null,
                hasSearch: _query.search.trim().isNotEmpty,
              ),
              loading: () => Center(
                child: CircularProgressIndicator(color: palette.red),
              ),
              // An error, never an empty list: "no results" during an outage
              // would tell someone the business they want does not exist.
              error: (err, _) {
                debugPrint('Search: listings failed to load: $err');
                return _Message(
                  text: 'Could not load businesses. Check your connection.',
                  action: TextButton(
                    onPressed: () => ref.invalidate(businessListProvider),
                    child: const Text('Try again'),
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

class _SortBar extends StatelessWidget {
  const _SortBar({
    required this.selected,
    required this.locating,
    required this.onSelected,
  });

  final ListingSort selected;
  final bool locating;
  final ValueChanged<ListingSort> onSelected;

  static const Map<ListingSort, String> _labels = {
    ListingSort.ranked: 'Best',
    ListingSort.nearest: 'Near me',
    ListingSort.topRated: 'Top rated',
    ListingSort.name: 'A–Z',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.huge,
        vertical: Insets.md,
      ),
      child: Row(
        children: [
          for (final entry in _labels.entries) ...[
            ChoiceChip(
              label: Text(entry.value),
              selected: selected == entry.key,
              avatar: entry.key == ListingSort.nearest
                  ? (locating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.near_me_outlined, size: 16))
                  : null,
              onSelected: (_) => onSelected(entry.key),
            ),
            const SizedBox(width: Insets.md),
          ],
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.businesses,
    required this.origin,
    required this.hasSearch,
  });

  final List<Business> businesses;
  final GeoPoint? origin;
  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    if (businesses.isEmpty) {
      return _Message(
        text: hasSearch
            ? 'Nothing matches that. Try a shorter word, or a category like '
                  '"food".'
            : 'No businesses listed yet.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        Insets.huge,
        Insets.xs,
        Insets.huge,
        Insets.giant,
      ),
      itemCount: businesses.length,
      separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
      itemBuilder: (context, i) {
        final b = businesses[i];
        return BusinessListRow(
          business: b,
          distanceKm: origin == null ? null : distanceTo(b, origin!),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.giant),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppText.bodyMedium.copyWith(color: context.palette.muted),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

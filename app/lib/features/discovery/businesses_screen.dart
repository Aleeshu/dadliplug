import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/listing_filter_service.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/widgets/business_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Businesses tab (2026-10-28 redesign): search, category chips, Open
/// now, and every listing as a photo row, best-ranked first. Rank is earned,
/// so a paying business is not lifted here (plan.md 5).
class BusinessesScreen extends ConsumerStatefulWidget {
  const BusinessesScreen({super.key});

  @override
  ConsumerState<BusinessesScreen> createState() => _BusinessesScreenState();
}

class _BusinessesScreenState extends ConsumerState<BusinessesScreen> {
  final _search = TextEditingController();
  BusinessCategory? _category;
  bool _openNow = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final all = ref.watch(businessListProvider);

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
        title: const Text('Businesses'),
        backgroundColor: palette.app,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              0,
              Insets.lg,
              Insets.sm,
            ),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: Color(0xFF0A1F44)),
              decoration: InputDecoration(
                hintText: 'Search businesses…',
                hintStyle: const TextStyle(color: Color(0xFF5B6B85)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF5B6B85)),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF5B6B85)),
                        onPressed: () => setState(_search.clear),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Corners.pill),
                  borderSide: BorderSide(color: palette.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Corners.pill),
                  borderSide: BorderSide(color: palette.line),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              children: [
                chip(
                  'All',
                  selected: _category == null,
                  onTap: () => setState(() => _category = null),
                ),
                chip(
                  'Open now',
                  selected: _openNow,
                  onTap: () => setState(() => _openNow = !_openNow),
                ),
                for (final c in BusinessCategory.values)
                  chip(
                    c.shortLabel,
                    selected: _category == c,
                    onTap: () => setState(() => _category = c),
                  ),
              ],
            ),
          ),
          Expanded(
            child: all.when(
              loading: () =>
                  Center(child: CircularProgressIndicator(color: palette.red)),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(businessListProvider),
                  child: const Text('Could not load businesses. Try again'),
                ),
              ),
              data: (businesses) {
                final results = ListingFilter.apply(
                  businesses,
                  ListingQuery(
                    categories: {?_category},
                    openNowOnly: _openNow,
                    search: _search.text,
                  ),
                );
                if (results.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.huge),
                      child: Text(
                        'Nothing matches. Try a shorter word or another '
                        'category.',
                        textAlign: TextAlign.center,
                        style: AppText.bodyMedium.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(businessListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      Insets.sm,
                      Insets.lg,
                      Insets.giant,
                    ),
                    itemCount: results.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Insets.sm),
                    itemBuilder: (_, i) =>
                        BusinessListRow(business: results[i]),
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

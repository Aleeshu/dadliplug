import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/business_repository.dart';
import 'package:antigua_business_map/services/listing_filter_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the [BusinessRepository].
final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return SupabaseBusinessRepository();
});

/// Team-only listing writes. Backed by the same Supabase repository.
final listingAdminRepositoryProvider = Provider<ListingAdminRepository>((ref) {
  return SupabaseBusinessRepository();
});

/// Stream provider for all active business listings.
///
/// Automatic retry is off. Riverpod 3 retries a failed provider by default and
/// reports loading while it does, so with no connection the map showed a
/// spinner forever and the "could not load" error, with its retry button,
/// never appeared. The screens retry by invalidating this provider.
final businessListProvider = StreamProvider<List<Business>>(
  (ref) {
    final repo = ref.watch(businessRepositoryProvider);
    return repo.watchBusinesses();
  },
  retry: (_, _) => null,
);

/// Notifier managing active map filters ([ListingQuery]).
class MapQueryNotifier extends Notifier<ListingQuery> {
  @override
  ListingQuery build() => const ListingQuery();

  void toggleCategory(BusinessCategory category) {
    final updated = Set<BusinessCategory>.from(state.categories);
    if (updated.contains(category)) {
      updated.remove(category);
    } else {
      updated.add(category);
    }
    state = state.copyWith(categories: updated);
  }

  void setOpenNowOnly({required bool openNowOnly}) {
    state = state.copyWith(openNowOnly: openNowOnly);
  }

  void setOpenLateOnly({required bool value}) {
    state = state.copyWith(openLateOnly: value);
  }

  void setOpenSundayOnly({required bool value}) {
    state = state.copyWith(openSundayOnly: value);
  }

  void setSearch(String search) {
    state = state.copyWith(search: search);
  }

  void clearFilters() {
    state = const ListingQuery();
  }
}

/// Provider managing the active [ListingQuery].
final mapQueryProvider = NotifierProvider<MapQueryNotifier, ListingQuery>(
  MapQueryNotifier.new,
);

/// Provider computing filtered businesses based on current map query.
final filteredBusinessesProvider = Provider<AsyncValue<List<Business>>>((ref) {
  final businessesAsync = ref.watch(businessListProvider);
  final query = ref.watch(mapQueryProvider);

  return businessesAsync.whenData((list) {
    return ListingFilter.apply(list, query);
  });
});

/// Notifier managing currently tapped / selected business on the map.
class SelectedBusinessNotifier extends Notifier<Business?> {
  @override
  Business? build() => null;

  Business? get selected => state;

  set selected(Business? business) {
    state = business;
  }
}

/// Currently tapped / selected business on the map.
final selectedBusinessProvider =
    NotifierProvider<SelectedBusinessNotifier, Business?>(
      SelectedBusinessNotifier.new,
    );

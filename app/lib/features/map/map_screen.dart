import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/core/routing/app_tabs.dart';
import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/auth_factory.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/widgets/business_preview_card.dart';
import 'package:antigua_business_map/widgets/category_filter_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:antigua_business_map/features/map/island_ads_map.dart';

/// Shown when the database has no listings yet.
///
/// This is a real state at launch, not an error. It doubles as the first sales
/// asset: the empty app is the pitch for listing 1.
class _EmptyListings extends StatelessWidget {
  const _EmptyListings({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.giant),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 44, color: palette.line),
            const SizedBox(height: Insets.xl),
            Text(
              'No businesses listed yet',
              textAlign: TextAlign.center,
              style: AppText.displayMedium.copyWith(color: palette.ink),
            ),
            const SizedBox(height: Insets.md),
            Text(
              'IslandAds is new to Antigua. If you run a business, get in '
              'touch and be one of the first to appear.',
              textAlign: TextAlign.center,
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the listings could not be loaded.
///
/// Deliberately distinct from [_EmptyListings]. Showing "no businesses yet"
/// when the database is unreachable would hide an outage behind a screen that
/// looks fine.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.palette, required this.onRetry});

  final AppPalette palette;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.giant),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 44, color: palette.bad),
            const SizedBox(height: Insets.xl),
            Text(
              'Could not load businesses',
              textAlign: TextAlign.center,
              style: AppText.displayMedium.copyWith(color: palette.ink),
            ),
            const SizedBox(height: Insets.md),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.giant),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Core map screen for Antigua.
///
/// Features a fullscreen map of Antigua with business pins, category filters,
/// real-time opening status indicators, and pin preview cards.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({
    required this.session,
    required this.roleSwitcher,
    super.key,
  });

  final AuthSession session;
  final RoleSwitcherController roleSwitcher;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  /// Handle on the map so the recentre button and pin selection can move the
  /// camera without this screen importing a map SDK.
  final _mapKey = GlobalKey<IslandAdsMapState>();

  bool get _isDesktopOrWeb =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final query = ref.watch(mapQueryProvider);
    final queryNotifier = ref.read(mapQueryProvider.notifier);
    final businessesAsync = ref.watch(filteredBusinessesProvider);
    final selectedBusiness = ref.watch(selectedBusinessProvider);

    return Scaffold(
      backgroundColor: palette.app,
      body: Stack(
        children: [
          // 1. Map View (Google Maps on Mobile, Interactive Fallback on Desktop/Web)
          //
          // Empty and error are different states with different messages. A
          // database that is down must not read as "no businesses yet", because
          // that hides a real outage behind a plausible-looking screen.
          businessesAsync.when(
            data: (businesses) => businesses.isEmpty
                ? _EmptyListings(palette: palette)
                : _buildMap(businesses, selectedBusiness, palette),
            loading: () => Center(
              child: CircularProgressIndicator(color: palette.red),
            ),
            error: (err, _) {
              // Logged, not swallowed. A silent catch here turned a Supabase
              // outage into an unexplained dark map for an entire debugging
              // session — the screen said "could not load" and nothing said
              // why. The message still stays generic for users; the reason
              // goes to the log.
              debugPrint('Listings failed to load: $err');
              return _LoadFailed(
                palette: palette,
                onRetry: () => ref.invalidate(businessListProvider),
              );
            },
          ),

          // 2. Top Bar & Category Filters
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeaderBar(context, palette),
                CategoryFilterBar(
                  selectedCategories: query.categories,
                  openNowOnly: query.openNowOnly,
                  onCategoryToggled: queryNotifier.toggleCategory,
                  onOpenNowToggled: (openNow) =>
                      queryNotifier.setOpenNowOnly(openNowOnly: openNow),
                  onClearAll: queryNotifier.clearFilters,
                ),
              ],
            ),
          ),

          // 3. Re-center FAB button
          Positioned(
            right: Insets.lg,
            bottom: selectedBusiness != null ? 280 : Insets.xxl,
            child: FloatingActionButton.small(
              heroTag: 'map_recenter',
              backgroundColor: palette.surface,
              foregroundColor: palette.ink,
              onPressed: _recenterMap,
              tooltip: 'Center on Antigua',
              child: const Icon(Icons.my_location),
            ),
          ),

          // 4. Pin Preview Card Overlay
          if (selectedBusiness != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: BusinessPreviewCard(
                  business: selectedBusiness,
                  onClose: () {
                    ref.read(selectedBusinessProvider.notifier).selected = null;
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(
    List<Business> businesses,
    Business? selectedBusiness,
    AppPalette palette,
  ) {
    final mapBusinesses = businesses.where((b) => b.hasLocation).toList();

    // MapLibre has no desktop and web support in this package, so those
    // platforms get the non-map layout rather than a blank surface.
    if (_isDesktopOrWeb) {
      return _DesktopMapFallback(
        businesses: mapBusinesses,
        onSelectBusiness: _selectBusiness,
        palette: palette,
      );
    }

    return IslandAdsMap(
      key: _mapKey,
      businesses: mapBusinesses,
      selected: selectedBusiness,
      onSelect: _selectBusiness,
      onDeselect: () =>
          ref.read(selectedBusinessProvider.notifier).selected = null,
    );
  }

  void _selectBusiness(Business business) {
    ref.read(selectedBusinessProvider.notifier).selected = business;
    // Move the map to the pin that was just tapped, so the user sees where it
    // is rather than inferring it from a card.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapKey.currentState?.focusOn(business);
    });
  }

  void _recenterMap() {
    ref.read(selectedBusinessProvider.notifier).selected = null;
    _mapKey.currentState?.resetCamera();
  }

  Widget _buildHeaderBar(BuildContext context, AppPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.sm,
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.xs,
      ),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(Corners.xl),
        border: Border.all(color: palette.line),
        boxShadow: Shadows.card,
      ),
      child: Row(
        children: [
          Text(
            'Antigua',
            style: AppText.displayMedium.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search),
            color: palette.ink,
            tooltip: 'Search businesses',
          ),
          if (widget.roleSwitcher.isEnabled)
            RoleSwitcher(
              session: widget.session,
              controller: widget.roleSwitcher,
            ),
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline),
            color: palette.ink,
            tooltip: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Fallback interactive map layout for desktop & web preview mode.
class _DesktopMapFallback extends StatelessWidget {
  const _DesktopMapFallback({
    required this.businesses,
    required this.onSelectBusiness,
    required this.palette,
  });

  final List<Business> businesses;
  final ValueChanged<Business> onSelectBusiness;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: palette.sea,
      child: Stack(
        children: [
          // Background stylized island illustration
          Center(
            child: Container(
              width: 500,
              height: 380,
              decoration: BoxDecoration(
                color: palette.land,
                borderRadius: BorderRadius.circular(160),
                border: Border.all(color: palette.landLine, width: 3),
              ),
              child: Center(
                child: Text(
                  // Says which of the two reasons this fallback is showing.
                  // "Desktop" and "no API key" are very different problems and
                  // a blank island tells you neither.
                  AppConfig.hasGoogleMapsKey
                      ? 'ANTIGUA MAP'
                      : 'MAP OFFLINE\nMaps API key missing',
                  style: AppText.titleMedium.copyWith(
                    color: palette.landLine,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),

          // Interactive business pins
          for (final b in businesses)
            _PositionedPin(
              business: b,
              onTap: () => onSelectBusiness(b),
              palette: palette,
            ),
        ],
      ),
    );
  }
}

class _PositionedPin extends StatelessWidget {
  const _PositionedPin({
    required this.business,
    required this.onTap,
    required this.palette,
  });

  final Business business;
  final VoidCallback onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    // Map LatLng coordinates (16.95-17.20 N, -61.95 - -61.60 W) into screen percentage
    final lat = business.latitude ?? 17.06;
    final lng = business.longitude ?? -61.76;

    final topNorm = ((17.20 - lat) / 0.25).clamp(0.1, 0.9);
    final leftNorm = ((lng - (-61.95)) / 0.35).clamp(0.1, 0.9);

    final color = business.isPremium
        ? palette.red
        : (business.tier == SubscriptionTier.trial
              ? palette.gold
              : palette.ink);

    return Align(
      alignment: FractionalOffset(leftNorm, topNorm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Insets.xs),
          decoration: BoxDecoration(
            color: palette.surface,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: Shadows.card,
          ),
          child: Icon(Icons.place, size: 24, color: color),
        ),
      ),
    );
  }
}

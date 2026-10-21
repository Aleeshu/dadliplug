import 'package:antigua_business_map/widgets/notice_banner.dart';
import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/core/routing/app_tabs.dart';
import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/auth_factory.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:antigua_business_map/services/engagement_recorder.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/widgets/business_preview_card.dart';
import 'package:antigua_business_map/widgets/category_filter_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:antigua_business_map/features/map/featured_rail.dart';
import 'package:antigua_business_map/features/map/island_ads_map.dart';
import 'package:antigua_business_map/services/listing_filter_service.dart';

/// Shown when the database has no listings yet.
///
/// This is a real state at launch, not an error. It doubles as the first sales
/// asset: the empty app is the pitch for listing 1.
class _EmptyListings extends StatelessWidget {
  const _EmptyListings({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Sits over a live map now, so the text needs its own ground to sit on.
      // A full-bleed opaque scrim would hide the island again, which is what
      // this change was meant to fix. A soft vertical fade keeps the middle of
      // the screen readable and leaves the map visible top and bottom.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.app.withValues(alpha: 0.0),
            palette.app.withValues(alpha: 0.92),
            palette.app.withValues(alpha: 0.92),
            palette.app.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.28, 0.72, 1.0],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.giant),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined, size: 44, color: palette.muted),
              const SizedBox(height: Insets.xl),
              Text(
                'No businesses listed yet',
                textAlign: TextAlign.center,
                style: AppText.displayMedium.copyWith(color: palette.ink),
              ),
              const SizedBox(height: Insets.md),
              Text(
                'Dadliplug is new to Antigua. If you run a business, get in '
                'touch and be one of the first to appear.',
                textAlign: TextAlign.center,
                style: AppText.bodyMedium.copyWith(color: palette.muted),
              ),
            ],
          ),
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
    this.focusBusinessId,
    super.key,
  });

  /// Opened from "Get Directions": select this business and centre on it.
  final String? focusBusinessId;

  final AuthSession session;
  final RoleSwitcherController roleSwitcher;

  /// Layout-test seam. Swaps the native Google Maps surface for an equivalent
  /// widget so the chrome around it can be measured without a device.
  /// Null in every real code path.
  @visibleForTesting
  static Widget? debugMapSurfaceOverride;

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
    final filteredAsync = ref.watch(filteredBusinessesProvider);
    // A refresh that failed after listings had loaded (a dropped connection,
    // normal on island mobile data): the raw provider still holds the last
    // good list, so keep showing it, filtered, and flag it as stale rather
    // than replacing a working map with an error.
    final rawAsync = ref.watch(businessListProvider);
    final staleList = rawAsync.hasError ? rawAsync.value : null;
    final isStale = staleList != null;
    final businessesAsync = isStale
        ? AsyncData(ListingFilter.apply(staleList, query))
        : filteredAsync;
    final selectedBusiness = ref.watch(selectedBusinessProvider);
    _applyFocus(businessesAsync.value);

    // The rail follows the active filters, so choosing "Food" does not leave
    // a featured salon advertised under it. Hidden while a preview card is
    // up: both live at the bottom and the card is what was asked for.
    final featured = selectedBusiness == null
        ? featuredBusinesses(businessesAsync.value ?? const [])
        : const <Business>[];
    final showRail = featured.isNotEmpty;

    return Scaffold(
      backgroundColor: palette.app,
      body: Stack(
        // StackFit.expand is load-bearing, and its absence caused every layout
        // fault on this screen at once. Scaffold hands its body *loose*
        // constraints, so a default Stack shrink-wraps to its largest
        // non-positioned child. The only such child here was the header-and-
        // chips column, which made the whole Stack about 111px tall. The map
        // then filled 111px instead of the screen, the recentre button sat at
        // the top over the filter chips, and the empty state stacked behind
        // them. Positioned.fill on the map could not fix this, because fill
        // expands to the Stack's size, and the Stack was already the wrong
        // size. Fix it here, once.
        fit: StackFit.expand,
        children: [
          // 1. Map View (Google Maps on Mobile, Interactive Fallback on Desktop/Web)
          //
          // Empty and error are different states with different messages. A
          // database that is down must not read as "no businesses yet", because
          // that hides a real outage behind a plausible-looking screen.
          //
          // The map renders in BOTH the empty and populated cases. Replacing it
          // with the empty state hid the island entirely, which made a working
          // map look broken and gave no context for where those businesses
          // would be. The empty state now sits on top of a real map.
          // With nothing loaded yet, a failure still shows the error; after
          // a load, see staleList above.
          businessesAsync.when(
            data: (businesses) => Stack(
              fit: StackFit.expand,
              children: [
                // Positioned.fill is not optional. A Stack passes loose
                // constraints to non-positioned children, and a native map
                // surface does not expand to fill them — so the map collapsed
                // to nothing while the overlays drew over the top. That is
                // what left a blank map with no error anywhere.
                Positioned.fill(
                  child: _buildMap(
                    businesses,
                    selectedBusiness,
                    palette,
                  ),
                ),
                if (businesses.isEmpty && !isStale)
                  Positioned.fill(child: _EmptyListings(palette: palette)),
                if (isStale)
                  Positioned(
                    left: Insets.lg,
                    right: Insets.lg,
                    top: 132,
                    child: SafeArea(
                      child: _StaleBanner(
                        onRetry: () => ref.invalidate(businessListProvider),
                      ),
                    ),
                  ),
              ],
            ),
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
                const NoticeBanner(
                  padding: EdgeInsets.symmetric(horizontal: Insets.lg),
                ),
                CategoryFilterBar(
                  selectedCategories: query.categories,
                  openNowOnly: query.openNowOnly,
                  onCategoryToggled: queryNotifier.toggleCategory,
                  onOpenNowToggled: (openNow) =>
                      queryNotifier.setOpenNowOnly(openNowOnly: openNow),
                  openLateOnly: query.openLateOnly,
                  openSundayOnly: query.openSundayOnly,
                  onOpenLateToggled: (v) =>
                      queryNotifier.setOpenLateOnly(value: v),
                  onOpenSundayToggled: (v) =>
                      queryNotifier.setOpenSundayOnly(value: v),
                  onClearAll: queryNotifier.clearFilters,
                ),
              ],
            ),
          ),

          // 3. Re-center FAB button
          Positioned(
            right: Insets.lg,
            bottom: selectedBusiness != null
                ? 280
                : showRail
                ? FeaturedRail.height + Insets.md
                : Insets.xxl,
            child: FloatingActionButton.small(
              heroTag: 'map_recenter',
              backgroundColor: palette.surface,
              foregroundColor: palette.ink,
              onPressed: _recenterMap,
              tooltip: 'Center on Antigua',
              child: const Icon(Icons.my_location),
            ),
          ),

          // 4. Featured rail
          if (showRail)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: FeaturedRail(
                  businesses: featured,
                  onSelect: _selectBusiness,
                  onSeeAll: () => context.push('/featured'),
                ),
              ),
            ),

          // 5. Pin Preview Card Overlay
          if (selectedBusiness != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: BusinessPreviewCard(
                  business: selectedBusiness,
                  onEngagement: (kind) => ref
                      .read(engagementRecorderProvider)
                      .record(selectedBusiness.id, kind),
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

    // Desktop has no Google Maps plugin, and the web build is not configured
    // with a key, so those platforms get the non-map layout rather than a
    // blank surface.
    if (_isDesktopOrWeb) {
      return _DesktopMapFallback(
        businesses: mapBusinesses,
        onSelectBusiness: _selectBusiness,
        palette: palette,
        message: 'MAP PREVIEW\nRun on a phone for the live map',
      );
    }

    // Google Maps is a PlatformView whose native surface does not exist in the
    // test environment. Layout tests substitute a plain box of the
    // same geometry so the surrounding chrome can be measured honestly.
    if (MapScreen.debugMapSurfaceOverride case final Widget surface?) {
      return surface;
    }

    // Google Maps draws blank tiles with no error when the key is missing, so
    // a keyless build says so instead of showing an empty grey map.
    if (!AppConfig.hasGoogleMapsKey) {
      return _DesktopMapFallback(
        businesses: mapBusinesses,
        onSelectBusiness: _selectBusiness,
        palette: palette,
        message: 'NO MAPS KEY\nBuild with scripts/build-apk.ps1',
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

  bool _focusApplied = false;

  /// Selects [MapScreen.focusBusinessId] once the listings have arrived.
  /// Filters are cleared first, so the business is not hidden behind a
  /// category the viewer picked earlier.
  void _applyFocus(List<Business>? businesses) {
    final id = widget.focusBusinessId;
    if (_focusApplied || id == null || businesses == null) return;
    final matches = businesses.where((b) => b.id == id && b.hasLocation);
    if (matches.isEmpty) return;
    _focusApplied = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(mapQueryProvider.notifier).clearFilters();
      _selectBusiness(matches.first);
    });
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

  /// The design's "Search this area" box, with Near me beside it. The
  /// account lives under More now, so the header is only about finding.
  Widget _buildHeaderBar(BuildContext context, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: palette.surface,
              elevation: 2,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(Corners.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(Corners.pill),
                onTap: () => context.push('/search'),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: Insets.huge),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: palette.muted),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Text(
                          'Search this area',
                          style: AppText.bodyMedium.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.tune,
                        color: palette.ink,
                        size: 20,
                        semanticLabel: 'Search businesses',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Insets.md),
          Material(
            color: palette.surface,
            elevation: 2,
            shadowColor: Colors.black26,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: () => context.push('/search?sort=nearest'),
              icon: const Icon(Icons.near_me_outlined),
              color: palette.red,
              tooltip: 'Near me',
            ),
          ),
          if (widget.roleSwitcher.isEnabled) ...[
            const SizedBox(width: Insets.sm),
            RoleSwitcher(
              session: widget.session,
              controller: widget.roleSwitcher,
            ),
          ],
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
    required this.message,
  });

  final List<Business> businesses;
  final ValueChanged<Business> onSelectBusiness;
  final AppPalette palette;

  /// Says which reason this fallback is showing. "Desktop" and "no API key"
  /// are very different problems and a blank island tells you neither.
  final String message;

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
                  message,
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

/// Shown over the map when a refresh failed but earlier listings are still
/// on screen: they may be out of date, and the viewer should know that.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.warnBg,
      elevation: 2,
      borderRadius: BorderRadius.circular(Corners.lg),
      child: Padding(
        padding: const EdgeInsets.only(left: Insets.xl),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 18, color: palette.warn),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text(
                'No connection. Showing what was loaded earlier.',
                style: AppText.caption.copyWith(color: palette.warn),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

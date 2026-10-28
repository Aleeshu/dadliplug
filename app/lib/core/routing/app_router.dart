import 'package:antigua_business_map/features/discovery/community_board_screen.dart';
import 'package:antigua_business_map/features/business_admin/create_ad_screen.dart';
import 'package:antigua_business_map/features/more/settings_screen.dart';
import 'package:antigua_business_map/features/business_admin/plans_screen.dart';
import 'package:antigua_business_map/features/discovery/businesses_screen.dart';
import 'package:antigua_business_map/features/discovery/ad_screen.dart';
import 'package:antigua_business_map/features/discovery/feed_screen.dart';
import 'package:antigua_business_map/features/business_admin/redeem_deal_screen.dart';
import 'package:antigua_business_map/features/business_admin/pin_editor_screen.dart';
import 'package:antigua_business_map/features/more/get_listed_screen.dart';
import 'package:antigua_business_map/features/team_admin/leads_screen.dart';
import 'package:antigua_business_map/features/more/legal_screens.dart';
import 'package:antigua_business_map/features/team_admin/content_screen.dart';
import 'package:antigua_business_map/core/routing/app_tabs.dart';
import 'package:antigua_business_map/features/auth/choose_role_screen.dart';
import 'package:antigua_business_map/features/auth/profile_screen.dart';
import 'package:antigua_business_map/features/auth/sign_in_screen.dart';
import 'package:antigua_business_map/features/auth/sign_up_screen.dart';
import 'package:antigua_business_map/features/business_admin/business_dashboard_screen.dart';
import 'package:antigua_business_map/features/business_admin/business_listing_screen.dart';
import 'package:antigua_business_map/features/business_admin/business_reviews_screen.dart';
import 'package:antigua_business_map/features/business_admin/monthly_report_screen.dart';
import 'package:antigua_business_map/features/business_admin/posting_screens.dart';
import 'package:antigua_business_map/features/discovery/bookmarks_screen.dart';
import 'package:antigua_business_map/features/discovery/categories_screen.dart';
import 'package:antigua_business_map/features/home/home_screen.dart';
import 'package:antigua_business_map/features/more/more_screen.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/features/discovery/business_content_screens.dart';
import 'package:antigua_business_map/features/discovery/explore_screen.dart';
import 'package:antigua_business_map/features/discovery/leaderboard_screen.dart';
import 'package:antigua_business_map/features/discovery/your_places_screen.dart';
import 'package:antigua_business_map/features/listing/listing_screen.dart';
import 'package:antigua_business_map/features/map/map_screen.dart';
import 'package:antigua_business_map/features/discovery/featured_screen.dart';
import 'package:antigua_business_map/features/reviews/visit_code_screen.dart';
import 'package:antigua_business_map/features/events/event_detail_screen.dart';
import 'package:antigua_business_map/features/events/events_screen.dart';
import 'package:antigua_business_map/features/discovery/offers_screen.dart';
import 'package:antigua_business_map/features/search/search_screen.dart';
import 'package:antigua_business_map/services/listing_filter_service.dart';
import 'package:antigua_business_map/features/discovery/collection_screen.dart';
import 'package:antigua_business_map/features/team_admin/billing_screen.dart';
import 'package:antigua_business_map/features/team_admin/moderation_screen.dart';
import 'package:antigua_business_map/features/team_admin/ranking_screen.dart';
import 'package:antigua_business_map/features/team_admin/spotlight_screen.dart';
import 'package:antigua_business_map/features/team_admin/team_listings_screen.dart';
import 'package:antigua_business_map/models/user.dart';
import 'package:antigua_business_map/services/auth_factory.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Route paths, kept in one place so nothing is spelled twice.
abstract final class Routes {
  // User
  static const String home = '/';
  static const String map = '/map';
  static const String categories = '/categories';
  static const String more = '/more';
  static const String explore = '/explore';
  static const String places = '/places';
  static const String bookmarks = '/bookmarks';
  static const String events = '/events';
  static const String announcements = '/announcements';
  static const String leaderboard = '/leaderboard';

  // Business admin
  static const String businessDashboard = '/business';
  static const String businessListing = '/business/listing';
  static const String businessReviews = '/business/reviews';
  static const String businessAnnouncements = '/business/announcements';
  static const String businessAds = '/business/ads';
  static const String businessEvents = '/business/events';
  static const String businessReport = '/business/report';

  // Team admin
  static const String teamDashboard = '/team';
  static const String teamBilling = '/team/billing';
  static const String teamRanking = '/team/ranking';
  static const String teamSpotlight = '/team/spotlight';
  static const String teamListings = '/team/listings';

  static const String teamPrefix = '/team';

  // Full-screen, outside the tab bar
  static const String search = '/search';
  static const String nearMe = '/search?sort=nearest';
  static const String featured = '/featured';
  static String listing(String businessId) => '/listing/$businessId';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String profile = '/profile';
  static const String chooseRole = '/choose-role';

  /// Where a signed-out user is sent when they hit a guarded route.
  static const String signedOutLanding = Routes.signIn;
}

/// Navigation structure.
///
/// The tab sets match the prototype's `TABS`: three for users, three for
/// business admins, four for the team. Authenticated screens sit outside the
/// shell and cover it, so signing in does not leave a tab bar behind.
///
/// Guards are redirects, not in-screen checks. Hiding a tab is not access
/// control — a user who types `/team` must not reach the moderation queue, and
/// the same has to be true server-side via RLS. This is the client half only.
GoRouter buildRouter({
  required AuthSession session,
  required RoleSwitcherController roleSwitcher,
  bool askAudienceFirst = false,
}) {
  // The listing the business screens act on. A team admin manages several, so
  // the one they last opened is remembered; otherwise the tab bar, which
  // carries no id, would drop back to their first listing on every tab change.
  String? activeBusinessId;

  String businessIdFor(GoRouterState state) {
    final fromUrl = state.uri.queryParameters['business'];
    if (fromUrl != null && fromUrl.isNotEmpty) {
      activeBusinessId = fromUrl;
      return fromUrl;
    }
    return activeBusinessId ?? session.primaryBusinessId ?? '';
  }

  return _buildRouter(
    session: session,
    roleSwitcher: roleSwitcher,
    askAudienceFirst: askAudienceFirst,
    businessIdFor: businessIdFor,
  );
}

GoRouter _buildRouter({
  required AuthSession session,
  required RoleSwitcherController roleSwitcher,
  required bool askAudienceFirst,
  required String Function(GoRouterState) businessIdFor,
}) => GoRouter(
  // plan.md 6a: the first screen asks business or customer. Only on a first
  // run — main.dart records that it has been asked.
  initialLocation: askAudienceFirst ? Routes.chooseRole : Routes.home,
  redirect: (context, state) {
    final location = state.uri.path;
    final requiredRole = AppTabs.roleForLocation(location);
    final isGuarded = location != Routes.home;

    // Team and business areas are gated. Everything else is public, because
    // browsing the map without an account is the whole point.
    if (requiredRole == UserRole.teamAdmin &&
        !session.canAccessTeamDashboard()) {
      return _fallbackFor(session, location);
    }
    if (requiredRole == UserRole.businessAdmin &&
        !session.canAccessBusinessDashboard()) {
      return _fallbackFor(session, location);
    }

    // Already signed in, so the auth screens are dead ends.
    if (isGuarded &&
        (location == Routes.signIn || location == Routes.signUp) &&
        session.isSignedIn) {
      return Routes.home;
    }

    return null;
  },
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, session: session, child: child),
      routes: [
        GoRoute(
          path: Routes.home,
          builder: (c, s) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'search',
              builder: (c, s) {
                final category = s.uri.queryParameters['category'];
                return SearchScreen(
                  initialSort: s.uri.queryParameters['sort'] == 'nearest'
                      ? ListingSort.nearest
                      : ListingSort.ranked,
                  initialCategory: category == null
                      ? null
                      : BusinessCategoryX.fromName(category),
                );
              },
            ),
            GoRoute(
              path: 'featured',
              builder: (c, s) => const FeaturedScreen(),
            ),
            GoRoute(
              path: 'offers',
              builder: (c, s) => const OffersScreen(),
            ),
          ],
        ),
        GoRoute(
          path: Routes.map,
          builder: (c, s) {
            final focus = s.uri.queryParameters['focus'];
            return MapScreen(
              // Keyed on the target so opening the map for another business
              // re-applies the focus instead of keeping the old selection.
              key: ValueKey('map-$focus'),
              session: session,
              roleSwitcher: roleSwitcher,
              focusBusinessId: focus,
            );
          },
        ),
        GoRoute(
          path: Routes.categories,
          // The Businesses tab (2026-10-28 redesign); the category list is
          // its sub-page.
          builder: (c, s) => const BusinessesScreen(),
          routes: [
            GoRoute(
              path: 'all',
              builder: (c, s) => const CategoriesScreen(),
            ),
          ],
        ),
        GoRoute(
          path: Routes.more,
          builder: (c, s) => MoreScreen(session: session),
        ),
        GoRoute(
          path: Routes.explore,
          builder: (c, s) => const ExploreScreen(),
        ),
        GoRoute(
          path: Routes.places,
          builder: (c, s) => YourPlacesScreen(session: session),
        ),
        GoRoute(
          path: Routes.bookmarks,
          builder: (c, s) => BookmarksScreen(isSignedIn: session.isSignedIn),
        ),
        GoRoute(
          path: Routes.events,
          builder: (c, s) => const EventsScreen(),
        ),
        GoRoute(
          path: Routes.announcements,
          builder: (c, s) => AnnouncementsScreen(
            isSignedIn: session.isSignedIn,
          ),
        ),
        GoRoute(
          path: Routes.leaderboard,
          builder: (c, s) => const LeaderboardScreen(),
        ),

        GoRoute(
          path: Routes.businessDashboard,
          builder: (c, s) {
            final id = businessIdFor(s);
            return BusinessDashboardScreen(
              key: ValueKey('dashboard-$id'),
              businessId: id,
              otherBusinessIds: session.user?.businessIds ?? const [],
            );
          },
        ),
        GoRoute(
          path: '/business/plans',
          builder: (c, s) => PlansScreen(businessId: businessIdFor(s)),
        ),
        GoRoute(
          path: '/business/redeem',
          builder: (c, s) => const RedeemDealScreen(),
        ),
        GoRoute(
          path: '/business/pin',
          builder: (c, s) => PinEditorScreen(businessId: businessIdFor(s)),
        ),
        GoRoute(
          path: Routes.businessListing,
          builder: (c, s) {
            final id = businessIdFor(s);
            // Keyed on the id so switching listings rebuilds the form rather
            // than keeping the previous listing's text in its controllers.
            return BusinessListingScreen(
              key: ValueKey('listing-$id'),
              businessId: id,
              isTeam: session.canAccessTeamDashboard(),
            );
          },
        ),
        GoRoute(
          path: Routes.businessReviews,
          builder: (c, s) =>
              BusinessReviewsScreen(businessId: businessIdFor(s)),
        ),
        GoRoute(
          path: '/business/visit-code',
          builder: (c, s) => VisitCodeScreen(businessId: businessIdFor(s)),
        ),
        GoRoute(
          path: Routes.businessAnnouncements,
          builder: (c, s) => AnnouncementsScreen(
            businessId: businessIdFor(s),
            isSignedIn: session.isSignedIn,
          ),
          routes: [
            GoRoute(
              path: 'new',
              builder: (c, s) =>
                  PostAnnouncementScreen(businessId: businessIdFor(s)),
            ),
          ],
        ),
        GoRoute(
          path: Routes.businessAds,
          builder: (c, s) => BusinessAdsScreen(businessId: businessIdFor(s)),
          routes: [
            GoRoute(
              path: 'new',
              // The three-step wizard from the 2026-10-28 redesign.
              builder: (c, s) => CreateAdScreen(businessId: businessIdFor(s)),
            ),
          ],
        ),
        GoRoute(
          path: Routes.businessReport,
          builder: (c, s) => MonthlyReportScreen(businessId: businessIdFor(s)),
        ),
        GoRoute(
          path: Routes.businessEvents,
          builder: (c, s) => EventsCalendarScreen(businessId: businessIdFor(s)),
          routes: [
            GoRoute(
              path: 'new',
              builder: (c, s) => PostEventScreen(businessId: businessIdFor(s)),
            ),
          ],
        ),

        GoRoute(
          path: Routes.teamDashboard,
          builder: (c, s) => const ModerationScreen(),
          routes: [
            GoRoute(path: 'billing', builder: (c, s) => const BillingScreen()),
            GoRoute(path: 'content', builder: (c, s) => const ContentScreen()),
            GoRoute(path: 'leads', builder: (c, s) => const LeadsScreen()),
            GoRoute(path: 'ranking', builder: (c, s) => const RankingScreen()),
            GoRoute(
              path: 'spotlight',
              builder: (c, s) => const SpotlightScreen(),
            ),
            GoRoute(
              path: 'listings',
              builder: (c, s) => const TeamListingsScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (c, s) => const BusinessListingScreen(
                    createNew: true,
                    isTeam: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    GoRoute(
      path: Routes.signIn,
      builder: (c, s) => SignInScreen(session: session),
    ),
    GoRoute(
      path: Routes.signUp,
      builder: (c, s) => SignUpScreen(session: session),
    ),
    GoRoute(
      path: '/event/:id',
      builder: (c, s) => EventDetailScreen(eventId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: Routes.chooseRole,
      builder: (context, state) => ChooseRoleScreen(
        onChosen: (audience) {
          // Businesses need an account to run a listing; customers can go
          // straight to browsing, because guest access is a real state.
          if (audience == Audience.business) {
            context.push(Routes.signUp);
          } else {
            context.go(Routes.home);
          }
        },
      ),
    ),
    GoRoute(
      path: '/privacy',
      builder: (c, s) => const LegalScreen(
        asset: 'assets/legal/privacy.md',
        title: 'Privacy policy',
      ),
    ),
    GoRoute(
      path: '/terms',
      builder: (c, s) => const LegalScreen(
        asset: 'assets/legal/terms.md',
        title: 'Terms of use',
      ),
    ),
    GoRoute(path: '/about', builder: (c, s) => const AboutScreen()),
    GoRoute(
      path: '/settings',
      builder: (c, s) => SettingsScreen(session: session),
      routes: [
        GoRoute(
          path: 'payments',
          builder: (c, s) => PaymentHistoryScreen(
            businessId: s.uri.queryParameters['business'] ?? '',
          ),
        ),
      ],
    ),
    GoRoute(path: '/get-listed', builder: (c, s) => const GetListedScreen()),
    GoRoute(
      path: Routes.profile,
      builder: (c, s) => ProfileScreen(session: session),
    ),
    GoRoute(path: '/feed', builder: (c, s) => const FeedScreen()),
    GoRoute(
      path: '/board',
      builder: (c, s) => const CommunityBoardScreen(),
      routes: [
        GoRoute(path: 'new', builder: (c, s) => const NewBoardPostScreen()),
        GoRoute(path: 'mine', builder: (c, s) => const MyBoardPostsScreen()),
      ],
    ),
    GoRoute(
      path: '/ad/:id',
      builder: (c, s) => AdScreen(adId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/collection/:id',
      builder: (c, s) =>
          CollectionScreen(collectionId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/listing/:id',
      builder: (c, s) => ListingScreen(businessId: s.pathParameters['id']!),
    ),
  ],
);

/// Where a user who lacks a role should land.
///
/// Signed-out users go to sign in, because they can fix it. Signed-in users
/// with the wrong role go to the map, because they cannot — redirecting them
/// to a sign-in screen they are already signed in to is a loop.
String? _fallbackFor(AuthSession session, String attemptedLocation) {
  if (!session.isSignedIn) return Routes.signedOutLanding;
  if (attemptedLocation.startsWith(Routes.teamPrefix)) return Routes.home;
  if (attemptedLocation.startsWith(Routes.businessDashboard)) {
    return Routes.home;
  }
  return null;
}

/// Scaffold for the tabbed area: content plus the role-aware bottom bar.
class AppShell extends StatelessWidget {
  const AppShell({
    required this.location,
    required this.session,
    required this.child,
    super.key,
  });

  final String location;
  final AuthSession session;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The team and business tab bars have no Home tab (five is the most the
    // bar holds), and tabs navigate with `go`, which leaves nothing to pop. So
    // back from an admin area returns to Home instead of closing the app.
    final inAdminArea = AppTabs.roleForLocation(location) != UserRole.user;

    return PopScope(
      canPop: !inAdminArea,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.home);
      },
      child: Scaffold(
        body: SafeArea(bottom: false, child: child),
        bottomNavigationBar: AppTabBar(
          currentPath: location,
          session: session,
          onSelect: (path) => context.go(path),
        ),
      ),
    );
  }
}

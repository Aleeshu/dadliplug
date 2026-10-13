import 'package:antigua_business_map/core/routing/app_tabs.dart';
import 'package:antigua_business_map/features/auth/choose_role_screen.dart';
import 'package:antigua_business_map/features/auth/profile_screen.dart';
import 'package:antigua_business_map/features/auth/sign_in_screen.dart';
import 'package:antigua_business_map/features/auth/sign_up_screen.dart';
import 'package:antigua_business_map/features/business_admin/business_dashboard_screen.dart';
import 'package:antigua_business_map/features/business_admin/business_listing_screen.dart';
import 'package:antigua_business_map/features/business_admin/business_reviews_screen.dart';
import 'package:antigua_business_map/features/discovery/bookmarks_screen.dart';
import 'package:antigua_business_map/features/discovery/business_content_screens.dart';
import 'package:antigua_business_map/features/discovery/explore_screen.dart';
import 'package:antigua_business_map/features/discovery/leaderboard_screen.dart';
import 'package:antigua_business_map/features/discovery/your_places_screen.dart';
import 'package:antigua_business_map/features/listing/listing_screen.dart';
import 'package:antigua_business_map/features/map/map_screen.dart';
import 'package:antigua_business_map/features/search/search_screen.dart';
import 'package:antigua_business_map/features/team_admin/billing_screen.dart';
import 'package:antigua_business_map/features/team_admin/moderation_screen.dart';
import 'package:antigua_business_map/features/team_admin/ranking_screen.dart';
import 'package:antigua_business_map/features/team_admin/spotlight_screen.dart';
import 'package:antigua_business_map/models/user.dart';
import 'package:antigua_business_map/services/auth_factory.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Route paths, kept in one place so nothing is spelled twice.
abstract final class Routes {
  // User
  static const String map = '/';
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

  // Team admin
  static const String teamDashboard = '/team';
  static const String teamBilling = '/team/billing';
  static const String teamRanking = '/team/ranking';
  static const String teamSpotlight = '/team/spotlight';

  static const String teamPrefix = '/team';

  // Full-screen, outside the tab bar
  static const String search = '/search';
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
}) => GoRouter(
  initialLocation: Routes.map,
  redirect: (context, state) {
    final location = state.uri.path;
    final requiredRole = AppTabs.roleForLocation(location);
    final isGuarded = location != Routes.map;

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
      return Routes.map;
    }

    return null;
  },
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, session: session, child: child),
      routes: [
        GoRoute(
          path: Routes.map,
          builder: (c, s) => MapScreen(
            session: session,
            roleSwitcher: roleSwitcher,
          ),
          routes: [
            GoRoute(
              path: 'search',
              builder: (c, s) => const SearchScreen(),
            ),
          ],
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
          builder: (c, s) => const EventsCalendarScreen(),
        ),
        GoRoute(
          path: Routes.announcements,
          builder: (c, s) => const AnnouncementsScreen(),
        ),
        GoRoute(
          path: Routes.leaderboard,
          builder: (c, s) => const LeaderboardScreen(),
        ),

        GoRoute(
          path: Routes.businessDashboard,
          builder: (c, s) => const BusinessDashboardScreen(),
        ),
        GoRoute(
          path: Routes.businessListing,
          builder: (c, s) => const BusinessListingScreen(),
        ),
        GoRoute(
          path: Routes.businessReviews,
          builder: (c, s) => const BusinessReviewsScreen(),
        ),
        GoRoute(
          path: Routes.businessAnnouncements,
          builder: (c, s) => const AnnouncementsScreen(),
        ),
        GoRoute(
          path: Routes.businessAds,
          builder: (c, s) => BusinessAdsScreen(
            businessId: s.uri.queryParameters['business'] ?? '',
          ),
        ),

        GoRoute(
          path: Routes.teamDashboard,
          builder: (c, s) => const ModerationScreen(),
          routes: [
            GoRoute(path: 'billing', builder: (c, s) => const BillingScreen()),
            GoRoute(path: 'ranking', builder: (c, s) => const RankingScreen()),
            GoRoute(
              path: 'spotlight',
              builder: (c, s) => const SpotlightScreen(),
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
      path: Routes.chooseRole,
      builder: (context, state) => ChooseRoleScreen(
        onChosen: (audience) {
          // Businesses need an account to run a listing; customers can go
          // straight to browsing, because guest access is a real state.
          if (audience == Audience.business) {
            context.push(Routes.signUp);
          } else {
            context.go(Routes.map);
          }
        },
      ),
    ),
    GoRoute(
      path: Routes.profile,
      builder: (c, s) => ProfileScreen(session: session),
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
  if (attemptedLocation.startsWith(Routes.teamPrefix)) return Routes.map;
  if (attemptedLocation.startsWith(Routes.businessDashboard)) return Routes.map;
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
    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: AppTabBar(
        currentPath: location,
        session: session,
        onSelect: (path) => context.go(path),
      ),
    );
  }
}

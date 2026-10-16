import 'package:antigua_business_map/core/theme/app_theme.dart';
import 'package:antigua_business_map/features/discovery/your_places_screen.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:antigua_business_map/models/user.dart';
import 'package:antigua_business_map/services/auth_service.dart';
import 'package:antigua_business_map/services/mock_auth_service.dart';
import 'package:antigua_business_map/services/user_places_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the states "your places" can be in.
///
/// Each of these is a state a real user hits, and the difference between them
/// is whether the app is being honest: an empty history must read as empty, a
/// signed-out user must not be told they have never been anywhere, and no state
/// may ever show invented rows.
Widget _app({
  List<UserPlace> places = const [],
  List<ReviewRequestSummary> requests = const [],
  Exception? error,
  AuthSession? session,
}) {
  return ProviderScope(
    overrides: [
      userPlacesProvider.overrideWith((ref) async {
        if (error != null) throw error;
        return places;
      }),
      reviewRequestsProvider.overrideWith((ref) async => requests),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: YourPlacesScreen(session: session ?? _signedOut()),
    ),
  );
}

/// A session with nobody signed in. The mock starts clean, which is exactly the
/// signed-out state.
AuthSession _signedOut() =>
    AuthSession(service: MockAuthService(latency: Duration.zero));

/// A session that is already signed in, built synchronously.
///
/// Deliberately not `MockAuthService.signIn`, which awaits a `Future.delayed`.
/// Inside `testWidgets` time is fake, so awaiting that before the first pump
/// deadlocks the test rather than failing it. `AuthSession` only reads
/// `currentUser` and subscribes to `authStateChanges` in its constructor, so
/// returning those directly is enough.
AuthSession _signedIn() {
  // role defaults to user; the field is omitted deliberately.
  const user = AppUser(id: 'u1', email: 'demo@antiguamap.app');
  return AuthSession(service: _SignedInService(user));
}

class _SignedInService implements AuthService {
  _SignedInService(this.user);

  final AppUser user;

  @override
  AppUser? get currentUser => user;

  @override
  Stream<AppUser?> get authStateChanges => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

UserPlace _place(String name, {bool confirmed = false}) => UserPlace(
  visitId: name,
  businessId: 'b-$name',
  businessName: name,
  category: BusinessCategory.food,
  visitedAt: DateTime.utc(2026, 3, 4),
  confirmedByBusiness: confirmed,
);

void main() {
  testWidgets('a signed-out user is asked to sign in, not told they are new', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // "No places yet" would claim the user has never been anywhere, which is a
    // different and false claim than "we cannot tell until you sign in".
    expect(find.text('Sign in to see your places'), findsOneWidget);
    expect(find.text('No places yet'), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('an empty history says so, and invents nothing', (tester) async {
    final session = _signedIn();
    await tester.pumpWidget(_app(session: session));
    await tester.pumpAndSettle();

    expect(find.text('No places yet'), findsOneWidget);
    expect(find.text("Auntie Mae's"), findsNothing);
  });

  testWidgets('a visited business is listed by name', (tester) async {
    final session = _signedIn();
    await tester.pumpWidget(
      _app(session: session, places: [_place("Auntie Mae's")]),
    );
    await tester.pumpAndSettle();

    expect(find.text("Auntie Mae's"), findsOneWidget);
    expect(find.text('No places yet'), findsNothing);
  });

  testWidgets('a place with no known category reads as Other', (tester) async {
    final session = _signedIn();
    await tester.pumpWidget(
      _app(
        session: session,
        places: [
          UserPlace(
            visitId: 'v1',
            businessId: 'b1',
            businessName: "Auntie Mae's",
            visitedAt: DateTime.utc(2026, 3, 4),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Never "Retail" or any other guessed industry.
    expect(find.textContaining('Other'), findsWidgets);
  });

  testWidgets('a visit without approval cannot be reviewed', (tester) async {
    final session = _signedIn();
    await tester.pumpWidget(
      _app(session: session, places: [_place('Barbershop')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Awaiting approval'), findsOneWidget);
    expect(find.text('Review'), findsNothing);
  });

  testWidgets('an approved visit offers the review', (tester) async {
    final session = _signedIn();
    await tester.pumpWidget(
      _app(
        session: session,
        places: [_place('Barbershop', confirmed: true)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Awaiting approval'), findsNothing);
  });

  testWidgets('a pending request is surfaced while it waits', (tester) async {
    final session = _signedIn();
    await tester.pumpWidget(
      _app(
        session: session,
        places: [_place('Barbershop')],
        requests: [
          ReviewRequestSummary(
            id: 'r1',
            businessId: 'b1',
            businessName: 'Barbershop',
            status: ReviewRequestStatus.pending,
            requestedAt: DateTime.utc(2026, 3),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waiting on a business'), findsOneWidget);
  });

  testWidgets('a load failure is an error, not an empty history', (
    tester,
  ) async {
    final session = _signedIn();
    await tester.pumpWidget(
      _app(session: session, error: Exception('offline')),
    );
    await tester.pumpAndSettle();

    // "No places yet" would tell a user they have never been anywhere, which
    // is a different and false claim.
    expect(find.text('Could not load your places'), findsOneWidget);
    expect(find.text('No places yet'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('retry re-runs the query', (tester) async {
    final session = _signedIn();
    await tester.pumpWidget(
      _app(session: session, error: Exception('offline')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

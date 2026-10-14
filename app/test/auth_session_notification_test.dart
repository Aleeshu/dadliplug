import 'package:antigua_business_map/core/theme/app_theme.dart';
import 'package:antigua_business_map/features/auth/profile_screen.dart';
import 'package:antigua_business_map/models/user.dart';
import 'package:antigua_business_map/services/auth_service.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the session not notifying.
///
/// Signing out called Supabase successfully and logged it, but the profile
/// screen kept rendering the signed-in account. The session mutated in place,
/// the screen read it directly, and nothing had subscribed — so there was no
/// rebuild. The app looked broken only in the one place a user checks
/// immediately after signing out, and nothing in the suite noticed.
void main() {
  late _FakeService service;
  late AuthSession session;

  setUp(() {
    service = _FakeService();
    session = AuthSession(service: service);
  });

  tearDown(() => session.dispose());

  Widget app() => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: ProfileScreen(session: session),
        ),
      );

  testWidgets('the profile shows the signed-in user', (tester) async {
    await tester.pumpWidget(app());

    await session.signIn('demo@antiguamap.app', '');
    await tester.pump();

    expect(find.text('demo@antiguamap.app'), findsOneWidget);
  });

  testWidgets('signing out clears the profile immediately', (tester) async {
    await tester.pumpWidget(app());

    await session.signIn('demo@antiguamap.app', '');
    await tester.pump();
    expect(find.text('demo@antiguamap.app'), findsOneWidget);

    await session.signOut();
    await tester.pump();

    // The bug: this still found the email, because nothing rebuilt.
    expect(find.text('demo@antiguamap.app'), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('a role change updates the account type shown', (tester) async {
    await tester.pumpWidget(app());

    await session.signIn('demo@antiguamap.app', '');
    await tester.pump();
    expect(find.textContaining('Team admin'), findsNothing);

    await session.setRole(UserRole.teamAdmin);
    await tester.pump();

    // The role lives in the session, so the screen must react to it.
    expect(find.textContaining('Team admin'), findsOneWidget);
  });

  test('the session notifies on sign in and again on sign out', () async {
    var notifications = 0;
    session.addListener(() => notifications++);

    await session.signIn('demo@antiguamap.app', '');
    expect(notifications, 1);

    await session.signOut();
    expect(notifications, 2);
  });

  test('an unchanged user does not notify again', () async {
    await session.signIn('demo@antiguamap.app', '');

    var notifications = 0;
    session.addListener(() => notifications++);

    // Same id, same role: nothing a screen displays has changed, so a rebuild
    // would be pure churn.
    await session.setRole(UserRole.user);
    expect(notifications, 0);
  });
}

/// Synchronous fake. [MockAuthService] awaits a `Future.delayed`, and inside
/// `testWidgets` time is fake, so awaiting it before the first pump deadlocks
/// the test instead of failing it.
class _FakeService implements AuthService {
  bool _signedIn = false;
  UserRole role = UserRole.user;

  static const _user = AppUser(
    id: 'u1',
    email: 'demo@antiguamap.app',
    displayName: 'Demo',
  );

  @override
  AppUser? get currentUser =>
      _signedIn ? _user.copyWith(role: role) : null;

  @override
  Stream<AppUser?> get authStateChanges => const Stream.empty();

  @override
  bool get isInitialized => true;

  @override
  Future<AuthResult> signInWithEmail(String email, String password) async {
    _signedIn = true;
    return const AuthSuccess(_user);
  }

  @override
  Future<void> signOut() async => _signedIn = false;

  @override
  Future<void> setRole(UserRole next) async => role = next;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}
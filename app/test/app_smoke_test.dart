import 'package:antigua_business_map/main.dart';
import 'package:antigua_business_map/services/auth_factory.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:antigua_business_map/services/mock_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shell tests, run against the in-memory mock auth.
///
/// These check that the app boots, the theme applies, and the role-based tab
/// sets resolve. Layout review is done by running the app and looking at it,
/// not by asserting pixel positions.
void main() {
  ({AntiguaMapApp app, MockAuthService auth}) buildApp() {
    final auth = MockAuthService(latency: Duration.zero);
    final session = AuthSession(service: auth);
    return (
      app: AntiguaMapApp(
        session: session,
        roleSwitcher: RoleSwitcherController(session),
      ),
      auth: auth,
    );
  }

  testWidgets('app boots and shows the map screen', (tester) async {
    final built = buildApp();
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    expect(find.text('Antigua'), findsOneWidget);
    expect(find.text('Open now'), findsOneWidget);
  });

  testWidgets('user tabs render three items', (tester) async {
    final built = buildApp();
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Your places'), findsOneWidget);
  });

  testWidgets('creating an account signs the user in', (tester) async {
    final built = buildApp();
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    // Navigate profile -> sign-in -> sign-up
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create one'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'someone@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'correcthorsebattery',
    );
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    // Open profile to verify signed in email is displayed
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('someone@example.com'),
      findsWidgets,
    );
  });

  testWidgets('sign in rejects a weak password with a readable message', (
    tester,
  ) async {
    final built = buildApp();
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create one'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'someone@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'short',
    );
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(find.text('At least 8 characters.'), findsOneWidget);
  });

  testWidgets('dark mode applies without error', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final built = buildApp();
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

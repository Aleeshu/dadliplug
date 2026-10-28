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

  testWidgets('app boots on Home', (tester) async {
    final built = buildApp();
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    expect(find.text('Search businesses, products, services…'), findsOneWidget);
    expect(find.text('Shopping'), findsOneWidget);
  });

  testWidgets('customer tabs match the Dadliplug design', (tester) async {
    final built = buildApp();
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    // Home, Businesses, Map (raised centre), Events, More: the 2026-10-28
    // redesign. These names are the spec, not a placeholder set, so a change
    // here is a change to the product.
    for (final tab in ['Home', 'Businesses', 'Map', 'Events', 'More']) {
      expect(find.text(tab), findsOneWidget, reason: tab);
    }
  });

  testWidgets('creating an account signs the user in', (tester) async {
    final built = buildApp();
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    // Navigate More -> sign-in -> sign-up
    await tester.tap(find.text('More'));
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

    // Open the account to verify the signed-in email is displayed
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your account'));
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

    await tester.tap(find.text('More'));
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

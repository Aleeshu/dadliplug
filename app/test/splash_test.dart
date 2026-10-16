import 'package:antigua_business_map/features/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the splash shows, then lifts to reveal the app', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashGate(
          duration: Duration(milliseconds: 500),
          child: Text('the app'),
        ),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Plug Into Local.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('the app underneath is already built while the splash shows', (
    tester,
  ) async {
    // So a deep link lands immediately when the splash lifts.
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashGate(
          duration: Duration(milliseconds: 500),
          child: Text('the app'),
        ),
      ),
    );
    expect(find.text('the app'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });
}

import 'package:antigua_business_map/services/auth_factory.dart';
import 'package:antigua_business_map/services/mock_auth_service.dart';
import 'package:antigua_business_map/services/supabase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

/// Guards a bug that produced a black screen on a real phone.
///
/// `SupabaseAuthService` read `Supabase.instance` in its constructor. When the
/// app was built with keys but `Supabase.initialize` had not run yet, that
/// assertion fired *before* `runApp` — so nothing rendered, and nothing on the
/// screen or in a normal error report said why.
///
/// It hid because builds without keys fall back to the mock, which touches no
/// client. The bug only appeared the first time real keys were supplied.
void main() {
  group('SupabaseAuthService construction', () {
    test('does not touch Supabase.instance when constructed', () {
      // No Supabase.initialize has run in this test, so any access to
      // `Supabase.instance` throws here — which is exactly the condition that
      // caused the black screen.
      expect(SupabaseAuthService.new, returnsNormally);
    });

    test('can be constructed with an injected client', () {
      expect(
        () => SupabaseAuthService(client: _unusedClient()),
        returnsNormally,
      );
    });
  });

  group('auth service factory', () {
    test('returns the mock when no Supabase keys are configured', () {
      // The current test build has no dart-defines, so this is the path the
      // app takes without configuration.
      final service = createAuthService(isRelease: false);
      expect(service, isA<MockAuthService>());
    });

    test('a release build without keys refuses to run', () {
      // Mock auth lets anyone sign in as anyone. Shipping that by accident
      // would be far worse than failing to start.
      expect(
        () => createAuthService(isRelease: true),
        throwsA(isA<StateError>()),
      );
    });

    test('the mock does not require a backend to be initialised', () {
      final service = MockAuthService(latency: Duration.zero);
      expect(service.currentUser, isNull);
      expect(service.isInitialized, isFalse);
    });
  });
}

/// A client that is never dereferenced — the test only checks construction.
///
/// Built without touching the network: `SupabaseClient` needs a url and key,
/// and supplying dummies is enough because nothing here issues a query.
SupabaseClient _unusedClient() =>
    SupabaseClient('https://example.supabase.co', 'dummy-anon-key');

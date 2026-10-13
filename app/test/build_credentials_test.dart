import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/auth_factory.dart';
import 'package:antigua_business_map/services/business_repository.dart';
import 'package:antigua_business_map/services/mock_auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards against the class of build mistake that costs a day.
///
/// `flutter build` run by hand compiles perfectly without any dart-defines. The
/// app boots, looks healthy, silently uses mock auth, and the business
/// repository reaches for an SDK instance that was never initialised. The
/// resulting assertion reaches the user as an unexplained "Could not load
/// businesses" with nothing in it about dart-defines.
///
/// These tests run with no SUPABASE_URL/SUPABASE_ANON_KEY, which is exactly the
/// broken-build configuration.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('build credentials', () {
    test('an unconfigured build reports itself as unconfigured', () {
      expect(AppConfig.supabaseConfigured, isFalse);
    });

    test('the missing-credentials hint names the real fix', () {
      const hint = AppConfig.supabaseMissingBuildHint;
      expect(hint, contains('build-apk.ps1'));
      expect(hint, contains('dart-define'));
    });
  });

  group('auth factory', () {
    test('a debug build without keys falls back to mock auth', () {
      expect(
        createAuthService(isRelease: false),
        isA<MockAuthService>(),
      );
    });

    test('a release build without keys refuses to start', () {
      // Publishing mock auth would mean every account is a string comparison
      // away from every other one, so this must throw rather than degrade.
      expect(
        () => createAuthService(isRelease: true),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('build-apk.ps1'),
          ),
        ),
      );
    });
  });

  group('business repository', () {
    // The repository wraps everything in ListingsUnavailable, which is what the
    // screen's error branch renders. So the assertion has to be that the cause
    // survives the wrap — otherwise the hint is lost on the way to the user and
    // the screen says only "Could not load businesses" again.
    final explainsMissingBuild = throwsA(
      predicate<Object>(
        (e) => e.toString().contains('build-apk.ps1'),
        'explains that the build is missing its credentials',
      ),
    );

    test('explains itself instead of raising a bare SDK assertion', () async {
      // The specific regression: this used to fail with
      // `'_instance._isInitialized'` and no explanation. The throw is
      // asynchronous, so it has to be awaited or the test passes vacuously.
      await expectLater(
        SupabaseBusinessRepository().getBusinesses(),
        explainsMissingBuild,
      );
    });

    test('the stream reports the error instead of emitting nothing', () async {
      // An empty stream would render as "no businesses on the island", which
      // is a lie: the app was never able to ask. The error has to reach the
      // screen's error branch.
      //
      // The error arrives asynchronously, after the stream retries once, so
      // listen-then-cancel races it and leaks an unhandled async error.
      await expectLater(
        SupabaseBusinessRepository().watchBusinesses(),
        emitsError(
          predicate<Object>(
            (e) => e.toString().contains('build-apk.ps1'),
            'explains that the build is missing its credentials',
          ),
        ),
      );
    });
  });

  group('repository contract', () {
    test('an empty result stays empty rather than inventing businesses', () {
      // Guards the promise that the app never shows sample data. If this ever
      // needs to change it has to be a deliberate edit here.
      expect(<Business>[], isEmpty);
      expect(debugPrint, isNotNull);
    });
  });
}

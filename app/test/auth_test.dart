import 'package:antigua_business_map/models/user.dart';
import 'package:antigua_business_map/services/auth_service.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:antigua_business_map/services/mock_auth_service.dart';
import 'package:antigua_business_map/services/supabase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

void main() {
  late MockAuthService service;
  late AuthSession session;

  setUp(() {
    service = MockAuthService(latency: Duration.zero);
    session = AuthSession(service: service);
  });

  tearDown(() => session.dispose());

  group('registration', () {
    test('creates an account and signs in', () async {
      final result = await session.register(
        'owner@barbuda.com',
        'correcthorse',
        'Sam',
      );

      expect(result.isSuccess, isTrue);
      expect(session.isSignedIn, isTrue);
      expect(session.user!.email, 'owner@barbuda.com');
      expect(session.user!.displayName, 'Sam');
    });

    test('new accounts are regular users, never admin', () async {
      await session.register('new@example.com', 'correcthorse', 'New');
      expect(session.role, UserRole.user);
      expect(session.canAccessBusinessDashboard(), isFalse);
      expect(session.canAccessTeamDashboard(), isFalse);
    });

    test('rejects a duplicate email', () async {
      await session.register('dup@example.com', 'correcthorse', 'First');

      final second = await session.register(
        'dup@example.com',
        'differentpassword',
        'Second',
      );

      expect(second.isSuccess, isFalse);
      expect(second.errorMessage, contains('already'));
    });

    test('rejects a weak password before it reaches the backend', () async {
      final result = await session.register('weak@example.com', 'short', 'W');
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('8 characters'));
    });

    test('rejects a malformed email', () async {
      final result = await session.register(
        'not-an-email',
        'correcthorse',
        'X',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('email'));
    });

    test('email is normalised, so case does not create two accounts', () async {
      await session.register('Mixed@Example.com', 'correcthorse', 'A');
      final duplicate = await session.register(
        'mixed@example.com',
        'correcthorse',
        'B',
      );

      expect(duplicate.isSuccess, isFalse);
    });
  });

  group('sign in', () {
    test(
      'wrong password gives the same message as an unknown account',
      () async {
        // Identical messages, so the form cannot be used to discover which
        // emails have accounts.
        await session.register('known@example.com', 'correcthorse', 'K');

        final wrongPassword = await session.signIn(
          'known@example.com',
          'wrongpassword',
        );
        final unknownAccount = await session.signIn(
          'nobody@example.com',
          'wrongpassword',
        );

        expect(wrongPassword.errorMessage, unknownAccount.errorMessage);
      },
    );

    test('sign out clears the session', () async {
      await session.register('out@example.com', 'correcthorse', 'O');
      expect(session.isSignedIn, isTrue);

      await session.signOut();
      expect(session.isSignedIn, isFalse);
      expect(session.role, UserRole.user);
    });
  });

  group('permissions', () {
    test('a user cannot reach the business or team areas', () async {
      await session.register('plain@example.com', 'correcthorse', 'P');

      expect(session.canAccessBusinessDashboard(), isFalse);
      expect(session.canAccessTeamDashboard(), isFalse);
    });

    test('a business admin cannot reach the team area', () async {
      await session.register('boss@example.com', 'correcthorse', 'Boss');
      await session.setRole(UserRole.businessAdmin);

      expect(session.canAccessBusinessDashboard(), isTrue);
      expect(session.canAccessTeamDashboard(), isFalse);
    });

    test('a team admin reaches both', () async {
      await session.register('staff@example.com', 'correcthorse', 'Staff');
      await session.setRole(UserRole.teamAdmin);

      // Both, as the name says. The team maintains listings for owners who
      // will not, so it needs the business screens as well.
      expect(session.canAccessTeamDashboard(), isTrue);
      expect(session.canAccessBusinessDashboard(), isTrue);
    });

    test('business ids gate editing', () async {
      await session.register('owner@example.com', 'correcthorse', 'Owner');
      await session.setRole(UserRole.businessAdmin);

      // No assigned businesses yet, so nothing is editable.
      expect(session.canEditBusiness('any'), isFalse);
    });
  });

  group('supabase error mapping', () {
    // The mapping is what keeps a raw exception out of the UI. Tested here
    // because these strings change between Supabase versions and the failure
    // mode is an unhelpful message, not a crash.
    test('maps known messages to specific failures', () {
      expect(
        SupabaseAuthService.mapError(
          const AuthException('Invalid login credentials'),
        ),
        AuthFailure.invalidCredentials,
      );
      expect(
        SupabaseAuthService.mapError(
          const AuthException('User already registered'),
        ),
        AuthFailure.emailAlreadyInUse,
      );
      expect(
        SupabaseAuthService.mapError(
          const AuthException('Email not valid'),
        ),
        AuthFailure.invalidEmail,
      );
      expect(
        SupabaseAuthService.mapError(
          const AuthException('fetch failed'),
        ),
        AuthFailure.networkUnavailable,
      );
    });

    test('an unrecognised message becomes unknown, not a guess', () {
      expect(
        SupabaseAuthService.mapError(const AuthException('something new')),
        AuthFailure.unknown,
      );
    });

    test('every failure has a message a user can read', () {
      for (final failure in AuthFailure.values) {
        expect(failure.message, isNotEmpty);
        expect(failure.message, isNot(contains('Exception')));
      }
    });
  });
}

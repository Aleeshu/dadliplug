import 'dart:async';

import 'package:antigua_business_map/models/user.dart';
import 'package:antigua_business_map/services/auth_service.dart';

/// In-memory auth, used until the Firebase project exists.
///
/// Phase 2 needs working screens and tests, not a live backend. This keeps the
/// app fully runnable so the UI can be reviewed on a phone, and it makes the
/// auth tests deterministic instead of network-dependent.
///
/// Not secure and not for release. Swapped for `FirebaseAuthService` in Phase 5.
///
/// A deliberate limitation: accounts live in memory and are gone when the app
/// restarts. That is fine for UI review and actively useful for testing — every
/// cold start is a clean slate, so there is no stale test account left behind.
class MockAuthService implements AuthService {
  MockAuthService({this._latency = const Duration(milliseconds: 400)});

  final Duration _latency;
  final _controller = StreamController<AppUser?>.broadcast();

  final Map<String, _MockAccount> _accounts = {};

  AppUser? _current;
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  /// Call once at startup. Simulates Firebase's session restore.
  Future<void> initialize() async {
    await _delay();
    _initialized = true;
  }

  @override
  Future<AuthResult> signInWithEmail(String email, String password) async {
    await _delay();

    final normalised = _normalise(email);
    if (!_isValidEmail(normalised)) {
      return const AuthError(AuthFailure.invalidEmail);
    }

    final account = _accounts[normalised];
    if (account == null || account.password != password) {
      return const AuthError(AuthFailure.invalidCredentials);
    }

    return _emit(account.user);
  }

  @override
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await _delay();

    final normalised = _normalise(email);
    if (!_isValidEmail(normalised)) {
      return const AuthError(AuthFailure.invalidEmail);
    }
    if (password.length < 8) {
      return const AuthError(AuthFailure.weakPassword);
    }
    if (_accounts.containsKey(normalised)) {
      return const AuthError(AuthFailure.emailAlreadyInUse);
    }

    final user = AppUser(
      id: 'mock_${_accounts.length + 1}',
      email: normalised,
      displayName: displayName?.trim().isEmpty ?? true
          ? null
          : displayName!.trim(),
    );

    _accounts[normalised] = _MockAccount(password: password, user: user);
    return _emit(user);
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    await _delay();
    // Stands in for the platform chooser. Creates an account if there is not
    // one, matching how Google sign-in behaves for a first-time user.
    const email = 'demo@antiguamap.app';
    final existing = _accounts[email];
    if (existing != null) return _emit(existing.user);

    const user = AppUser(
      id: 'mock_google',
      email: email,
      displayName: 'Demo User',
    );
    _accounts[email] = const _MockAccount(password: '', user: user);
    return _emit(user);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _delay();
    // Deliberately does not reveal whether the account exists. Reporting that
    // would turn the reset form into a way to enumerate customers.
  }

  @override
  Future<void> signOut() async {
    await _delay();
    _current = null;
    _controller.add(null);
  }

  /// Test seam. Escalates a user's role without going through a backend call.
  @override
  Future<void> setRole(UserRole role) async {
    final user = _current;
    if (user == null) return;
    _current = user.copyWith(role: role);
    _controller.add(_current);
  }

  AuthResult _emit(AppUser user) {
    _current = user;
    _controller.add(user);
    return AuthSuccess(user);
  }

  Future<void> _delay() => Future<void>.delayed(_latency);

  static String _normalise(String email) => email.trim().toLowerCase();

  static bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
}

class _MockAccount {
  const _MockAccount({required this.password, required this.user});

  final String password;
  final AppUser user;
}

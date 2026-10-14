import 'dart:async';

import 'package:antigua_business_map/models/user.dart';
import 'package:antigua_business_map/services/auth_service.dart';
import 'package:flutter/foundation.dart';

/// Session state, shared by both auth implementations.
///
/// Screens talk to this, never to [AuthService] directly, so swapping
/// `MockAuthService` for `SupabaseAuthService` changes nothing above this line.
///
/// A [ChangeNotifier] because the user changes without a navigation event.
/// Signing out, or claiming a role, both mutate this object in place: the
/// profile screen does not rebuild, so it kept showing a signed-in user after
/// sign-out until the app was restarted. Widgets that read [user] must wrap
/// themselves in a `ListenableBuilder`.
class AuthSession extends ChangeNotifier {
  AuthSession({required AuthService service}) : _service = service {
    _user = service.currentUser;
    _subscription = service.authStateChanges.listen(_setUser);
  }

  final AuthService _service;
  late final StreamSubscription<AppUser?> _subscription;

  AppUser? _user;

  AppUser? get user => _user;
  bool get isSignedIn => _user != null;
  UserRole get role => _user?.role ?? UserRole.user;

  /// False until the backend has finished checking for an existing session.
  /// Guards against flashing the sign-in screen at a signed-in user.
  bool get isInitialized => _service.isInitialized;

  /// What the current user is allowed to reach.
  ///
  /// Derived from the role rather than checked at each route, so a deep link
  /// into `/team` from a regular user is refused rather than rendered.
  bool canAccessBusinessDashboard() => role == UserRole.businessAdmin;

  bool canAccessTeamDashboard() => role == UserRole.teamAdmin;

  /// Whether this user administers the given business.
  bool canEditBusiness(String businessId) =>
      _user?.businessIds.contains(businessId) ?? false;

  /// Whether this user may act on a review for this business. Used by the
  /// business admin screens to gate replies and disputes.
  bool canReviewFor(String businessId) => canEditBusiness(businessId);

  /// Applies the user immediately rather than waiting for the auth stream.
  ///
  /// A broadcast stream delivers asynchronously, so reading `user` straight
  /// after `signIn` returned would still give the previous value. Every screen
  /// that navigates on success hits that race, so the result is applied here
  /// and the stream is only a backstop for changes made elsewhere.
  Future<AuthResult> signIn(String email, String password) async {
    final result = await _service.signInWithEmail(email, password);
    if (result case AuthSuccess(:final user)) _setUser(user);
    return result;
  }

  Future<AuthResult> register(
    String email,
    String password,
    String? name,
  ) async {
    final result = await _service.registerWithEmail(
      email: email,
      password: password,
      displayName: name,
    );
    if (result case AuthSuccess(:final user)) _setUser(user);
    return result;
  }

  Future<AuthResult> signInWithGoogle() async {
    final result = await _service.signInWithGoogle();
    if (result case AuthSuccess(:final user)) _setUser(user);
    return result;
  }

  Future<void> sendPasswordReset(String email) =>
      _service.sendPasswordReset(email);

  /// Development-only. Changes the signed-in user's role.
  ///
  /// Goes through [AuthService.setRole] rather than writing `_user` directly,
  /// so the session and the service cannot disagree about who is signed in.
  Future<void> setRole(UserRole role) async {
    await _service.setRole(role);
    _setUser(_service.currentUser);
  }

  Future<void> signOut() async {
    await _service.signOut();
    _setUser(null);
  }

  /// Promotes this user to team admin while the island has none.
  ///
  /// Re-reads the session afterwards, because the role lives in the database
  /// and this screen's copy of the user is otherwise unchanged — the tab bar
  /// would keep showing the user tabs until a restart.
  Future<bool> claimTeamAdmin() async {
    final claimed = await _service.claimTeamAdmin();
    if (!claimed) return false;

    _setUser(await _service.reloadUser());
    return true;
  }

  void _setUser(AppUser? user) {
    // Compare on the fields that change what a screen shows. The previous
    // check ignored businessIds, so a role or ownership change that kept the
    // same id and role would silently not notify.
    if (_user?.id == user?.id &&
        _user?.role == user?.role &&
        _user?.email == user?.email &&
        _user?.displayName == user?.displayName) {
      return;
    }
    _user = user;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

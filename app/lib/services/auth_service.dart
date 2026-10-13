import 'package:antigua_business_map/models/user.dart';

/// Errors the UI can show a real message for.
///
/// Firebase throws strings, which cannot be switched on and force every screen
/// to parse prose. Mapping to a closed set here means the sign-in screen can
/// say "that email is already registered" instead of dumping an exception.
enum AuthFailure {
  /// Wrong email or password. Deliberately vague — telling a caller which one
  /// was wrong leaks whether an account exists.
  invalidCredentials,

  emailAlreadyInUse,
  weakPassword,
  invalidEmail,
  userNotFound,
  tooManyAttempts,
  networkUnavailable,
  notSignedIn,

  /// Should not happen. Logged and reported, never shown raw.
  unknown,
}

extension AuthFailureX on AuthFailure {
  String get message => switch (this) {
    AuthFailure.invalidCredentials => 'That email and password do not match.',
    AuthFailure.emailAlreadyInUse =>
      'There is already an account with that email. Try signing in.',
    AuthFailure.weakPassword =>
      'Choose a longer password. At least 8 characters.',
    AuthFailure.invalidEmail => 'That does not look like an email address.',
    AuthFailure.userNotFound => 'No account found with that email.',
    AuthFailure.tooManyAttempts =>
      'Too many attempts. Wait a few minutes and try again.',
    AuthFailure.networkUnavailable =>
      'No connection. Check your data and try again.',
    AuthFailure.notSignedIn => 'You need to sign in first.',
    AuthFailure.unknown => 'Something went wrong. Please try again.',
  };

  /// Whether retrying without changing anything could work.
  bool get isRetryable =>
      this == AuthFailure.networkUnavailable || this == AuthFailure.unknown;
}

/// Result of an auth call. Either a user or a reason there isn't one.
sealed class AuthResult {
  const AuthResult();

  bool get isSuccess => this is AuthSuccess;

  String? get errorMessage =>
      this is AuthError ? (this as AuthError).message : null;
}

class AuthSuccess extends AuthResult {
  const AuthSuccess(this.user);

  final AppUser user;
}

class AuthError extends AuthResult {
  const AuthError(this.failure);

  final AuthFailure failure;

  String get message => failure.message;
}

/// Authentication backend.
///
/// An interface rather than direct Firebase calls so the app can run — and be
/// tested — before the Firebase project exists. `MockAuthService` backs the
/// Phase 2 screens; `FirebaseAuthService` swaps in for Phase 5 with no change
/// above this line.
abstract interface class AuthService {
  /// Emits on every sign in, sign out, or token refresh.
  Stream<AppUser?> get authStateChanges;

  AppUser? get currentUser;

  Future<AuthResult> signInWithEmail(String email, String password);

  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  Future<AuthResult> signInWithGoogle();

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();

  /// Promotes the signed-in user to team admin, but only while the island has
  /// none at all.
  ///
  /// Without this the first team member is locked out permanently: the role
  /// trigger correctly refuses any non-admin from changing a role, so someone
  /// has to be an admin before anyone can become one. The database function
  /// closes the window the moment the first admin exists.
  ///
  /// Returns false once an admin exists, or if it could not promote.
  Future<bool> claimTeamAdmin() async => false;

  /// Changes the signed-in user's role.
  ///
  /// Only the mock service implements this. Roles are granted by the team
  /// through Supabase, and a client-side role change against a real backend
  /// would be meaningless — Row Level Security decides, not the app.
  /// Part of the interface so `AuthSession` does not need to know which one it
  /// is holding.
  Future<void> setRole(UserRole role) async {}

  /// Re-reads the signed-in user from the backend.
  ///
  /// Needed after anything that changes the stored profile — a role promotion,
  /// or an admin being assigned a business. Without it the app keeps showing
  /// whatever role it last saw until a restart, which looks like the change did
  /// not work.
  Future<AppUser?> reloadUser() async => currentUser;

  /// True once the service has finished checking for an existing session.
  /// Guards against briefly showing the sign-in screen to a signed-in user.
  bool get isInitialized;
}

import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/models/user.dart';
import 'package:antigua_business_map/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [AuthService].
///
/// Roles live in a `profiles` table rather than in Supabase auth metadata,
/// because the team changes them by hand and needs to query them alongside
/// businesses. Row Level Security reads the role from that same table, so
/// neither the client nor the user can escalate their own role.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  /// Resolved on first use, not in the constructor.
  ///
  /// Reading `Supabase.instance` during construction asserts when
  /// `Supabase.initialize` has not run yet. That throw happens before
  /// `runApp`, so the app dies to a black screen with nothing on it and
  /// nothing in logcat the user can act on. Deferring the lookup means startup
  /// order in `main.dart` cannot cause a crash, and a missing initialisation
  /// surfaces as an ordinary query failure the UI already handles.
  late final SupabaseClient _db = _injected ?? Supabase.instance.client;

  /// `_googleSignIn` is created on first use because v7 requires an explicit
  /// `initialize()` with the client ids before any sign-in call.
  GoogleSignIn? _googleSignIn;

  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  AppUser? get currentUser {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    return _toAppUser(user, null);
  }

  @override
  Stream<AppUser?> get authStateChanges =>
      _db.auth.onAuthStateChange.asyncMap((event) async {
        // `initialSession` fires once on startup with the restored session.
        // That is what flips `_initialized`, so the app can tell "still
        // checking" apart from "definitely signed out".
        if (event.event == AuthChangeEvent.initialSession) _initialized = true;
        if (event.session == null) return null;
        return _loadUser(event.session!.user.id);
      });

  @override
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final response = await _db.auth
          .signInWithPassword(email: email.trim(), password: password)
          .timeout(_timeout);
      return AuthSuccess(await _loadUser(response.user!.id));
    } catch (e) {
      return AuthError(mapError(e));
    }
  }

  @override
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final result = await _db.auth
          .signUp(
            email: email.trim(),
            password: password,
            // Must be allow-listed in the Supabase dashboard. Left unset it
            // redirects to the placeholder Site URL and nobody can finish
            // signing up.
            emailRedirectTo: AppConfig.privacyPolicyUrl.isEmpty
                ? null
                : AppConfig.privacyPolicyUrl,
            data: {'display_name': displayName?.trim()},
          )
          .timeout(_timeout);

      final user = result.user;
      if (user == null) return const AuthError(AuthFailure.unknown);

      // The profile row is created by a trigger on auth.users, so a failed
      // read here is not fatal to sign-up.
      return AuthSuccess(await _loadUser(user.id));
    } catch (e) {
      return AuthError(mapError(e));
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      final signIn = _ensureGoogleSignIn();

      // `attemptLightweightAuthentication` first, so a returning user skips the
      // account chooser entirely. Falls through to `authenticate` when there
      // is no usable cached credential.
      var account = await signIn.attemptLightweightAuthentication();
      account ??= await signIn.authenticate();

      final idToken = account.authentication.idToken;
      if (idToken == null) return const AuthError(AuthFailure.unknown);

      final response = await _db.auth
          .signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
          )
          .timeout(_timeout);

      final user = response.user;
      if (user == null) return const AuthError(AuthFailure.unknown);
      return AuthSuccess(await _loadUser(user.id));
    } catch (e) {
      // Logged because the screen only ever says "Something went wrong", and
      // Google sign-in failed that way for weeks with nothing to go on. The
      // cause is almost always configuration (SHA-1, client ids, Supabase's
      // Google provider), and the exception names which.
      debugPrint('Google sign-in failed: $e');
      return AuthError(mapError(e));
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    // Errors propagate as `AuthException`, which the calling screen maps with
    // `mapError`. Deliberately not swallowed: a silent failure here reads as
    // "email sent" when nothing was sent.
    await _db.auth
        .resetPasswordForEmail(
          email.trim(),
          redirectTo: AppConfig.privacyPolicyUrl.isEmpty
              ? null
              : AppConfig.privacyPolicyUrl,
        )
        .timeout(_timeout);
  }

  @override
  Future<void> signOut() => _db.auth.signOut();

  /// Promotes the caller to team admin while the window is open.
  ///
  /// The window is closed in the database, not here — this only reports what
  /// the function decided. If it returns false, someone already claimed it or
  /// the profile row is missing, and neither is worth retrying.
  @override
  Future<bool> claimTeamAdmin() async {
    try {
      return await _db.rpc<bool>('claim_team_admin').timeout(_timeout);
    } catch (error) {
      debugPrint('claim_team_admin failed: $error');
      return false;
    }
  }

  /// Intentionally does nothing.
  ///
  /// Roles come from the `profiles` table and are granted by the team. A
  /// client-side role change would be a no-op at best, and Row Level Security
  /// would reject the resulting queries anyway — so pretending to support it
  /// would hide a real permission problem.
  @override
  Future<void> setRole(UserRole role) async {}

  @override
  Future<AppUser?> reloadUser() async {
    final id = _db.auth.currentUser?.id;
    if (id == null) return null;
    return _loadUser(id);
  }

  GoogleSignIn _ensureGoogleSignIn() {
    return _googleSignIn ??= GoogleSignIn.instance;
  }

  /// Initialises Google sign-in with the right client id.
  ///
  /// Android needs the *Web application* client id as `serverClientId`,
  /// because `google_sign_in` v7 goes through Credential Manager there and
  /// Credential Manager only accepts ID tokens minted by a Web-type client.
  /// The app's own client id identifies it to the platform.
  ///
  /// Both values are required on Android. An Android-type client id passed as
  /// `serverClientId` fails at runtime with an error that reads like a network
  /// problem rather than a configuration one.
  Future<void> initializeGoogleSignIn() async {
    if (AppConfig.googleSignInClientId.isEmpty) return;

    await _ensureGoogleSignIn().initialize(
      clientId: AppConfig.googleSignInClientId,
      serverClientId: AppConfig.googleSignInServerClientId.isEmpty
          ? null
          : AppConfig.googleSignInServerClientId,
    );
  }

  Future<AppUser> _loadUser(String id) async {
    final profile = await _db
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    return _toAppUser(_db.auth.currentUser, profile, fallbackId: id);
  }

  AppUser _toAppUser(
    User? user,
    Object? rawProfile, {
    String? fallbackId,
  }) {
    final profile = rawProfile is Map<String, dynamic> ? rawProfile : null;

    return AppUser(
      id: user?.id ?? profile?['id'] as String? ?? fallbackId ?? '',
      email: user?.email ?? profile?['email'] as String? ?? '',
      displayName:
          profile?['display_name'] as String? ??
          user?.userMetadata?['display_name'] as String?,
      role: parseRole(profile?['role'] as String?),
      businessIds: parseIds(profile?['business_ids']),
    );
  }

  static const Duration _timeout = Duration(seconds: 20);

  static UserRole parseRole(String? raw) => switch (raw) {
    'business_admin' => UserRole.businessAdmin,
    'team_admin' => UserRole.teamAdmin,
    _ => UserRole.user,
  };

  static List<String> parseIds(Object? raw) =>
      raw is List ? raw.map((e) => '$e').toList() : const [];

  /// Supabase throws `AuthException` with a message string. Mapping it here
  /// keeps that parsing out of every screen.
  ///
  /// Ordered deliberately. "Email already registered" contains both "email"
  /// and "registered", so an email-validity check placed above the duplicate
  /// check would swallow it and report a format problem instead. There is a
  /// test for exactly that.
  static AuthFailure mapError(Object error) {
    if (error is! AuthException) return AuthFailure.unknown;
    final message = error.message.toLowerCase();

    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return AuthFailure.emailAlreadyInUse;
    }
    if (message.contains('password should be') ||
        message.contains('weak password')) {
      return AuthFailure.weakPassword;
    }
    if (message.contains('invalid email') ||
        message.contains('email not valid') ||
        message.contains('invalid format')) {
      return AuthFailure.invalidEmail;
    }
    if (message.contains('invalid login') ||
        message.contains('invalid credentials')) {
      return AuthFailure.invalidCredentials;
    }
    if (message.contains('rate limit') || message.contains('too many')) {
      return AuthFailure.tooManyAttempts;
    }
    if (message.contains('network') ||
        message.contains('failed to fetch') ||
        // Supabase says "fetch failed", the browser says "failed to fetch".
        // Both mean the request never reached the server.
        message.contains('fetch failed') ||
        message.contains('socket') ||
        message.contains('timeout')) {
      return AuthFailure.networkUnavailable;
    }
    return AuthFailure.unknown;
  }
}

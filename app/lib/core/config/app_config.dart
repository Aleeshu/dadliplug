/// Compile-time configuration.
///
/// Every value comes from `--dart-define` at build time. No secrets in the
/// repository.
///
/// The Supabase anon key is safe to ship in the app — it is protected by Row
/// Level Security, not by secrecy. What must never appear here is the
/// `service_role` key, which bypasses RLS entirely.
library;

abstract final class AppConfig {
  static const String appName = 'IslandAds';

  /// Short label used where the full name does not fit.
  static const String appShortName = 'IslandAds';

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static const String supabaseUrlDev = String.fromEnvironment(
    'SUPABASE_URL_DEV',
  );
  static const String supabaseAnonKeyDev = String.fromEnvironment(
    'SUPABASE_ANON_KEY_DEV',
  );

  /// Whether this build was given the credentials it needs to reach Supabase.
  ///
  /// Single source of truth, so `main`, the auth factory and the business
  /// repository cannot disagree about it. When they did, a build with no keys
  /// booted on the mock auth service while the repository still reached for
  /// `Supabase.instance`, and the resulting assertion surfaced to the user as an
  /// unexplained "Could not load businesses".
  static bool get supabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Actionable description of a missing-credentials build.
  static const String supabaseMissingBuildHint =
      'This build has no Supabase credentials, so it cannot load data. Build '
      'with scripts/build-apk.ps1, which passes the dart-defines from .env. '
      'Do not call `flutter build` directly — it succeeds and produces an app '
      'that talks to nothing.';

  /// Google Maps SDK key. Must be restricted by bundle id and package name in
  /// Google Cloud before release.
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );

  /// Whether the real map can be shown.
  ///
  /// The Android SDK renders a blank tile layer when the key is missing or
  /// invalid — no exception, no error message, just a black screen that covers
  /// everything. So the map is only built when a key is present.
  static bool get hasGoogleMapsKey => googleMapsApiKey.isNotEmpty;

  /// Google sign-in client ids. Android and iOS need different ones, and
  /// swapping them fails with an error that looks like a network problem.
  ///
  /// The important subtlety: on Android, `google_sign_in` v7 uses Credential
  /// Manager, which returns an ID token minted only by a **Web-type** OAuth
  /// client. An Android-type client id does not work here at all — which is
  /// why there are two values rather than one.
  ///
  /// [googleSignInServerClientId] is passed to Google Sign-In as
  /// `serverClientId`. [googleSignInClientId] identifies the app itself to
  /// Credential Manager and to the iOS flow.
  static const String googleSignInClientId = String.fromEnvironment(
    'GOOGLE_SIGN_IN_CLIENT_ID',
  );

  /// From the **Web application** OAuth client. Required for Android sign-in.
  static const String googleSignInServerClientId = String.fromEnvironment(
    'GOOGLE_SIGN_IN_WEB_CLIENT_ID',
  );

  /// Whether Google sign-in is usable in this build.
  ///
  /// Android needs the web client id. Without it, the sign-in button throws
  /// something that reads like a network error, so it is better to hide the
  /// button than to offer one that cannot work.
  static bool get hasGoogleSignIn =>
      googleSignInClientId.isNotEmpty && googleSignInServerClientId.isNotEmpty;

  /// How long a trial listing stays live without payment, and how long a
  /// lapsed business keeps its listing before removal.
  static const Duration trialDuration = Duration(days: 3);
  static const Duration paymentGracePeriod = Duration(days: 7);

  /// The rotating Spotlight board. Ten slots, per the plan.
  static const int spotlightSlots = 10;

  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
  );
  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
  );
}

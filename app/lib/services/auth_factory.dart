import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/models/user.dart';
import 'package:antigua_business_map/services/auth_service.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:antigua_business_map/services/mock_auth_service.dart';
import 'package:antigua_business_map/services/supabase_auth_service.dart';

/// Builds the auth service the app runs on.
///
/// Uses Supabase when credentials are supplied at build time, and falls back
/// to the in-memory mock otherwise. That fallback is what lets the app run on a
/// phone today, before the Supabase project exists.
///
/// The release guard is deliberate. A debug build without keys is fine; a
/// release build without them would ship mock auth, where every account is a
/// string comparison away from any other. Better to fail at startup than to
/// publish that.
AuthService createAuthService({required bool isRelease}) {
  if (!AppConfig.supabaseConfigured) {
    if (isRelease) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_ANON_KEY are required in release builds. '
        '${AppConfig.supabaseMissingBuildHint}',
      );
    }
    return MockAuthService();
  }

  return SupabaseAuthService();
}

/// Development-only role switching.
///
/// Phase 2 has no Supabase project yet, so there is no way to promote an
/// account to `business_admin` or `team_admin` through the app. This lets the
/// team reach all three tab sets on a real device.
///
/// Only works while the mock service is in use, and `isEnabled` returns false
/// otherwise. Against a real backend a client-side role is meaningless anyway
/// — Row Level Security decides, not the app.
class RoleSwitcherController {
  RoleSwitcherController(this._session);

  final AuthSession? _session;

  bool get isEnabled => _session != null;

  Future<void> setRole(UserRole role) async => _session?.setRole(role);
}

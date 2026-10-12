import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/core/routing/app_router.dart';
import 'package:antigua_business_map/core/theme/app_theme.dart';
import 'package:antigua_business_map/services/auth_factory.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:antigua_business_map/services/mock_auth_service.dart';
import 'package:antigua_business_map/services/supabase_auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const isRelease = kReleaseMode;

  // Supabase must be initialised **before** the auth service is constructed.
  // `SupabaseAuthService` reaches for `Supabase.instance` in its constructor,
  // which asserts if initialisation has not happened yet — and the result is a
  // black screen with no explanation, because the throw happens before
  // `runApp`.
  //
  // This only bites when keys are actually supplied. Without them the factory
  // returns the mock, which needs no client, so the misordering hides until the
  // day someone builds with real keys.
  final hasSupabase =
      AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty;
  if (hasSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // Supabase renamed `anonKey` to `publishableKey`. Same value, same
      // meaning: it is public and protected by Row Level Security, not by
      // secrecy. The `service_role` key bypasses RLS and must never ship.
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  final authService = createAuthService(isRelease: isRelease);

  // Google sign-in must be initialised before any sign-in call, and it needs
  // both client ids. A failure here must not stop the app from starting —
  // email sign-in still works without Google.
  if (authService is SupabaseAuthService && AppConfig.hasGoogleSignIn) {
    try {
      await authService.initializeGoogleSignIn();
    } catch (e) {
      debugPrint('Google sign-in unavailable: $e');
    }
  }

  final session = AuthSession(service: authService);

  runApp(
    AntiguaMapApp(
      session: session,
      // Only enabled while the mock is in use. Against Supabase, roles come
      // from the database and a client-side switch would just be a lie.
      roleSwitcher: authService is MockAuthService
          ? RoleSwitcherController(session)
          : RoleSwitcherController(null),
    ),
  );
}

class AntiguaMapApp extends StatefulWidget {
  const AntiguaMapApp({
    required this.session,
    required this.roleSwitcher,
    super.key,
  });

  final AuthSession session;
  final RoleSwitcherController roleSwitcher;

  @override
  State<AntiguaMapApp> createState() => _AntiguaMapAppState();
}

class _AntiguaMapAppState extends State<AntiguaMapApp> {
  // Built once. A router rebuilt on every build throws away navigation state,
  // and here it would also re-read the session mid-redirect.
  late final GoRouter _router = buildRouter(
    session: widget.session,
    roleSwitcher: widget.roleSwitcher,
  );

  @override
  void dispose() {
    widget.session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // Follows the device. The prototype supports both, and a business app
        // gets used in the evening.
        routerConfig: _router,
      ),
    );
  }
}

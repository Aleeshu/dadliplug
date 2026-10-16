import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Push notifications (Firebase Cloud Messaging).
///
/// Permission is asked at the moment it means something — turning on a
/// business's bell, or opening your business tools — never at first launch,
/// where a cold "allow notifications?" is mostly refused. After that, the
/// token is refreshed quietly on each start.
///
/// Sending is server-side (`supabase/functions/push`); the phone only
/// registers where to send.
abstract final class PushService {
  static bool _ready = false;
  static StreamSubscription<String>? _refresh;

  /// Called on a notification tap with the screen to open, e.g.
  /// `/announcements`. Set by the app once the router exists.
  static void Function(String route)? onOpenRoute;

  /// Starts Firebase. Safe to call when Firebase is not configured for this
  /// platform: push is a nicety, and its absence must not stop the app.
  static Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Firebase.initializeApp();
      _ready = true;

      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _open(initial);

      // Already allowed earlier: keep the token current, without asking.
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        unawaited(_register());
      }
    } catch (e) {
      debugPrint('Push unavailable: $e');
    }
  }

  static void _open(RemoteMessage message) {
    final route = message.data['route'];
    if (route is String && route.startsWith('/')) onOpenRoute?.call(route);
  }

  /// Asks for permission (Android 13+ shows the system prompt) and registers
  /// this phone. Returns whether notifications are allowed.
  static Future<bool> enable() async {
    if (!_ready) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (allowed) await _register();
      return allowed;
    } catch (e) {
      debugPrint('Could not enable push: $e');
      return false;
    }
  }

  static bool _askedForBusiness = false;

  /// For a business owner opening their tools: review requests arrive there,
  /// so that is when to ask. Once per app session at most.
  static void enableForBusiness() {
    if (_askedForBusiness) return;
    _askedForBusiness = true;
    unawaited(enable());
  }

  static Future<void> _register() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;

    // The registration token, which the server's FCM v1 `messages:send`
    // takes as `message.token`. firebase_messaging 17 deprecates this for
    // register()/onRegistered, which yield an installation ID meant for a
    // newer direct-send path; until that is confirmed against our sender,
    // the proven token path stays.
    // ignore: deprecated_member_use
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _save(token);

    await _refresh?.cancel();
    // Same reason as getToken above: keeps the token the sender uses current.
    // ignore: deprecated_member_use
    _refresh = FirebaseMessaging.instance.onTokenRefresh.listen(_save);
  }

  static Future<void> _save(String token) async {
    try {
      await Supabase.instance.client.rpc<void>(
        'register_push_token',
        params: {'p_token': token, 'p_platform': 'android'},
      );
    } catch (e) {
      debugPrint('Push token not saved: $e');
    }
  }
}

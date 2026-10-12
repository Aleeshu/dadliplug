import 'dart:async';

import 'package:antigua_business_map/services/auth_service.dart';

/// Turns a thrown exception into something a user can read.
///
/// Supabase raises `AuthException`, the mock service raises nothing, and a dead
/// connection raises a `SocketException` or `TimeoutException`. Screens should
/// not have to know which, so it happens here once.
abstract final class SupabaseErrorMapper {
  static String describe(Object error) {
    if (error is AuthError) return error.message;
    if (error is TimeoutException) {
      return 'That took too long. Check your connection and try again.';
    }
    return AuthFailure.unknown.message;
  }
}

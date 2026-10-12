import 'package:antigua_business_map/core/routing/stub_scaffold.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:flutter/material.dart';

/// Phase 2 stub. Holds visit history and review requests, which the profile
/// screen now renders. The store itself lands with the Supabase layer in
/// Phase 5.
class YourPlacesScreen extends StatelessWidget {
  const YourPlacesScreen({required this.session, super.key});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    if (!session.isSignedIn) return const _SignInPrompt();
    return const StubScaffold(title: 'Your places', phase: '5');
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) => const StubScaffold(
    title: 'Your places',
    phase: '2',
  );
}

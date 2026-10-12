import 'package:antigua_business_map/core/routing/stub_scaffold.dart';
import 'package:flutter/material.dart';

/// Phase 1 stub. Analytics plus the customer review verification queue. The
/// queue is what gates who is allowed to review, so it is the screen that
/// makes the app's reviews trustworthy. Phase 7.
class BusinessDashboardScreen extends StatelessWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const StubScaffold(
    title: 'Dashboard',
    phase: '7',
  );
}

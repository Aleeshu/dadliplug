import 'package:antigua_business_map/core/routing/stub_scaffold.dart';
import 'package:flutter/material.dart';

/// Phase 1 stub. The customer's review verification queue, plus replies. The
/// queue is the most important screen for the app's credibility, since it is
/// what gates who is allowed to review. Phase 7.
class BusinessReviewsScreen extends StatelessWidget {
  const BusinessReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) => const StubScaffold(
    title: 'Reviews',
    phase: '7',
  );
}

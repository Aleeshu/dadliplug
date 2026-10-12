import 'package:antigua_business_map/core/routing/stub_scaffold.dart';
import 'package:flutter/material.dart';

/// Phase 1 stub. Reached from the Featured tab, or from a search result.
/// Ordering comes from the earned ranking. Phase 5.
class FeaturedScreen extends StatelessWidget {
  const FeaturedScreen({super.key});

  @override
  Widget build(BuildContext context) => const StubScaffold(
    title: 'Featured',
    phase: '5',
  );
}

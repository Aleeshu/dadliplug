import 'package:antigua_business_map/core/routing/stub_scaffold.dart';
import 'package:flutter/material.dart';

/// Phase 1 stub. Shows each business its score and the components behind it.
/// Being transparent about this is the point — a business paying $100 can see
/// exactly what it needs to improve. Phase 8.
class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) => const StubScaffold(
    title: 'Ranking',
    phase: '8',
  );
}

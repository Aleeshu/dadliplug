import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:antigua_business_map/services/user_places_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The user's own visit history and review requests.
///
/// This is the app's answer to "why should I come back", so it must never show
/// placeholder rows. An empty history is a real state and says so.
class YourPlacesScreen extends ConsumerWidget {
  const YourPlacesScreen({required this.session, super.key});

  final AuthSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilt on session changes, same reason as the profile screen: the
    // signed-out prompt and the signed-in list are different screens wearing
    // one widget, and signing out has to swap them immediately.
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _body(context, ref),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    final placesAsync = ref.watch(userPlacesProvider);
    final requestsAsync = ref.watch(reviewRequestsProvider);

    return Scaffold(
      backgroundColor: context.palette.app,
      appBar: AppBar(
        title: const Text('Your places'),
        backgroundColor: context.palette.app,
        surfaceTintColor: Colors.transparent,
      ),
      // Signed out is its own state. Without this the providers return an empty
      // list and the screen claims the user has never been anywhere, which is
      // a different and false claim than "we cannot tell yet".
      body: !session.isSignedIn
          ? _Message(
              icon: Icons.person_outline,
              title: 'Sign in to see your places',
              body:
                  'Your visits and any reviews you have asked for are kept '
                  'on your account.',
              action: FilledButton(
                onPressed: () => context.push('/sign-in'),
                child: const Text('Sign in'),
              ),
            )
          : placesAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: context.palette.red),
              ),
              error: (error, _) => _Message(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load your places',
                body: 'Check your connection and try again.',
                onRetry: () {
                  ref
                    ..invalidate(userPlacesProvider)
                    ..invalidate(reviewRequestsProvider);
                },
              ),
              data: (places) => RefreshIndicator(
                onRefresh: () async {
                  ref
                    ..invalidate(userPlacesProvider)
                    ..invalidate(reviewRequestsProvider);
                  await ref.read(userPlacesProvider.future);
                },
                child: places.isEmpty
                    // The honest empty state. Not "no visits yet" with invented
                    // suggestions to visit somewhere: the list is empty because the
                    // user has not been anywhere the app knows about.
                    ? const _Message(
                        icon: Icons.explore_outlined,
                        title: 'No places yet',
                        body:
                            'Places you visit show up here, along with any review '
                            'you have requested.',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(Insets.lg),
                        children: [
                          if (requestsAsync.hasValue &&
                              requestsAsync.value!.isNotEmpty) ...[
                            _ReviewRequests(requests: requestsAsync.value!),
                            const SizedBox(height: Insets.xl),
                          ],
                          for (final place in places) ...[
                            _PlaceTile(place: place),
                            const SizedBox(height: Insets.sm),
                          ],
                        ],
                      ),
              ),
            ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place});

  final UserPlace place;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final when = DateFormat.yMMMd().format(place.visitedAt.toLocal());

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Icon(Icons.place_outlined, color: palette.red, size: 22),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.businessName,
                  style: AppText.titleMedium.copyWith(color: palette.ink),
                ),
                const SizedBox(height: Insets.xxs),
                Text(
                  '$when · ${place.category?.shortLabel ?? 'Other'}',
                  style: AppText.bodyMedium.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
          // Spells out why a review is or is not possible, rather than leaving
          // a user guessing whether a button is missing.
          _ReviewBadge(place: place),
        ],
      ),
    );
  }
}

class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge({required this.place});

  final UserPlace place;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (label, bg, fg) = place.canReview
        ? ('Review', palette.goodBg, palette.good)
        : ('Awaiting approval', palette.surface, palette.muted);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: Insets.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Corners.pill),
      ),
      child: Text(
        label,
        style: AppText.labelMedium.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReviewRequests extends StatelessWidget {
  const _ReviewRequests({required this.requests});

  final List<ReviewRequestSummary> requests;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final open = requests
        .where((r) => r.status == ReviewRequestStatus.pending)
        .toList();

    if (open.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Waiting on a business',
          style: AppText.titleSmall.copyWith(color: palette.muted),
        ),
        const SizedBox(height: Insets.sm),
        for (final request in open)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.xs),
            child: Text(
              request.businessName,
              style: AppText.bodyMedium.copyWith(color: palette.ink),
            ),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.onRetry,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onRetry;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListView(
      // A scroll view, not a Column, so pull-to-refresh still works when the
      // list is empty.
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
        Icon(icon, size: 44, color: palette.muted),
        const SizedBox(height: Insets.lg),
        Center(
          child: Text(
            title,
            style: AppText.displayMedium.copyWith(color: palette.ink),
          ),
        ),
        const SizedBox(height: Insets.sm),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: Insets.lg),
          Center(child: action),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: Insets.lg),
          Center(
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
        ],
      ],
    );
  }
}

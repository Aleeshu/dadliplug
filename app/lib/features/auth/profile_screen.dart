import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/features/auth/auth_widgets.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/user.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:antigua_business_map/services/user_places_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The user's own account screen.
///
/// Holds visit history and their review requests. Visit history is what makes
/// "you have to have used the business to review it" enforceable and visible
/// rather than a hidden rule.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({
    required this.session,
    super.key,
  });

  final AuthSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The session is a ChangeNotifier, and this screen reads it directly. It
    // has to rebuild when the user changes or nothing updates in place:
    // signing out used to call Supabase successfully and leave the profile
    // showing the account until the app was restarted.
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _body(context, ref),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    final user = session.user;

    // Read from Supabase rather than being handed lists. These were
    // constructor arguments defaulting to empty, which rendered as "0 visits,
    // nothing requested" forever — indistinguishable from a user who really
    // had no history. Worse, the rows rendered a raw business UUID where the
    // name should be, which only surfaced once real data arrived.
    final placesAsync = ref.watch(userPlacesProvider);
    final requestsAsync = ref.watch(reviewRequestsProvider);
    final places = placesAsync.value ?? const <UserPlace>[];
    final requests = requestsAsync.value ?? const <ReviewRequestSummary>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (session.isSignedIn)
            IconButton(
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout, size: 20),
              tooltip: 'Sign out',
            ),
        ],
      ),
      body: user == null
          ? _SignedOut(onSignIn: () => context.push('/sign-in'))
          : ListView(
              padding: const EdgeInsets.all(Insets.giant),
              children: [
                _Identity(user: user),
                const SizedBox(height: Insets.giant),

                if (!session.isSignedIn)
                  const AuthPrompt()
                else ...[
                  _Stats(places: places, requests: requests),
                  const SizedBox(height: Insets.giant),
                  _PlacesSection(
                    title: 'Places you visited',
                    // There is no "I was here" button, and there must not be
                    // one: a self-reported tap verifies nothing (plan.md 8).
                    // Visits arrive with the QR check-in in Phase 6.
                    emptyLabel:
                        'Nothing yet. Visits are recorded when you check in '
                        'at a business.',
                    places: places,
                  ),
                  const SizedBox(height: Insets.giant),
                  _RequestsSection(requests: requests),
                ],

                const SizedBox(height: Insets.giant),
                _RoleExplainer(session: session),
              ],
            ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your visits and reviews stay on your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) await session.signOut();
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: palette.red,
          child: Text(
            _initials(user),
            style: AppText.titleLarge.copyWith(color: palette.onRed),
          ),
        ),
        const SizedBox(width: Insets.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName ?? 'Signed in',
                style: AppText.titleLarge.copyWith(color: palette.ink),
              ),
              const SizedBox(height: Insets.xxs),
              Text(
                user.email,
                style: AppText.bodyMedium.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Falls back to the email's first letter when there is no display name.
  static String _initials(AppUser user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name
          .split(RegExp(r'\s+'))
          .take(2)
          .map((p) => p[0])
          .join()
          .toUpperCase();
    }
    final email = user.email.trim();
    return email.isEmpty ? '?' : email[0].toUpperCase();
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.places, required this.requests});

  final List<UserPlace> places;
  final List<ReviewRequestSummary> requests;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pending = requests
        .where((r) => r.status == ReviewRequestStatus.pending)
        .length;
    // A request is "approved" once the business confirmed the visit, which is
    // when a review becomes possible. Nothing here counts a review as written
    // because reviews themselves land in Phase 6.
    final approved = requests
        .where((r) => r.status == ReviewRequestStatus.approved)
        .length;

    return Row(
      children: [
        _StatTile(label: 'Visits', value: places.length, palette: palette),
        const SizedBox(width: Insets.md),
        _StatTile(label: 'Approved', value: approved, palette: palette),
        const SizedBox(width: Insets.md),
        _StatTile(
          label: 'Pending',
          value: pending,
          palette: palette,
          highlight: pending > 0,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.palette,
    this.highlight = false,
  });

  final String label;
  final int value;
  final AppPalette palette;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: Insets.xxl,
          horizontal: Insets.xl,
        ),
        decoration: BoxDecoration(
          color: highlight ? palette.goldBg : palette.surface,
          borderRadius: BorderRadius.circular(Corners.xl),
          border: Border.all(color: highlight ? palette.gold : palette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: AppText.numericLarge.copyWith(
                color: highlight ? palette.goldInk : palette.ink,
              ),
            ),
            const SizedBox(height: Insets.xxs),
            Text(
              label,
              style: AppText.caption.copyWith(
                color: highlight ? palette.goldInk : palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacesSection extends StatelessWidget {
  const _PlacesSection({
    required this.title,
    required this.emptyLabel,
    required this.places,
  });

  final String title;
  final String emptyLabel;
  final List<UserPlace> places;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (places.isEmpty) {
      return _EmptyState(label: emptyLabel, palette: palette);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: AppText.sectionLabel),
        const SizedBox(height: Insets.md),
        for (final place in places) _PlaceRow(place: place, palette: palette),
      ],
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place, required this.palette});

  final UserPlace place;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      padding: const EdgeInsets.all(Insets.xxl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.xl),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Icon(Icons.place_outlined, size: 18, color: palette.red),
          const SizedBox(width: Insets.md),
          Expanded(
            // The business name, not the id. Showing a raw UUID here is how a
            // user finds out nobody has ever opened this screen.
            child: Text(
              place.businessName,
              style: AppText.titleMedium.copyWith(color: palette.ink),
            ),
          ),
          if (place.confirmedByBusiness)
            Icon(Icons.verified_outlined, size: 16, color: palette.good),
        ],
      ),
    );
  }
}

class _RequestsSection extends StatelessWidget {
  const _RequestsSection({required this.requests});

  final List<ReviewRequestSummary> requests;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (requests.isEmpty) {
      return _EmptyState(
        label: 'No review requests yet.',
        palette: palette,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('YOUR REVIEW REQUESTS', style: AppText.sectionLabel),
        const SizedBox(height: Insets.md),
        for (final request in requests)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: Container(
              padding: const EdgeInsets.all(Insets.xxl),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(Corners.xl),
                border: Border.all(color: palette.line),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusIcon(request.status),
                    size: 18,
                    color: palette.muted,
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      request.businessName,
                      style: AppText.titleMedium.copyWith(color: palette.ink),
                    ),
                  ),
                  Text(
                    _statusLabel(request.status),
                    style: AppText.caption.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // These describe a review *request*, not a review, so they use the request
  // vocabulary. Mapping them onto ReviewStatus would imply a verification the
  // business has not performed.
  static IconData _statusIcon(ReviewRequestStatus status) => switch (status) {
    ReviewRequestStatus.pending => Icons.hourglass_empty,
    ReviewRequestStatus.approved => Icons.check_circle_outline,
    ReviewRequestStatus.declined => Icons.block_outlined,
  };

  static String _statusLabel(ReviewRequestStatus status) => switch (status) {
    ReviewRequestStatus.pending => 'Waiting on business',
    ReviewRequestStatus.approved => 'Approved',
    ReviewRequestStatus.declined => 'Declined',
  };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label, required this.palette});

  final String label;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.giant),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.xl),
        border: Border.all(color: palette.line),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppText.bodyMedium.copyWith(color: palette.muted),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 40, color: palette.line),
          const SizedBox(height: Insets.xl),
          Text(
            'You are not signed in',
            style: AppText.titleLarge.copyWith(color: palette.ink),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Sign in to leave reviews and see your places.',
            style: AppText.bodyMedium.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.giant),
          FilledButton(onPressed: onSignIn, child: const Text('Sign in')),
        ],
      ),
    );
  }
}

class AuthPrompt extends StatelessWidget {
  const AuthPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(Insets.giant),
      decoration: BoxDecoration(
        color: palette.blueBg,
        borderRadius: BorderRadius.circular(Corners.xl),
      ),
      child: Text(
        'Reviews only count once the business confirms you were a customer. '
        'That is what stops bought ratings.',
        style: AppText.bodyMedium.copyWith(color: palette.blue),
      ),
    );
  }
}

class _RoleExplainer extends StatefulWidget {
  const _RoleExplainer({required this.session});

  final AuthSession session;

  @override
  State<_RoleExplainer> createState() => _RoleExplainerState();
}

class _RoleExplainerState extends State<_RoleExplainer> {
  bool _claiming = false;
  String? _claimError;

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() {
      _claiming = true;
      _claimError = null;
    });

    final claimed = await widget.session.claimTeamAdmin();
    if (!mounted) return;

    setState(() {
      _claiming = false;
      if (!claimed) {
        _claimError =
            'Someone else already claimed this, or your profile could not be '
            'found. A team admin can set it from the database instead.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final role = widget.session.role;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ACCOUNT TYPE', style: AppText.sectionLabel),
        const SizedBox(height: Insets.md),
        Container(
          padding: const EdgeInsets.all(Insets.xxl),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(Corners.xl),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 18,
                color: palette.muted,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  _roleLabel(role),
                  style: AppText.bodyMedium.copyWith(color: palette.ink),
                ),
              ),
            ],
          ),
        ),

        // The only way into the admin areas against Supabase. The header's
        // role switcher exists for the mock only, so without these a real
        // team admin had the role and no route to any of its screens.
        if (widget.session.canAccessTeamDashboard()) ...[
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            onPressed: () => context.go('/team/listings'),
            icon: const Icon(Icons.shield_outlined, size: 18),
            label: const Text('Team tools'),
          ),
        ],
        if (widget.session.canAccessBusinessDashboard()) ...[
          const SizedBox(height: Insets.md),
          OutlinedButton.icon(
            onPressed: () => context.go('/business'),
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('Business tools'),
          ),
        ],

        // Only offered to someone who is not already an admin. The database
        // refuses it once an admin exists, so this is a convenience rather
        // than the gate — but a button that silently does nothing is worse
        // than no button, hence the error message below.
        if (role == UserRole.user) ...[
          const SizedBox(height: Insets.lg),
          OutlinedButton.icon(
            onPressed: _claiming ? null : _claim,
            icon: _claiming
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.shield_outlined, size: 18),
            label: Text(_claiming ? 'Claiming' : 'Become a team admin'),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'One-time setup, so the island is not locked out of its own '
            'moderation tools. It stops working as soon as an admin exists.',
            style: AppText.caption.copyWith(color: palette.muted),
          ),
          if (_claimError != null) ...[
            const SizedBox(height: Insets.md),
            AuthErrorBanner(message: _claimError!),
          ],
        ],
      ],
    );
  }

  static String _roleLabel(UserRole role) => switch (role) {
    UserRole.businessAdmin =>
      'Business admin. You can edit your listing and confirm customers.',
    UserRole.teamAdmin =>
      'Team admin. You can moderate reviews and manage subscriptions.',
    UserRole.user => 'Regular user. You can browse, visit and review.',
  };
}

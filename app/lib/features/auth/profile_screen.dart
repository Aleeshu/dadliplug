import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/features/auth/auth_widgets.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/review.dart';
import 'package:antigua_business_map/models/user.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The user's own account screen.
///
/// Holds visit history and their review requests. Visit history is what makes
/// "you have to have used the business to review it" enforceable and visible
/// rather than a hidden rule.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.session,
    this.visits = const [],
    this.requests = const [],
    super.key,
  });

  final AuthSession session;

  /// Passed in rather than fetched. The visit store lands with the Supabase
  /// layer in Phase 5; until then this renders empty, which is honest.
  final List<Visit> visits;
  final List<Review> requests;

  @override
  Widget build(BuildContext context) {
    final user = session.user;

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
                  _Stats(visits: visits, requests: requests),
                  const SizedBox(height: Insets.giant),
                  _PlacesSection(
                    title: 'Places you visited',
                    emptyLabel:
                        'Nothing yet. Open a business and tap '
                        '"I was here" to add it.',
                    visits: visits,
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
  const _Stats({required this.visits, required this.requests});

  final List<Visit> visits;
  final List<Review> requests;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pending = requests
        .where((r) => r.status == ReviewStatus.pending)
        .length;
    final written = requests.where((r) => !r.isRequestOnly).length;

    return Row(
      children: [
        _StatTile(label: 'Visits', value: visits.length, palette: palette),
        const SizedBox(width: Insets.md),
        _StatTile(label: 'Reviews', value: written, palette: palette),
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
    required this.visits,
  });

  final String title;
  final String emptyLabel;
  final List<Visit> visits;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (visits.isEmpty) {
      return _EmptyState(label: emptyLabel, palette: palette);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: AppText.sectionLabel),
        const SizedBox(height: Insets.md),
        for (final visit in visits) _PlaceRow(visit: visit, palette: palette),
      ],
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.visit, required this.palette});

  final Visit visit;
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
            child: Text(
              visit.businessId,
              style: AppText.titleMedium.copyWith(color: palette.ink),
            ),
          ),
          if (visit.confirmedByBusiness)
            Icon(Icons.verified_outlined, size: 16, color: palette.good),
        ],
      ),
    );
  }
}

class _RequestsSection extends StatelessWidget {
  const _RequestsSection({required this.requests});

  final List<Review> requests;

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
                      request.businessId,
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

  static IconData _statusIcon(ReviewStatus status) => switch (status) {
    ReviewStatus.pending => Icons.hourglass_empty,
    ReviewStatus.verified => Icons.check_circle_outline,
    ReviewStatus.locked => Icons.lock_outline,
    ReviewStatus.removed => Icons.block_outlined,
  };

  static String _statusLabel(ReviewStatus status) => switch (status) {
    ReviewStatus.pending => 'Waiting on business',
    ReviewStatus.verified => 'Verified',
    ReviewStatus.locked => 'Not verified',
    ReviewStatus.removed => 'Removed',
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

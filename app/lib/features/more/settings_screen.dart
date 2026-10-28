import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:antigua_business_map/services/billing.dart';
import 'package:antigua_business_map/services/theme_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Settings, from the redesign: appearance, account, and for owners their
/// plan, payments and ad history in one place.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({required this.session, super.key});

  final AuthSession session;

  Future<void> _changePassword(BuildContext context) async {
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Change password'),
        content: TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password',
            helperText: 'At least 8 characters',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final value = password.text;
    password.dispose();
    if (ok != true || !context.mounted) return;
    if (value.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use at least 8 characters.')),
      );
      return;
    }
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: value),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed.')),
        );
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is AuthException
                  ? e.message
                  : 'Could not change it. Try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final user = session.user;
    final businessId = session.primaryBusinessId;
    final mode = ref.watch(themeModeProvider);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(4, Insets.xl, 4, Insets.sm),
      child: Text(title.toUpperCase(), style: AppText.sectionLabel),
    );

    Widget item({
      required IconData icon,
      required String title,
      String? subtitle,
      VoidCallback? onTap,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.xl),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Corners.xl),
            side: BorderSide(color: palette.line),
          ),
          leading: CircleAvatar(
            backgroundColor: palette.app,
            child: Icon(icon, color: palette.ink, size: 20),
          ),
          title: Text(
            title,
            style: AppText.titleSmall.copyWith(color: palette.ink),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  style: AppText.caption.copyWith(color: palette.muted),
                ),
          trailing: onTap == null
              ? null
              : Icon(Icons.chevron_right, color: palette.muted),
          onTap: onTap,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: palette.app,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          0,
          Insets.lg,
          Insets.giant,
        ),
        children: [
          if (user != null)
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: palette.red,
                  child: Text(
                    (user.displayName ?? user.email).characters.first
                        .toUpperCase(),
                    style: AppText.titleLarge.copyWith(color: palette.onRed),
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? 'Your account',
                        style: AppText.titleMedium.copyWith(color: palette.ink),
                      ),
                      Text(
                        user.email,
                        style: AppText.caption.copyWith(color: palette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          section('Appearance'),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Phone'),
                icon: Icon(Icons.phone_android),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).set(s.first),
          ),

          if (businessId != null) ...[
            section('Your business'),
            item(
              icon: Icons.bar_chart,
              title: 'Your dashboard',
              subtitle: "Results, tools and today's special",
              onTap: () => context.go('/business?business=$businessId'),
            ),
            item(
              icon: Icons.workspace_premium_outlined,
              title: 'Plan and billing',
              subtitle: 'Starter, Growth or Premium',
              onTap: () => context.push('/business/plans?business=$businessId'),
            ),
            item(
              icon: Icons.receipt_long_outlined,
              title: 'Payment history',
              subtitle: 'Transfers the team has recorded',
              onTap: () =>
                  context.push('/settings/payments?business=$businessId'),
            ),
            item(
              icon: Icons.history,
              title: 'Ad history',
              subtitle: 'Running and past advertisements',
              onTap: () => context.go('/business/ads?business=$businessId'),
            ),
            item(
              icon: Icons.edit_outlined,
              title: 'Business details',
              subtitle: 'Hours, contact, menu, photos',
              onTap: () => context.go('/business/listing?business=$businessId'),
            ),
          ],

          section('Account'),
          if (user != null) ...[
            item(
              icon: Icons.lock_outline,
              title: 'Password',
              subtitle: 'Change your password',
              onTap: () => _changePassword(context),
            ),
            item(
              icon: Icons.person_outline,
              title: 'Your account',
              subtitle: 'Profile, places, delete account',
              onTap: () => context.push('/profile'),
            ),
          ] else
            item(
              icon: Icons.login,
              title: 'Sign in',
              onTap: () => context.push('/sign-in'),
            ),

          section('Permissions'),
          item(
            icon: Icons.shield_outlined,
            title: 'What Dadliplug uses',
            subtitle:
                'Location only for "Near me", never stored. Camera only to '
                'scan a visit or deal code. Notifications only if you allow '
                "them. Change any of these in your phone's settings.",
          ),

          section('About'),
          item(
            icon: Icons.info_outline,
            title: 'About, privacy and terms',
            subtitle: '${AppConfig.appName}, licences and photo credits',
            onTap: () => context.push('/about'),
          ),
        ],
      ),
    );
  }
}

/// Every transfer the team has recorded for a business, newest first.
class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({required this.businessId, super.key});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Payment history'),
        backgroundColor: palette.app,
      ),
      body: FutureBuilder<List<Payment>>(
        future: ref.read(billingRepositoryProvider).payments(businessId),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load payments.'));
          }
          final payments = snap.data;
          if (payments == null) {
            return Center(child: CircularProgressIndicator(color: palette.red));
          }
          if (payments.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Insets.huge),
                child: Text(
                  'No payments recorded yet. Pay by bank transfer and the '
                  'team records it here the same day.',
                  textAlign: TextAlign.center,
                  style: AppText.bodyMedium.copyWith(color: palette.muted),
                ),
              ),
            );
          }
          final date = DateFormat.yMMMd();
          return ListView.separated(
            padding: const EdgeInsets.all(Insets.lg),
            itemCount: payments.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (_, i) {
              final p = payments[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${p.tier.label}, ${p.months} '
                  '${p.months == 1 ? 'month' : 'months'}',
                ),
                subtitle: Text(
                  'Ref ${p.reference} · paid until '
                  '${date.format(p.paidUntil.toLocal())}',
                ),
                trailing: Text(
                  'EC\$${p.amountEc.toStringAsFixed(2)}',
                  style: AppText.titleSmall.copyWith(color: palette.ink),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

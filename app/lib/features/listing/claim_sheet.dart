import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/claims.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "Is this your business?" under a listing, with what the viewer can do.
class ClaimPrompt extends ConsumerWidget {
  const ClaimPrompt({required this.business, super.key});

  final Business business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final standing = ref.watch(claimStandingProvider(business.id)).value;
    final caption = AppText.caption.copyWith(color: palette.muted);

    return switch (standing) {
      null || ClaimStanding.owns => const SizedBox.shrink(),
      ClaimStanding.pending => Row(
        children: [
          Icon(Icons.hourglass_top, size: 16, color: palette.muted),
          const SizedBox(width: Insets.xs),
          Expanded(
            child: Text(
              'Your claim is with the Dadliplug team. We will call the '
              'business to confirm.',
              style: caption,
            ),
          ),
        ],
      ),
      ClaimStanding.signedOut || ClaimStanding.canClaim => TextButton.icon(
        onPressed: () => standing == ClaimStanding.signedOut
            ? context.push('/sign-in')
            : ClaimSheet.show(context, business),
        icon: const Icon(Icons.storefront_outlined, size: 18),
        label: Text(
          standing == ClaimStanding.signedOut
              ? 'Own this business? Sign in to claim it'
              : 'Own this business? Claim it',
        ),
      ),
    };
  }
}

/// The claim form. Its answers go to the team, who verify by phone.
class ClaimSheet extends ConsumerStatefulWidget {
  const ClaimSheet({required this.business, super.key});

  final Business business;

  static Future<void> show(BuildContext context, Business business) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ClaimSheet(business: business),
      );

  @override
  ConsumerState<ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends ConsumerState<ClaimSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _role = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _role, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(claimsRepositoryProvider)
          .request(
            businessId: widget.business.id,
            name: _name.text,
            phone: _phone.text,
            role: _role.text,
            note: _note.text,
          );
      ref.invalidate(claimStandingProvider(widget.business.id));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Claim sent. The team will call the business.'),
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = claimErrorMessage(error);
        });
      }
    }
  }

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? 'Needed so the team can check' : null;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final listed = widget.business.phone ?? widget.business.whatsapp;

    return Padding(
      padding: EdgeInsets.only(
        left: Insets.huge,
        right: Insets.huge,
        top: Insets.huge,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Insets.huge,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Claim ${widget.business.name}',
                style: AppText.titleLarge.copyWith(color: palette.ink),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                listed == null
                    ? 'The Dadliplug team will contact the business to '
                          'confirm before you can edit the listing.'
                    : 'To confirm, the Dadliplug team will call the number '
                          'on this listing ($listed), not the one you give '
                          'below. Once confirmed you can edit the listing.',
                style: AppText.bodyMedium.copyWith(color: palette.muted),
              ),
              const SizedBox(height: Insets.lg),
              TextFormField(
                controller: _name,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Your name'),
                validator: _required,
              ),
              TextFormField(
                controller: _role,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Your role',
                  hintText: 'e.g. Owner, Manager',
                ),
                validator: _required,
              ),
              TextFormField(
                controller: _phone,
                maxLength: 30,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Your phone',
                  hintText: '+1 268 …',
                ),
                validator: (v) =>
                    (v ?? '').replaceAll(RegExp('[^0-9]'), '').length < 7
                    ? 'Enter a phone number'
                    : null,
              ),
              TextFormField(
                controller: _note,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Anything that helps (optional)',
                  hintText: 'e.g. Best time to call the shop',
                ),
              ),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: AppText.bodyMedium.copyWith(color: palette.bad),
                ),
                const SizedBox(height: Insets.sm),
              ],
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Sending…' : 'Send claim'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

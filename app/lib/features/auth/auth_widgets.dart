import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:flutter/material.dart';

/// Minimum password length. Matches Supabase's default so the app does not
/// accept something the backend then rejects with a less clear message.
const int kMinimumPasswordLength = 8;

final RegExp kEmailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Email and password fields, shared by sign in and sign up.
///
/// The two screens differ only in wording and which button sits at the bottom,
/// so the fields live here rather than being copy-pasted and drifting apart.
class AuthFields extends StatefulWidget {
  const AuthFields({
    required this.emailController,
    required this.passwordController,
    this.nameController,
    this.errorText,
    this.autofocusEmail = true,
    this.requirePasswordLength = false,
    super.key,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;

  /// Only shown on sign up.
  final TextEditingController? nameController;

  final String? errorText;
  final bool autofocusEmail;

  /// Enforces the minimum length. On for sign up, off for sign in — refusing
  /// to let an existing user sign in over a typo in their password is worse
  /// than a backend error.
  final bool requirePasswordLength;

  @override
  State<AuthFields> createState() => _AuthFieldsState();
}

class _AuthFieldsState extends State<AuthFields> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.nameController != null) ...[
          TextFormField(
            controller: widget.nameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          const SizedBox(height: Insets.xl),
        ],

        TextFormField(
          controller: widget.emailController,
          autofocus: widget.autofocusEmail,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          // Matters on Android: without this the keyboard offers the wrong
          // layout and autocorrect mangles the address.
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'you@example.com',
          ),
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty) return 'Enter your email.';
            if (!kEmailPattern.hasMatch(email)) {
              return 'That does not look like an email address.';
            }
            return null;
          },
        ),
        const SizedBox(height: Insets.xl),

        TextFormField(
          controller: widget.passwordController,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Password',
            helperText: widget.requirePasswordLength
                ? 'At least $kMinimumPasswordLength characters'
                : null,
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: palette.muted,
              ),
              tooltip: _obscure ? 'Show password' : 'Hide password',
            ),
          ),
          validator: (value) {
            final password = value ?? '';
            if (password.isEmpty) return 'Enter your password.';
            if (widget.requirePasswordLength &&
                password.length < kMinimumPasswordLength) {
              return 'At least $kMinimumPasswordLength characters.';
            }
            return null;
          },
          onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
        ),

        if (widget.errorText != null) ...[
          const SizedBox(height: Insets.xl),
          AuthErrorBanner(message: widget.errorText!),
        ],
      ],
    );
  }
}

/// Error banner.
///
/// Uses the prototype's bad/warn banner styling rather than a bare red text
/// row. Failures are the one thing on the screen that matters at that moment,
/// so they should be impossible to miss.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({
    required this.message,
    this.isWarning = false,
    super.key,
  });

  final String message;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final background = isWarning ? palette.warnBg : palette.badBg;
    final foreground = isWarning ? palette.warn : palette.bad;

    return Container(
      padding: const EdgeInsets.all(Insets.xxl),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Corners.xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.info_outline : Icons.error_outline,
            size: 18,
            color: foreground,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              message,
              style: AppText.bodyMedium.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Continue with Google".
///
/// Visually secondary to email, because plenty of people on a small island will
/// not have a Google account set up on their phone. Email has to be a
/// first-class path rather than the fallback.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.muted,
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.g_mobiledata, size: 20),
                SizedBox(width: Insets.md),
                Text('Continue with Google'),
              ],
            ),
    );
  }
}

/// The "or" divider between email and Google.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Expanded(child: Divider(color: palette.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          child: Text(
            'or',
            style: AppText.caption.copyWith(color: palette.muted),
          ),
        ),
        Expanded(child: Divider(color: palette.line)),
      ],
    );
  }
}

/// Header for the auth screens.
class AuthHeader extends StatelessWidget {
  const AuthHeader({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.displayLarge.copyWith(color: palette.ink)),
        const SizedBox(height: Insets.md),
        Text(
          subtitle,
          style: AppText.bodyLarge.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}

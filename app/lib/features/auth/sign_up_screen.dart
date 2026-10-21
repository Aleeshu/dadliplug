import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/auth/auth_widgets.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Minimum password length. Matches Supabase's default so the app does not
/// accept something the backend then rejects with a less clear message.
const int kMinimumPasswordLength = 8;

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({required this.session, super.key});

  final AuthSession session;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });

    final result = await widget.session.register(
      _email.text,
      _password.text,
      _name.text,
    );
    if (!mounted) return;

    setState(() {
      _isBusy = false;
      if (!result.isSuccess) _error = result.errorMessage;
    });

    // Supabase may require email confirmation. On a project set up for it,
    // there is no session yet, so the sign-in screen is the honest next step.
    if (result.isSuccess && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Insets.giant),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthHeader(
                      title: 'Create an account',
                      subtitle: 'To leave a review, you need an account.',
                    ),
                    const SizedBox(height: Insets.giant),

                    AuthFields(
                      emailController: _email,
                      passwordController: _password,
                      nameController: _name,
                      autofocusEmail: false,
                      requirePasswordLength: true,
                      errorText: _error,
                    ),

                    const SizedBox(height: Insets.giant),
                    FilledButton(
                      onPressed: _isBusy ? null : _submit,
                      child: _isBusy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: palette.app,
                              ),
                            )
                          : const Text('Create account'),
                    ),
                    const SizedBox(height: Insets.md),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'By creating an account you agree to the',
                          style: AppText.caption.copyWith(
                            color: palette.muted,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/terms'),
                          child: const Text('Terms'),
                        ),
                        Text(
                          'and',
                          style: AppText.caption.copyWith(
                            color: palette.muted,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/privacy'),
                          child: const Text('Privacy policy'),
                        ),
                      ],
                    ),

                    const SizedBox(height: Insets.giant),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have one?',
                          style: AppText.bodyMedium.copyWith(
                            color: palette.muted,
                          ),
                        ),
                        TextButton(
                          onPressed: _isBusy ? null : () => context.pop(),
                          child: const Text('Sign in'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/auth/auth_widgets.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:antigua_business_map/services/error_mapper.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({required this.session, super.key});

  final AuthSession session;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isBusy = false;
  String? _error;
  bool _resetSent = false;

  @override
  void dispose() {
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
      _resetSent = false;
    });

    final result = await widget.session.signIn(_email.text, _password.text);
    if (!mounted) return;

    setState(() {
      _isBusy = false;
      if (result.isSuccess) {
        _error = null;
      } else {
        _error = result.errorMessage;
      }
    });

    if (result.isSuccess && mounted) context.go('/');
  }

  Future<void> _sendReset() async {
    if (_isBusy) return;

    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first, then tap reset.');
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      await widget.session.sendPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _resetSent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _error = SupabaseErrorMapper.describe(e);
      });
    }
  }

  Future<void> _googleSignIn() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final result = await widget.session.signInWithGoogle();
    if (!mounted) return;

    setState(() {
      _isBusy = false;
      if (!result.isSuccess) _error = result.errorMessage;
    });

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
                      title: 'Sign in',
                      subtitle: 'Find what is open on the island right now.',
                    ),
                    const SizedBox(height: Insets.giant),

                    AuthFields(
                      emailController: _email,
                      passwordController: _password,
                      errorText: _resetSent
                          ? 'If that email has an account, a reset link is on '
                                'its way. Check spam too.'
                          : _error,
                    ),

                    if (!_resetSent)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isBusy ? null : _sendReset,
                          child: const Text('Forgot password?'),
                        ),
                      ),

                    const SizedBox(height: Insets.xl),
                    FilledButton(
                      onPressed: _isBusy ? null : _submit,
                      child: _isBusy
                          ? _Spinner(color: palette.app)
                          : const Text('Sign in'),
                    ),

                    if (AppConfig.hasGoogleSignIn) ...[
                      const SizedBox(height: Insets.giant),
                      const AuthDivider(),
                      const SizedBox(height: Insets.giant),
                      GoogleSignInButton(
                        onPressed: _googleSignIn,
                        isLoading: _isBusy,
                      ),
                    ],

                    const SizedBox(height: Insets.giant),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No account?',
                          style: AppText.bodyMedium.copyWith(
                            color: palette.muted,
                          ),
                        ),
                        TextButton(
                          onPressed: _isBusy
                              ? null
                              : () => context.push('/sign-up'),
                          child: const Text('Create one'),
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

class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );
}

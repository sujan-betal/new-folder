import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/google_sign_in_service.dart';
import '../../../injection_container.dart' as di;
import '../../../logic/providers/auth_provider.dart';
import '../../widgets/primary_button.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final GoogleSignInService _googleService = di.sl<GoogleSignInService>();
  String? _busyWith;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(
    String key,
    Future<bool> Function() action,
  ) async {
    if (_busyWith != null) return;
    setState(() => _busyWith = key);
    final auth = context.read<AuthProvider>();
    final ok = await action();
    if (!mounted) return;
    setState(() => _busyWith = null);
    if (ok) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Login failed')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    await _run('password', () => auth.login(
          _identifierController.text.trim(),
          _passwordController.text,
        ));
  }

  Future<void> _guest() async {
    final auth = context.read<AuthProvider>();
    await _run('guest', () => auth.loginAsGuest());
  }

  Future<void> _google() async {
    final auth = context.read<AuthProvider>();
    await _run('google', () async {
      try {
        final idToken = await _googleService.getIdToken();
        return await auth.loginWithSocialToken(
            provider: 'google', token: idToken);
      } on ApiExceptionMessage catch (e) {
        auth.setTransientError(e.toString());
        return false;
      }
    });
  }

  Future<void> _facebook() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Add the flutter_facebook_auth plugin and pass its token to '
          'loginWithSocialToken(provider: facebook) - backend is ready.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final busy = _busyWith != null || auth.loading;

    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '\u{1F3B2}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 56),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _identifierController,
                      decoration: const InputDecoration(
                        labelText: 'Username or Email',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter your username or email'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) => value == null || value.length < 6
                          ? 'Minimum 6 characters'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: busy
                          ? 'Please wait...'
                          : 'Log In',
                      onPressed: busy ? null : _submit,
                    ),

                    // Quick guest entry
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: busy ? null : _guest,
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              AppColors.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                AppColors.gold.withValues(alpha: 0.6),
                          ),
                        ),
                        child: _busyWith == 'guest'
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.gold))
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt,
                                      color: AppColors.gold, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Play as Guest - no account needed',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(children: [
                      const Expanded(
                          child: Divider(color: Colors.white24)),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or continue with',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white
                                    .withValues(alpha: 0.55))),
                      ),
                      const Expanded(
                          child: Divider(color: Colors.white24)),
                    ]),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _SocialButton(
                            label: 'Google',
                            icon: Icons.g_mobiledata,
                            iconColor: Colors.redAccent,
                            busy: _busyWith == 'google',
                            enabled: !busy,
                            onTap: isMobileTarget
                                ? _google
                                : () => ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                    content: Text(
                                        'Google Sign-In works on Android/iOS builds'),
                                  )),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SocialButton(
                            label: 'Facebook',
                            icon: Icons.facebook,
                            iconColor: const Color(0xFF1877F2),
                            busy: false,
                            enabled: !busy,
                            onTap: _facebook,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'New player? ',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          ),
                          child: const Text(
                            'Create account',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: iconColor, size: 24),
                      const SizedBox(width: 8),
                      Text(label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
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

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      _identifierController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Login failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
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
                    const SizedBox(height: 32),
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
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: auth.loading ? 'Please wait...' : 'Log In',
                      onPressed: auth.loading ? null : _submit,
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

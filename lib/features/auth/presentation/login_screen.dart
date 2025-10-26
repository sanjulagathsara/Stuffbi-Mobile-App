import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    if (!ok) return 'Enter a valid email';
    return null;
  }

  String? _pwValidator(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Min 6 characters';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    // TODO: integrate real auth
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _busy = false);
    context.go('/bundles');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Image.asset(
                    'assets/images/stuffbi_welcoming.png',
                    height: 180, // Adjust height as needed
                    fit: BoxFit.contain,
                  ),
              Text(
                'Welcome!',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              Text(
                'Sign in to continue',
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 4),

              // Card container for the login form (to match Create Account style)
              Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: _emailValidator,
                          autofillHints: const [AutofillHints.email],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _pwCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure ? Icons.visibility_off : Icons.visibility,
                              ),
                            ),
                            border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: _pwValidator,
                          autofillHints: const [AutofillHints.password],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push(
                              '/under_development',
                            ), // TODO: forgot password
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Login'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () => context.go('/bundles'),
                  child: const Text('Continue as Guest'),
                ),
              ),
              // // Continue as Guest
              // OutlinedButton.icon(
              //   onPressed: () => context.go('/bundles'),
              //   icon: const Icon(Icons.person_outline),
              //   label: const Text('Continue as Guest'),
              // ),

              const SizedBox(height: 8),

              // Social row placeholder
              Row(
                children: [
                  Expanded(child: Divider(color: cs.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('or', style: textTheme.bodyMedium),
                  ),
                  Expanded(child: Divider(color: cs.outlineVariant)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/under_development',
                    ), // TODO: Google sign-in
                    icon: const Icon(Icons.g_mobiledata_rounded),
                    label: const Text('Google'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/under_development',
                    ), // TODO: Apple sign-in
                    icon: const Icon(Icons.apple),
                    label: const Text('Apple'),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('New here?', style: textTheme.bodyMedium),
                  TextButton(
                    onPressed: () => context.push(
                      '/register',
                    ),
                    child: const Text('Create an account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

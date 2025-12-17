import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_api.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ac,
    curve: Curves.easeOutCubic,
  );

  final AuthApi _authApi = AuthApi();
  bool _isCheckingAuth = false;

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  /// Check if user has a valid (non-expired) token and navigate accordingly
  Future<void> _handleStart() async {
    setState(() => _isCheckingAuth = true);

    try {
      // First check if token exists
      final hasToken = await _authApi.isLoggedIn();
      
      if (!mounted) return;

      if (!hasToken) {
        // No token - go to login
        context.go('/login');
        return;
      }

      // Token exists - validate it by calling /auth/me
      // If token is expired, this will throw an exception
      try {
        await _authApi.getMe();
        
        if (!mounted) return;
        
        // Token is valid - go directly to bundles
        context.go('/bundles');
      } catch (e) {
        // Token is invalid/expired - clear it and go to login
        debugPrint('Token validation failed: $e');
        await _authApi.logout(); // Clear the expired token
        
        if (!mounted) return;
        context.go('/login');
      }
    } catch (e) {
      // On error, fall back to login screen
      debugPrint('Auth check error: $e');
      if (mounted) {
        context.go('/login');
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingAuth = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 140, width: 140, child: _Logo()),
                  const SizedBox(height: 8),
                  Text(
                    'Personal Inventory Management System',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 133, 250),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isCheckingAuth ? null : _handleStart,
                      child: _isCheckingAuth
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Start'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Image.asset(
      'assets/images/logo_stuffbi.png',
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.backpack_outlined, size: 64),
      ),
    );
  }
}

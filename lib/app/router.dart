import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/bundles/presentation/bundles_screen.dart';
import '../features/dev/presentation/under_development_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/bundles', builder: (_, __) => const BundlesScreen()),
    GoRoute(path: '/under_development', builder: (_, __) => const UnderDevelopmentScreen()),
  ],
  // Optional: simple error page
  errorBuilder: (_, state) => Scaffold(
    appBar: AppBar(title: const Text('Oops')),
    body: Center(child: Text(state.error.toString())),
  ),
);

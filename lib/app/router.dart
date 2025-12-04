import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stuffbi/app/app_shell.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/bundles/presentation/bundles_screen.dart';
import '../features/dev/presentation/under_development_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/items/presentation/items_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/bundles/presentation/bundle_details_screen.dart';
import '../features/bundles/models/bundle_model.dart';
import '../features/bundles/presentation/add_edit_bundle_screen.dart';
import '../features/activity/presentation/activity_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(
      path: '/under_development',
      builder: (_, _) => const UnderDevelopmentScreen(),
    ),
    GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    ShellRoute(
      builder: (context, state, child) {
        return AppShell(child: child);
      },
      routes: [
        GoRoute(path: '/bundles', builder: (_, _) => const BundlesScreen()),
        GoRoute(
          path: '/bundle_details',
          builder: (context, state) {
            final bundle = state.extra as Bundle;
            return BundleDetailsScreen(bundle: bundle);
          },
        ),
        GoRoute(
          path: '/add_bundle',
          builder: (context, state) {
            final bundle = state.extra as Bundle?;
            return AddEditBundleScreen(bundle: bundle);
          },
        ),
        GoRoute(path: '/items', builder: (_, _) => const ItemsScreen()),
        GoRoute(path: '/activity', builder: (_, _) => const ActivityScreen()),
        GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      ],
    ),
  ],
  // Optional: simple error page
  errorBuilder: (_, state) => Scaffold(
    appBar: AppBar(title: const Text('Oops')),
    body: Center(child: Text(state.error.toString())),
  ),
);

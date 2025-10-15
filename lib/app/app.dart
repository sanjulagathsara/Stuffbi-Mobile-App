import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme/theme.dart';
import 'router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = appRouter;
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Stuffbi',
      theme: buildTheme(),
      routerConfig: router,
    );
  }
}

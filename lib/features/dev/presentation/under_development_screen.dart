import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/under_development.dart';

class UnderDevelopmentScreen extends StatelessWidget {
  const UnderDevelopmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dev')),
      body: UnderDevelopment(
        title: 'Under Development',
        message: 'We’re crafting this feature for the next release.',
        primaryLabel: 'Back',
        imageAsset: 'assets/images/under_development.png', // ← your asset path
        onPrimary: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/bundles');
          }
        },
      ),
    );
  }
}

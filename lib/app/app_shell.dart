import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/bag.png', width: 24, height: 24),
            activeIcon: Image.asset('assets/icons/bag.png', width: 24, height: 24, color: Colors.blue),
            label: 'Bundles',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/items.png', width: 24, height: 24),
            activeIcon: Image.asset('assets/icons/items.png', width: 24, height: 24, color: Colors.blue),
            label: 'Items',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/profile.png', width: 24, height: 24),
            activeIcon: Image.asset('assets/icons/profile.png', width: 24, height: 24, color: Colors.blue),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/bundles')) {
      return 0;
    }
    if (location.startsWith('/items')) {
      return 1;
    }
    if (location.startsWith('/profile')) {
      return 2;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        GoRouter.of(context).go('/bundles');
        break;
      case 1:
        GoRouter.of(context).go('/items');
        break;
      case 2:
        GoRouter.of(context).go('/profile');
        break;
    }
  }
}

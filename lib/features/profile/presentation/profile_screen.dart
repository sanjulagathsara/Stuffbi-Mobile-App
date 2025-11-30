import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_api.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthApi auth = AuthApi();

  bool loading = true;
  bool isGuest = true; // <-- NEW
  Map<String, dynamic>? user;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final token = await auth.getToken();

    if (token == null) {
      // Guest mode
      setState(() {
        isGuest = true;
        loading = false;
      });
      return;
    }

    // Logged-in mode: try fetch /me
    try {
      final data = await auth.getMe();
      setState(() {
        isGuest = false;
        user = data;
        loading = false;
      });
    } catch (e) {
      // Token invalid or backend error → treat as guest
      setState(() {
        isGuest = true;
        loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("Logout?"),
        content: const Text("Do you want to log out from Stuffbi?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(dialogCtx).pop(false),
          ),
          ElevatedButton(
            child: const Text("Logout"),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await auth.logout();

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
    }
  }

  // -------------------------------------------------
  //            UI FOR GUEST (NO ACCOUNT)
  // -------------------------------------------------
  Widget _buildGuestUI(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(
                  'https://via.placeholder.com/150',
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                "Guest User",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 6),
              const Text(
                "You are browsing as a guest.",
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login),
                label: const Text("Login to your Account"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------
  //          UI FOR LOGGED-IN AUTH USER
  // -------------------------------------------------
  Widget _buildUserUI(BuildContext context) {
    final name = "${user!['firstName']} ${user!['lastName']}";
    final email = user!['email'];

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage('https://via.placeholder.com/150'),
            ),
            const SizedBox(height: 10),

            // Name
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            // Email
            Text(
              email,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),

            const SizedBox(height: 20),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text('Billing Details'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Support'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return isGuest ? _buildGuestUI(context) : _buildUserUI(context);
  }
}

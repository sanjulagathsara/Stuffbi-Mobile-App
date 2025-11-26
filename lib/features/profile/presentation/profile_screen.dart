import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit profile screen
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 50,
              // TODO: Replace with actual user image
              backgroundImage: NetworkImage('https://via.placeholder.com/150'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Guest Profile', // TODO: Replace with actual user name
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'guest.@example.com', // TODO: Replace with actual user email
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to settings screen
              },
            ),
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text('Billing Details'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to billing screen
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Support'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to help screen
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                // TODO: Handle logout
              },
            ),
          ],
        ),
      ),
    );
  }
}

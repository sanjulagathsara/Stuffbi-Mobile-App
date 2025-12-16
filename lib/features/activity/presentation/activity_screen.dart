import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'providers/activity_provider.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    // Load activities when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityProvider>().loadActivities();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        actions: [
          if (context.watch<ActivityProvider>().activities.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear Logs',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Activity Log'),
                    content: const Text('Are you sure you want to clear all activity logs?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await context.read<ActivityProvider>().clearLogs();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Activity logs cleared')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: Consumer<ActivityProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.activities.isEmpty) {
            return const Center(
              child: Text('No recent activity'),
            );
          }

          return ListView.builder(
            itemCount: provider.activities.length,
            itemBuilder: (context, index) {
              final activity = provider.activities[index];
              return ListTile(
                leading: _buildLeadingIcon(activity.actionType),
                title: Text(activity.details),
                subtitle: Text(
                  DateFormat('MMM d, y h:mm a').format(activity.timestamp),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLeadingIcon(String actionType) {
    IconData iconData;
    Color color;

    switch (actionType) {
      case 'check':
        iconData = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case 'move':
        iconData = Icons.swap_horiz;
        color = Colors.blue;
        break;
      case 'create':
        iconData = Icons.add_circle_outline;
        color = Colors.orange;
        break;
      case 'delete':
        iconData = Icons.delete_outline;
        color = Colors.red;
        break;
      case 'create_bundle':
        iconData = Icons.add_circle_outline;
        color = Colors.orange;
        break;
      case 'delete_bundle':
        iconData = Icons.delete_outline;
        color = Colors.red;
        break;
      default:
        iconData = Icons.history;
        color = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(iconData, color: color),
    );
  }
}

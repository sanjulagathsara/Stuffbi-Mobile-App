import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/sync/connectivity_service.dart';
import '../../../core/sync/sync_service.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  bool _syncActivityLogs = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _syncActivityLogs = prefs.getBool('sync_activity_logs') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _setSyncActivityLogs(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_activity_logs', value);
    setState(() {
      _syncActivityLogs = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectivityService = Provider.of<ConnectivityService>(context);
    final syncService = Provider.of<SyncService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Connection Status Card
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          connectivityService.isConnected
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                          size: 40,
                          color: connectivityService.isConnected
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                connectivityService.isConnected
                                    ? 'Connected'
                                    : 'Offline',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                syncService.isSyncing
                                    ? 'Syncing...'
                                    : syncService.lastSyncAt != null
                                        ? 'Last sync: ${_formatDateTime(syncService.lastSyncAt!)}'
                                        : 'Never synced',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (connectivityService.isConnected && !syncService.isSyncing)
                          IconButton(
                            icon: const Icon(Icons.sync),
                            onPressed: () => syncService.performSync(),
                            tooltip: 'Sync now',
                          ),
                        if (syncService.isSyncing)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Sync Settings
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Sync Options',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                
                SwitchListTile(
                  title: const Text('Sync Activity Logs'),
                  subtitle: const Text('Upload activity logs to the cloud'),
                  value: _syncActivityLogs,
                  onChanged: _setSyncActivityLogs,
                ),
                
                const Divider(),
                
                // Info section
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About Sync'),
                  subtitle: const Text(
                    'Your data syncs automatically when connected. '
                    'Changes made offline will sync when you reconnect.',
                  ),
                ),
                
                // Error display
                if (syncService.lastError != null)
                  Card(
                    margin: const EdgeInsets.all(16),
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Last error: ${syncService.lastError}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }
}

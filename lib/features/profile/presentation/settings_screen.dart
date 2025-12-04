import 'package:flutter/material.dart';
import '../../../core/services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();

  late bool _logChecks;
  late bool _logMovements;
  late bool _logBundleOps;

  @override
  void initState() {
    super.initState();
    _logChecks = _settings.logChecks;
    _logMovements = _settings.logMovements;
    _logBundleOps = _settings.logBundleOps;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Activity Logging Preferences',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Log Item Checks'),
            subtitle: const Text('Record when you check/uncheck items'),
            value: _logChecks,
            onChanged: (bool value) async {
              await _settings.setLogChecks(value);
              setState(() {
                _logChecks = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Log Item Movements'),
            subtitle: const Text('Record when items are moved between bundles'),
            value: _logMovements,
            onChanged: (bool value) async {
              await _settings.setLogMovements(value);
              setState(() {
                _logMovements = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Log Bundle Operations'),
            subtitle: const Text('Record bundle creation and deletion'),
            value: _logBundleOps,
            onChanged: (bool value) async {
              await _settings.setLogBundleOps(value);
              setState(() {
                _logBundleOps = value;
              });
            },
          ),
        ],
      ),
    );
  }
}

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  late SharedPreferences _prefs;

  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Keys
  static const String _keyLogChecks = 'log_checks';
  static const String _keyLogMovements = 'log_movements';
  static const String _keyLogBundleOps = 'log_bundle_ops';

  // Getters
  bool get logChecks => _prefs.getBool(_keyLogChecks) ?? true;
  bool get logMovements => _prefs.getBool(_keyLogMovements) ?? true;
  bool get logBundleOps => _prefs.getBool(_keyLogBundleOps) ?? true;

  // Setters
  Future<void> setLogChecks(bool value) async {
    await _prefs.setBool(_keyLogChecks, value);
  }

  Future<void> setLogMovements(bool value) async {
    await _prefs.setBool(_keyLogMovements, value);
  }

  Future<void> setLogBundleOps(bool value) async {
    await _prefs.setBool(_keyLogBundleOps, value);
  }
}

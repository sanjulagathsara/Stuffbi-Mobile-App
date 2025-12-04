import 'package:flutter/material.dart';
import '../../data/activity_repository.dart';
import '../../models/activity_log_model.dart';

class ActivityProvider extends ChangeNotifier {
  final ActivityRepository _repository = ActivityRepository();
  List<ActivityLog> _activities = [];
  bool _isLoading = false;

  List<ActivityLog> get activities => _activities;
  bool get isLoading => _isLoading;

  Future<void> loadActivities() async {
    _isLoading = true;
    notifyListeners();
    try {
      _activities = await _repository.getActivities();
    } catch (e) {
      debugPrint('Error loading activities: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logActivity(ActivityLog log) async {
    await _repository.logActivity(log);
    // Refresh the list if we are currently viewing it, or just append it
    // For simplicity and correctness with sorting, we reload or insert at top
    _activities.insert(0, log);
    notifyListeners();
  }

  Future<void> clearLogs() async {
    await _repository.deleteAllActivities();
    _activities.clear();
    notifyListeners();
  }
}

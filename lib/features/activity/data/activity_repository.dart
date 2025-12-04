import 'package:sqflite/sqflite.dart';
import '../../../core/services/settings_service.dart';
import '../../../../core/database/database_helper.dart';
import '../models/activity_log_model.dart';

class ActivityRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<void> logActivity(ActivityLog log) async {
    final settings = SettingsService();
    
    // Check settings
    if (log.actionType == 'check' && !settings.logChecks) return;
    if (log.actionType == 'move' && !settings.logMovements) return;
    if ((log.actionType == 'create_bundle' || log.actionType == 'delete_bundle') && !settings.logBundleOps) return;

    final db = await _databaseHelper.database;
    await db.insert(
      'activity_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ActivityLog>> getActivities({int limit = 50}) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'activity_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return ActivityLog.fromMap(maps[i]);
    });
  }

  Future<void> deleteAllActivities() async {
    final db = await _databaseHelper.database;
    await db.delete('activity_logs');
  }
}

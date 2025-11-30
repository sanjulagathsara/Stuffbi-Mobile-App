import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../models/bundle_model.dart';

class BundlesRepositoryImpl {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<List<Bundle>> getBundles() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('bundles');
    return List.generate(maps.length, (i) {
      return Bundle.fromMap(maps[i]);
    });
  }

  Future<void> addBundle(Bundle bundle) async {
    final db = await _databaseHelper.database;
    await db.insert(
      'bundles',
      bundle.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateBundle(Bundle bundle) async {
    final db = await _databaseHelper.database;
    await db.update(
      'bundles',
      bundle.toMap(),
      where: 'id = ?',
      whereArgs: [bundle.id],
    );
  }

  Future<void> deleteBundle(String id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'bundles',
      where: 'id = ?',
      whereArgs: [id],
    );
    // Also update items to remove bundleId
    await db.update(
      'items',
      {'bundleId': null},
      where: 'bundleId = ?',
      whereArgs: [id],
    );
  }

  Future<void> addItemsToBundle(String bundleId, List<String> itemIds) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      for (String itemId in itemIds) {
        await txn.update(
          'items',
          {'bundleId': bundleId},
          where: 'id = ?',
          whereArgs: [itemId],
        );
      }
    });
  }

  Future<void> removeItemsFromBundle(List<String> itemIds) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      for (String itemId in itemIds) {
        await txn.update(
          'items',
          {'bundleId': null},
          where: 'id = ?',
          whereArgs: [itemId],
        );
      }
    });
  }
}

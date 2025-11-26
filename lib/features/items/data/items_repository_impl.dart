import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../models/item_model.dart';

class ItemsRepositoryImpl {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<List<Item>> getItems() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('items');
    return List.generate(maps.length, (i) {
      return Item.fromMap(maps[i]);
    });
  }

  Future<void> addItem(Item item) async {
    final db = await _databaseHelper.database;
    await db.insert(
      'items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateItem(Item item) async {
    final db = await _databaseHelper.database;
    await db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteItem(String id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteItems(List<String> ids) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'items',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }
}

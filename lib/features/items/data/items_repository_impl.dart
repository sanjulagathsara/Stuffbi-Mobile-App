import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/sync_status.dart';
import '../models/item_model.dart';

class ItemsRepositoryImpl {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  /// Get all items (excluding soft-deleted)
  Future<List<Item>> getItems() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: 'deleted_at IS NULL',
    );
    return List.generate(maps.length, (i) {
      return Item.fromMap(maps[i]);
    });
  }

  /// Add a new item (marks as pending sync)
  Future<void> addItem(Item item) async {
    final db = await _databaseHelper.database;
    final itemWithSync = item.copyWith(
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime.now(),
    );
    await db.insert(
      'items',
      itemWithSync.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an item (marks as pending sync)
  Future<void> updateItem(Item item) async {
    final db = await _databaseHelper.database;
    final itemWithSync = item.copyWith(
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime.now(),
    );
    await db.update(
      'items',
      itemWithSync.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// Soft delete an item (marks for sync deletion)
  Future<void> deleteItem(String id) async {
    final db = await _databaseHelper.database;
    await db.update(
      'items',
      {
        'deleted_at': DateTime.now().toIso8601String(),
        'sync_status': SyncStatus.pending.toDbString(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Soft delete multiple items
  Future<void> deleteItems(List<String> ids) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'items',
      {
        'deleted_at': now,
        'sync_status': SyncStatus.pending.toDbString(),
        'updated_at': now,
      },
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  /// Hard delete an item (after confirmed sync)
  Future<void> hardDeleteItem(String id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== SYNC METHODS ====================

  /// Get all items pending sync (new or updated)
  Future<List<Item>> getPendingItems() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: "sync_status = ? AND deleted_at IS NULL",
      whereArgs: [SyncStatus.pending.toDbString()],
    );
    return maps.map((m) => Item.fromMap(m)).toList();
  }

  /// Get items pending deletion (soft-deleted but not synced)
  Future<List<String>> getPendingDeleteIds() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      columns: ['id'],
      where: "sync_status = ? AND deleted_at IS NOT NULL",
      whereArgs: [SyncStatus.pending.toDbString()],
    );
    return maps.map((m) => m['id'] as String).toList();
  }

  /// Mark an item as synced with server ID
  Future<void> markItemSynced(String localId, int serverId) async {
    final db = await _databaseHelper.database;
    await db.update(
      'items',
      {
        'server_id': serverId,
        'sync_status': SyncStatus.synced.toDbString(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Mark delete as synced (then hard delete)
  Future<void> markDeleteSynced(String localId) async {
    await hardDeleteItem(localId);
  }

  /// Merge server items into local database
  Future<void> mergeServerItems(List<Item> serverItems) async {
    final db = await _databaseHelper.database;
    
    for (final serverItem in serverItems) {
      // Check if we have a local version
      final existing = await db.query(
        'items',
        where: 'id = ? OR server_id = ?',
        whereArgs: [serverItem.id, serverItem.serverId],
      );

      if (existing.isEmpty) {
        // New item from server - insert
        await db.insert('items', serverItem.toMap());
      } else {
        // Existing item - check for conflicts
        final localItem = Item.fromMap(existing.first);
        
        // Last-write-wins: compare updated_at
        if (serverItem.updatedAt != null && localItem.updatedAt != null) {
          if (serverItem.updatedAt!.isAfter(localItem.updatedAt!)) {
            // Server wins
            await db.update(
              'items',
              serverItem.copyWith(id: localItem.id).toMap(),
              where: 'id = ?',
              whereArgs: [localItem.id],
            );
          }
          // else: local wins, keep local version
        } else if (localItem.syncStatus == SyncStatus.synced) {
          // Local is synced, update with server version
          await db.update(
            'items',
            serverItem.copyWith(id: localItem.id).toMap(),
            where: 'id = ?',
            whereArgs: [localItem.id],
          );
        }
      }
    }
  }

  /// Get item by local ID
  Future<Item?> getItemById(String id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Item.fromMap(maps.first);
  }
}


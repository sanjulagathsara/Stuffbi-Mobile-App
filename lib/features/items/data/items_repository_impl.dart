import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../../core/network/api_service.dart';
import '../models/item_model.dart';

class ItemsRepositoryImpl {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final ApiService _apiService = ApiService();

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

  /// Get pending items that have a server_id (for conflict detection)
  Future<List<Item>> getPendingSyncedItems() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: "sync_status = ? AND server_id IS NOT NULL",
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
      print('[ItemsRepo] Merging item: ${serverItem.name}, id=${serverItem.id}, serverId=${serverItem.serverId}');
      
      // Check if we have a local version by server_id or matching local id
      List<Map<String, dynamic>> existing = [];
      
      if (serverItem.serverId != null) {
        existing = await db.query(
          'items',
          where: 'server_id = ?',
          whereArgs: [serverItem.serverId],
        );
      }
      
      // If not found by server_id, check by local id
      if (existing.isEmpty) {
        existing = await db.query(
          'items',
          where: 'id = ?',
          whereArgs: [serverItem.id],
        );
      }

      if (existing.isEmpty) {
        // New item from server - insert
        print('[ItemsRepo] Inserting new item: ${serverItem.name}');
        await db.insert('items', serverItem.toMap());
      } else {
        // Existing item - check for conflicts
        final localItem = Item.fromMap(existing.first);
        print('[ItemsRepo] Found existing item: ${localItem.name}, checking timestamps');
        
        // Last-write-wins: compare updated_at
        if (serverItem.updatedAt != null && localItem.updatedAt != null) {
          if (serverItem.updatedAt!.isAfter(localItem.updatedAt!)) {
            // Server wins
            print('[ItemsRepo] Server version is newer, updating');
            await db.update(
              'items',
              serverItem.copyWith(id: localItem.id).toMap(),
              where: 'id = ?',
              whereArgs: [localItem.id],
            );
          } else {
            print('[ItemsRepo] Local version is newer, keeping local');
          }
        } else if (localItem.syncStatus == SyncStatus.synced) {
          // Local is synced, update with server version
          print('[ItemsRepo] Local is synced, updating with server version');
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

  /// Delete local items that don't exist on server (server IDs not in list)
  Future<void> deleteNonServerItems(Set<int> serverItemIds) async {
    final db = await _databaseHelper.database;
    
    // Get all local items that have a server_id (synced from server)
    final localItems = await db.query(
      'items',
      where: 'server_id IS NOT NULL',
    );
    
    for (final itemMap in localItems) {
      final serverId = itemMap['server_id'] as int?;
      if (serverId != null && !serverItemIds.contains(serverId)) {
        // This item exists locally but not on server - delete it
        print('[ItemsRepo] Deleting item with server_id=$serverId (no longer on server)');
        await db.delete(
          'items',
          where: 'server_id = ?',
          whereArgs: [serverId],
        );
      }
    }
  }

  /// Delete local items that don't exist on server, except those in conflict list
  Future<void> deleteNonServerItemsExcept(Set<int> serverItemIds, Set<String> exceptLocalIds) async {
    final db = await _databaseHelper.database;
    
    // Get all local items that have a server_id (synced from server)
    final localItems = await db.query(
      'items',
      where: 'server_id IS NOT NULL',
    );
    
    for (final itemMap in localItems) {
      final serverId = itemMap['server_id'] as int?;
      final localId = itemMap['id'] as String?;
      
      if (serverId != null && !serverItemIds.contains(serverId)) {
        // This item doesn't exist on server
        if (localId != null && exceptLocalIds.contains(localId)) {
          // Skip - this is in conflict list
          print('[ItemsRepo] Skipping deletion of item with server_id=$serverId (in conflict)');
          continue;
        }
        // Delete it
        print('[ItemsRepo] Deleting item with server_id=$serverId (no longer on server)');
        await db.delete(
          'items',
          where: 'server_id = ?',
          whereArgs: [serverId],
        );
      }
    }
  }

  /// Update item's bundle_id directly on server via PUT /items/{serverId}
  /// This is used when moving items between bundles to avoid sync duplication
  /// Returns true if successful, false otherwise
  Future<bool> updateItemBundleOnServer(int itemServerId, int? bundleServerId) async {
    try {
      print('[ItemsRepo] Updating item $itemServerId bundle to $bundleServerId on server');
      
      final response = await _apiService.put(
        '/items/$itemServerId',
        {'bundle_id': bundleServerId},
      );
      
      if (response.success) {
        print('[ItemsRepo] Successfully updated item bundle on server');
        return true;
      } else {
        print('[ItemsRepo] Failed to update item bundle on server: ${response.error}');
        return false;
      }
    } catch (e) {
      print('[ItemsRepo] Error updating item bundle on server: $e');
      return false;
    }
  }

  /// Create item on server via POST /items
  /// Returns the server ID if successful, null otherwise
  /// Also updates local item with server ID
  Future<int?> createItemOnServer(Item item, {int? bundleServerId}) async {
    try {
      print('[ItemsRepo] Creating item ${item.name} on server');
      
      final requestBody = {
        'name': item.name,
        'subtitle': item.details,
        'bundle_id': bundleServerId,
        'image_url': item.imagePath,
      };
      
      final response = await _apiService.post('/items', requestBody);
      
      if (response.success && response.data != null) {
        final serverId = response.data['id'] as int?;
        if (serverId != null) {
          // Update local item with server ID and mark as synced
          final db = await _databaseHelper.database;
          await db.update(
            'items',
            {
              'server_id': serverId,
              'sync_status': SyncStatus.synced.toDbString(),
            },
            where: 'id = ?',
            whereArgs: [item.id],
          );
          print('[ItemsRepo] Item created on server with ID: $serverId');
          return serverId;
        }
      }
      print('[ItemsRepo] Failed to create item on server: ${response.error}');
      return null;
    } catch (e) {
      print('[ItemsRepo] Error creating item on server: $e');
      return null;
    }
  }

  /// Update item on server via PUT /items/{serverId}
  /// Returns true if successful
  Future<bool> updateItemOnServer(Item item) async {
    if (item.serverId == null) {
      print('[ItemsRepo] Cannot update item on server - no server ID');
      return false;
    }
    
    try {
      print('[ItemsRepo] Updating item ${item.name} on server');
      
      final requestBody = {
        'name': item.name,
        'subtitle': item.details,
        'image_url': item.imagePath,
      };
      
      final response = await _apiService.put('/items/${item.serverId}', requestBody);
      
      if (response.success) {
        // Mark as synced
        final db = await _databaseHelper.database;
        await db.update(
          'items',
          {'sync_status': SyncStatus.synced.toDbString()},
          where: 'id = ?',
          whereArgs: [item.id],
        );
        print('[ItemsRepo] Item updated on server successfully');
        return true;
      }
      print('[ItemsRepo] Failed to update item on server: ${response.error}');
      return false;
    } catch (e) {
      print('[ItemsRepo] Error updating item on server: $e');
      return false;
    }
  }

  /// Delete item on server via DELETE /items/{serverId}
  /// Returns true if successful
  Future<bool> deleteItemOnServer(int serverId) async {
    try {
      print('[ItemsRepo] Deleting item $serverId on server');
      
      final response = await _apiService.delete('/items/$serverId');
      
      if (response.success) {
        print('[ItemsRepo] Item deleted on server successfully');
        return true;
      }
      print('[ItemsRepo] Failed to delete item on server: ${response.error}');
      return false;
    } catch (e) {
      print('[ItemsRepo] Error deleting item on server: $e');
      return false;
    }
  }

  /// Fetch all items from server via GET /items and merge with local DB
  /// This updates local items to match server state
  Future<bool> fetchItemsFromServer() async {
    try {
      print('[ItemsRepo] Fetching items from server via GET /items');
      
      final response = await _apiService.get('/items');
      
      if (!response.success || response.data == null) {
        print('[ItemsRepo] Failed to fetch items: ${response.error}');
        return false;
      }
      
      final serverItems = response.data as List<dynamic>;
      print('[ItemsRepo] Received ${serverItems.length} items from server');
      
      final db = await _databaseHelper.database;
      
      // Get all local bundles to map server bundle_id to local bundle id
      final localBundles = await db.query('bundles');
      final bundleServerToLocalMap = <int, String>{};
      for (final b in localBundles) {
        final serverId = b['server_id'] as int?;
        final localId = b['id'] as String?;
        if (serverId != null && localId != null) {
          bundleServerToLocalMap[serverId] = localId;
        }
      }
      
      // Track server IDs we've seen
      final Set<int> serverItemIds = {};
      
      for (final serverItem in serverItems) {
        final serverId = serverItem['id'] as int?;
        if (serverId == null) continue;
        
        serverItemIds.add(serverId);
        
        // Map server bundle_id to local bundle id
        final serverBundleId = serverItem['bundle_id'] as int?;
        String? localBundleId;
        if (serverBundleId != null) {
          localBundleId = bundleServerToLocalMap[serverBundleId];
          // If bundle mapping not found, use server ID format
          // This can happen if bundles haven't been synced yet
          if (localBundleId == null) {
            localBundleId = 'server_$serverBundleId';
            print('[ItemsRepo] No local bundle found for server bundle $serverBundleId, using server_$serverBundleId');
          }
        }
        
        // Check if we have this item locally by server_id
        final existing = await db.query(
          'items',
          where: 'server_id = ?',
          whereArgs: [serverId],
        );
        
        if (existing.isEmpty) {
          // New item from server - insert
          print('[ItemsRepo] Inserting new item from server: ${serverItem['name']}');
          await db.insert('items', {
            'id': 'server_$serverId',
            'name': serverItem['name'] ?? '',
            'category': '',
            'bundleId': localBundleId,
            'imagePath': serverItem['image_url'],
            'details': serverItem['subtitle'] ?? '',
            'isSynced': 1,
            'is_checked': 0,
            'server_id': serverId,
            'sync_status': SyncStatus.synced.toDbString(),
            'updated_at': serverItem['updated_at'],
          });
        } else {
          // Update existing item
          final localItem = existing.first;
          final localSyncStatus = localItem['sync_status'] as String?;
          
          // Only update if not pending (don't overwrite local changes)
          if (localSyncStatus != SyncStatus.pending.toDbString()) {
            print('[ItemsRepo] Updating item from server: ${serverItem['name']}');
            await db.update(
              'items',
              {
                'name': serverItem['name'] ?? localItem['name'],
                'bundleId': localBundleId,
                'imagePath': serverItem['image_url'] ?? localItem['imagePath'],
                'details': serverItem['subtitle'] ?? localItem['details'],
                'sync_status': SyncStatus.synced.toDbString(),
                'updated_at': serverItem['updated_at'],
              },
              where: 'server_id = ?',
              whereArgs: [serverId],
            );
          } else {
            print('[ItemsRepo] Skipping update for pending item: ${serverItem['name']}');
          }
        }
      }
      
      // Delete local items that no longer exist on server (and are not pending)
      final localItems = await db.query('items', where: 'server_id IS NOT NULL AND deleted_at IS NULL');
      for (final localItem in localItems) {
        final serverId = localItem['server_id'] as int?;
        final syncStatus = localItem['sync_status'] as String?;
        
        if (serverId != null && !serverItemIds.contains(serverId) && syncStatus != SyncStatus.pending.toDbString()) {
          print('[ItemsRepo] Deleting item no longer on server: ${localItem['name']}');
          await db.delete('items', where: 'server_id = ?', whereArgs: [serverId]);
        }
      }
      
      print('[ItemsRepo] Fetch from server complete');
      return true;
    } catch (e) {
      print('[ItemsRepo] Error fetching items from server: $e');
      return false;
    }
  }
}


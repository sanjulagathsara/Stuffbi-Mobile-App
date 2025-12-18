import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/sync_status.dart';
import '../../items/data/items_repository_impl.dart';
import '../models/bundle_model.dart';

class BundlesRepositoryImpl {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final ItemsRepositoryImpl _itemsRepo = ItemsRepositoryImpl();

  /// Get all bundles (excluding soft-deleted)
  Future<List<Bundle>> getBundles() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bundles',
      where: 'deleted_at IS NULL',
    );
    return List.generate(maps.length, (i) {
      return Bundle.fromMap(maps[i]);
    });
  }

  /// Add a new bundle (marks as pending sync)
  Future<void> addBundle(Bundle bundle) async {
    final db = await _databaseHelper.database;
    final bundleWithSync = bundle.copyWith(
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime.now(),
    );
    await db.insert(
      'bundles',
      bundleWithSync.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update a bundle (marks as pending sync)
  Future<void> updateBundle(Bundle bundle) async {
    final db = await _databaseHelper.database;
    final bundleWithSync = bundle.copyWith(
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime.now(),
    );
    await db.update(
      'bundles',
      bundleWithSync.toMap(),
      where: 'id = ?',
      whereArgs: [bundle.id],
    );
  }

  /// Soft delete a bundle (marks for sync deletion)
  Future<void> deleteBundle(String id) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'bundles',
      {
        'deleted_at': now,
        'sync_status': SyncStatus.pending.toDbString(),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    // Also update items to remove bundleId and mark as pending
    await db.update(
      'items',
      {
        'bundleId': null,
        'sync_status': SyncStatus.pending.toDbString(),
        'updated_at': now,
      },
      where: 'bundleId = ?',
      whereArgs: [id],
    );
  }

  /// Add items to bundle
  /// For items with serverId, calls API directly to update bundle_id
  /// For items without serverId, marks as pending (sync will handle creation)
  Future<void> addItemsToBundle(String bundleId, List<String> itemIds) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    
    // Get the bundle's server ID (needed for API call)
    final bundleMaps = await db.query(
      'bundles',
      columns: ['server_id'],
      where: 'id = ?',
      whereArgs: [bundleId],
    );
    final int? bundleServerId = bundleMaps.isNotEmpty ? bundleMaps.first['server_id'] as int? : null;
    
    for (String itemId in itemIds) {
      // Get item's server ID
      final itemMaps = await db.query(
        'items',
        columns: ['server_id'],
        where: 'id = ?',
        whereArgs: [itemId],
      );
      final int? itemServerId = itemMaps.isNotEmpty ? itemMaps.first['server_id'] as int? : null;
      
      // If both item and bundle have server IDs, call API directly
      if (itemServerId != null && bundleServerId != null) {
        debugPrint('[BundlesRepo] Updating item $itemId bundle via API (item server: $itemServerId, bundle server: $bundleServerId)');
        final success = await _itemsRepo.updateItemBundleOnServer(itemServerId, bundleServerId);
        
        if (success) {
          // API call succeeded, mark as synced
          await db.update(
            'items',
            {
              'bundleId': bundleId,
              'sync_status': SyncStatus.synced.toDbString(),
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [itemId],
          );
        } else {
          // API call failed, mark as pending for retry
          await db.update(
            'items',
            {
              'bundleId': bundleId,
              'sync_status': SyncStatus.pending.toDbString(),
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [itemId],
          );
        }
      } else {
        // No server IDs, just update locally and mark pending for sync
        debugPrint('[BundlesRepo] Updating item $itemId bundle locally (no server IDs yet)');
        await db.update(
          'items',
          {
            'bundleId': bundleId,
            'sync_status': SyncStatus.pending.toDbString(),
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [itemId],
        );
      }
    }
  }

  /// Remove items from bundle (marks items as pending sync)
  Future<void> removeItemsFromBundle(List<String> itemIds) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (String itemId in itemIds) {
        await txn.update(
          'items',
          {
            'bundleId': null,
            'sync_status': SyncStatus.pending.toDbString(),
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [itemId],
        );
      }
    });
  }

  // ==================== SYNC METHODS ====================

  /// Get all bundles pending sync (new or updated)
  Future<List<Bundle>> getPendingBundles() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bundles',
      where: "sync_status = ? AND deleted_at IS NULL",
      whereArgs: [SyncStatus.pending.toDbString()],
    );
    return maps.map((m) => Bundle.fromMap(m)).toList();
  }

  /// Get pending bundles that have a server_id (for conflict detection)
  Future<List<Bundle>> getPendingSyncedBundles() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bundles',
      where: "sync_status = ? AND server_id IS NOT NULL",
      whereArgs: [SyncStatus.pending.toDbString()],
    );
    return maps.map((m) => Bundle.fromMap(m)).toList();
  }

  /// Get bundles pending deletion (soft-deleted but not synced)
  Future<List<String>> getPendingDeleteIds() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bundles',
      columns: ['id'],
      where: "sync_status = ? AND deleted_at IS NOT NULL",
      whereArgs: [SyncStatus.pending.toDbString()],
    );
    return maps.map((m) => m['id'] as String).toList();
  }

  /// Mark a bundle as synced with server ID
  Future<void> markBundleSynced(String localId, int serverId) async {
    final db = await _databaseHelper.database;
    await db.update(
      'bundles',
      {
        'server_id': serverId,
        'sync_status': SyncStatus.synced.toDbString(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Hard delete a bundle (after confirmed sync)
  Future<void> hardDeleteBundle(String id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'bundles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark delete as synced (then hard delete)
  Future<void> markDeleteSynced(String localId) async {
    await hardDeleteBundle(localId);
  }

  /// Merge server bundles into local database
  Future<void> mergeServerBundles(List<Bundle> serverBundles) async {
    final db = await _databaseHelper.database;
    
    for (final serverBundle in serverBundles) {
      print('[BundlesRepo] Merging bundle: ${serverBundle.name}, id=${serverBundle.id}, serverId=${serverBundle.serverId}');
      
      // Check if we have a local version by server_id or matching local id
      List<Map<String, dynamic>> existing = [];
      
      if (serverBundle.serverId != null) {
        existing = await db.query(
          'bundles',
          where: 'server_id = ?',
          whereArgs: [serverBundle.serverId],
        );
      }
      
      // If not found by server_id, check by local id
      if (existing.isEmpty) {
        existing = await db.query(
          'bundles',
          where: 'id = ?',
          whereArgs: [serverBundle.id],
        );
      }

      if (existing.isEmpty) {
        // New bundle from server - insert
        print('[BundlesRepo] Inserting new bundle: ${serverBundle.name}');
        await db.insert('bundles', serverBundle.toMap());
      } else {
        // Existing bundle - check for conflicts
        final localBundle = Bundle.fromMap(existing.first);
        print('[BundlesRepo] Found existing bundle: ${localBundle.name}, checking timestamps');
        
        // Last-write-wins: compare updated_at
        if (serverBundle.updatedAt != null && localBundle.updatedAt != null) {
          if (serverBundle.updatedAt!.isAfter(localBundle.updatedAt!)) {
            // Server wins
            print('[BundlesRepo] Server version is newer, updating');
            await db.update(
              'bundles',
              serverBundle.copyWith(id: localBundle.id).toMap(),
              where: 'id = ?',
              whereArgs: [localBundle.id],
            );
          } else {
            print('[BundlesRepo] Local version is newer, keeping local');
          }
        } else if (localBundle.syncStatus == SyncStatus.synced) {
          // Local is synced, update with server version
          print('[BundlesRepo] Local is synced, updating with server version');
          await db.update(
            'bundles',
            serverBundle.copyWith(id: localBundle.id).toMap(),
            where: 'id = ?',
            whereArgs: [localBundle.id],
          );
        }
      }
    }
  }

  /// Get bundle by local ID
  Future<Bundle?> getBundleById(String id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'bundles',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Bundle.fromMap(maps.first);
  }

  /// Delete local bundles that don't exist on server (server IDs not in list)
  Future<void> deleteNonServerBundles(Set<int> serverBundleIds) async {
    final db = await _databaseHelper.database;
    
    // Get all local bundles that have a server_id (synced from server)
    final localBundles = await db.query(
      'bundles',
      where: 'server_id IS NOT NULL',
    );
    
    for (final bundleMap in localBundles) {
      final serverId = bundleMap['server_id'] as int?;
      if (serverId != null && !serverBundleIds.contains(serverId)) {
        // This bundle exists locally but not on server - delete it
        print('[BundlesRepo] Deleting bundle with server_id=$serverId (no longer on server)');
        await db.delete(
          'bundles',
          where: 'server_id = ?',
          whereArgs: [serverId],
        );
      }
    }
  }

  /// Delete local bundles that don't exist on server, except those in conflict list
  Future<void> deleteNonServerBundlesExcept(Set<int> serverBundleIds, Set<String> exceptLocalIds) async {
    final db = await _databaseHelper.database;
    
    // Get all local bundles that have a server_id (synced from server)
    final localBundles = await db.query(
      'bundles',
      where: 'server_id IS NOT NULL',
    );
    
    for (final bundleMap in localBundles) {
      final serverId = bundleMap['server_id'] as int?;
      final localId = bundleMap['id'] as String?;
      
      if (serverId != null && !serverBundleIds.contains(serverId)) {
        // This bundle doesn't exist on server
        if (localId != null && exceptLocalIds.contains(localId)) {
          // Skip - this is in conflict list
          print('[BundlesRepo] Skipping deletion of bundle with server_id=$serverId (in conflict)');
          continue;
        }
        // Delete it
        print('[BundlesRepo] Deleting bundle with server_id=$serverId (no longer on server)');
        await db.delete(
          'bundles',
          where: 'server_id = ?',
          whereArgs: [serverId],
        );
      }
    }
  }
}


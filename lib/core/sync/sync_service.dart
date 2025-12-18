import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_service.dart';
import '../services/s3_upload_service.dart';
import '../services/image_url_service.dart';
import 'connectivity_service.dart';
import 'sync_status.dart';
import 'sync_conflict.dart';
import '../../features/items/data/items_repository_impl.dart';
import '../../features/items/models/item_model.dart';
import '../../features/bundles/data/bundles_repository_impl.dart';
import '../../features/bundles/models/bundle_model.dart';

/// Core sync service that handles bidirectional synchronization
class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final ApiService _apiService = ApiService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final ItemsRepositoryImpl _itemsRepo = ItemsRepositoryImpl();
  final BundlesRepositoryImpl _bundlesRepo = BundlesRepositoryImpl();
  
  Timer? _periodicSyncTimer;
  bool _isSyncing = false;
  bool _isInitialized = false;
  DateTime? _lastSyncAt;
  String? _lastError;
  
  // Conflicts detected during sync (items/bundles deleted on server with pending local changes)
  final List<SyncConflict> _pendingConflicts = [];
  
  // Sync interval: 30 seconds
  static const Duration _syncInterval = Duration(seconds: 30);
  
  // Callbacks for notifying repositories
  final List<Function()> _onSyncCompleteCallbacks = [];
  
  // Callback for conflict resolution
  Function(List<SyncConflict>)? _onConflictsDetected;

  bool get isSyncing => _isSyncing;
  bool get isInitialized => _isInitialized;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastError => _lastError;
  List<SyncConflict> get pendingConflicts => List.unmodifiable(_pendingConflicts);
  bool get hasConflicts => _pendingConflicts.isNotEmpty;

  /// Initialize sync service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load last sync timestamp
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString('last_sync_at');
    if (lastSyncStr != null) {
      _lastSyncAt = DateTime.tryParse(lastSyncStr);
    }

    // Listen for connectivity changes
    _connectivityService.addListener(_onConnectivityChanged);

    // Start periodic sync timer
    _startPeriodicSync();

    _isInitialized = true;
    print('[SyncService] Initialized. Last sync: $_lastSyncAt');

    // Trigger initial sync if connected
    print('[SyncService] Connected: ${_connectivityService.isConnected}');
    if (_connectivityService.isConnected) {
      scheduleSync();
    }
  }

  /// Register a callback to be notified when sync completes
  void addSyncCompleteCallback(Function() callback) {
    _onSyncCompleteCallbacks.add(callback);
  }

  void removeSyncCompleteCallback(Function() callback) {
    _onSyncCompleteCallbacks.remove(callback);
  }

  /// Register callback for when conflicts are detected
  void setConflictCallback(Function(List<SyncConflict>)? callback) {
    _onConflictsDetected = callback;
  }

  /// Resolve a conflict - either delete locally or restore to cloud
  Future<bool> resolveConflict(SyncConflict conflict, ConflictResolution resolution) async {
    switch (resolution) {
      case ConflictResolution.deleteLocally:
        // Accept server deletion - remove from local DB
        if (conflict.type == SyncConflictType.itemDeletedOnServer) {
          await _itemsRepo.deleteItem(conflict.localId);
        } else {
          await _bundlesRepo.deleteBundle(conflict.localId);
        }
        _pendingConflicts.remove(conflict);
        notifyListeners();
        return true;
        
      case ConflictResolution.restoreToCloud:
        // Push local version back to server
        if (conflict.type == SyncConflictType.itemDeletedOnServer && conflict.item != null) {
          final success = await _restoreItemToCloud(conflict.item!);
          if (success) {
            _pendingConflicts.remove(conflict);
            notifyListeners();
          }
          return success;
        } else if (conflict.bundle != null) {
          final success = await _restoreBundleToCloud(conflict.bundle!);
          if (success) {
            _pendingConflicts.remove(conflict);
            notifyListeners();
          }
          return success;
        }
        return false;
        
      case ConflictResolution.skip:
        // Do nothing for now
        return true;
    }
  }

  /// Restore item to cloud (re-create it)
  Future<bool> _restoreItemToCloud(Item item) async {
    try {
      final response = await _apiService.post('/items', item.toServerJson());
      if (response.success && response.data != null) {
        // Update local item with new server ID
        final newServerId = response.data['id'];
        await _itemsRepo.updateItem(item.copyWith(
          serverId: newServerId,
          syncStatus: SyncStatus.synced,
        ));
        print('[SyncService] Restored item to cloud: ${item.name}');
        return true;
      }
    } catch (e) {
      print('[SyncService] Error restoring item: $e');
    }
    return false;
  }

  /// Restore bundle to cloud (re-create it)
  Future<bool> _restoreBundleToCloud(Bundle bundle) async {
    try {
      final response = await _apiService.post('/bundles', bundle.toServerJson());
      if (response.success && response.data != null) {
        // Update local bundle with new server ID
        final newServerId = response.data['id'];
        await _bundlesRepo.updateBundle(bundle.copyWith(
          serverId: newServerId,
          syncStatus: SyncStatus.synced,
        ));
        print('[SyncService] Restored bundle to cloud: ${bundle.name}');
        return true;
      }
    } catch (e) {
      print('[SyncService] Error restoring bundle: $e');
    }
    return false;
  }

  /// Clear all pending conflicts
  void clearConflicts() {
    _pendingConflicts.clear();
    notifyListeners();
  }

  void _onConnectivityChanged() {
    if (_connectivityService.isConnected) {
      debugPrint('[SyncService] Connection restored, triggering sync');
      scheduleSync();
    }
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(_syncInterval, (_) {
      if (_connectivityService.isConnected) {
        debugPrint('[SyncService] Periodic sync triggered');
        scheduleSync();
      }
    });
  }

  /// Schedule a sync operation (debounced)
  Timer? _debounceTimer;
  void scheduleSync() {
    print('[SyncService] scheduleSync called');
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      print('[SyncService] Debounce timer fired, calling performSync');
      performSync();
    });
  }

  /// Perform full bidirectional sync using direct CRUD APIs
  /// This replaces the old /sync endpoint with direct POST/PUT/DELETE calls
  Future<bool> performSync() async {
    // Check if user is logged in
    final isLoggedIn = await _apiService.isLoggedIn();
    if (!isLoggedIn) {
      debugPrint('[SyncService] Not logged in, skipping sync');
      return false;
    }

    // Check connectivity
    if (!_connectivityService.isConnected) {
      debugPrint('[SyncService] No connectivity, skipping sync');
      return false;
    }

    // Prevent concurrent syncs
    if (_isSyncing) {
      debugPrint('[SyncService] Already syncing, skipping');
      return false;
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      debugPrint('[SyncService] Starting sync with direct APIs...');

      // === STEP 1: Fetch server data first to get latest updated_at timestamps ===
      debugPrint('[SyncService] Step 1: Fetching server bundles...');
      final serverBundlesResponse = await _apiService.get('/bundles');
      final serverBundles = serverBundlesResponse.success 
          ? (serverBundlesResponse.data as List<dynamic>?) ?? []
          : [];
      
      debugPrint('[SyncService] Step 2: Fetching server items...');
      final serverItemsResponse = await _apiService.get('/items');
      final serverItems = serverItemsResponse.success 
          ? (serverItemsResponse.data as List<dynamic>?) ?? []
          : [];

      // Build server timestamp maps (serverId -> updated_at)
      final serverBundleTimestamps = <int, DateTime>{};
      for (final b in serverBundles) {
        final id = b['id'] as int?;
        final updatedAt = b['updated_at'] != null ? DateTime.tryParse(b['updated_at'].toString()) : null;
        if (id != null && updatedAt != null) {
          serverBundleTimestamps[id] = updatedAt;
        }
      }

      final serverItemTimestamps = <int, DateTime>{};
      for (final item in serverItems) {
        final id = item['id'] as int?;
        final updatedAt = item['updated_at'] != null ? DateTime.tryParse(item['updated_at'].toString()) : null;
        if (id != null && updatedAt != null) {
          serverItemTimestamps[id] = updatedAt;
        }
      }

      // === STEP 2: Sync pending bundles using direct APIs ===
      debugPrint('[SyncService] Step 3: Syncing pending bundles...');
      await _syncPendingBundles(serverBundleTimestamps);

      // === STEP 3: Sync pending items using direct APIs ===
      debugPrint('[SyncService] Step 4: Syncing pending items...');
      await _syncPendingItems(serverItemTimestamps);

      // === STEP 4: Handle pending deletes ===
      debugPrint('[SyncService] Step 5: Processing deletes...');
      await _syncPendingDeletes();

      // === STEP 5: Merge server changes into local DB ===
      debugPrint('[SyncService] Step 6: Merging server changes...');
      await _bundlesRepo.fetchBundlesFromServer();
      await _itemsRepo.fetchItemsFromServer();

      // Update last sync timestamp
      _lastSyncAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_at', _lastSyncAt!.toIso8601String());

      debugPrint('[SyncService] Sync completed successfully');

      // Notify callbacks
      for (final callback in _onSyncCompleteCallbacks) {
        callback();
      }

      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[SyncService] Sync error: $e');
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Sync pending bundles using POST /bundles and PUT /bundles/:id
  Future<void> _syncPendingBundles(Map<int, DateTime> serverTimestamps) async {
    final pendingBundles = await _bundlesRepo.getPendingBundles();
    debugPrint('[SyncService] Found ${pendingBundles.length} pending bundles');

    for (final bundle in pendingBundles) {
      try {
        if (bundle.serverId == null) {
          // NEW bundle - POST to create
          debugPrint('[SyncService] Creating new bundle: ${bundle.name}');
          final response = await _apiService.post('/bundles', {
            'title': bundle.name,
            'subtitle': bundle.description,
            'image_url': bundle.imagePath,
          });

          if (response.success && response.data != null) {
            final serverId = response.data['id'] as int?;
            if (serverId != null) {
              await _bundlesRepo.markBundleSynced(bundle.id, serverId);
              // Upload image if needed
              await _uploadBundleImageIfNeeded(bundle.id, serverId);
              debugPrint('[SyncService] Bundle created with server ID: $serverId');
            }
          } else {
            debugPrint('[SyncService] Failed to create bundle: ${response.error}');
          }
        } else {
          // EXISTING bundle - check conflict then PUT
          final serverUpdatedAt = serverTimestamps[bundle.serverId];
          final localUpdatedAt = bundle.updatedAt;

          // Conflict check: only push if local is newer
          if (serverUpdatedAt != null && localUpdatedAt != null) {
            if (localUpdatedAt.isBefore(serverUpdatedAt) || localUpdatedAt.isAtSameMomentAs(serverUpdatedAt)) {
              debugPrint('[SyncService] Skipping bundle ${bundle.name} - server has newer version');
              // Mark as synced since server wins
              await _bundlesRepo.markBundleSynced(bundle.id, bundle.serverId!);
              continue;
            }
          }

          debugPrint('[SyncService] Updating bundle: ${bundle.name}');
          final response = await _apiService.put('/bundles/${bundle.serverId}', {
            'title': bundle.name,
            'subtitle': bundle.description,
            'image_url': bundle.imagePath,
          });

          if (response.success) {
            await _bundlesRepo.markBundleSynced(bundle.id, bundle.serverId!);
            debugPrint('[SyncService] Bundle updated successfully');
          } else {
            debugPrint('[SyncService] Failed to update bundle: ${response.error}');
          }
        }
      } catch (e) {
        debugPrint('[SyncService] Error syncing bundle ${bundle.name}: $e');
      }
    }
  }

  /// Sync pending items using POST /items and PUT /items/:id
  Future<void> _syncPendingItems(Map<int, DateTime> serverTimestamps) async {
    final pendingItems = await _itemsRepo.getPendingItems();
    debugPrint('[SyncService] Found ${pendingItems.length} pending items');

    for (final item in pendingItems) {
      try {
        // Get bundle's server ID for the request
        int? bundleServerId;
        if (item.bundleId != null) {
          final bundle = await _bundlesRepo.getBundleById(item.bundleId!);
          bundleServerId = bundle?.serverId;
        }

        if (item.serverId == null) {
          // NEW item - POST to create
          debugPrint('[SyncService] Creating new item: ${item.name}');
          final response = await _apiService.post('/items', {
            'name': item.name,
            'subtitle': item.details,
            'bundle_id': bundleServerId,
            'image_url': item.imagePath,
          });

          if (response.success && response.data != null) {
            final serverId = response.data['id'] as int?;
            if (serverId != null) {
              await _itemsRepo.markItemSynced(item.id, serverId);
              debugPrint('[SyncService] Item created with server ID: $serverId');
            }
          } else {
            debugPrint('[SyncService] Failed to create item: ${response.error}');
          }
        } else {
          // EXISTING item - check conflict then PUT
          final serverUpdatedAt = serverTimestamps[item.serverId];
          final localUpdatedAt = item.updatedAt;

          // Conflict check: only push if local is newer
          if (serverUpdatedAt != null && localUpdatedAt != null) {
            if (localUpdatedAt.isBefore(serverUpdatedAt) || localUpdatedAt.isAtSameMomentAs(serverUpdatedAt)) {
              debugPrint('[SyncService] Skipping item ${item.name} - server has newer version');
              // Mark as synced since server wins
              await _itemsRepo.markItemSynced(item.id, item.serverId!);
              continue;
            }
          }

          debugPrint('[SyncService] Updating item: ${item.name}');
          final response = await _apiService.put('/items/${item.serverId}', {
            'name': item.name,
            'subtitle': item.details,
            'bundle_id': bundleServerId,
            'image_url': item.imagePath,
          });

          if (response.success) {
            await _itemsRepo.markItemSynced(item.id, item.serverId!);
            debugPrint('[SyncService] Item updated successfully');
          } else {
            debugPrint('[SyncService] Failed to update item: ${response.error}');
          }
        }
      } catch (e) {
        debugPrint('[SyncService] Error syncing item ${item.name}: $e');
      }
    }
  }

  /// Sync pending deletes using DELETE /items/:id and DELETE /bundles/:id
  Future<void> _syncPendingDeletes() async {
    // Delete items
    final pendingItemDeletes = await _itemsRepo.getPendingDeleteIds();
    debugPrint('[SyncService] Found ${pendingItemDeletes.length} pending item deletes');

    for (final itemId in pendingItemDeletes) {
      try {
        final item = await _itemsRepo.getItemById(itemId);
        if (item?.serverId != null) {
          debugPrint('[SyncService] Deleting item from server: ${item!.serverId}');
          final response = await _apiService.delete('/items/${item.serverId}');
          if (response.success) {
            await _itemsRepo.markDeleteSynced(itemId);
            debugPrint('[SyncService] Item deleted from server');
          }
        } else {
          // No server ID means it was never synced, just clean up locally
          await _itemsRepo.markDeleteSynced(itemId);
        }
      } catch (e) {
        debugPrint('[SyncService] Error deleting item: $e');
      }
    }

    // Delete bundles
    final pendingBundleDeletes = await _bundlesRepo.getPendingDeleteIds();
    debugPrint('[SyncService] Found ${pendingBundleDeletes.length} pending bundle deletes');

    for (final bundleId in pendingBundleDeletes) {
      try {
        final bundle = await _bundlesRepo.getBundleById(bundleId);
        if (bundle?.serverId != null) {
          debugPrint('[SyncService] Deleting bundle from server: ${bundle!.serverId}');
          final response = await _apiService.delete('/bundles/${bundle.serverId}');
          if (response.success) {
            await _bundlesRepo.markDeleteSynced(bundleId);
            debugPrint('[SyncService] Bundle deleted from server');
          }
        } else {
          // No server ID means it was never synced, just clean up locally
          await _bundlesRepo.markDeleteSynced(bundleId);
        }
      } catch (e) {
        debugPrint('[SyncService] Error deleting bundle: $e');
      }
    }
  }

  /// Process sync response from server
  Future<void> _processSyncResponse(Map<String, dynamic> data) async {
    final items = data['items'] as Map<String, dynamic>?;
    final bundles = data['bundles'] as Map<String, dynamic>?;

    // --- Process CREATED items (mark local items as synced) ---
    if (items != null) {
      final createdItems = items['created'] as List<dynamic>?;
      if (createdItems != null) {
        for (final item in createdItems) {
          if (item['client_id'] != null && item['id'] != null) {
            await _itemsRepo.markItemSynced(item['client_id'], item['id']);
            print('[SyncService] Marked item ${item['client_id']} as synced with server ID ${item['id']}');
          }
        }
      }

      final deletedItems = items['deleted'] as List<dynamic>?;
      if (deletedItems != null) {
        for (final clientId in deletedItems) {
          await _itemsRepo.markDeleteSynced(clientId);
        }
      }

      // --- Process SERVER CHANGES (pull from cloud) ---
      final serverItems = items['server_changes'] as List<dynamic>?;
      if (serverItems != null && serverItems.isNotEmpty) {
        print('[SyncService] Processing ${serverItems.length} items from server');
        final itemModels = serverItems.map((json) {
          // Convert server JSON to Item model
          return Item.fromServerJson(json as Map<String, dynamic>);
        }).toList();
        await _itemsRepo.mergeServerItems(itemModels);
      }
    }

    // --- Process CREATED bundles (mark local bundles as synced + upload images) ---
    if (bundles != null) {
      final createdBundles = bundles['created'] as List<dynamic>?;
      if (createdBundles != null) {
        for (final bundle in createdBundles) {
          if (bundle['client_id'] != null && bundle['id'] != null) {
            final clientId = bundle['client_id'] as String;
            final serverId = bundle['id'] as int;
            
            await _bundlesRepo.markBundleSynced(clientId, serverId);
            print('[SyncService] Marked bundle $clientId as synced with server ID $serverId');
            
            // Check if bundle has a local image that needs to be uploaded to S3
            await _uploadBundleImageIfNeeded(clientId, serverId);
          }
        }
      }

      final deletedBundles = bundles['deleted'] as List<dynamic>?;
      if (deletedBundles != null) {
        for (final clientId in deletedBundles) {
          await _bundlesRepo.markDeleteSynced(clientId);
        }
      }

      // --- Process SERVER CHANGES (pull from cloud) ---
      final serverBundles = bundles['server_changes'] as List<dynamic>?;
      if (serverBundles != null && serverBundles.isNotEmpty) {
        print('[SyncService] Processing ${serverBundles.length} bundles from server');
        final bundleModels = serverBundles.map((json) {
          // Convert server JSON to Bundle model
          return Bundle.fromServerJson(json as Map<String, dynamic>);
        }).toList();
        await _bundlesRepo.mergeServerBundles(bundleModels);
      }
    }
  }

  /// Pull-only sync (for refresh) using direct GET APIs
  Future<bool> pullChanges() async {
    final isLoggedIn = await _apiService.isLoggedIn();
    if (!isLoggedIn || !_connectivityService.isConnected) {
      return false;
    }

    try {
      debugPrint('[SyncService] Pulling changes from server...');
      
      // Use direct GET APIs instead of /sync/pull
      await _bundlesRepo.fetchBundlesFromServer();
      await _itemsRepo.fetchItemsFromServer();
      
      _lastSyncAt = DateTime.now();
      
      for (final callback in _onSyncCompleteCallbacks) {
        callback();
      }
      
      debugPrint('[SyncService] Pull changes complete');
      return true;
    } catch (e) {
      debugPrint('[SyncService] Pull error: $e');
      return false;
    }
  }

  /// Full sync - fetches ALL data from server and merges with local database
  /// Uses last-write-wins based on updated_at timestamps
  Future<bool> fullSync() async {
    final isLoggedIn = await _apiService.isLoggedIn();
    if (!isLoggedIn) {
      print('[SyncService] Not logged in, skipping full sync');
      return false;
    }

    if (!_connectivityService.isConnected) {
      print('[SyncService] No connectivity, skipping full sync');
      return false;
    }

    if (_isSyncing) {
      print('[SyncService] Already syncing, skipping');
      return false;
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      print('[SyncService] Starting full sync...');

      // First, push any local pending changes
      final pendingItems = await _itemsRepo.getPendingItems();
      final pendingItemDeletes = await _itemsRepo.getPendingDeleteIds();
      final pendingBundles = await _bundlesRepo.getPendingBundles();
      final pendingBundleDeletes = await _bundlesRepo.getPendingDeleteIds();

      if (pendingItems.isNotEmpty || pendingBundles.isNotEmpty || 
          pendingItemDeletes.isNotEmpty || pendingBundleDeletes.isNotEmpty) {
        print('[SyncService] Pushing ${pendingItems.length} items, ${pendingBundles.length} bundles first...');
        
        final pushRequest = {
          'items': {
            'created': pendingItems.where((i) => i.serverId == null).map((i) => i.toServerJson()).toList(),
            'updated': pendingItems.where((i) => i.serverId != null).map((i) => i.toServerJson()).toList(),
            'deleted': pendingItemDeletes,
          },
          'bundles': {
            'created': pendingBundles.where((b) => b.serverId == null).map((b) => b.toServerJson()).toList(),
            'updated': pendingBundles.where((b) => b.serverId != null).map((b) => b.toServerJson()).toList(),
            'deleted': pendingBundleDeletes,
          },
          'activity_logs': [],
        };

        final pushResponse = await _apiService.post('/sync', pushRequest);
        if (pushResponse.success) {
          await _processSyncResponse(pushResponse.data);
        }
      }

      // Now fetch ALL data from server using existing endpoints
      print('[SyncService] Fetching bundles from server...');
      final bundlesResponse = await _apiService.get('/bundles');
      
      print('[SyncService] Fetching items from server...');
      final itemsResponse = await _apiService.get('/items');

      print('[SyncService] Bundles response: ${bundlesResponse.success}, Items response: ${itemsResponse.success}');

      if (bundlesResponse.success || itemsResponse.success) {
        // Track server IDs for deletion/conflict detection
        final Set<int> serverBundleIds = {};
        final Set<int> serverItemIds = {};
        
        // Merge bundles from server
        if (bundlesResponse.success && bundlesResponse.data != null) {
          final serverBundles = bundlesResponse.data as List<dynamic>;
          if (serverBundles.isNotEmpty) {
            print('[SyncService] Merging ${serverBundles.length} bundles from server');
            final bundleModels = serverBundles.map((json) {
              final bundle = Bundle.fromServerJson(json as Map<String, dynamic>);
              if (bundle.serverId != null) {
                serverBundleIds.add(bundle.serverId!);
              }
              return bundle;
            }).toList();
            await _bundlesRepo.mergeServerBundles(bundleModels);
          }
          // Detect conflicts and delete non-conflicting bundles
          await _detectBundleConflicts(serverBundleIds);
        }

        // Merge items from server
        if (itemsResponse.success && itemsResponse.data != null) {
          final serverItems = itemsResponse.data as List<dynamic>;
          if (serverItems.isNotEmpty) {
            print('[SyncService] Merging ${serverItems.length} items from server');
            final itemModels = serverItems.map((json) {
              final item = Item.fromServerJson(json as Map<String, dynamic>);
              if (item.serverId != null) {
                serverItemIds.add(item.serverId!);
              }
              return item;
            }).toList();
            await _itemsRepo.mergeServerItems(itemModels);
          }
          // Detect conflicts and delete non-conflicting items
          await _detectItemConflicts(serverItemIds);
        }

        // Update last sync timestamp
        _lastSyncAt = DateTime.now();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_sync_at', _lastSyncAt!.toIso8601String());

        print('[SyncService] Full sync completed successfully');

        // Notify callbacks
        for (final callback in _onSyncCompleteCallbacks) {
          callback();
        }

        // Notify about conflicts if any were detected
        if (_pendingConflicts.isNotEmpty && _onConflictsDetected != null) {
          print('[SyncService] Detected ${_pendingConflicts.length} conflicts');
          _onConflictsDetected!(_pendingConflicts);
        }

        _isSyncing = false;
        notifyListeners();
        return true;
      } else {
        _lastError = bundlesResponse.error ?? itemsResponse.error ?? 'Full sync failed';
        print('[SyncService] Full sync failed: $_lastError');
        _isSyncing = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      print('[SyncService] Full sync error: $e');
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Detect bundle conflicts: items with pending local changes that were deleted on server
  Future<void> _detectBundleConflicts(Set<int> serverBundleIds) async {
    final localBundles = await _bundlesRepo.getPendingSyncedBundles();
    
    for (final bundle in localBundles) {
      if (bundle.serverId != null && !serverBundleIds.contains(bundle.serverId)) {
        // This bundle was deleted on server but has pending local changes
        print('[SyncService] Conflict detected: Bundle "${bundle.name}" deleted on server but has local changes');
        _pendingConflicts.add(SyncConflict(
          type: SyncConflictType.bundleDeletedOnServer,
          localId: bundle.id,
          serverId: bundle.serverId,
          name: bundle.name,
          localUpdatedAt: bundle.updatedAt,
          bundle: bundle,
        ));
      }
    }
    
    // Also delete bundles without pending changes
    await _bundlesRepo.deleteNonServerBundlesExcept(serverBundleIds, _pendingConflicts.map((c) => c.localId).toSet());
  }

  /// Detect item conflicts: items with pending local changes that were deleted on server
  Future<void> _detectItemConflicts(Set<int> serverItemIds) async {
    final localItems = await _itemsRepo.getPendingSyncedItems();
    
    for (final item in localItems) {
      if (item.serverId != null && !serverItemIds.contains(item.serverId)) {
        // This item was deleted on server but has pending local changes
        print('[SyncService] Conflict detected: Item "${item.name}" deleted on server but has local changes');
        _pendingConflicts.add(SyncConflict(
          type: SyncConflictType.itemDeletedOnServer,
          localId: item.id,
          serverId: item.serverId,
          name: item.name,
          localUpdatedAt: item.updatedAt,
          item: item,
        ));
      }
    }
    
    // Also delete items without pending changes
    await _itemsRepo.deleteNonServerItemsExcept(serverItemIds, _pendingConflicts.map((c) => c.localId).toSet());
  }

  /// Upload bundle image to S3 if it's a local file path
  /// Called after bundle gets a server ID during sync
  Future<void> _uploadBundleImageIfNeeded(String clientId, int serverId) async {
    try {
      final bundle = await _bundlesRepo.getBundleById(clientId);
      if (bundle == null || bundle.imagePath == null) return;
      
      final imagePath = bundle.imagePath!;
      
      // Check if it's a local file path (not an S3 URL)
      if (!imagePath.startsWith('http') && File(imagePath).existsSync()) {
        print('[SyncService] Uploading local bundle image to S3 for bundle $clientId');
        
        final s3Url = await S3UploadService().uploadBundleImage(
          File(imagePath),
          bundleServerId: serverId,
        );
        
        if (s3Url != null) {
          // Update bundle with S3 URL
          await _bundlesRepo.updateBundle(bundle.copyWith(
            imagePath: s3Url,
            syncStatus: SyncStatus.pending, // Will sync the updated URL on next sync
          ));
          
          // Cache local file for immediate display
          ImageUrlService().cacheLocalFile(s3Url, imagePath);
          
          print('[SyncService] Bundle image uploaded to S3: $s3Url');
        } else {
          print('[SyncService] Failed to upload bundle image to S3');
        }
      }
    } catch (e) {
      print('[SyncService] Error uploading bundle image: $e');
    }
  }

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    _debounceTimer?.cancel();
    _connectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}


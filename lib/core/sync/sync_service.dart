import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_service.dart';
import 'connectivity_service.dart';
import 'sync_status.dart';
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
  
  // Sync interval: 5 minutes
  static const Duration _syncInterval = Duration(minutes: 5);
  
  // Callbacks for notifying repositories
  final List<Function()> _onSyncCompleteCallbacks = [];

  bool get isSyncing => _isSyncing;
  bool get isInitialized => _isInitialized;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastError => _lastError;

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

  /// Perform full bidirectional sync
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
      debugPrint('[SyncService] Starting sync...');

      // Get pending items from repositories
      final pendingItems = await _itemsRepo.getPendingItems();
      final pendingItemDeletes = await _itemsRepo.getPendingDeleteIds();
      final pendingBundles = await _bundlesRepo.getPendingBundles();
      final pendingBundleDeletes = await _bundlesRepo.getPendingDeleteIds();

      debugPrint('[SyncService] Pending: ${pendingItems.length} items, ${pendingBundles.length} bundles');
      debugPrint('[SyncService] Pending deletes: ${pendingItemDeletes.length} items, ${pendingBundleDeletes.length} bundles');

      // Build sync request
      final syncRequest = {
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
        'last_sync_at': _lastSyncAt?.toIso8601String(),
      };

      debugPrint('[SyncService] Sync request: $syncRequest');

      // Push/pull sync
      final response = await _apiService.post('/sync', syncRequest);

      debugPrint('[SyncService] Sync response: ${response.success} - ${response.data}');

      if (response.success) {
        // Process server response
        await _processSyncResponse(response.data);

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
      } else {
        _lastError = response.error ?? 'Unknown sync error';
        debugPrint('[SyncService] Sync failed: $_lastError');
        _isSyncing = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[SyncService] Sync error: $e');
      _isSyncing = false;
      notifyListeners();
      return false;
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

    // --- Process CREATED bundles (mark local bundles as synced) ---
    if (bundles != null) {
      final createdBundles = bundles['created'] as List<dynamic>?;
      if (createdBundles != null) {
        for (final bundle in createdBundles) {
          if (bundle['client_id'] != null && bundle['id'] != null) {
            await _bundlesRepo.markBundleSynced(bundle['client_id'], bundle['id']);
            print('[SyncService] Marked bundle ${bundle['client_id']} as synced with server ID ${bundle['id']}');
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

  /// Pull-only sync (for refresh)
  Future<bool> pullChanges() async {
    final isLoggedIn = await _apiService.isLoggedIn();
    if (!isLoggedIn || !_connectivityService.isConnected) {
      return false;
    }

    try {
      final since = _lastSyncAt?.toIso8601String() ?? DateTime(2000).toIso8601String();
      final response = await _apiService.get('/sync/pull?since=$since');

      if (response.success) {
        await _processSyncResponse(response.data);
        _lastSyncAt = DateTime.now();
        
        for (final callback in _onSyncCompleteCallbacks) {
          callback();
        }
        
        return true;
      }
      return false;
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
        // Track server IDs for deletion cleanup
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
          // Delete local bundles that no longer exist on server
          await _bundlesRepo.deleteNonServerBundles(serverBundleIds);
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
          // Delete local items that no longer exist on server
          await _itemsRepo.deleteNonServerItems(serverItemIds);
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

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    _debounceTimer?.cancel();
    _connectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}


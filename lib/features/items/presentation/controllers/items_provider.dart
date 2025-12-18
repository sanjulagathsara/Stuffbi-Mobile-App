import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/items_repository_impl.dart';
import '../../models/item_model.dart';
import '../../../activity/data/activity_repository.dart';
import '../../../activity/models/activity_log_model.dart';
import '../../../bundles/data/bundles_repository_impl.dart';
import '../../../bundles/presentation/providers/bundles_provider.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/sync_service.dart';

class ItemsProvider extends ChangeNotifier {
  final ItemsRepositoryImpl _repository = ItemsRepositoryImpl();
  final ActivityRepository _activityRepository = ActivityRepository();
  final SyncService _syncService = SyncService();
  List<Item> _items = [];
  List<Item> _filteredItems = [];
  bool _isLoading = false;
  final Set<String> _selectedItemIds = {};
  bool _isSelectionMode = false;
  String _searchQuery = '';
  
  // Reference to BundlesProvider for updating bundle completion status
  BundlesProvider? _bundlesProvider;
  
  void setBundlesProvider(BundlesProvider provider) {
    _bundlesProvider = provider;
  }

  List<Item> get items => _filteredItems;
  bool get isLoading => _isLoading;
  Set<String> get selectedItemIds => _selectedItemIds;
  bool get isSelectionMode => _isSelectionMode;

  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _repository.getItems();
      _applySearch();
    } catch (e) {
      debugPrint('Error loading items: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh data from server using GET /items API
  /// Also refreshes bundles first to ensure bundle ID mappings are up to date
  Future<bool> refreshFromServer() async {
    debugPrint('[ItemsProvider] Refreshing from server...');
    try {
      // Fetch bundles first to ensure bundle ID mappings are available
      final bundlesRepo = BundlesRepositoryImpl();
      await bundlesRepo.fetchBundlesFromServer();
      
      // Then fetch items
      final success = await _repository.fetchItemsFromServer();
      if (success) {
        await loadItems();
        debugPrint('[ItemsProvider] Refresh from server complete');
      }
      return success;
    } catch (e) {
      debugPrint('[ItemsProvider] Error refreshing from server: $e');
      return false;
    }
  }

  Future<void> addItem(String name, String category, String details, String? imagePath, String? bundleId) async {
    final newItem = Item(
      id: const Uuid().v4(),
      name: name,
      category: category,
      details: details,
      imagePath: imagePath,
      bundleId: bundleId,
    );
    
    // Save locally first (optimistic)
    await _repository.addItem(newItem);
    
    // Log creation
    try {
      await _activityRepository.logActivity(ActivityLog(
        id: const Uuid().v4(),
        itemId: newItem.id,
        actionType: 'create',
        timestamp: DateTime.now(),
        details: 'Created item: ${newItem.name}',
      ));
    } catch (e) {
      debugPrint('Error logging creation: $e');
    }

    await loadItems();
    
    // Try to create on server immediately using POST /items API
    try {
      int? bundleServerId;
      if (bundleId != null) {
        // Get bundle's server ID from local DB
        bundleServerId = await _getBundleServerId(bundleId);
      }
      
      final serverId = await _repository.createItemOnServer(newItem, bundleServerId: bundleServerId);
      if (serverId != null) {
        debugPrint('[ItemsProvider] Item created on server with ID: $serverId');
        await loadItems(); // Reload to get updated server ID
      } else {
        debugPrint('[ItemsProvider] Failed to create on server, will sync later');
      }
    } catch (e) {
      debugPrint('[ItemsProvider] Error creating on server: $e');
    }
  }
  
  /// Helper to get bundle's server ID from local database
  Future<int?> _getBundleServerId(String bundleId) async {
    try {
      final db = await DatabaseHelper().database;
      final maps = await db.query(
        'bundles',
        columns: ['server_id'],
        where: 'id = ?',
        whereArgs: [bundleId],
      );
      if (maps.isNotEmpty) {
        return maps.first['server_id'] as int?;
      }
    } catch (e) {
      debugPrint('[ItemsProvider] Error getting bundle server ID: $e');
    }
    return null;
  }

  Future<void> updateItem(Item item) async {
    // Save locally first (optimistic)
    await _repository.updateItem(item);
    await loadItems();
    
    // Try to update on server immediately using PUT /items/:id API
    if (item.serverId != null) {
      try {
        final success = await _repository.updateItemOnServer(item);
        if (success) {
          debugPrint('[ItemsProvider] Item updated on server');
        } else {
          debugPrint('[ItemsProvider] Failed to update on server, will sync later');
        }
      } catch (e) {
        debugPrint('[ItemsProvider] Error updating on server: $e');
      }
    }
  }

  Future<void> deleteItem(String id) async {
    final item = _items.firstWhere((i) => i.id == id, orElse: () => Item(id: '', name: 'Unknown', category: '', details: ''));
    
    // Delete on server first if has serverId (using DELETE /items/:id API)
    if (item.serverId != null) {
      try {
        final success = await _repository.deleteItemOnServer(item.serverId!);
        if (success) {
          debugPrint('[ItemsProvider] Item deleted on server');
        } else {
          debugPrint('[ItemsProvider] Failed to delete on server');
        }
      } catch (e) {
        debugPrint('[ItemsProvider] Error deleting on server: $e');
      }
    }
    
    // Delete locally
    await _repository.deleteItem(id);
    
    if (item.id.isNotEmpty) {
      try {
        await _activityRepository.logActivity(ActivityLog(
          id: const Uuid().v4(),
          itemId: id,
          actionType: 'delete',
          timestamp: DateTime.now(),
          details: 'Deleted item: ${item.name}',
        ));
      } catch (e) {
        debugPrint('Error logging deletion: $e');
      }
    }

    await loadItems();
  }

  Future<void> deleteSelectedItems() async {
    await _repository.deleteItems(_selectedItemIds.toList());
    
    // Log bulk deletion
    try {
      await _activityRepository.logActivity(ActivityLog(
        id: const Uuid().v4(),
        itemId: 'multiple',
        actionType: 'delete',
        timestamp: DateTime.now(),
        details: 'Deleted ${_selectedItemIds.length} items',
      ));
    } catch (e) {
      debugPrint('Error logging bulk deletion: $e');
    }

    _selectedItemIds.clear();
    _isSelectionMode = false;
    await loadItems();
    _syncService.scheduleSync(); // Trigger sync
  }

  void searchItems(String query) {
    _searchQuery = query;
    _applySearch();
    notifyListeners();
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredItems = List.from(_items);
    } else {
      _filteredItems = _items.where((item) {
        return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            item.category.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
  }

  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) {
      _selectedItemIds.clear();
    }
    notifyListeners();
  }

  void toggleItemSelection(String id) {
    if (_selectedItemIds.contains(id)) {
      _selectedItemIds.remove(id);
      if (_selectedItemIds.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedItemIds.add(id);
      _isSelectionMode = true;
    }
    notifyListeners();
  }

  Future<void> toggleItemCheck(String itemId) async {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      final item = _items[index];
      final isChecking = !item.isChecked;
      final updatedItem = item.copyWith(
        isChecked: isChecking,
        lastCheckedAt: isChecking ? DateTime.now() : null,
      );
      
      // Optimistic update
      _items[index] = updatedItem;
      _applySearch();
      notifyListeners();

      await _repository.updateItem(updatedItem);
      
      // Update bundle completion status if item belongs to a bundle
      if (updatedItem.bundleId != null && _bundlesProvider != null) {
        final bundleItems = _items
            .where((i) => i.bundleId == updatedItem.bundleId)
            .toList();
        _bundlesProvider!.updateBundleCompletionStatus(
          updatedItem.bundleId!, 
          bundleItems,
        );
      }

      if (isChecking) {
        try {
          await _activityRepository.logActivity(ActivityLog(
            id: const Uuid().v4(),
            itemId: itemId,
            actionType: 'check',
            timestamp: DateTime.now(),
            details: 'Checked item: ${item.name}',
          ));
        } catch (e) {
          debugPrint('Error logging check: $e');
        }
      }
    }
  }

  Future<void> resetBundleChecklist(String bundleId) async {
    final bundleItems = _items.where((item) => item.bundleId == bundleId && item.isChecked).toList();
    
    for (var item in bundleItems) {
      final updatedItem = item.copyWith(
        isChecked: false,
        lastCheckedAt: null,
      );
      // Optimistic update
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        _items[index] = updatedItem;
      }
      await _repository.updateItem(updatedItem);
    }
    _applySearch();
    notifyListeners();
    
    // Update bundle completion status (will be false after reset)
    if (_bundlesProvider != null) {
      final updatedBundleItems = _items
          .where((item) => item.bundleId == bundleId)
          .toList();
      _bundlesProvider!.updateBundleCompletionStatus(bundleId, updatedBundleItems);
    }
  }

  void moveItemsLocal(List<String> itemIds, String targetBundleId) {
    for (var id in itemIds) {
      final index = _items.indexWhere((item) => item.id == id);
      if (index != -1) {
        _items[index] = _items[index].copyWith(bundleId: targetBundleId);
      }
    }
    _applySearch();
    notifyListeners();
  }
}

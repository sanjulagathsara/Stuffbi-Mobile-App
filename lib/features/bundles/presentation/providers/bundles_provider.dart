import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/bundles_repository_impl.dart';
import '../../models/bundle_model.dart';
import '../../../activity/data/activity_repository.dart';
import '../../../activity/models/activity_log_model.dart';
import '../../../../core/sync/sync_service.dart';

class BundlesProvider extends ChangeNotifier {
  final BundlesRepositoryImpl _repository = BundlesRepositoryImpl();
  final ActivityRepository _activityRepository = ActivityRepository();
  final SyncService _syncService = SyncService();
  List<Bundle> _bundles = [];
  List<Bundle> _filteredBundles = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _showFavoritesOnly = false;
  String _sortOrder = 'asc'; // 'asc' or 'recent'
  
  // Cache for bundle completion status
  final Map<String, bool> _bundleCompletionStatus = {};

  List<Bundle> get bundles => _filteredBundles;
  bool get isLoading => _isLoading;
  bool get showFavoritesOnly => _showFavoritesOnly;
  String get sortOrder => _sortOrder;
  
  /// Returns whether a bundle is completed checking (all items checked)
  bool isBundleCompleted(String bundleId) {
    return _bundleCompletionStatus[bundleId] ?? false;
  }
  
  /// Updates the completion status for a specific bundle
  /// Call this after items are checked/unchecked or moved
  void updateBundleCompletionStatus(String bundleId, List<dynamic> bundleItems) {
    final isCompleted = bundleItems.isNotEmpty && 
        bundleItems.every((item) => item.isChecked == true);
    
    if (_bundleCompletionStatus[bundleId] != isCompleted) {
      _bundleCompletionStatus[bundleId] = isCompleted;
      notifyListeners();
    }
  }
  
  /// Updates completion status for all bundles at once
  void updateAllBundleCompletionStatus(Map<String, List<dynamic>> bundleItemsMap) {
    bool hasChanges = false;
    
    for (final entry in bundleItemsMap.entries) {
      final bundleId = entry.key;
      final bundleItems = entry.value;
      final isCompleted = bundleItems.isNotEmpty && 
          bundleItems.every((item) => item.isChecked == true);
      
      if (_bundleCompletionStatus[bundleId] != isCompleted) {
        _bundleCompletionStatus[bundleId] = isCompleted;
        hasChanges = true;
      }
    }
    
    if (hasChanges) {
      notifyListeners();
    }
  }

  Future<void> loadBundles() async {
    _isLoading = true;
    notifyListeners();
    try {
      _bundles = await _repository.getBundles();
      _applyFilterAndSort();
    } catch (e) {
      debugPrint('Error loading bundles: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBundle(String name, String description, String? imagePath, List<String> selectedItemIds) async {
    final newBundle = Bundle(
      id: const Uuid().v4(),
      name: name,
      description: description,
      imagePath: imagePath,
    );
    await _repository.addBundle(newBundle);
    
    // Log bundle creation
    try {
      await _activityRepository.logActivity(ActivityLog(
        id: const Uuid().v4(),
        itemId: newBundle.id,
        actionType: 'create_bundle',
        timestamp: DateTime.now(),
        details: 'Created bundle: $name',
      ));
    } catch (e) {
      debugPrint('Error logging bundle creation: $e');
    }

    if (selectedItemIds.isNotEmpty) {
      await _repository.addItemsToBundle(newBundle.id, selectedItemIds);
      
      // Log items added to new bundle
      try {
        await _activityRepository.logActivity(ActivityLog(
          id: const Uuid().v4(),
          itemId: 'multiple',
          actionType: 'move',
          timestamp: DateTime.now(),
          details: 'Moved ${selectedItemIds.length} item(s) to new bundle: $name',
        ));
      } catch (e) {
        debugPrint('Error logging new bundle items: $e');
      }
    }
    await loadBundles();
    _syncService.scheduleSync(); // Trigger sync
  }

  Future<void> updateBundle(Bundle bundle) async {
    await _repository.updateBundle(bundle);
    await loadBundles();
    _syncService.scheduleSync(); // Trigger sync
  }

  Future<void> deleteBundle(String id) async {
    final bundle = _bundles.firstWhere((b) => b.id == id, orElse: () => Bundle(id: '', name: 'Unknown', description: ''));
    await _repository.deleteBundle(id);
    
    // Log bundle deletion
    try {
      await _activityRepository.logActivity(ActivityLog(
        id: const Uuid().v4(),
        itemId: id,
        actionType: 'delete_bundle',
        timestamp: DateTime.now(),
        details: 'Deleted bundle: ${bundle.name}',
      ));
    } catch (e) {
      debugPrint('Error logging bundle deletion: $e');
    }

    await loadBundles();
    _syncService.scheduleSync(); // Trigger sync
  }

  Future<void> moveItemsToBundle(String targetBundleId, List<String> itemIds) async {
    await _repository.addItemsToBundle(targetBundleId, itemIds);
    _syncService.scheduleSync(); // Trigger sync to backend
    
    // Find bundle name for log
    try {
      final bundle = _bundles.firstWhere((b) => b.id == targetBundleId, orElse: () => Bundle(id: '', name: 'Unknown', description: ''));
      
      await _activityRepository.logActivity(ActivityLog(
        id: const Uuid().v4(),
        itemId: 'multiple',
        actionType: 'move',
        timestamp: DateTime.now(),
        details: 'Moved ${itemIds.length} item(s) to ${bundle.name}',
      ));
    } catch (e) {
      debugPrint('Error logging move items: $e');
    }
  }

  Future<void> removeItemsFromBundle(List<String> itemIds) async {
    await _repository.removeItemsFromBundle(itemIds);
    _syncService.scheduleSync(); // Trigger sync to backend
    
    try {
      await _activityRepository.logActivity(ActivityLog(
        id: const Uuid().v4(),
        itemId: 'multiple',
        actionType: 'move',
        timestamp: DateTime.now(),
        details: 'Removed ${itemIds.length} item(s) from bundle',
      ));
    } catch (e) {
      debugPrint('Error logging remove items: $e');
    }
  }

  Future<void> toggleFavorite(String bundleId) async {
    final index = _bundles.indexWhere((b) => b.id == bundleId);
    if (index != -1) {
      final bundle = _bundles[index];
      final updatedBundle = bundle.copyWith(isFavorite: !bundle.isFavorite);
      // Optimistic update
      _bundles[index] = updatedBundle;
      _applyFilterAndSort();
      notifyListeners();
      
      await _repository.updateBundle(updatedBundle);
    }
  }

  void searchBundles(String query) {
    _searchQuery = query;
    _applyFilterAndSort();
    notifyListeners();
  }

  void toggleShowFavoritesOnly() {
    _showFavoritesOnly = !_showFavoritesOnly;
    _applyFilterAndSort();
    notifyListeners();
  }

  void setSortOrder(String order) {
    _sortOrder = order;
    _applyFilterAndSort();
    notifyListeners();
  }

  void _applyFilterAndSort() {
    List<Bundle> result = List.from(_bundles);

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      result = result.where((bundle) {
        return bundle.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            bundle.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filter by favorites
    if (_showFavoritesOnly) {
      result = result.where((bundle) => bundle.isFavorite).toList();
    }

    // Sort
    if (_sortOrder == 'asc') {
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortOrder == 'recent') {
      result = result.reversed.toList();
    }

    _filteredBundles = result;
  }
}

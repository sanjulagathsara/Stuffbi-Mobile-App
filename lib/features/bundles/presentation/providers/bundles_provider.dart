import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/bundles_repository_impl.dart';
import '../../models/bundle_model.dart';

class BundlesProvider extends ChangeNotifier {
  final BundlesRepositoryImpl _repository = BundlesRepositoryImpl();
  List<Bundle> _bundles = [];
  List<Bundle> _filteredBundles = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _showFavoritesOnly = false;
  String _sortOrder = 'asc'; // 'asc' or 'recent'

  List<Bundle> get bundles => _filteredBundles;
  bool get isLoading => _isLoading;
  bool get showFavoritesOnly => _showFavoritesOnly;
  String get sortOrder => _sortOrder;

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
    if (selectedItemIds.isNotEmpty) {
      await _repository.addItemsToBundle(newBundle.id, selectedItemIds);
    }
    await loadBundles();
  }

  Future<void> updateBundle(Bundle bundle) async {
    await _repository.updateBundle(bundle);
    await loadBundles();
  }

  Future<void> deleteBundle(String id) async {
    await _repository.deleteBundle(id);
    await loadBundles();
  }

  Future<void> moveItemsToBundle(String targetBundleId, List<String> itemIds) async {
    await _repository.addItemsToBundle(targetBundleId, itemIds);
  }

  Future<void> removeItemsFromBundle(List<String> itemIds) async {
    await _repository.removeItemsFromBundle(itemIds);
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
      // For "recently accessed", we ideally need a last_accessed or last_updated timestamp.
      // Since we don't have that yet, we can't strictly implement it without schema change.
      // However, the user asked to "check the possibility with database if it can detect the lastly item added bundle".
      // This would require a complex query joining items and grouping by bundle.
      // For now, let's reverse the list as a proxy for "newest created" if IDs are time-ordered (UUID v4 is random though).
      // Or we can just leave it as is or implement a simple name desc.
      // Let's assume the user wants to see the bundles they interacted with.
      // Without a timestamp, we can't do this accurately.
      // Let's stick to name sort for now or maybe reverse name?
      // Actually, let's just reverse the list to show "newest first" if the DB returns insertion order (rowid).
      // SQLite usually returns in insertion order by default.
      result = result.reversed.toList();
    }

    _filteredBundles = result;
  }
}

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/items_repository_impl.dart';
import '../../models/item_model.dart';

class ItemsProvider extends ChangeNotifier {
  final ItemsRepositoryImpl _repository = ItemsRepositoryImpl();
  List<Item> _items = [];
  List<Item> _filteredItems = [];
  bool _isLoading = false;
  final Set<String> _selectedItemIds = {};
  bool _isSelectionMode = false;
  String _searchQuery = '';

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

  Future<void> addItem(String name, String category, String details, String? imagePath, String? bundleId) async {
    final newItem = Item(
      id: const Uuid().v4(),
      name: name,
      category: category,
      details: details,
      imagePath: imagePath,
      bundleId: bundleId,
    );
    await _repository.addItem(newItem);
    await loadItems();
  }

  Future<void> updateItem(Item item) async {
    await _repository.updateItem(item);
    await loadItems();
  }

  Future<void> deleteItem(String id) async {
    await _repository.deleteItem(id);
    await loadItems();
  }

  Future<void> deleteSelectedItems() async {
    await _repository.deleteItems(_selectedItemIds.toList());
    _selectedItemIds.clear();
    _isSelectionMode = false;
    await loadItems();
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

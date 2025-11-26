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
}

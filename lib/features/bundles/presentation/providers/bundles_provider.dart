import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/bundles_repository_impl.dart';
import '../../models/bundle_model.dart';

class BundlesProvider extends ChangeNotifier {
  final BundlesRepositoryImpl _repository = BundlesRepositoryImpl();
  List<Bundle> _bundles = [];
  bool _isLoading = false;

  List<Bundle> get bundles => _bundles;
  bool get isLoading => _isLoading;

  Future<void> loadBundles() async {
    _isLoading = true;
    notifyListeners();
    try {
      _bundles = await _repository.getBundles();
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
    // Note: We might need to refresh items in the item provider as well, 
    // but for now we just ensure the bundle logic is correct.
    // The UI should handle refreshing the view.
  }

  Future<void> removeItemsFromBundle(List<String> itemIds) async {
    await _repository.removeItemsFromBundle(itemIds);
  }
}

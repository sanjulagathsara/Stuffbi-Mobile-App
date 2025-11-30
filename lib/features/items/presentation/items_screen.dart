import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/items_provider.dart';
import '../../bundles/presentation/providers/bundles_provider.dart';
import 'add_edit_item_screen.dart';
import 'item_details_screen.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ItemsProvider, BundlesProvider>(
      builder: (context, provider, bundlesProvider, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            toolbarHeight: 60,
            titleSpacing: 0,
            leadingWidth: 70,
            leading: provider.isSelectionMode
                ? IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.black,
                      size: 28,
                    ),
                    onPressed: () {
                      provider.toggleSelectionMode();
                    },
                  )
                : null,
            title: provider.isSelectionMode
                ? Text(
                    '${provider.selectedItemIds.length} Selected',
                    style: const TextStyle(color: Colors.black),
                  )
                : null,
            actions: [
              if (provider.isSelectionMode) ...[
                IconButton(
                  icon: const Icon(Icons.drive_file_move_outline, color: Colors.blue, size: 28),
                  onPressed: () {
                    _showBundleSelectionDialog(context, provider, bundlesProvider);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 28),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Items'),
                        content: Text('Are you sure you want to delete ${provider.selectedItemIds.length} items?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      provider.deleteSelectedItems();
                    }
                  },
                ),
              ] else
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.black, size: 28),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddEditItemScreen()),
                    );
                  },
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              if (!provider.isSelectionMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _searchController,
                        onChanged: (value) {
                          provider.searchItems(value);
                          setState(() {}); // Rebuild to show/hide clear icon
                        },
                        decoration: InputDecoration(
                          hintText: 'Search',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    provider.searchItems('');
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey[200],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.items.isEmpty
                        ? const Center(child: Text('No items found'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: provider.items.length,
                            separatorBuilder: (context, index) => Divider(
                              color: Colors.grey[200],
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final item = provider.items[index];
                              final isSelected = provider.selectedItemIds.contains(item.id);

                              return GestureDetector(
                                onLongPress: () {
                                  provider.toggleItemSelection(item.id);
                                },
                                onTap: () {
                                  if (provider.isSelectionMode) {
                                    provider.toggleItemSelection(item.id);
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ItemDetailsScreen(itemId: item.id),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8),
                                          image: item.imagePath != null
                                              ? DecorationImage(
                                                  image: FileImage(File(item.imagePath!)),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: item.imagePath == null
                                            ? const Center(
                                                child: Icon(
                                                  Icons.image_outlined,
                                                  color: Colors.grey,
                                                  size: 32,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                              if (item.bundleId != null && item.bundleId!.isNotEmpty)
                                                Builder(
                                                  builder: (context) {
                                                    final bundleName = bundlesProvider.bundles
                                                        .where((b) => b.id == item.bundleId)
                                                        .firstOrNull
                                                        ?.name;

                                                    return Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.indigo[50],
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: Colors.indigo[100]!),
                                                      ),
                                                      child: Text(
                                                        bundleName ?? 'Unknown Bundle',
                                                        style: TextStyle(
                                                          color: Colors.indigo[800],
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                )
                                            else
                                              const Text(
                                                'No Bundle',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                            if (!provider.isSelectionMode)
                                              GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => AddEditItemScreen(item: item),
                                                    ),
                                                  );
                                                },
                                                child: Icon(
                                                  Icons.edit_outlined,
                                                  color: Colors.blue[600],
                                                  size: 20,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (provider.isSelectionMode)
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (bool? newValue) {
                                            provider.toggleItemSelection(item.id);
                                          },
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showBundleSelectionDialog(
      BuildContext context, ItemsProvider itemsProvider, BundlesProvider bundlesProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return _BundleSelectionSheet(
              itemsProvider: itemsProvider,
              bundlesProvider: bundlesProvider,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }
}

class _BundleSelectionSheet extends StatefulWidget {
  final ItemsProvider itemsProvider;
  final BundlesProvider bundlesProvider;
  final ScrollController scrollController;

  const _BundleSelectionSheet({
    required this.itemsProvider,
    required this.bundlesProvider,
    required this.scrollController,
  });

  @override
  State<_BundleSelectionSheet> createState() => _BundleSelectionSheetState();
}

class _BundleSelectionSheetState extends State<_BundleSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access bundles directly from the provider. 
    // Note: We are not listening to changes here because we passed the provider instance.
    // If bundles change while this is open, it might not update unless we use Consumer or context.watch.
    // However, for this use case, it's likely fine.
    final allBundles = widget.bundlesProvider.bundles;
    final showSearch = allBundles.length > 5;

    final filteredBundles = _searchQuery.isEmpty
        ? allBundles
        : allBundles.where((bundle) {
            return bundle.name.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Assign to Bundle',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (showSearch)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search bundles...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        Expanded(
          child: filteredBundles.isEmpty
              ? const Center(child: Text('No bundles found'))
              : ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: filteredBundles.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final bundle = filteredBundles[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          image: bundle.imagePath != null
                              ? DecorationImage(
                                  image: FileImage(File(bundle.imagePath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: bundle.imagePath == null
                            ? const Icon(Icons.inventory_2_outlined, color: Colors.grey)
                            : null,
                      ),
                      title: Text(
                        bundle.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${widget.itemsProvider.items.where((i) => i.bundleId == bundle.id).length} items',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      onTap: () async {
                        // Perform assignment
                        final selectedIds = widget.itemsProvider.selectedItemIds.toList();
                        
                        // 1. Update Bundle (Repo + Provider)
                        await widget.bundlesProvider.moveItemsToBundle(bundle.id, selectedIds);
                        
                        // 2. Update Items (Local Provider State)
                        widget.itemsProvider.moveItemsLocal(selectedIds, bundle.id);
                        
                        // 3. Exit selection mode
                        widget.itemsProvider.toggleSelectionMode();
                        
                        // 4. Close dialog
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Moved ${selectedIds.length} items to ${bundle.name}'),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

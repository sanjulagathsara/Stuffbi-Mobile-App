import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/items_provider.dart';
import '../../bundles/presentation/providers/bundles_provider.dart';
import 'add_edit_item_screen.dart';
import 'item_details_screen.dart';

class ItemsScreen extends StatelessWidget {
  const ItemsScreen({super.key});

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
            leading: IconButton(
              icon: Icon(
                provider.isSelectionMode ? Icons.close : Icons.search,
                color: Colors.black,
                size: 28,
              ),
              onPressed: () {
                if (provider.isSelectionMode) {
                  provider.toggleSelectionMode();
                } else {
                  // Focus search bar or handle search action
                }
              },
            ),
            title: provider.isSelectionMode
                ? Text(
                    '${provider.selectedItemIds.length} Selected',
                    style: const TextStyle(color: Colors.black),
                  )
                : null,
            actions: [
              if (provider.isSelectionMode)
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
                )
              else
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
                        onChanged: (value) => provider.searchItems(value),
                        decoration: InputDecoration(
                          hintText: 'Search',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item_model.dart';
import 'controllers/items_provider.dart';
import 'add_edit_item_screen.dart';

class ItemDetailsScreen extends StatelessWidget {
  final String itemId;

  const ItemDetailsScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return Consumer<ItemsProvider>(
      builder: (context, provider, child) {
        // Find the item in the provider's list
        final item = provider.items.firstWhere(
          (element) => element.id == itemId,
          orElse: () => Item(id: '', name: 'Item not found', category: '', details: ''), // Fallback
        );

        // If item was deleted or not found, handle gracefully (e.g. pop)
        if (item.id.isEmpty) {
           // Ideally we should pop here, but we can't do it directly in build.
           // Just showing a message or empty container for now.
           return Scaffold(appBar: AppBar(), body: const Center(child: Text('Item not found')));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Item Details'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditItemScreen(item: item),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Item'),
                      content: const Text('Are you sure you want to delete this item?'),
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
                    await provider.deleteItem(item.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.imagePath != null)
                  Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(File(item.imagePath!)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.image, size: 80, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(
                      label: Text(item.category),
                      backgroundColor: Colors.blue[100],
                    ),
                    const SizedBox(width: 8),
                    if (item.bundleId != null)
                      Chip(
                        label: Text(item.bundleId!),
                        backgroundColor: Colors.green[100],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.details,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

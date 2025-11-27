import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../items/presentation/controllers/items_provider.dart';
import '../models/bundle_model.dart';
import 'package:go_router/go_router.dart';
import 'providers/bundles_provider.dart';

class BundleDetailsScreen extends StatefulWidget {
  final Bundle bundle;

  const BundleDetailsScreen({super.key, required this.bundle});

  @override
  State<BundleDetailsScreen> createState() => _BundleDetailsScreenState();
}

class _BundleDetailsScreenState extends State<BundleDetailsScreen> {
  bool _isDragMode = false;
  final Set<String> _selectedItemIds = {};

  Future<void> _removeSelectedItems() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Items'),
        content: Text('Remove ${_selectedItemIds.length} items from this bundle?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await Provider.of<BundlesProvider>(context, listen: false)
          .removeItemsFromBundle(_selectedItemIds.toList());
      if (mounted) {
        await Provider.of<ItemsProvider>(context, listen: false).loadItems();
        setState(() {
          _selectedItemIds.clear();
          _isDragMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Items removed from bundle')));
      }
    }
  }

  Future<void> _moveSelectedItemsToBundle() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => Consumer<BundlesProvider>(
        builder: (context, bundlesProvider, child) {
          final otherBundles = bundlesProvider.bundles
              .where((b) => b.id != widget.bundle.id)
              .toList();

          if (otherBundles.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No other bundles available.'),
            );
          }

          return ListView.builder(
            itemCount: otherBundles.length,
            itemBuilder: (context, index) {
              final targetBundle = otherBundles[index];
              return ListTile(
                leading: targetBundle.imagePath != null
                    ? Image.file(File(targetBundle.imagePath!), width: 40, height: 40, fit: BoxFit.cover)
                    : const Icon(Icons.folder),
                title: Text(targetBundle.name),
                onTap: () async {
                  Navigator.pop(context); // Close sheet
                  await Provider.of<BundlesProvider>(context, listen: false)
                      .moveItemsToBundle(targetBundle.id, _selectedItemIds.toList());
                  if (mounted) {
                    await Provider.of<ItemsProvider>(context, listen: false).loadItems();
                    setState(() {
                      _selectedItemIds.clear();
                      _isDragMode = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Moved items to ${targetBundle.name}')),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _moveSelectedItemsToNewBundle() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('New Bundle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Bundle Name'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        await Provider.of<BundlesProvider>(context, listen: false).addBundle(
          nameController.text,
          descriptionController.text,
          null, // No image for quick create
          _selectedItemIds.toList(),
        );
        if (mounted) {
          await Provider.of<ItemsProvider>(context, listen: false).loadItems();
          setState(() {
            _selectedItemIds.clear();
            _isDragMode = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Created bundle ${nameController.text} with items')),
          );
        }
      }
    } finally {
      nameController.dispose();
      descriptionController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BundlesProvider>(
      builder: (context, bundlesProvider, child) {
        // Find the updated bundle from the provider, fallback to widget.bundle if not found (e.g. just deleted)
        final bundle = bundlesProvider.bundles.firstWhere(
          (b) => b.id == widget.bundle.id,
          orElse: () => widget.bundle,
        );

        return Scaffold(
          bottomNavigationBar: _selectedItemIds.isNotEmpty
              ? BottomAppBar(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        tooltip: 'Remove',
                        onPressed: _removeSelectedItems,
                      ),
                      IconButton(
                        icon: const Icon(Icons.drive_file_move_outline),
                        tooltip: 'Move',
                        onPressed: _moveSelectedItemsToBundle,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_to_photos_outlined),
                        tooltip: 'New Bundle',
                        onPressed: _moveSelectedItemsToNewBundle,
                      ),
                    ],
                  ),
                )
              : null,
          appBar: AppBar(
            title: Text(bundle.name),
            actions: [
              if (_selectedItemIds.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _selectedItemIds.clear();
                      _isDragMode = false;
                    });
                  },
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    context.push('/add_bundle', extra: bundle);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Bundle'),
                        content: const Text('Are you sure you want to delete this bundle? Items will be unassigned.'),
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

                    if (confirm == true && mounted) {
                      await Provider.of<BundlesProvider>(context, listen: false).deleteBundle(bundle.id);
                      if (mounted) {
                         // Refresh items as their bundleId will be nullified
                        await Provider.of<ItemsProvider>(context, listen: false).loadItems();
                        context.pop();
                      }
                    }
                  },
                ),
              ],
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'reset') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Reset Checklist'),
                        content: const Text('Uncheck all items in this bundle?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      await Provider.of<ItemsProvider>(context, listen: false).resetBundleChecklist(bundle.id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checklist reset')));
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'reset',
                    child: Text('Reset Checklist'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Bundle Info Header
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    if (bundle.imagePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(bundle.imagePath!),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bundle.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(bundle.description),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              


              // Items List
              Expanded(
                child: Consumer<ItemsProvider>(
                  builder: (context, itemsProvider, child) {
                    final bundleItems = itemsProvider.items
                        .where((item) => item.bundleId == bundle.id)
                        .toList();

                    if (bundleItems.isEmpty) {
                      return const Center(child: Text('No items in this bundle'));
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: bundleItems.length,
                      itemBuilder: (context, index) {
                        final item = bundleItems[index];
                        final isSelected = _selectedItemIds.contains(item.id);

                        return GestureDetector(
                            onTap: () {
                              if (_isDragMode || _selectedItemIds.isNotEmpty) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedItemIds.remove(item.id);
                                    if (_selectedItemIds.isEmpty) {
                                      _isDragMode = false;
                                    }
                                  } else {
                                    _selectedItemIds.add(item.id);
                                  }
                                });
                              } else {
                                // Navigate to item details or show preview
                                // For now, let's make single tap toggle check if not in selection mode
                                // Or maybe we want a dedicated button? 
                                // Requirement says "green button inside the bundle named 'check' or suitable icon"
                                // Let's add the button in the card, but maybe tapping the card opens details?
                                // For now, let's just keep selection logic separate.
                              }
                            },
                            onLongPress: () {
                              setState(() {
                                _isDragMode = true;
                                _selectedItemIds.add(item.id);
                              });
                            },
                            child: _buildItemCard(item, isSelected),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildItemCard(dynamic item, bool isSelected) {
    return Card(
      color: isSelected ? Colors.blue[50] : (item.isChecked ? Colors.green[50] : Colors.white),
      elevation: item.isChecked ? 1 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
            ? const BorderSide(color: Colors.blue, width: 2) 
            : (item.isChecked ? BorderSide(color: Colors.green.withOpacity(0.5), width: 1) : BorderSide.none),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    image: item.imagePath != null
                        ? DecorationImage(
                            image: FileImage(File(item.imagePath!)),
                            fit: BoxFit.cover,
                            colorFilter: item.isChecked 
                                ? ColorFilter.mode(Colors.white.withOpacity(0.6), BlendMode.srcOver) 
                                : null,
                          )
                        : null,
                  ),
                  child: item.imagePath == null
                      ? const Center(child: Icon(Icons.image, color: Colors.grey))
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: item.isChecked ? TextDecoration.lineThrough : null,
                        color: item.isChecked ? Colors.grey : Colors.black,
                      ),
                    ),
                    Text(
                      item.category,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (item.isChecked && item.lastCheckedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 12, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              _getTimeAgo(item.lastCheckedAt!),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.green,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!_isDragMode && _selectedItemIds.isEmpty)
            Positioned(
              bottom: 4,
              right: 4,
              child: IconButton(
                icon: Icon(
                  item.isChecked ? Icons.check_circle : Icons.check_circle_outline,
                  color: item.isChecked ? Colors.green : Colors.grey,
                ),
                onPressed: () {
                  Provider.of<ItemsProvider>(context, listen: false).toggleItemCheck(item.id);
                },
              ),
            ),
        ],
      ),
    );
  }
}

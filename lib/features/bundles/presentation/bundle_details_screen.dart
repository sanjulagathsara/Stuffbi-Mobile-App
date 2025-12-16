import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../items/presentation/controllers/items_provider.dart';
import '../models/bundle_model.dart';
import 'package:go_router/go_router.dart';
import 'providers/bundles_provider.dart';
import '../../../core/widgets/smart_s3_image.dart';

class BundleDetailsScreen extends StatefulWidget {
  final Bundle bundle;

  const BundleDetailsScreen({super.key, required this.bundle});

  @override
  State<BundleDetailsScreen> createState() => _BundleDetailsScreenState();
}

class _BundleDetailsScreenState extends State<BundleDetailsScreen> {
  bool _isDragMode = false;
  bool _isDraggingItem = false;
  final Set<String> _selectedItemIds = {};
  String _searchQuery = '';
  bool _isSearchingToAdd = false;

  Future<void> _removeSelectedItems() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Items'),
        content: Text(
          'Remove ${_selectedItemIds.length} items from this bundle?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await Provider.of<BundlesProvider>(
        context,
        listen: false,
      ).removeItemsFromBundle(_selectedItemIds.toList());
      if (mounted) {
        await Provider.of<ItemsProvider>(context, listen: false).loadItems();
        setState(() {
          _selectedItemIds.clear();
          _isDragMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Items removed from bundle')),
        );
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
                    ? SmartS3Image(
                        imagePath: targetBundle.imagePath,
                        bundleServerId: targetBundle.serverId,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(4),
                      )
                    : const Icon(Icons.folder),
                title: Text(targetBundle.name),
                onTap: () async {
                  Navigator.pop(context); // Close sheet
                  await Provider.of<BundlesProvider>(
                    context,
                    listen: false,
                  ).moveItemsToBundle(
                    targetBundle.id,
                    _selectedItemIds.toList(),
                  );
                  if (mounted) {
                    await Provider.of<ItemsProvider>(
                      context,
                      listen: false,
                    ).loadItems();
                    setState(() {
                      _selectedItemIds.clear();
                      _isDragMode = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Moved items to ${targetBundle.name}'),
                      ),
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
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
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
            SnackBar(
              content: Text('Created bundle ${nameController.text} with items'),
            ),
          );
        }
      }
    } finally {
      nameController.dispose();
      descriptionController.dispose();
    }
  }

  Future<void> _showAddItemSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final Set<String> itemsToAdd = {};
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return Consumer<ItemsProvider>(
                  builder: (context, itemsProvider, child) {
                    final availableItems = itemsProvider.items
                        .where((item) => item.bundleId != widget.bundle.id)
                        .toList();
                    
                    final filteredAvailable = _isSearchingToAdd && _searchQuery.isNotEmpty
                        ? availableItems.where((item) => 
                            item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            item.category.toLowerCase().contains(_searchQuery.toLowerCase())
                          ).toList()
                        : availableItems;

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Text('Add Items to Bundle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search items to add...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onChanged: (val) {
                              setSheetState(() {
                                _searchQuery = val;
                                _isSearchingToAdd = true;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: filteredAvailable.isEmpty
                              ? const Center(child: Text('No items available to add'))
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: filteredAvailable.length,
                                  itemBuilder: (context, index) {
                                    final item = filteredAvailable[index];
                                    final isSelected = itemsToAdd.contains(item.id);
                                    return CheckboxListTile(
                                      title: Text(item.name),
                                      subtitle: Text(item.category),
                                      secondary: item.imagePath != null
                                          ? SmartS3Image(
                                              imagePath: item.imagePath,
                                              itemServerId: item.serverId,
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              borderRadius: BorderRadius.circular(4),
                                            )
                                          : const Icon(Icons.image),
                                      value: isSelected,
                                      onChanged: (bool? value) {
                                        setSheetState(() {
                                          if (value == true) {
                                            itemsToAdd.add(item.id);
                                          } else {
                                            itemsToAdd.remove(item.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: itemsToAdd.isEmpty
                                ? null
                                : () async {
                                    Navigator.pop(context);
                                    await Provider.of<BundlesProvider>(context, listen: false)
                                        .moveItemsToBundle(widget.bundle.id, itemsToAdd.toList());
                                    
                                    if (mounted) {
                                      await Provider.of<ItemsProvider>(context, listen: false).loadItems();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Added ${itemsToAdd.length} items to bundle')),
                                      );
                                    }
                                  },
                            child: Text('Add ${itemsToAdd.length} Items'),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    ).then((_) {
      setState(() {
        _searchQuery = '';
        _isSearchingToAdd = false;
      });
    });
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
              if (_selectedItemIds.isEmpty)
                 IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add Items',
                  onPressed: _showAddItemSheet,
                ),
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
                        content: const Text(
                          'Are you sure you want to delete this bundle? Items will be unassigned.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      await Provider.of<BundlesProvider>(
                        context,
                        listen: false,
                      ).deleteBundle(bundle.id);
                      if (mounted) {
                        // Refresh items as their bundleId will be nullified
                        await Provider.of<ItemsProvider>(
                          context,
                          listen: false,
                        ).loadItems();
                        context.pop();
                      }
                    }
                  },
                ),
              ],
              if (_selectedItemIds.isEmpty)
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: 'Select Items',
                  onPressed: () {
                    setState(() {
                      _isDragMode = true;
                    });
                  },
                ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'reset') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Reset Checklist'),
                        content: const Text(
                          'Uncheck all items in this bundle?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      await Provider.of<ItemsProvider>(
                        context,
                        listen: false,
                      ).resetBundleChecklist(bundle.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Checklist reset')),
                      );
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
          body: Stack(
            children: [
              Column(
                children: [
                  // Bundle Info Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[100],
                    child: Row(
                      children: [
                        if (bundle.imagePath != null)
                          SmartS3Image(
                            imagePath: bundle.imagePath,
                            bundleServerId: bundle.serverId,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(8),
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
                    final allBundleItems = itemsProvider.items
                        .where((item) => item.bundleId == bundle.id)
                        .toList();
                    
                    final displayItems = _searchQuery.isNotEmpty && !_isSearchingToAdd
                        ? allBundleItems.where((item) => 
                            item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            item.category.toLowerCase().contains(_searchQuery.toLowerCase())
                          ).toList()
                        : allBundleItems;

                    if (allBundleItems.isEmpty) {
                      return const Center(child: Text('No items in this bundle'));
                    }

                    return Column(
                      children: [
                        if (allBundleItems.length > 4)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search in bundle...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchQuery.isNotEmpty 
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                      },
                                    ) 
                                  : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                  _isSearchingToAdd = false;
                                });
                              },
                            ),
                          ),
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: displayItems.length,
                            itemBuilder: (context, index) {
                              final item = displayItems[index];
                        final isSelected = _selectedItemIds.contains(item.id);

                            return GestureDetector(
                              onTap: () {
                                if (_isDragMode ||
                                    _selectedItemIds.isNotEmpty) {
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
                                  // Toggle check on tap if not in selection mode
                                  Provider.of<ItemsProvider>(
                                    context,
                                    listen: false,
                                  ).toggleItemCheck(item.id);
                                }
                              },
                              onLongPress: () {
                                // If we want to keep long press for selection when NOT dragging,
                                // we might need a listener or different gesture.
                                // But LongPressDraggable usually consumes it.
                                // We'll rely on the "Select Items" button or just drag.
                              },
                              child: LongPressDraggable<String>(
                                data: item.id,
                                delay: const Duration(
                                  milliseconds: 150,
                                ), // Reduced delay for better responsiveness
                                onDragStarted: () {
                                  setState(() {
                                    _isDraggingItem = true;
                                  });
                                },
                                onDragEnd: (details) {
                                  setState(() {
                                    _isDraggingItem = false;
                                  });
                                },
                                onDraggableCanceled: (velocity, offset) {
                                  setState(() {
                                    _isDraggingItem = false;
                                  });
                                },
                                feedback: Material(
                                  color: Colors.transparent,
                                  child:
                                      _selectedItemIds.contains(item.id) &&
                                          _selectedItemIds.length > 1
                                      ? Container(
                                          width: 150,
                                          height: 150,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.2,
                                                ),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.layers,
                                                size: 48,
                                                color: Colors.blue,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                '${_selectedItemIds.length} Items',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : SizedBox(
                                          width: 150,
                                          height: 150,
                                          child: _buildItemCard(item, false),
                                        ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.5,
                                  child: _buildItemCard(item, isSelected),
                                ),
                                child: _buildItemCard(item, isSelected),
                              ),
                            );
                          },
                          ),
                        ),
                      ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (_isDraggingItem)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.8),
                    padding: const EdgeInsets.all(8),
                    // Ensure hit test works
                    alignment: Alignment.topLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                          child: Text(
                            'Drop to move to...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Consumer<BundlesProvider>(
                            builder: (context, bundlesProvider, child) {
                              final otherBundles = bundlesProvider.bundles
                                  .where((b) => b.id != widget.bundle.id)
                                  .toList();

                              if (otherBundles.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No other bundles',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                );
                              }

                              return ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: otherBundles.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final targetBundle = otherBundles[index];
                                  return DragTarget<String>(
                                    onWillAccept: (data) => true,
                                    onAccept: (itemId) async {
                                      List<String> itemsToMove = [itemId];
                                      if (_selectedItemIds.contains(itemId)) {
                                        itemsToMove = _selectedItemIds.toList();
                                      }

                                  // Optimistic Update
                                  Provider.of<ItemsProvider>(context, listen: false)
                                      .moveItemsLocal(itemsToMove, targetBundle.id);

                                  // Clear selection immediately
                                  if (_selectedItemIds.contains(itemId)) {
                                    setState(() {
                                      _selectedItemIds.clear();
                                      _isDragMode = false;
                                    });
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Moved ${itemsToMove.length} items to ${targetBundle.name}')),
                                  );

                                  // Persist in background
                                  await Provider.of<BundlesProvider>(context, listen: false)
                                      .moveItemsToBundle(targetBundle.id, itemsToMove);
                                  
                                  if (mounted) {
                                    // Ensure consistency (optional, but good practice)
                                    await Provider.of<ItemsProvider>(context, listen: false).loadItems();
                                  }
                                },
                                builder: (context, candidateData, rejectedData) {
                                  final isHovered = candidateData.isNotEmpty;
                                  return Container(
                                    width: 100,
                                    decoration: BoxDecoration(
                                      color: isHovered ? Colors.blue.withOpacity(0.5) : Colors.grey[800],
                                      borderRadius: BorderRadius.circular(12),
                                      border: isHovered ? Border.all(color: Colors.blue, width: 2) : null,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (targetBundle.imagePath != null)
                                          SmartS3Image(
                                            imagePath: targetBundle.imagePath,
                                            bundleServerId: targetBundle.serverId,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            borderRadius: BorderRadius.circular(8),
                                          )
                                        else
                                          const Icon(Icons.folder, color: Colors.white),
                                        const SizedBox(height: 4),
                                        Text(
                                          targetBundle.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
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
      color: isSelected
          ? Colors.blue[50]
          : (item.isChecked ? Colors.green[50] : Colors.white),
      elevation: item.isChecked ? 1 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: Colors.blue, width: 2)
            : (item.isChecked
                  ? BorderSide(
                      color: Colors.green.withValues(alpha: 0.5),
                      width: 1,
                    )
                  : BorderSide.none),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.grey[200]),
                      if (item.imagePath != null)
                        SmartS3Image(
                          imagePath: item.imagePath,
                          itemServerId: item.serverId,
                          fit: BoxFit.cover,
                        ),
                      if (item.imagePath != null && item.isChecked)
                        Container(
                          color: Colors.white.withOpacity(0.6),
                        ),
                      if (item.imagePath == null)
                        const Center(
                          child: Icon(Icons.image, color: Colors.grey),
                        ),
                    ],
                  ),
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
                        decoration: item.isChecked
                            ? TextDecoration.lineThrough
                            : null,
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
                            const Icon(
                              Icons.access_time,
                              size: 12,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getTimeAgo(item.lastCheckedAt!),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.green, fontSize: 10),
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
                  item.isChecked
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: item.isChecked ? Colors.green : Colors.grey,
                ),
                onPressed: () {
                  Provider.of<ItemsProvider>(
                    context,
                    listen: false,
                  ).toggleItemCheck(item.id);
                },
              ),
            ),
        ],
      ),
    );
  }
}

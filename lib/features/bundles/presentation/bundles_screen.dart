import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'providers/bundles_provider.dart';
import '../../items/presentation/controllers/items_provider.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/sync/connectivity_service.dart';
//import 'add_edit_bundle_screen.dart';

class BundlesScreen extends StatefulWidget {
  const BundlesScreen({super.key});

  @override
  State<BundlesScreen> createState() => _BundlesScreenState();
}

class _BundlesScreenState extends State<BundlesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshFromCloud() async {
    final syncService = SyncService();
    final connectivityService = ConnectivityService();
    
    if (!connectivityService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing with cloud...'), duration: Duration(seconds: 1)),
    );

    final success = await syncService.performSync();
    
    if (mounted) {
      if (success) {
        // Reload data from local database
        Provider.of<BundlesProvider>(context, listen: false).loadBundles();
        Provider.of<ItemsProvider>(context, listen: false).loadItems();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync complete!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: ${syncService.lastError ?? "Unknown error"}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 60,
        titleSpacing: 0,
        leadingWidth: 70,
        leading: null,
        actions: [
          // Cloud Sync Button
          Consumer<SyncService>(
            builder: (context, syncService, child) {
              return IconButton(
                icon: syncService.isSyncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_sync, color: Colors.blue, size: 28),
                onPressed: syncService.isSyncing ? null : _refreshFromCloud,
                tooltip: 'Sync with cloud',
              );
            },
          ),
          Consumer<BundlesProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: Icon(
                  provider.showFavoritesOnly
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: provider.showFavoritesOnly ? Colors.red : Colors.black,
                  size: 28,
                ),
                onPressed: () {
                  provider.toggleShowFavoritesOnly();
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.black,
              size: 28,
            ),
            onPressed: () {
              context.push('/add_bundle');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                // Search Bar
                Consumer<BundlesProvider>(
                  builder: (context, provider, child) {
                    return TextFormField(
                      controller: _searchController,
                      onChanged: (value) {
                        provider.searchBundles(value);
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Search',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  provider.searchBundles('');
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Sort and Filter Row
                Consumer<BundlesProvider>(
                  builder: (context, provider, child) {
                    return Row(
                      children: [
                        Expanded(
                          child: PopupMenuButton<String>(
                            onSelected: (value) {
                              provider.setSortOrder(value);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'asc',
                                child: Text('Sort by Name (A-Z)'),
                              ),
                              const PopupMenuItem(
                                value: 'recent',
                                child: Text('Recently Added'),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.sort, color: Colors.black),
                                  const SizedBox(width: 8),
                                  Text(
                                    provider.sortOrder == 'asc'
                                        ? 'Name (A-Z)'
                                        : 'Recently added',
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bundles Grid
          Expanded(
            child: Consumer2<BundlesProvider, ItemsProvider>(
              builder: (context, bundlesProvider, itemsProvider, child) {
                if (bundlesProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (bundlesProvider.bundles.isEmpty) {
                  return const Center(child: Text('No bundles found.'));
                }
                
                // Initialize completion status for all bundles
                final bundleItemsMap = <String, List<dynamic>>{};
                for (final bundle in bundlesProvider.bundles) {
                  bundleItemsMap[bundle.id] = itemsProvider.items
                      .where((item) => item.bundleId == bundle.id)
                      .toList();
                }
                // Update all bundle completion statuses (only notifies if changed)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  bundlesProvider.updateAllBundleCompletionStatus(bundleItemsMap);
                });

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 4.0,
                    mainAxisSpacing: 4.0,
                    childAspectRatio: 0.6, // Adjusted to prevent overflow
                  ),
                  itemCount: bundlesProvider.bundles.length,
                  itemBuilder: (context, index) {
                    final bundle = bundlesProvider.bundles[index];
                    return GestureDetector(
                      onTap: () {
                        context.push('/bundle_details', extra: bundle);
                      },
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Bundle Options'),
                            content: Text(
                              bundle.isFavorite
                                  ? 'Remove from favorites?'
                                  : 'Add to favorites?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  bundlesProvider.toggleFavorite(bundle.id);
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  bundle.isFavorite ? 'Remove' : 'Add',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: BundleCard(
                        title: bundle.name,
                        subtitle: bundle.description,
                        imagePath: bundle.imagePath,
                        isFavorite: bundle.isFavorite,
                        isCompleted: bundlesProvider.isBundleCompleted(bundle.id),
                        onEdit: () {
                          context.push('/add_bundle', extra: bundle);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BundleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imagePath;
  final bool isFavorite;
  final bool isCompleted;
  final VoidCallback? onEdit;

  const BundleCard({
    Key? key,
    required this.title,
    required this.subtitle,
    this.imagePath,
    this.isFavorite = false,
    this.isCompleted = false,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      color: isCompleted ? Colors.green[50] : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey[100]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            Stack(
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isCompleted ? Colors.green[600]! : Colors.grey.shade300,
                      width: isCompleted ? 3 : 1,
                    ),
                  ),
                  child: imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(
                            File(imagePath!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.blue,
                                ),
                              );
                            },
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.blue,
                            size: 50,
                          ),
                        ),
                ),
                if (isFavorite)
                  const Positioned(
                    top: 4,
                    right: 2,
                    child: Icon(Icons.favorite, color: Colors.purple, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 12), 
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: GestureDetector(
                onTap: onEdit,
                child: Icon(
                  Icons.edit_outlined,
                  color: Colors.blue[500],
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

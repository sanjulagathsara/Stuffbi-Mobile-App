import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../items/presentation/controllers/items_provider.dart';
import 'providers/bundles_provider.dart';
import '../models/bundle_model.dart';
import '../../../core/widgets/smart_s3_image.dart';
import '../../../core/services/s3_upload_service.dart';
import '../../../core/services/image_url_service.dart';

class AddEditBundleScreen extends StatefulWidget {
  final Bundle? bundle;

  const AddEditBundleScreen({super.key, this.bundle});

  @override
  State<AddEditBundleScreen> createState() => _AddEditBundleScreenState();
}

class _AddEditBundleScreenState extends State<AddEditBundleScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  File? _imageFile;
  String? _existingImageUrl; // For existing S3 images
  bool _isNewImage = false;
  bool _isUploading = false;
  final Set<String> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bundle?.name ?? '');
    _descriptionController = TextEditingController(text: widget.bundle?.description ?? '');
    if (widget.bundle?.imagePath != null) {
      // Check if it's a URL or local file
      if (widget.bundle!.imagePath!.startsWith('http')) {
        _existingImageUrl = widget.bundle!.imagePath;
      } else {
        _imageFile = File(widget.bundle!.imagePath!);
      }
    }
    
    // If editing, we should pre-select items that are in this bundle
    if (widget.bundle != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
        final bundleItems = itemsProvider.items.where((item) => item.bundleId == widget.bundle!.id);
        setState(() {
          _selectedItemIds.addAll(bundleItems.map((item) => item.id));
        });
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isNewImage = true;
        _existingImageUrl = null; // Clear existing URL if picking new image
      });
    }
  }

  Future<void> _saveBundle() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isUploading = true);
      
      try {
        final bundlesProvider = Provider.of<BundlesProvider>(context, listen: false);
        
        String? finalImagePath = _existingImageUrl; // Start with existing URL if any
        
        // If we have a new local image, upload to S3
        if (_isNewImage && _imageFile != null) {
          final s3Url = await S3UploadService().uploadBundleImage(_imageFile!);
          if (s3Url != null) {
            // Store S3 URL for sync - this is what gets saved to backend
            finalImagePath = s3Url;
            // Cache local file path for immediate display
            ImageUrlService().cacheLocalFile(s3Url, _imageFile!.path);
            debugPrint('S3 upload successful: $s3Url, cached local path for display');
          } else {
            // S3 upload failed, use local path
            debugPrint('S3 upload failed, using local path');
            finalImagePath = _imageFile?.path;
          }
        } else if (_imageFile != null && !_isNewImage) {
          // Existing local file (not a URL)
          finalImagePath = _imageFile!.path;
        }
        
        if (widget.bundle == null) {
          await bundlesProvider.addBundle(
            _nameController.text,
            _descriptionController.text,
            finalImagePath,
            _selectedItemIds.toList(),
          );
        } else {
          await bundlesProvider.updateBundle(
            widget.bundle!.copyWith(
              name: _nameController.text,
              description: _descriptionController.text,
              imagePath: finalImagePath,
            ),
          );
          // Also update items assignment
          // This is a bit tricky because we need to handle items added and removed.
          // For simplicity, we can just re-assign all selected items to this bundle.
          // Items that were deselected should probably be removed from the bundle (set bundleId to null).
          
          // However, the current `addItemsToBundle` only adds. 
          // We might need a more robust way to sync items.
          // For now, let's just add the selected ones. 
          // Ideally, we should diff the list.
          
          // Let's implement a simple sync:
          // 1. Get current items in bundle.
          // 2. Find items to remove (in current but not in selected).
          // 3. Find items to add (in selected but not in current).
          
          final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
          final currentBundleItems = itemsProvider.items.where((item) => item.bundleId == widget.bundle!.id).map((e) => e.id).toSet();
          
          final itemsToRemove = currentBundleItems.difference(_selectedItemIds);
          final itemsToAdd = _selectedItemIds.difference(currentBundleItems);
          
          if (itemsToAdd.isNotEmpty) {
            await bundlesProvider.moveItemsToBundle(widget.bundle!.id, itemsToAdd.toList());
          }
          
          // We need a way to remove items from bundle (set bundleId to null)
          // BundlesProvider doesn't have this yet. We can add it or just use ItemsProvider directly?
          // Let's use ItemsProvider to update items directly for removal.
           for (String itemId in itemsToRemove) {
             final item = itemsProvider.items.firstWhere((element) => element.id == itemId);
             await itemsProvider.updateItem(item.unassignBundle());
           }
           
           // Wait, if I pass null to copyWith(bundleId: null), it sees it as null and uses this.bundleId.
           // I need to check Item model.
        }

        if (mounted) {
          // Refresh items to reflect bundle assignment changes
          await Provider.of<ItemsProvider>(context, listen: false).loadItems();
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving bundle: $e')),
        );
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bundle == null ? 'Add New Bundle' : 'Edit Bundle'),
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveBundle,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    image: _imageFile != null
                        ? DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imageFile == null
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Add Bundle Image', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Bundle Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a bundle name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              const Text(
                'Select Items to Add',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Consumer<ItemsProvider>(
                builder: (context, itemsProvider, child) {
                  final items = itemsProvider.items;
                  if (items.isEmpty) {
                    return const Text('No items available to add.');
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isSelected = _selectedItemIds.contains(item.id);
                      return CheckboxListTile(
                        title: Text(item.name),
                        subtitle: Text(item.category),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedItemIds.add(item.id);
                            } else {
                              _selectedItemIds.remove(item.id);
                            }
                          });
                        },
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
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

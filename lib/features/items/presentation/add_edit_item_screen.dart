import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/item_model.dart';
import 'controllers/items_provider.dart';
import '../../bundles/presentation/providers/bundles_provider.dart';
import '../../../core/services/s3_upload_service.dart';
import '../../../core/services/image_url_service.dart';

class AddEditItemScreen extends StatefulWidget {
  final Item? item;

  const AddEditItemScreen({super.key, this.item});

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _detailsController;
  String? _selectedCategory;
  String? _selectedBundleId;
  String? _imagePath;
  bool _isNewImage = false; // Track if user picked a new local image
  bool _isUploading = false;

  final List<String> _categories = [
    'Electronics',
    'Clothing & Accessories',
    'Books & Stationery',
    'Home Items',
    'University / Work Supplies',
    'Personal Care & Hygiene',
    'Food & Groceries',
  'Other'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _detailsController = TextEditingController(text: widget.item?.details ?? '');
    // Ensure category exists in list, default to null if not
    final itemCategory = widget.item?.category;
    _selectedCategory = (itemCategory != null && _categories.contains(itemCategory)) 
        ? itemCategory
        : null;
    _selectedBundleId = widget.item?.bundleId;
    _imagePath = widget.item?.imagePath;

    // Load bundles if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BundlesProvider>(context, listen: false).loadBundles();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _imagePath = pickedFile.path;
          _isNewImage = true; // Mark as new local image that needs uploading
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isUploading = true);

      try {
        String? finalImagePath = _imagePath;

        // If we have a new local image, upload to S3
        if (_isNewImage && _imagePath != null) {
          final s3Url = await S3UploadService().uploadItemImage(File(_imagePath!));
          if (s3Url != null) {
            // Store S3 URL for sync - this is what gets saved to backend
            finalImagePath = s3Url;
            // Cache local file path for immediate display
            ImageUrlService().cacheLocalFile(s3Url, _imagePath!);
            debugPrint('S3 upload successful: $s3Url, cached local path for display');
          } else {
            // S3 upload failed, continue with local path
            debugPrint('S3 upload failed, using local path');
          }
        }

        final provider = Provider.of<ItemsProvider>(context, listen: false);
        if (widget.item == null) {
          await provider.addItem(
            _nameController.text,
            _selectedCategory ?? 'Other',
            _detailsController.text,
            finalImagePath,
            _selectedBundleId,
          );
        } else {
          await provider.updateItem(
            widget.item!.copyWith(
              name: _nameController.text,
              category: _selectedCategory ?? 'Other',
              details: _detailsController.text,
              imagePath: finalImagePath,
              bundleId: _selectedBundleId,
            ),
          );
        }
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('Error saving item: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save item: $e')),
          );
        }
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
        title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
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
              onPressed: _saveItem,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    image: _imagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_imagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imagePath == null
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap to add image', style: TextStyle(color: Colors.grey)),
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
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _detailsController,
                decoration: const InputDecoration(
                  labelText: 'Subtitle',
                  border: OutlineInputBorder(),
                ),
                maxLines: 1,
              ),
              // const SizedBox(height: 16),
              // DropdownButtonFormField<String>(
              //   value: _selectedCategory,
              //   decoration: const InputDecoration(
              //     labelText: 'Category',
              //     border: OutlineInputBorder(),
              //   ),
              //   items: _categories.map((category) {
              //     return DropdownMenuItem(
              //       value: category,
              //       child: Text(category),
              //     );
              //   }).toList(),
              //   onChanged: (value) {
              //     setState(() {
              //       _selectedCategory = value;
              //     });
              //   },
              // ),
              const SizedBox(height: 16),
              Consumer<BundlesProvider>(
                builder: (context, bundlesProvider, child) {
                  final bundles = bundlesProvider.bundles;
                  // Validate bundleId exists, otherwise set to null
                  final validBundleId = (bundles.any((b) => b.id == _selectedBundleId))
                      ? _selectedBundleId
                      : null;
                  return DropdownButtonFormField<String>(
                    value: validBundleId,
                    decoration: const InputDecoration(
                      labelText: 'Current Bundle',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...bundles.map((bundle) {
                        return DropdownMenuItem(
                          value: bundle.id,
                          child: Text(bundle.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedBundleId = value;
                      });
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

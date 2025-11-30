import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/item_model.dart';
import 'controllers/items_provider.dart';
import '../../bundles/presentation/providers/bundles_provider.dart';

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

  final List<String> _categories = ['Electronics', 'Clothing', 'Books', 'Furniture', 'University', 'Other'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _detailsController = TextEditingController(text: widget.item?.details ?? '');
    _selectedCategory = widget.item?.category;
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
      try {
        final provider = Provider.of<ItemsProvider>(context, listen: false);
        if (widget.item == null) {
          await provider.addItem(
            _nameController.text,
            _selectedCategory ?? 'Other',
            _detailsController.text,
            _imagePath,
            _selectedBundleId,
          );
        } else {
          await provider.updateItem(
            widget.item!.copyWith(
              name: _nameController.text,
              category: _selectedCategory ?? 'Other',
              details: _detailsController.text,
              imagePath: _imagePath,
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
        actions: [
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
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Consumer<BundlesProvider>(
                builder: (context, bundlesProvider, child) {
                  final bundles = bundlesProvider.bundles;
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedBundleId,
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _detailsController,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

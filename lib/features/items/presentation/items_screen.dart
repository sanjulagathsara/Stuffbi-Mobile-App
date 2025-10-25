import 'package:flutter/material.dart';
import 'package:stuffbi/core/widgets/primary_button.dart';

class ItemsScreen extends StatelessWidget {
  const ItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder list of items
    final List<DummyItem> dummyItems = [
      DummyItem(title: 'Item name', details: 'Details'),
      DummyItem(title: 'Item name', details: 'Details', isChecked: true),
      DummyItem(title: 'Item name', details: 'Details'),
      DummyItem(title: 'Item name', details: 'Details'),
      DummyItem(title: 'Item name', details: 'Details'),
    ];

    return Scaffold(
      backgroundColor: Colors.white, // Background color
      appBar: AppBar(
        backgroundColor: Colors.white, // White app bar background
        elevation: 0, // No shadow
        toolbarHeight: 60, // Custom height for the app bar
        titleSpacing: 0, // Remove default title spacing
        leadingWidth: 70, // Adjust leading width for the search icon
        leading: IconButton(
          icon: const Icon(Icons.search, color: Colors.black, size: 28),
          onPressed: () {
            // Handle search icon press
            print('Search icon pressed');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.black, size: 28),
            onPressed: () {
              // Handle add icon press
              print('Add icon pressed');
            },
          ),
          const SizedBox(width: 8), // Padding on the right
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                // Search Bar
                TextFormField(
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none, // No border line
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0), // Adjust vertical padding
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Items List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: dummyItems.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.grey[200],
                height: 1,
              ),
              itemBuilder: (context, index) {
                final item = dummyItems[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Placeholder Image area
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[200], // Light grey background
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: Colors.grey,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Item Details Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.details,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Icon(
                              Icons.edit_outlined,
                              color: Colors.blue[600], // Blue edit icon
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                      // Checkbox
                      Checkbox(
                        value: item.isChecked,
                        onChanged: (bool? newValue) {
                          // State change won't work in StatelessWidget
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Model for a dummy item
class DummyItem {
  String title;
  String details;
  bool isChecked;

  DummyItem({
    required this.title,
    required this.details,
    this.isChecked = false,
  });
}

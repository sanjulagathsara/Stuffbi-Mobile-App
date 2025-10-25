import 'package:flutter/material.dart';

class BundlesScreen extends StatefulWidget {
  const BundlesScreen({super.key});

  @override
  State<BundlesScreen> createState() => _BundlesScreenState();
}

class _BundlesScreenState extends State<BundlesScreen> {
  // Placeholder list of bundles
  final List<Map<String, String>> dummyBundles = [
    {'title': 'Title', 'subtitle': 'Subtitle'},
    {'title': 'Title', 'subtitle': 'Subtitle'},
    {'title': 'Title', 'subtitle': 'Subtitle'},
    {'title': 'Title', 'subtitle': 'Subtitle'},
    {'title': 'Title', 'subtitle': 'Subtitle'},
    {'title': 'Title', 'subtitle': 'Subtitle'},
  ];

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.favorite_border, color: Colors.black, size: 28),
            onPressed: () {
              // Handle favorite icon press
              print('Favorite icon pressed');
            },
          ),
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
                const SizedBox(height: 16),

                // Sort and Filter Row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          print('Sort button pressed');
                        },
                        icon: const Icon(Icons.sort, color: Colors.black),
                        label: const Text('Sort', style: TextStyle(color: Colors.black)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, // White background
                          elevation: 0, // No shadow
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey[300]!), // Light grey border
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          print('Filter button pressed');
                        },
                        icon: const Icon(Icons.filter_list, color: Colors.black),
                        label: Row(
                          children: [
                            const Text('Filter', style: TextStyle(color: Colors.black)),
                            const SizedBox(width: 4),
                            // Filter count badge
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.blue, // Blue badge color
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: const Text(
                                '2',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, // White background
                          elevation: 0, // No shadow
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey[300]!), // Light grey border
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bundles Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Two columns
                crossAxisSpacing: 16.0, // Spacing between columns
                mainAxisSpacing: 16.0, // Spacing between rows
                childAspectRatio: 0.75, // Aspect ratio of each card (height / width)
              ),
              itemCount: dummyBundles.length,
              itemBuilder: (context, index) {
                final bundle = dummyBundles[index];
                return BundleCard(
                  title: bundle['title']!,
                  subtitle: bundle['subtitle']!,
        );
      },
    ),
  ),
],
),
);
}
}// Custom Widget for a single Bundle Card
class BundleCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const BundleCard({
    Key? key,
    required this.title,
    required this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0, // No shadow for the card
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!), // Light grey border
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Placeholder Image area
            Container(
              height: 100, // Fixed height for the image area
              decoration: BoxDecoration(
                color: Colors.grey[200], // Light grey background
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.image_outlined,
                  color: Colors.grey,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const Spacer(), // Pushes the edit icon to the bottom
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                Icons.edit_outlined,
                color: Colors.blue[600], // Blue edit icon
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
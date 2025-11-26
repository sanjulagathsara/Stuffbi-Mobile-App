class Item {
  final String id;
  final String name;
  final String category;
  final String? bundleId;
  final String? imagePath;
  final String details;
  final bool isSynced;

  Item({
    required this.id,
    required this.name,
    required this.category,
    this.bundleId,
    this.imagePath,
    required this.details,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'bundleId': bundleId,
      'imagePath': imagePath,
      'details': details,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      bundleId: map['bundleId'],
      imagePath: map['imagePath'],
      details: map['details'],
      isSynced: map['isSynced'] == 1,
    );
  }

  Item copyWith({
    String? id,
    String? name,
    String? category,
    String? bundleId,
    String? imagePath,
    String? details,
    bool? isSynced,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      bundleId: bundleId ?? this.bundleId,
      imagePath: imagePath ?? this.imagePath,
      details: details ?? this.details,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

class Item {
  final String id;
  final String name;
  final String category;
  final String? bundleId;
  final String? imagePath;
  final String details;
  final bool isSynced;
  final bool isChecked;
  final DateTime? lastCheckedAt;

  Item({
    required this.id,
    required this.name,
    required this.category,
    this.bundleId,
    this.imagePath,
    required this.details,
    this.isSynced = false,
    this.isChecked = false,
    this.lastCheckedAt,
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
      'is_checked': isChecked ? 1 : 0,
      'last_checked_at': lastCheckedAt?.toIso8601String(),
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
      isChecked: map['is_checked'] == 1,
      lastCheckedAt: map['last_checked_at'] != null ? DateTime.parse(map['last_checked_at']) : null,
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
    bool? isChecked,
    DateTime? lastCheckedAt,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      bundleId: bundleId ?? this.bundleId,
      imagePath: imagePath ?? this.imagePath,
      details: details ?? this.details,
      isSynced: isSynced ?? this.isSynced,
      isChecked: isChecked ?? this.isChecked,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }
  Item unassignBundle() {
    return Item(
      id: id,
      name: name,
      category: category,
      bundleId: null,
      imagePath: imagePath,
      details: details,
      isSynced: isSynced,
      isChecked: isChecked,
      lastCheckedAt: lastCheckedAt,
    );
  }
}

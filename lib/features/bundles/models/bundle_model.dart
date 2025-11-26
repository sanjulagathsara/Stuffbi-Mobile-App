class Bundle {
  final String id;
  final String name;
  final String description;
  final String? imagePath;
  final bool isSynced;
  final bool isFavorite;

  Bundle({
    required this.id,
    required this.name,
    required this.description,
    this.imagePath,
    this.isSynced = false,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imagePath': imagePath,
      'isSynced': isSynced ? 1 : 0,
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  factory Bundle.fromMap(Map<String, dynamic> map) {
    return Bundle(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      imagePath: map['imagePath'],
      isSynced: map['isSynced'] == 1,
      isFavorite: map['is_favorite'] == 1,
    );
  }

  Bundle copyWith({
    String? id,
    String? name,
    String? description,
    String? imagePath,
    bool? isSynced,
    bool? isFavorite,
  }) {
    return Bundle(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      isSynced: isSynced ?? this.isSynced,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

import '../../../core/sync/sync_status.dart';

class Bundle {
  final String id;
  final String name;
  final String description;
  final String? imagePath;
  final bool isSynced;
  final bool isFavorite;
  
  // Sync fields
  final int? serverId;
  final SyncStatus syncStatus;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  Bundle({
    required this.id,
    required this.name,
    required this.description,
    this.imagePath,
    this.isSynced = false,
    this.isFavorite = false,
    this.serverId,
    this.syncStatus = SyncStatus.pending,
    this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imagePath': imagePath,
      'isSynced': isSynced ? 1 : 0,
      'is_favorite': isFavorite ? 1 : 0,
      'server_id': serverId,
      'sync_status': syncStatus.toDbString(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
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
      serverId: map['server_id'],
      syncStatus: SyncStatusExtension.fromDbString(map['sync_status']),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
      deletedAt: map['deleted_at'] != null ? DateTime.tryParse(map['deleted_at']) : null,
    );
  }

  /// Create from server JSON response
  factory Bundle.fromServerJson(Map<String, dynamic> json) {
    return Bundle(
      id: json['client_id'] ?? '',
      name: json['title'] ?? '',
      description: json['subtitle'] ?? '',
      imagePath: json['image_url'],
      serverId: json['id'],
      syncStatus: SyncStatus.synced,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  /// Convert to server JSON for API request
  Map<String, dynamic> toServerJson() {
    return {
      'client_id': id,
      'title': name,
      'subtitle': description,
      'image_url': imagePath,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Bundle copyWith({
    String? id,
    String? name,
    String? description,
    String? imagePath,
    bool? isSynced,
    bool? isFavorite,
    int? serverId,
    SyncStatus? syncStatus,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Bundle(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      isSynced: isSynced ?? this.isSynced,
      isFavorite: isFavorite ?? this.isFavorite,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
  
  /// Mark bundle as pending sync with updated timestamp
  Bundle markPending() {
    return copyWith(
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime.now(),
    );
  }
  
  /// Mark bundle as synced with server ID
  Bundle markSynced(int serverBundleId) {
    return copyWith(
      serverId: serverBundleId,
      syncStatus: SyncStatus.synced,
    );
  }
}


import '../../../core/sync/sync_status.dart';

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
  
  // Sync fields
  final int? serverId;
  final SyncStatus syncStatus;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

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
    this.serverId,
    this.syncStatus = SyncStatus.pending,
    this.updatedAt,
    this.deletedAt,
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
      'server_id': serverId,
      'sync_status': syncStatus.toDbString(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
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
      serverId: map['server_id'],
      syncStatus: SyncStatusExtension.fromDbString(map['sync_status']),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
      deletedAt: map['deleted_at'] != null ? DateTime.tryParse(map['deleted_at']) : null,
    );
  }

  /// Create from server JSON response
  factory Item.fromServerJson(Map<String, dynamic> json) {
    return Item(
      id: json['client_id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      bundleId: json['bundle_client_id'],
      imagePath: json['image_url'],
      details: json['subtitle'] ?? '',
      serverId: json['id'],
      syncStatus: SyncStatus.synced,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  /// Convert to server JSON for API request
  Map<String, dynamic> toServerJson() {
    return {
      'client_id': id,
      'name': name,
      'subtitle': details,
      'bundle_client_id': bundleId,
      'image_url': imagePath,
      'updated_at': updatedAt?.toIso8601String(),
    };
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
    int? serverId,
    SyncStatus? syncStatus,
    DateTime? updatedAt,
    DateTime? deletedAt,
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
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
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
      serverId: serverId,
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime.now(),
      deletedAt: deletedAt,
    );
  }
  
  /// Mark item as pending sync with updated timestamp
  Item markPending() {
    return copyWith(
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime.now(),
    );
  }
  
  /// Mark item as synced with server ID
  Item markSynced(int serverItemId) {
    return copyWith(
      serverId: serverItemId,
      syncStatus: SyncStatus.synced,
    );
  }
}


import '../../../features/items/models/item_model.dart';
import '../../../features/bundles/models/bundle_model.dart';

/// Represents a sync conflict when an item/bundle was deleted on server
/// but has pending local changes
class SyncConflict {
  final SyncConflictType type;
  final String localId;
  final int? serverId;
  final String name;
  final DateTime? localUpdatedAt;
  
  // Store the actual model for restoration
  final Item? item;
  final Bundle? bundle;

  SyncConflict({
    required this.type,
    required this.localId,
    this.serverId,
    required this.name,
    this.localUpdatedAt,
    this.item,
    this.bundle,
  });

  @override
  String toString() {
    return 'SyncConflict($type: $name, localId: $localId, serverId: $serverId)';
  }
}

enum SyncConflictType {
  itemDeletedOnServer,
  bundleDeletedOnServer,
}

/// Result of conflict resolution
enum ConflictResolution {
  deleteLocally,  // Accept server deletion
  restoreToCloud, // Push local version back to server
  skip,           // Decide later
}

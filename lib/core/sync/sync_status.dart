/// Represents the synchronization status of an entity
enum SyncStatus {
  /// Entity is synced with the server
  synced,
  
  /// Entity has local changes pending upload
  pending,
  
  /// Entity sync failed (will retry)
  error,
}

/// Extension to convert SyncStatus to/from string for database storage
extension SyncStatusExtension on SyncStatus {
  String toDbString() {
    switch (this) {
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.pending:
        return 'pending';
      case SyncStatus.error:
        return 'error';
    }
  }

  static SyncStatus fromDbString(String? value) {
    switch (value) {
      case 'synced':
        return SyncStatus.synced;
      case 'pending':
        return SyncStatus.pending;
      case 'error':
        return SyncStatus.error;
      default:
        return SyncStatus.pending;
    }
  }
}

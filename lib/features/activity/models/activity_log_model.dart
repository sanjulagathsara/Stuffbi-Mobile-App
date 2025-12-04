class ActivityLog {
  final String id;
  final String itemId;
  final String actionType; // 'check', 'move', 'create', 'delete'
  final DateTime timestamp;
  final String details;

  ActivityLog({
    required this.id,
    required this.itemId,
    required this.actionType,
    required this.timestamp,
    required this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_id': itemId,
      'action_type': actionType,
      'timestamp': timestamp.toIso8601String(),
      'details': details,
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'],
      itemId: map['item_id'],
      actionType: map['action_type'],
      timestamp: DateTime.parse(map['timestamp']),
      details: map['details'],
    );
  }
}

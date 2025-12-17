import 'package:flutter/material.dart';
import '../../core/sync/sync_conflict.dart';
import '../../core/sync/sync_service.dart';

/// Dialog for resolving sync conflicts
class ConflictResolutionDialog extends StatefulWidget {
  final List<SyncConflict> conflicts;

  const ConflictResolutionDialog({
    Key? key,
    required this.conflicts,
  }) : super(key: key);

  /// Show the dialog and return true if all conflicts were resolved
  static Future<bool> show(BuildContext context, List<SyncConflict> conflicts) async {
    if (conflicts.isEmpty) return true;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConflictResolutionDialog(conflicts: conflicts),
    );
    return result ?? false;
  }

  @override
  State<ConflictResolutionDialog> createState() => _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  final SyncService _syncService = SyncService();
  final Map<String, ConflictResolution> _resolutions = {};
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    // Default all to skip
    for (final conflict in widget.conflicts) {
      _resolutions[conflict.localId] = ConflictResolution.skip;
    }
  }

  Future<void> _applyResolutions() async {
    setState(() => _isResolving = true);
    
    for (final conflict in widget.conflicts) {
      final resolution = _resolutions[conflict.localId] ?? ConflictResolution.skip;
      if (resolution != ConflictResolution.skip) {
        await _syncService.resolveConflict(conflict, resolution);
      }
    }
    
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 28),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Sync Conflicts Detected',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The following items were deleted on another device but have pending changes locally. What would you like to do?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.conflicts.length,
                itemBuilder: (context, index) {
                  return _buildConflictItem(widget.conflicts[index]);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isResolving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Decide Later'),
        ),
        ElevatedButton(
          onPressed: _isResolving ? null : _applyResolutions,
          child: _isResolving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildConflictItem(SyncConflict conflict) {
    final resolution = _resolutions[conflict.localId] ?? ConflictResolution.skip;
    final isItem = conflict.type == SyncConflictType.itemDeletedOnServer;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isItem ? Icons.inventory_2_outlined : Icons.folder_outlined,
                  size: 20,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    conflict.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isItem ? 'Item deleted on cloud' : 'Bundle deleted on cloud',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (conflict.localUpdatedAt != null)
              Text(
                'Your changes: ${_formatDate(conflict.localUpdatedAt!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildChoiceButton(
                    conflict,
                    ConflictResolution.deleteLocally,
                    'Delete',
                    Icons.delete_outline,
                    Colors.red,
                    resolution == ConflictResolution.deleteLocally,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildChoiceButton(
                    conflict,
                    ConflictResolution.restoreToCloud,
                    'Restore',
                    Icons.cloud_upload_outlined,
                    Colors.green,
                    resolution == ConflictResolution.restoreToCloud,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceButton(
    SyncConflict conflict,
    ConflictResolution resolution,
    String label,
    IconData icon,
    Color color,
    bool isSelected,
  ) {
    return OutlinedButton.icon(
      onPressed: _isResolving
          ? null
          : () {
              setState(() {
                _resolutions[conflict.localId] = resolution;
              });
            },
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected ? Colors.white : color,
        backgroundColor: isSelected ? color : Colors.transparent,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

import 'package:flutter/material.dart';

import '../../../../models/selected_street.dart';

/// Shows selected streets list with route name field, reorder and remove support.
class SelectedStreetsPanel extends StatelessWidget {
  final List<SelectedStreet> streets;
  final VoidCallback onSave;
  final bool saveEnabled;
  final bool saving;
  final TextEditingController routeNameController;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onRemove;
  final void Function(int index, String newName) onRename;

  const SelectedStreetsPanel({
    super.key,
    required this.streets,
    required this.onSave,
    required this.saveEnabled,
    required this.saving,
    required this.routeNameController,
    required this.onReorder,
    required this.onRemove,
    required this.onRename,
  });

  Future<void> _showRenameDialog(BuildContext context, int index, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Street'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Street Name',
            hintText: 'Enter custom street name',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null) {
      onRename(index, newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // ── Empty state: instructions ───────────────
    if (streets.isEmpty) {
      return SafeArea(
        child: Container(
          color: colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.touch_app, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tap on any road to add it',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Zoom in close and tap directly on a road line.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Streets selected: name + list ───────────
    return SafeArea(
      child: SizedBox(
        height: 280,
        child: Column(
          children: [
            // Header: route name field + save button
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: routeNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Route name',
                        hintText: 'e.g. Morning Market Run',
                        prefixIcon: const Icon(Icons.route, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: saveEnabled ? onSave : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save, size: 18),
                    label: Text(saving ? 'Saving…' : 'Save'),
                  ),
                ],
              ),
            ),

            // Street count label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${streets.length} street${streets.length > 1 ? "s" : ""} in route',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '• Drag to reorder',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(height: 8),

            // Reorderable street list
            Expanded(
              child: ReorderableListView.builder(
                padding: EdgeInsets.zero,
                itemCount: streets.length,
                onReorder: onReorder,
                itemBuilder: (context, index) {
                  final street = streets[index];
                  return ListTile(
                    key: ValueKey('${index}_${street.name}_${street.center.latitude}'),
                    dense: true,
                    leading: CircleAvatar(
                      radius: 13,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      street.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${street.center.latitude.toStringAsFixed(4)}, '
                      '${street.center.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          tooltip: 'Rename',
                          onPressed: () => _showRenameDialog(context, index, street.name),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          tooltip: 'Remove',
                          onPressed: () => onRemove(index),
                        ),
                        const Icon(Icons.drag_handle, size: 18),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../models.dart';

/// UC3's list-item view of a single entry on the staff dashboard: shows
/// type, title, description, tags, and last-updated (FR5), with edit/
/// delete actions. Purely presentational — the caller owns what edit and
/// delete actually do.
class DashboardEntryCard extends StatelessWidget {
  final Entry entry;
  final Map<int, String> tagNamesById;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DashboardEntryCard({
    super.key,
    required this.entry,
    required this.tagNamesById,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(
                    entry.type == EntryType.idea ? 'Project idea' : 'Interest',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
            if (entry.description != null) ...[
              const SizedBox(height: 4),
              Text(entry.description!),
            ],
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: entry.tags
                    .map(
                      (id) => Chip(
                        label: Text(
                          tagNamesById[id] ?? 'Tag $id',
                          style: const TextStyle(fontSize: 12),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Last updated ${entry.updatedAt.toLocal()}'.split('.').first,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

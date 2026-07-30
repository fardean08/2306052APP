import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/session.dart';

/// UC2 (Set Supervision Availability) + UC3 (Manage Areas of Interest /
/// Project Ideas), combined into one staff dashboard as the spec
/// describes: "a dashboard control to change Open/Limited/Closed" plus
/// "create/update/delete entries from the dashboard".
class StaffDashboardScreen extends StatefulWidget {
  final ApiClient apiClient;
  final Session session;

  const StaffDashboardScreen({
    super.key,
    required this.apiClient,
    required this.session,
  });

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  StaffProfile? _profile;
  List<Entry> _entries = const [];
  List<Tag> _allTags = const [];
  bool _isUpdatingStatus = false;

  String get _userId => widget.session.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profileResponse = await widget.apiClient.get(
        '/api/staff/$_userId',
      ) as Map<String, dynamic>;
      final tagsResponse =
          await widget.apiClient.get('/api/tags') as Map<String, dynamic>;

      final profile = StaffProfile.fromJson(
        profileResponse['profile'] as Map<String, dynamic>,
      );
      final entries = (profileResponse['entries'] as List<dynamic>)
          .map((e) => Entry.fromJson(e as Map<String, dynamic>))
          .toList();
      final tags = (tagsResponse['tags'] as List<dynamic>)
          .map((t) => Tag.fromJson(t as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _entries = entries;
        _allTags = tags;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  /// FR2: change Open/Limited/Closed for the caller's own profile.
  Future<void> _changeStatus(AvailabilityStatus status) async {
    setState(() => _isUpdatingStatus = true);
    try {
      final response = await widget.apiClient.patch(
        '/api/staff/$_userId/availability',
        body: {'status': status.toJson()},
      ) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _profile = StaffProfile.fromJson(response);
        _isUpdatingStatus = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingStatus = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openEntryForm({Entry? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EntryFormSheet(
        apiClient: widget.apiClient,
        allTags: _allTags,
        existing: existing,
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  /// FR7: deleting an entry with an active enquiry warns and requires
  /// explicit confirmation rather than silently orphaning the enquiry.
  Future<void> _deleteEntry(Entry entry) async {
    final confirmed = await _confirm(
      title: 'Delete entry?',
      message: 'Delete "${entry.title}"? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (confirmed != true) return;

    try {
      await widget.apiClient.delete('/api/entries/${entry.id}');
      await _load();
    } on ApiException catch (e) {
      if (e.statusCode != 409) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }

      final forceConfirmed = await _confirm(
        title: 'This entry has enquiries',
        message:
            '${e.message}\n\nDeleting it will not remove those enquiries, '
            'but they will no longer be linked to a visible entry. '
            'Delete anyway?',
        confirmLabel: 'Delete anyway',
      );
      if (forceConfirmed != true) return;

      try {
        await widget.apiClient.delete(
          '/api/entries/${entry.id}',
          query: {'confirm': 'true'},
        );
        await _load();
      } on ApiException catch (e2) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e2.message)));
      }
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    final profile = _profile!;
    final tagNamesById = {for (final t in _allTags) t.id: t.name};

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Supervision availability',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _isUpdatingStatus
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              : SegmentedButton<AvailabilityStatus>(
                  segments: AvailabilityStatus.values
                      .map(
                        (s) => ButtonSegment(value: s, label: Text(s.label)),
                      )
                      .toList(),
                  selected: {profile.status},
                  onSelectionChanged: (selection) =>
                      _changeStatus(selection.first),
                ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your areas of interest & project ideas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openEntryForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                "You haven't added anything yet. Tap Add to get started.",
              ),
            )
          else
            ..._entries.map(
              (entry) => _DashboardEntryCard(
                entry: entry,
                tagNamesById: tagNamesById,
                onEdit: () => _openEntryForm(existing: entry),
                onDelete: () => _deleteEntry(entry),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashboardEntryCard extends StatelessWidget {
  final Entry entry;
  final Map<int, String> tagNamesById;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DashboardEntryCard({
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

/// The FR3 create/edit form for a single entry, shown as a modal bottom
/// sheet. Pops with `true` if a save succeeded, so the caller knows to
/// reload.
class _EntryFormSheet extends StatefulWidget {
  final ApiClient apiClient;
  final List<Tag> allTags;
  final Entry? existing;

  const _EntryFormSheet({
    required this.apiClient,
    required this.allTags,
    this.existing,
  });

  @override
  State<_EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends State<_EntryFormSheet> {
  static const _minTitleLength = 3;
  static const _maxTitleLength = 80;
  static const _maxDescriptionLength = 300;
  static const _minTagCount = 1;
  static const _maxTagCount = 5;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _linkUrlController;
  late EntryType _type;
  late Set<int> _selectedTagIds;
  ProjectType? _projectType;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _tagsErrorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _linkUrlController = TextEditingController(text: existing?.linkUrl ?? '');
    _type = existing?.type ?? EntryType.interest;
    _selectedTagIds = {...(existing?.tags ?? const [])};
    _projectType = existing?.projectType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState!.validate();
    final tagsValid =
        _selectedTagIds.length >= _minTagCount &&
        _selectedTagIds.length <= _maxTagCount;
    setState(() {
      _tagsErrorMessage = tagsValid
          ? null
          : 'Select between $_minTagCount and $_maxTagCount tags';
    });
    if (!formValid || !tagsValid) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final description = _descriptionController.text.trim();
    final linkUrl = _linkUrlController.text.trim();
    final body = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': description.isEmpty ? null : description,
      'tags': _selectedTagIds.toList(),
      if (_type == EntryType.idea) 'projectType': _projectType?.toJson(),
      if (_type == EntryType.idea) 'linkUrl': linkUrl.isEmpty ? null : linkUrl,
    };

    try {
      if (_isEditing) {
        await widget.apiClient.patch(
          '/api/entries/${widget.existing!.id}',
          body: body,
        );
      } else {
        await widget.apiClient.post(
          '/api/entries',
          body: {'type': _type.toJson(), ...body},
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _isEditing ? 'Edit entry' : 'Add a new entry',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (!_isEditing)
                SegmentedButton<EntryType>(
                  segments: const [
                    ButtonSegment(
                      value: EntryType.interest,
                      label: Text('Area of interest'),
                    ),
                    ButtonSegment(
                      value: EntryType.idea,
                      label: Text('Project idea'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selection) =>
                      setState(() => _type = selection.first),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final length = (value ?? '').trim().length;
                  if (length < _minTitleLength || length > _maxTitleLength) {
                    return 'Title must be $_minTitleLength-$_maxTitleLength '
                        'characters (currently $length)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                maxLength: _maxDescriptionLength,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final length = (value ?? '').trim().length;
                  if (length > _maxDescriptionLength) {
                    return 'Description must be at most '
                        '$_maxDescriptionLength characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Tags ($_minTagCount-$_maxTagCount)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: widget.allTags.map((tag) {
                  final selected = _selectedTagIds.contains(tag.id);
                  return FilterChip(
                    label: Text(tag.name),
                    selected: selected,
                    onSelected: (isSelected) {
                      setState(() {
                        if (isSelected) {
                          _selectedTagIds.add(tag.id);
                        } else {
                          _selectedTagIds.remove(tag.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              if (_tagsErrorMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  _tagsErrorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
              if (_type == EntryType.idea) ...[
                const SizedBox(height: 16),
                Text(
                  'Project type (optional)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('None'),
                      selected: _projectType == null,
                      onSelected: (_) => setState(() => _projectType = null),
                    ),
                    ...ProjectType.values.map(
                      (type) => ChoiceChip(
                        label: Text(type.label),
                        selected: _projectType == type,
                        onSelected: (_) => setState(() => _projectType = type),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _linkUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Link URL (optional, http/https)',
                    border: OutlineInputBorder(),
                    hintText: 'https://example.com/project',
                  ),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) return null;
                    final uri = Uri.tryParse(trimmed);
                    final isValid =
                        uri != null &&
                        (uri.scheme == 'http' || uri.scheme == 'https') &&
                        uri.host.isNotEmpty;
                    return isValid
                        ? null
                        : 'Enter a well-formed http/https URL';
                  },
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Save changes' : 'Create entry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

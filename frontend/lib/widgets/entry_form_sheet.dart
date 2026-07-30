import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';

/// UC3's FR3 create/edit form for a single entry, shown as a modal bottom
/// sheet. Pops with `true` if a save succeeded, so the caller knows to
/// reload; pops with nothing (null) if dismissed without saving.
///
/// Client-side validation here is a UX convenience only — the backend's
/// [EntryService] is the authoritative enforcement of these same rules
/// (NFR3), so nothing here needs to be perfectly exhaustive.
class EntryFormSheet extends StatefulWidget {
  final ApiClient apiClient;
  final List<Tag> allTags;
  final Entry? existing;

  const EntryFormSheet({
    super.key,
    required this.apiClient,
    required this.allTags,
    this.existing,
  });

  @override
  State<EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends State<EntryFormSheet> {
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

import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import 'profile_detail_screen.dart';

/// UC1: Search and Filter Staff Profiles (Student).
///
/// FR1: keyword + subject-tag search, combinable, with an empty query
/// showing everyone and no matches showing an empty state rather than an
/// error. FR10: an additional project-type filter, also combinable.
/// NFR1: no instructions needed — a text field plus tap-to-toggle chips.
class BrowseScreen extends StatefulWidget {
  final ApiClient apiClient;
  final Session session;

  const BrowseScreen({
    super.key,
    required this.apiClient,
    required this.session,
  });

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _keywordController = TextEditingController();
  Timer? _debounce;

  List<Tag> _allTags = [];
  final Set<int> _selectedTagIds = {};
  ProjectType? _selectedProjectType;

  bool _isLoading = true;
  String? _errorMessage;
  List<StaffSearchResult> _results = [];

  @override
  void initState() {
    super.initState();
    _loadTagsThenSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _loadTagsThenSearch() async {
    try {
      final tagsJson =
          await widget.apiClient.get('/api/tags') as Map<String, dynamic>;
      _allTags = (tagsJson['tags'] as List<dynamic>)
          .map((t) => Tag.fromJson(t as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // If the tag list fails to load, search still works — filter chips
      // just won't be available.
    }
    await _search();
  }

  void _onKeywordChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final query = <String, String>{};
      final keyword = _keywordController.text.trim();
      if (keyword.isNotEmpty) query['keyword'] = keyword;
      if (_selectedTagIds.isNotEmpty) {
        query['tags'] = _selectedTagIds.join(',');
      }
      if (_selectedProjectType != null) {
        query['projectType'] = _selectedProjectType!.toJson();
      }

      final response = await widget.apiClient.get(
        '/api/search',
        query: query.isEmpty ? null : query,
      ) as Map<String, dynamic>;
      final results = (response['results'] as List<dynamic>)
          .map((r) => StaffSearchResult.fromJson(r as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _results = results;
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

  void _toggleTag(int tagId) {
    setState(() {
      if (!_selectedTagIds.add(tagId)) {
        _selectedTagIds.remove(tagId);
      }
    });
    _search();
  }

  void _setProjectType(ProjectType? type) {
    setState(() => _selectedProjectType = type);
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final tagNamesById = {for (final t in _allTags) t.id: t.name};

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _keywordController,
            onChanged: _onKeywordChanged,
            decoration: const InputDecoration(
              labelText: 'Search by name, tag, or project title',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        if (_allTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _allTags.map((tag) {
                  final selected = _selectedTagIds.contains(tag.id);
                  return FilterChip(
                    label: Text(tag.name),
                    selected: selected,
                    onSelected: (_) => _toggleTag(tag.id),
                  );
                }).toList(),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Project type:'),
                ChoiceChip(
                  label: const Text('Any'),
                  selected: _selectedProjectType == null,
                  onSelected: (_) => _setProjectType(null),
                ),
                ChoiceChip(
                  label: Text(ProjectType.researchBased.label),
                  selected: _selectedProjectType == ProjectType.researchBased,
                  onSelected: (_) => _setProjectType(ProjectType.researchBased),
                ),
                ChoiceChip(
                  label: Text(ProjectType.implementationBased.label),
                  selected:
                      _selectedProjectType == ProjectType.implementationBased,
                  onSelected: (_) =>
                      _setProjectType(ProjectType.implementationBased),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildResultsList(tagNamesById)),
      ],
    );
  }

  Widget _buildResultsList(Map<int, String> tagNamesById) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    if (_results.isEmpty) {
      return const Center(child: Text('No matching staff profiles.'));
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return _StaffResultCard(
          result: result,
          tagNamesById: tagNamesById,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileDetailScreen(
                  apiClient: widget.apiClient,
                  session: widget.session,
                  userId: result.user.id,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StaffResultCard extends StatelessWidget {
  final StaffSearchResult result;
  final Map<int, String> tagNamesById;
  final VoidCallback onTap;

  const _StaffResultCard({
    required this.result,
    required this.tagNamesById,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tagIds = <int>{};
    for (final entry in result.entries) {
      tagIds.addAll(entry.tags);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: onTap,
        title: Row(
          children: [
            Expanded(
              child: Text(
                result.user.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            _StatusBadge(status: result.profile.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.profile.office),
              const SizedBox(height: 6),
              if (tagIds.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tagIds
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
              const SizedBox(height: 4),
              Text(
                '${result.entries.length} area(s) of interest/idea listed',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AvailabilityStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (status) {
      case AvailabilityStatus.open:
        color = Colors.green.shade700;
        break;
      case AvailabilityStatus.limited:
        color = Colors.orange.shade800;
        break;
      case AvailabilityStatus.closed:
        color = Colors.red.shade700;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

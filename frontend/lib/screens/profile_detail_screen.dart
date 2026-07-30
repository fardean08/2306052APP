import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import 'contact_screen.dart';

/// The staff profile detail view reached from [BrowseScreen] (part of
/// UC1) and the entry point for UC4 (Contact Supervisor About a
/// Project). Always fetched fresh from the backend (FR4: no cached
/// listing) — including on pull-to-refresh.
class ProfileDetailScreen extends StatefulWidget {
  final ApiClient apiClient;
  final Session session;
  final String userId;

  const ProfileDetailScreen({
    super.key,
    required this.apiClient,
    required this.session,
    required this.userId,
  });

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  AppUser? _owner;
  StaffProfile? _profile;
  List<Entry> _entries = const [];
  Map<int, String> _tagNamesById = const {};

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
        '/api/staff/${widget.userId}',
      ) as Map<String, dynamic>;
      final tagsResponse =
          await widget.apiClient.get('/api/tags') as Map<String, dynamic>;

      final owner = AppUser.fromJson(
        profileResponse['user'] as Map<String, dynamic>,
      );
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
        _owner = owner;
        _profile = profile;
        _entries = entries;
        _tagNamesById = {for (final t in tags) t.id: t.name};
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_owner?.name ?? 'Staff profile')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    final owner = _owner!;
    final profile = _profile!;
    final isStudent = widget.session.currentUser?.role == UserRole.student;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(owner.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(profile.office, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(label: Text('Availability: ${profile.status.label}')),
              Text(
                'Profile last updated: ${_formatTimestamp(profile.lastUpdated)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Areas of interest & project ideas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('This staff member has not listed anything yet.'),
            )
          else
            ..._entries.map(
              (entry) => _EntryCard(
                entry: entry,
                tagNamesById: _tagNamesById,
                showContactButton: isStudent && entry.type == EntryType.idea,
                onContact: () => _openContactScreen(entry),
              ),
            ),
        ],
      ),
    );
  }

  void _openContactScreen(Entry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactScreen(
          apiClient: widget.apiClient,
          entry: entry,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

class _EntryCard extends StatelessWidget {
  final Entry entry;
  final Map<int, String> tagNamesById;
  final bool showContactButton;
  final VoidCallback onContact;

  const _EntryCard({
    required this.entry,
    required this.tagNamesById,
    required this.showContactButton,
    required this.onContact,
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
                Expanded(
                  child: Text(
                    entry.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(
                    entry.type == EntryType.idea ? 'Project idea' : 'Interest',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (entry.projectType != null) ...[
              const SizedBox(height: 4),
              Text(
                entry.projectType!.label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (entry.description != null) ...[
              const SizedBox(height: 8),
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
            if (entry.linkUrl != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _openLink(context, entry.linkUrl!),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link, size: 16),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        entry.linkUrl!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Last updated ${entry.updatedAt.toLocal()}'.split('.').first,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (showContactButton) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onContact,
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Contact about this idea'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }
}

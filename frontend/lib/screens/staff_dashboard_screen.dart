import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../widgets/availability_control.dart';
import '../widgets/dashboard_entry_card.dart';
import '../widgets/entry_form_sheet.dart';

/// UC2 (Set Supervision Availability) + UC3 (Manage Areas of Interest /
/// Project Ideas), combined into one staff dashboard as the spec
/// describes: "a dashboard control to change Open/Limited/Closed" plus
/// "create/update/delete entries from the dashboard". Loads the caller's
/// own profile/entries/tags and coordinates the [AvailabilityControl],
/// [DashboardEntryCard] list, and [EntryFormSheet].
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
      builder: (_) => EntryFormSheet(
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
          AvailabilityControl(
            status: profile.status,
            isUpdating: _isUpdatingStatus,
            onChanged: _changeStatus,
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
              (entry) => DashboardEntryCard(
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

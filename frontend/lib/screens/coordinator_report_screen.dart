import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';

/// UC5: Review Outdated Profiles (Coordinator).
///
/// FR8: every staff profile, sorted oldest-first by most recent activity
/// (the ordering is done server-side by [CoordinatorService] — this
/// screen just renders it as-is). Staff with zero entries are flagged
/// with a distinct "No entries" chip rather than left looking like any
/// other row.
class CoordinatorReportScreen extends StatefulWidget {
  final ApiClient apiClient;

  const CoordinatorReportScreen({super.key, required this.apiClient});

  @override
  State<CoordinatorReportScreen> createState() =>
      _CoordinatorReportScreenState();
}

class _CoordinatorReportScreenState extends State<CoordinatorReportScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<StaffReportRow> _rows = const [];

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
      final response = await widget.apiClient.get(
        '/api/coordinator/report',
      ) as Map<String, dynamic>;
      final rows = (response['rows'] as List<dynamic>)
          .map((r) => StaffReportRow.fromJson(r as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _rows = rows;
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('No staff profiles found.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _ReportRow(row: _rows[index]),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final StaffReportRow row;

  const _ReportRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          row.user.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.profile.office),
              const SizedBox(height: 4),
              Text(
                'Most recent activity: '
                '${_formatTimestamp(row.mostRecentActivity)}',
              ),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: row.hasNoEntries
            ? Chip(
                label: const Text('No entries'),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              )
            : Chip(label: Text(row.profile.status.label)),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)}';
  }
}

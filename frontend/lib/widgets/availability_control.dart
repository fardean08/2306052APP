import 'package:flutter/material.dart';

import '../models.dart';

/// UC2's availability control: a segmented Open/Limited/Closed toggle.
/// Purely presentational — the caller owns the API call and loading
/// state, this widget just renders the current [status] and reports
/// taps via [onChanged].
class AvailabilityControl extends StatelessWidget {
  final AvailabilityStatus status;
  final bool isUpdating;
  final ValueChanged<AvailabilityStatus> onChanged;

  const AvailabilityControl({
    super.key,
    required this.status,
    required this.isUpdating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isUpdating) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }
    return SegmentedButton<AvailabilityStatus>(
      segments: AvailabilityStatus.values
          .map((s) => ButtonSegment(value: s, label: Text(s.label)))
          .toList(),
      selected: {status},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

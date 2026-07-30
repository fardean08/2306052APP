import 'dart:io';

import '../services/auth_service.dart';
import '../services/coordinator_service.dart';
import 'http_helpers.dart';

/// Handles the coordinator-only staleness report (FR8).
class CoordinatorController {
  final CoordinatorService _coordinatorService;
  final AuthService _authService;

  CoordinatorController(this._coordinatorService, this._authService);

  /// GET /api/coordinator/report — every staff profile, sorted
  /// oldest-first by most recent activity, with zero-entry staff flagged
  /// via `hasNoEntries` rather than omitted. Requires an authenticated
  /// coordinator (enforced by [CoordinatorService]).
  Future<void> getStalenessReport(HttpRequest request) async {
    try {
      final actingUser = await requireAuthenticatedUser(request, _authService);
      final rows = await _coordinatorService.getStalenessReport(
        actingUser: actingUser,
      );
      await writeJson(request, 200, {
        'rows': rows
            .map((row) => {
                  'user': row.user.toPublicJson(),
                  'profile': row.profile.toJson(),
                  'mostRecentActivity':
                      row.mostRecentActivity.toIso8601String(),
                  'hasNoEntries': row.hasNoEntries,
                })
            .toList(),
      });
    } catch (e) {
      await writeError(request, e);
    }
  }
}

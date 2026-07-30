import 'dart:io';

import '../models/staff_profile.dart';
import '../services/app_exceptions.dart';
import '../services/auth_service.dart';
import '../services/entry_service.dart';
import '../services/staff_service.dart';
import 'http_helpers.dart';

/// Handles the staff-profile-detail view (FR4/FR5) and the FR2
/// availability control. Browsing/reading a profile requires no
/// authentication (NFR6: always accessible); changing availability does.
class StaffController {
  final StaffService _staffService;
  final EntryService _entryService;
  final AuthService _authService;

  StaffController(this._staffService, this._entryService, this._authService);

  /// GET /api/staff/<userId> — full profile detail: the owner's public
  /// info, their canonical profile (office/status/lastUpdated), and their
  /// current entries, always read live (FR4) rather than from any cache.
  Future<void> getProfile(HttpRequest request, String userId) async {
    try {
      final profile = await _staffService.getProfile(userId);
      final owner = await _staffService.getOwner(userId);
      final entries = await _entryService.getEntriesForStaff(userId);
      await writeJson(request, 200, {
        'user': owner.toPublicJson(),
        'profile': profile.toJson(),
        'entries': entries.map((e) => e.toJson()).toList(),
      });
    } catch (e) {
      await writeError(request, e);
    }
  }

  /// PATCH /api/staff/<userId>/availability — FR2. Body: `{"status":
  /// "open" | "limited" | "closed"}`. NFR3: only the owner or a
  /// coordinator may call this successfully.
  Future<void> setAvailability(HttpRequest request, String userId) async {
    try {
      final actingUser = await requireAuthenticatedUser(request, _authService);
      final body = await readJsonBody(request);
      final statusValue = body['status'] as String?;
      if (statusValue == null) {
        throw ValidationException('status is required');
      }
      final status = _parseStatus(statusValue);
      final updated = await _staffService.setAvailability(
        actingUser: actingUser,
        targetUserId: userId,
        status: status,
      );
      await writeJson(request, 200, updated.toJson());
    } catch (e) {
      await writeError(request, e);
    }
  }

  AvailabilityStatus _parseStatus(String value) {
    for (final status in AvailabilityStatus.values) {
      if (status.name == value) return status;
    }
    throw ValidationException('Invalid status: $value');
  }
}

import 'dart:io';

import '../services/app_exceptions.dart';
import '../services/auth_service.dart';
import '../services/enquiry_service.dart';
import 'http_helpers.dart';

/// Handles sending an enquiry about an entry (FR9) and a staff member's
/// own enquiry inbox (NFR4 — scoping is enforced by [EnquiryService], so
/// this controller never has to filter anything itself).
class EnquiryController {
  final EnquiryService _enquiryService;
  final AuthService _authService;

  EnquiryController(this._enquiryService, this._authService);

  /// POST /api/entries/<entryId>/enquiries — body: `{"message": "..."}`.
  /// Requires an authenticated student (enforced by [EnquiryService]).
  Future<void> sendEnquiry(HttpRequest request, String entryId) async {
    try {
      final actingUser = await requireAuthenticatedUser(request, _authService);
      final body = await readJsonBody(request);
      final message = body['message'];
      if (message is! String) {
        throw ValidationException('message is required');
      }
      final enquiry = await _enquiryService.sendEnquiry(
        actingUser: actingUser,
        entryId: entryId,
        message: message,
      );
      await writeJson(request, 201, enquiry.toJson());
    } catch (e) {
      await writeError(request, e);
    }
  }

  /// GET /api/enquiries — the caller's own inbox. Requires an
  /// authenticated staff member (enforced by [EnquiryService]).
  Future<void> getInbox(HttpRequest request) async {
    try {
      final actingUser = await requireAuthenticatedUser(request, _authService);
      final enquiries = await _enquiryService.getInboxForStaff(actingUser);
      await writeJson(request, 200, {
        'enquiries': enquiries.map((e) => e.toJson()).toList(),
      });
    } catch (e) {
      await writeError(request, e);
    }
  }
}

import 'dart:io';

import '../models/entry.dart';
import '../services/app_exceptions.dart';
import '../services/auth_service.dart';
import '../services/entry_service.dart';
import 'http_helpers.dart';

/// Handles create/update/delete of areas-of-interest and project-idea
/// entries (FR3/FR6/FR7), plus a public read-by-id used by the student
/// enquiry flow to show what's being asked about. All ownership and
/// validation is enforced by [EntryService], not here.
class EntryController {
  final EntryService _entryService;
  final AuthService _authService;

  EntryController(this._entryService, this._authService);

  /// GET /api/entries/<id>
  Future<void> getEntry(HttpRequest request, String id) async {
    try {
      final entry = await _entryService.getEntry(id);
      await writeJson(request, 200, entry.toJson());
    } catch (e) {
      await writeError(request, e);
    }
  }

  /// POST /api/entries — creates an entry owned by the caller (must be
  /// staff). Body: `{type, title, description?, tags, projectType?,
  /// linkUrl?}`.
  Future<void> createEntry(HttpRequest request) async {
    try {
      final actingUser = await requireAuthenticatedUser(request, _authService);
      final body = await readJsonBody(request);
      final entry = await _entryService.createEntry(
        actingUser: actingUser,
        type: _parseEntryType(body['type']),
        title: _requireString(body, 'title'),
        description: body['description'] as String?,
        tags: _parseTags(body['tags']),
        projectType: _parseProjectType(body['projectType']),
        linkUrl: body['linkUrl'] as String?,
      );
      await writeJson(request, 201, entry.toJson());
    } catch (e) {
      await writeError(request, e);
    }
  }

  /// PATCH /api/entries/<id> — updates fields of an entry the caller owns.
  /// Any field omitted from the body is left unchanged.
  Future<void> updateEntry(HttpRequest request, String id) async {
    try {
      final actingUser = await requireAuthenticatedUser(request, _authService);
      final body = await readJsonBody(request);
      final entry = await _entryService.updateEntry(
        actingUser: actingUser,
        entryId: id,
        title: body['title'] as String?,
        description: body.containsKey('description')
            ? body['description'] as String?
            : null,
        tags: body.containsKey('tags') ? _parseTags(body['tags']) : null,
        projectType: body.containsKey('projectType')
            ? _parseProjectType(body['projectType'])
            : null,
        linkUrl:
            body.containsKey('linkUrl') ? body['linkUrl'] as String? : null,
      );
      await writeJson(request, 200, entry.toJson());
    } catch (e) {
      await writeError(request, e);
    }
  }

  /// DELETE /api/entries/<id>?confirm=true — FR7: if the entry has active
  /// enquiries, this fails with 409 unless `confirm=true` is passed, so
  /// the client can warn the user before an enquiry is orphaned.
  Future<void> deleteEntry(HttpRequest request, String id) async {
    try {
      final actingUser = await requireAuthenticatedUser(request, _authService);
      final confirm = request.uri.queryParameters['confirm'] == 'true';
      await _entryService.deleteEntry(
        actingUser: actingUser,
        entryId: id,
        confirm: confirm,
      );
      await writeJson(request, 204, null);
    } catch (e) {
      await writeError(request, e);
    }
  }

  String _requireString(Map<String, dynamic> body, String key) {
    final value = body[key];
    if (value is! String) {
      throw ValidationException('$key is required');
    }
    return value;
  }

  EntryType _parseEntryType(Object? value) {
    if (value is! String) {
      throw ValidationException('type is required');
    }
    for (final type in EntryType.values) {
      if (type.name == value) return type;
    }
    throw ValidationException('Invalid type: $value');
  }

  ProjectType? _parseProjectType(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw ValidationException('Invalid projectType: $value');
    }
    for (final type in ProjectType.values) {
      if (type.name == value) return type;
    }
    throw ValidationException('Invalid projectType: $value');
  }

  List<int> _parseTags(Object? value) {
    if (value is! List) {
      throw ValidationException('tags must be a list of tag ids');
    }
    return value.map((e) {
      if (e is int) return e;
      throw ValidationException('tags must be a list of tag ids');
    }).toList();
  }
}

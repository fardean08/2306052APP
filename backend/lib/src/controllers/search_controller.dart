import 'dart:io';

import '../models/entry.dart';
import '../services/app_exceptions.dart';
import '../services/search_service.dart';
import 'http_helpers.dart';

/// Handles the staff browse/search view (FR1, FR10). Deliberately public
/// (no authentication) — NFR6 requires the app stay accessible, and
/// nothing in FR1 restricts browsing to logged-in students.
class SearchController {
  final SearchService _searchService;

  SearchController(this._searchService);

  /// GET /api/search?keyword=&tags=1,2&projectType=researchBased
  ///
  /// All parameters are optional and combine with AND semantics. An
  /// absent/empty parameter matches everything for that dimension; no
  /// matches overall yields an empty list, not an error.
  Future<void> search(HttpRequest request) async {
    try {
      final params = request.uri.queryParameters;
      final keyword = params['keyword'];
      final tagIds = _parseTagIds(params['tags']);
      final projectType = _parseProjectType(params['projectType']);

      final results = await _searchService.searchStaff(
        keyword: keyword,
        tagIds: tagIds,
        projectType: projectType,
      );

      await writeJson(request, 200, {
        'results': results
            .map((r) => {
                  'user': r.user.toPublicJson(),
                  'profile': r.profile.toJson(),
                  'entries': r.entries.map((e) => e.toJson()).toList(),
                })
            .toList(),
      });
    } catch (e) {
      await writeError(request, e);
    }
  }

  List<int>? _parseTagIds(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.split(',').map((part) {
      final id = int.tryParse(part.trim());
      if (id == null) {
        throw ValidationException('Invalid tag id in tags: $part');
      }
      return id;
    }).toList();
  }

  ProjectType? _parseProjectType(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    for (final type in ProjectType.values) {
      if (type.name == raw) return type;
    }
    throw ValidationException('Invalid projectType: $raw');
  }
}

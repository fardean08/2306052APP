import 'dart:io';

import '../services/tag_service.dart';
import 'http_helpers.dart';

/// Exposes the shared tag list (NFR5) so the frontend can render tag
/// pickers for the FR1 search filter and the FR3 entry form.
class TagController {
  final TagService _tagService;

  TagController(this._tagService);

  /// GET /api/tags
  Future<void> getAllTags(HttpRequest request) async {
    try {
      final tags = await _tagService.getAllTags();
      await writeJson(request, 200, {
        'tags': tags.map((t) => t.toJson()).toList(),
      });
    } catch (e) {
      await writeError(request, e);
    }
  }
}

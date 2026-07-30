import '../models/tag.dart';
import '../repositories/tag_repository.dart';

/// Read access to the shared, extensible tag list (NFR5). The frontend
/// uses this to populate tag pickers for both the FR1 search filter and
/// the FR3 entry form — there is no create/edit endpoint in this
/// prototype, only seeded data.
class TagService {
  final TagRepository _tagRepository;

  TagService(this._tagRepository);

  Future<List<Tag>> getAllTags() => _tagRepository.getAll();
}

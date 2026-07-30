import '../data/json_store.dart';
import '../models/tag.dart';

/// The only place that translates between [Tag] and the JSON store's
/// `tags` collection. Tags are data (NFR5): new ones can be inserted
/// without a code change.
class TagRepository {
  static const _collection = 'tags';
  final JsonStore _store;

  TagRepository(this._store);

  Future<List<Tag>> getAll() async {
    return _store.read(_collection).map(Tag.fromJson).toList();
  }

  Future<Tag?> findById(int id) async {
    final tags = await getAll();
    for (final tag in tags) {
      if (tag.id == id) return tag;
    }
    return null;
  }

  Future<void> insert(Tag tag) async {
    final tags = await getAll();
    if (tags.any((t) => t.id == tag.id)) {
      throw StateError('Tag with id ${tag.id} already exists');
    }
    tags.add(tag);
    await _persist(tags);
  }

  Future<void> _persist(List<Tag> tags) async {
    await _store.write(_collection, tags.map((t) => t.toJson()).toList());
  }
}

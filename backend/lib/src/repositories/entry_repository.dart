import '../data/json_store.dart';
import '../models/entry.dart';

/// The only place that translates between [Entry] and the JSON store's
/// `entries` collection.
class EntryRepository {
  static const _collection = 'entries';
  final JsonStore _store;

  EntryRepository(this._store);

  Future<List<Entry>> getAll() async {
    return _store.read(_collection).map(Entry.fromJson).toList();
  }

  Future<Entry?> findById(String id) async {
    final entries = await getAll();
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<List<Entry>> findByUserId(String userId) async {
    final entries = await getAll();
    return entries.where((e) => e.userId == userId).toList();
  }

  Future<void> insert(Entry entry) async {
    final entries = await getAll();
    entries.add(entry);
    await _persist(entries);
  }

  Future<void> update(Entry entry) async {
    final entries = await getAll();
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) {
      throw StateError('Cannot update non-existent entry ${entry.id}');
    }
    entries[index] = entry;
    await _persist(entries);
  }

  Future<void> delete(String id) async {
    final entries = await getAll();
    final removed = entries.where((e) => e.id != id).toList();
    if (removed.length == entries.length) {
      throw StateError('Cannot delete non-existent entry $id');
    }
    await _persist(removed);
  }

  Future<void> _persist(List<Entry> entries) async {
    await _store.write(_collection, entries.map((e) => e.toJson()).toList());
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The single canonical JSON file acting as this app's data store.
/// Only the Repository layer is meant to touch this class directly.
///
/// The document is one JSON object with an array per entity type: `users`,
/// `staffProfiles`, `entries`, `tags`, `enquiries`. Writes are serialized
/// through an internal queue (the server is a single Dart isolate handling
/// requests concurrently via the event loop, so without this, two
/// overlapping writes could interleave and corrupt the file) and persisted
/// via write-temp-then-rename so a crash mid-write can't leave a half
/// written file behind.
class JsonStore {
  final File file;
  Map<String, dynamic> _data = _emptyDocument();
  Future<void> _queue = Future.value();

  JsonStore(this.file);

  static Map<String, dynamic> _emptyDocument() => {
        'users': <dynamic>[],
        'staffProfiles': <dynamic>[],
        'entries': <dynamic>[],
        'tags': <dynamic>[],
        'enquiries': <dynamic>[],
      };

  /// Loads the file into memory, creating it with empty collections if it
  /// does not yet exist.
  Future<void> load() async {
    if (!await file.exists()) {
      await file.create(recursive: true);
      _data = _emptyDocument();
      await _persist();
      return;
    }
    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      _data = _emptyDocument();
      return;
    }
    _data = jsonDecode(contents) as Map<String, dynamic>;
    for (final key in _emptyDocument().keys) {
      _data.putIfAbsent(key, () => <dynamic>[]);
    }
  }

  /// Returns a snapshot copy of [collectionName]'s raw JSON maps. Mutating
  /// the returned list/maps does not affect the store — call [write] to
  /// persist changes.
  List<Map<String, dynamic>> read(String collectionName) {
    final list = _data[collectionName] as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Replaces [collectionName] wholesale and persists to disk. Calls are
  /// serialized so concurrent repository writes cannot interleave.
  Future<void> write(
    String collectionName,
    List<Map<String, dynamic>> items,
  ) {
    final resultCompleter = Completer<void>();
    _queue = _queue.then((_) async {
      _data[collectionName] = items;
      await _persist();
    }).then((_) {
      resultCompleter.complete();
    }).catchError((Object e, StackTrace st) {
      resultCompleter.completeError(e, st);
    });
    return resultCompleter.future;
  }

  Future<void> _persist() async {
    final tmp = File('${file.path}.tmp');
    await tmp
        .writeAsString(const JsonEncoder.withIndent('  ').convert(_data));
    await tmp.rename(file.path);
  }
}

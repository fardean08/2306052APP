import '../data/json_store.dart';
import '../models/user.dart';

/// The only place that translates between [User] and the JSON store's
/// `users` collection. The Service layer never touches [JsonStore]
/// directly.
class UserRepository {
  static const _collection = 'users';
  final JsonStore _store;

  UserRepository(this._store);

  Future<List<User>> getAll() async {
    return _store.read(_collection).map(User.fromJson).toList();
  }

  Future<User?> findById(String id) async {
    final users = await getAll();
    for (final user in users) {
      if (user.id == id) return user;
    }
    return null;
  }

  Future<User?> findByEmail(String email) async {
    final users = await getAll();
    final normalized = email.trim().toLowerCase();
    for (final user in users) {
      if (user.email.toLowerCase() == normalized) return user;
    }
    return null;
  }

  Future<void> insert(User user) async {
    final users = await getAll();
    users.add(user);
    await _persist(users);
  }

  Future<void> update(User user) async {
    final users = await getAll();
    final index = users.indexWhere((u) => u.id == user.id);
    if (index == -1) {
      throw StateError('Cannot update non-existent user ${user.id}');
    }
    users[index] = user;
    await _persist(users);
  }

  Future<void> _persist(List<User> users) async {
    await _store.write(_collection, users.map((u) => u.toJson()).toList());
  }
}

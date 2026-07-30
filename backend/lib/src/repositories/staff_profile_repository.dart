import '../data/json_store.dart';
import '../models/staff_profile.dart';

/// The only place that translates between [StaffProfile] and the JSON
/// store's `staffProfiles` collection. One record per staff member (FR4),
/// keyed by [StaffProfile.userId].
class StaffProfileRepository {
  static const _collection = 'staffProfiles';
  final JsonStore _store;

  StaffProfileRepository(this._store);

  Future<List<StaffProfile>> getAll() async {
    return _store.read(_collection).map(StaffProfile.fromJson).toList();
  }

  Future<StaffProfile?> findByUserId(String userId) async {
    final profiles = await getAll();
    for (final profile in profiles) {
      if (profile.userId == userId) return profile;
    }
    return null;
  }

  Future<void> insert(StaffProfile profile) async {
    final profiles = await getAll();
    if (profiles.any((p) => p.userId == profile.userId)) {
      throw StateError(
        'Staff profile already exists for user ${profile.userId}',
      );
    }
    profiles.add(profile);
    await _persist(profiles);
  }

  Future<void> update(StaffProfile profile) async {
    final profiles = await getAll();
    final index = profiles.indexWhere((p) => p.userId == profile.userId);
    if (index == -1) {
      throw StateError(
        'Cannot update non-existent staff profile ${profile.userId}',
      );
    }
    profiles[index] = profile;
    await _persist(profiles);
  }

  Future<void> _persist(List<StaffProfile> profiles) async {
    await _store.write(
      _collection,
      profiles.map((p) => p.toJson()).toList(),
    );
  }
}

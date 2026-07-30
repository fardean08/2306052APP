import '../models/entry.dart';
import '../models/staff_profile.dart';
import '../models/user.dart';
import '../repositories/entry_repository.dart';
import '../repositories/staff_profile_repository.dart';
import '../repositories/tag_repository.dart';
import '../repositories/user_repository.dart';

/// One staff profile's match for a browse/search query: the owning
/// [user], their [profile], and all of their [entries] — enough for the
/// browse UI to render the summary card (name, status, tags, idea count)
/// without a second round trip per profile.
class StaffSearchResult {
  final User user;
  final StaffProfile profile;
  final List<Entry> entries;

  StaffSearchResult({
    required this.user,
    required this.profile,
    required this.entries,
  });
}

/// FR1: keyword + subject-tag search over staff profiles, combinable with
/// AND semantics. FR10: an additional optional project-type filter, also
/// combinable. A missing/empty filter matches everything; no matches
/// yields an empty list rather than an error.
class SearchService {
  final StaffProfileRepository _profileRepository;
  final UserRepository _userRepository;
  final EntryRepository _entryRepository;
  final TagRepository _tagRepository;

  SearchService(
    this._profileRepository,
    this._userRepository,
    this._entryRepository,
    this._tagRepository,
  );

  Future<List<StaffSearchResult>> searchStaff({
    String? keyword,
    List<int>? tagIds,
    ProjectType? projectType,
  }) async {
    final normalizedKeyword = (keyword ?? '').trim().toLowerCase();
    final tagFilter = (tagIds ?? const <int>[]).toSet();

    final profiles = await _profileRepository.getAll();
    final allEntries = await _entryRepository.getAll();
    final allUsers = await _userRepository.getAll();
    final allTags = await _tagRepository.getAll();

    final usersById = {for (final u in allUsers) u.id: u};
    final tagNamesById = {for (final t in allTags) t.id: t.name.toLowerCase()};

    final results = <StaffSearchResult>[];
    for (final profile in profiles) {
      final user = usersById[profile.userId];
      if (user == null) continue; // orphaned profile; skip defensively

      final entries =
          allEntries.where((e) => e.userId == profile.userId).toList();

      if (!_matchesKeyword(normalizedKeyword, user, entries, tagNamesById)) {
        continue;
      }
      if (!_matchesTags(tagFilter, entries)) continue;
      if (!_matchesProjectType(projectType, entries)) continue;

      results.add(
        StaffSearchResult(user: user, profile: profile, entries: entries),
      );
    }
    return results;
  }

  bool _matchesKeyword(
    String keyword,
    User user,
    List<Entry> entries,
    Map<int, String> tagNamesById,
  ) {
    if (keyword.isEmpty) return true;
    if (user.name.toLowerCase().contains(keyword)) return true;
    for (final entry in entries) {
      if (entry.title.toLowerCase().contains(keyword)) return true;
      for (final tagId in entry.tags) {
        final name = tagNamesById[tagId];
        if (name != null && name.contains(keyword)) return true;
      }
    }
    return false;
  }

  bool _matchesTags(Set<int> tagFilter, List<Entry> entries) {
    if (tagFilter.isEmpty) return true;
    return entries.any((e) => e.tags.any(tagFilter.contains));
  }

  bool _matchesProjectType(ProjectType? projectType, List<Entry> entries) {
    if (projectType == null) return true;
    return entries.any(
      (e) => e.type == EntryType.idea && e.projectType == projectType,
    );
  }
}

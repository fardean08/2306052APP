import 'dart:io';

import 'package:supervisor_finder_backend/src/data/json_store.dart';
import 'package:supervisor_finder_backend/src/models/entry.dart';
import 'package:supervisor_finder_backend/src/models/staff_profile.dart';
import 'package:supervisor_finder_backend/src/models/tag.dart';
import 'package:supervisor_finder_backend/src/models/user.dart';
import 'package:supervisor_finder_backend/src/repositories/entry_repository.dart';
import 'package:supervisor_finder_backend/src/repositories/staff_profile_repository.dart';
import 'package:supervisor_finder_backend/src/repositories/tag_repository.dart';
import 'package:supervisor_finder_backend/src/repositories/user_repository.dart';
import 'package:supervisor_finder_backend/src/services/search_service.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late UserRepository userRepository;
  late StaffProfileRepository profileRepository;
  late EntryRepository entryRepository;
  late SearchService searchService;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('search_service_test_');
    final store = JsonStore(File('${tempDir.path}/db.json'));
    await store.load();

    userRepository = UserRepository(store);
    profileRepository = StaffProfileRepository(store);
    entryRepository = EntryRepository(store);
    final tagRepository = TagRepository(store);
    searchService = SearchService(
      profileRepository,
      userRepository,
      entryRepository,
      tagRepository,
    );

    await tagRepository.insert(Tag(id: 1, name: 'Artificial Intelligence'));
    await tagRepository.insert(Tag(id: 2, name: 'Databases'));
    await tagRepository.insert(Tag(id: 3, name: 'Web Development'));
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<void> addStaff({
    required String id,
    required String name,
    required List<Entry> entries,
  }) async {
    final user = User(
      id: id,
      name: name,
      email: '$id@test.com',
      role: UserRole.staff,
      salt: 's',
      passwordHash: 'h',
    );
    await userRepository.insert(user);
    await profileRepository.insert(
      StaffProfile(userId: id, office: 'Room 1', lastUpdated: DateTime.now()),
    );
    for (final entry in entries) {
      await entryRepository.insert(entry);
    }
  }

  Entry makeEntry({
    required String id,
    required String userId,
    required EntryType type,
    required String title,
    required List<int> tags,
    ProjectType? projectType,
  }) {
    final now = DateTime.now();
    return Entry(
      id: id,
      userId: userId,
      type: type,
      title: title,
      tags: tags,
      projectType: projectType,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('FR1 keyword and tag search', () {
    setUp(() async {
      await addStaff(
        id: 'staff_ada',
        name: 'Dr. Ada Lovelace',
        entries: [
          makeEntry(
            id: 'e1',
            userId: 'staff_ada',
            type: EntryType.interest,
            title: 'Neural Networks for Vision',
            tags: [1],
          ),
        ],
      );
      await addStaff(
        id: 'staff_grace',
        name: 'Dr. Grace Hopper',
        entries: [
          makeEntry(
            id: 'e2',
            userId: 'staff_grace',
            type: EntryType.idea,
            title: 'Compiler Optimisation Techniques',
            tags: [2],
            projectType: ProjectType.researchBased,
          ),
        ],
      );
    });

    test('FR1: an empty query returns every staff profile', () async {
      final results = await searchService.searchStaff();
      expect(results, hasLength(2));
    });

    test('FR1: keyword matches staff name', () async {
      final results = await searchService.searchStaff(keyword: 'lovelace');
      expect(results, hasLength(1));
      expect(results.single.user.id, 'staff_ada');
    });

    test('FR1: keyword matches an entry title', () async {
      final results = await searchService.searchStaff(
        keyword: 'compiler optimisation',
      );
      expect(results, hasLength(1));
      expect(results.single.user.id, 'staff_grace');
    });

    test('FR1: keyword matches a tag name', () async {
      final results = await searchService.searchStaff(
        keyword: 'artificial intelligence',
      );
      expect(results, hasLength(1));
      expect(results.single.user.id, 'staff_ada');
    });

    test('FR1: a keyword with no matches returns an empty list', () async {
      final results = await searchService.searchStaff(
        keyword: 'quantum cryptography',
      );
      expect(results, isEmpty);
    });

    test('FR1: keyword and tag filters combine with AND semantics',
        () async {
      final results = await searchService.searchStaff(
        keyword: 'grace',
        tagIds: [1], // Ada's tag, not Grace's — combined filter excludes both.
      );
      expect(results, isEmpty);
    });

    test('FR1: tag filter alone narrows to profiles with that tag',
        () async {
      final results = await searchService.searchStaff(tagIds: [2]);
      expect(results, hasLength(1));
      expect(results.single.user.id, 'staff_grace');
    });
  });

  group('FR10 project type filter', () {
    setUp(() async {
      await addStaff(
        id: 'staff_impl',
        name: 'Dr. Impl Staff',
        entries: [
          makeEntry(
            id: 'e3',
            userId: 'staff_impl',
            type: EntryType.idea,
            title: 'Build a mobile app',
            tags: [3],
            projectType: ProjectType.implementationBased,
          ),
        ],
      );
      await addStaff(
        id: 'staff_res',
        name: 'Dr. Research Staff',
        entries: [
          makeEntry(
            id: 'e4',
            userId: 'staff_res',
            type: EntryType.idea,
            title: 'Study distributed consensus',
            tags: [3],
            projectType: ProjectType.researchBased,
          ),
        ],
      );
    });

    test('FR10: project type filter combines with the subject-tag filter',
        () async {
      final results = await searchService.searchStaff(
        tagIds: [3],
        projectType: ProjectType.implementationBased,
      );
      expect(results, hasLength(1));
      expect(results.single.user.id, 'staff_impl');
    });
  });

  group('NFR2 search performance', () {
    test('NFR2: search over ~100 profiles completes well under 1 second',
        () async {
      for (var i = 0; i < 100; i++) {
        await addStaff(
          id: 'staff_bulk_$i',
          name: 'Staff Member Number $i',
          entries: [
            makeEntry(
              id: 'entry_bulk_$i',
              userId: 'staff_bulk_$i',
              type: EntryType.interest,
              title: 'Research Topic $i',
              tags: [1],
            ),
          ],
        );
      }

      final stopwatch = Stopwatch()..start();
      final results = await searchService.searchStaff(keyword: 'research');
      stopwatch.stop();

      expect(results, hasLength(100));
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}

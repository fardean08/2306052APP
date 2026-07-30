import 'dart:io';

import 'package:supervisor_finder_backend/src/data/json_store.dart';
import 'package:supervisor_finder_backend/src/models/entry.dart';
import 'package:supervisor_finder_backend/src/models/enquiry.dart';
import 'package:supervisor_finder_backend/src/models/tag.dart';
import 'package:supervisor_finder_backend/src/models/user.dart';
import 'package:supervisor_finder_backend/src/repositories/entry_repository.dart';
import 'package:supervisor_finder_backend/src/repositories/enquiry_repository.dart';
import 'package:supervisor_finder_backend/src/repositories/tag_repository.dart';
import 'package:supervisor_finder_backend/src/services/app_exceptions.dart';
import 'package:supervisor_finder_backend/src/services/entry_service.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late EntryRepository entryRepository;
  late EnquiryRepository enquiryRepository;
  late EntryService entryService;
  late User owner;
  late User otherStaff;
  late User student;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('entry_service_test_');
    final store = JsonStore(File('${tempDir.path}/db.json'));
    await store.load();

    final tagRepository = TagRepository(store);
    for (var id = 1; id <= 6; id++) {
      await tagRepository.insert(Tag(id: id, name: 'Tag $id'));
    }

    entryRepository = EntryRepository(store);
    enquiryRepository = EnquiryRepository(store);
    entryService =
        EntryService(entryRepository, enquiryRepository, tagRepository);

    owner = User(
      id: 'staff_owner',
      name: 'Owner Staff',
      email: 'owner@test.com',
      role: UserRole.staff,
      salt: 's',
      passwordHash: 'h',
    );
    otherStaff = User(
      id: 'staff_other',
      name: 'Other Staff',
      email: 'other@test.com',
      role: UserRole.staff,
      salt: 's',
      passwordHash: 'h',
    );
    student = User(
      id: 'student_1',
      name: 'Student One',
      email: 'student@test.com',
      role: UserRole.student,
      salt: 's',
      passwordHash: 'h',
    );
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<Entry> createValidEntry() {
    return entryService.createEntry(
      actingUser: owner,
      type: EntryType.interest,
      title: 'A valid title',
      tags: [1],
    );
  }

  group('FR3 title length boundary', () {
    test('FR3: title of 2 characters is rejected', () async {
      expect(
        () => entryService.createEntry(
          actingUser: owner,
          type: EntryType.interest,
          title: 'ab',
          tags: [1],
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('FR3: title of 3 characters is accepted', () async {
      final entry = await entryService.createEntry(
        actingUser: owner,
        type: EntryType.interest,
        title: 'abc',
        tags: [1],
      );
      expect(entry.title, 'abc');
    });

    test('FR3: title of 80 characters is accepted', () async {
      final title = 'a' * 80;
      final entry = await entryService.createEntry(
        actingUser: owner,
        type: EntryType.interest,
        title: title,
        tags: [1],
      );
      expect(entry.title.length, 80);
    });

    test('FR3: title of 81 characters is rejected', () async {
      final title = 'a' * 81;
      expect(
        () => entryService.createEntry(
          actingUser: owner,
          type: EntryType.interest,
          title: title,
          tags: [1],
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('FR3 tag count boundary', () {
    test('FR3: 0 tags is rejected', () async {
      expect(
        () => entryService.createEntry(
          actingUser: owner,
          type: EntryType.interest,
          title: 'Valid title',
          tags: [],
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('FR3: 1 tag is accepted', () async {
      final entry = await entryService.createEntry(
        actingUser: owner,
        type: EntryType.interest,
        title: 'Valid title',
        tags: [1],
      );
      expect(entry.tags, [1]);
    });

    test('FR3: 5 tags is accepted', () async {
      final entry = await entryService.createEntry(
        actingUser: owner,
        type: EntryType.interest,
        title: 'Valid title',
        tags: [1, 2, 3, 4, 5],
      );
      expect(entry.tags.length, 5);
    });

    test('FR3: 6 tags is rejected', () async {
      expect(
        () => entryService.createEntry(
          actingUser: owner,
          type: EntryType.interest,
          title: 'Valid title',
          tags: [1, 2, 3, 4, 5, 6],
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('FR3 description length boundary', () {
    test('FR3: description of 300 characters is accepted', () async {
      final description = 'd' * 300;
      final entry = await entryService.createEntry(
        actingUser: owner,
        type: EntryType.interest,
        title: 'Valid title',
        description: description,
        tags: [1],
      );
      expect(entry.description!.length, 300);
    });

    test('FR3: description of 301 characters is rejected', () async {
      final description = 'd' * 301;
      expect(
        () => entryService.createEntry(
          actingUser: owner,
          type: EntryType.interest,
          title: 'Valid title',
          description: description,
          tags: [1],
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('FR6 URL validation', () {
    test('FR6: a well-formed https URL is accepted on an idea entry',
        () async {
      final entry = await entryService.createEntry(
        actingUser: owner,
        type: EntryType.idea,
        title: 'Valid idea',
        tags: [1],
        linkUrl: 'https://example.com/project',
      );
      expect(entry.linkUrl, 'https://example.com/project');
    });

    test('FR6: a malformed URL is rejected', () async {
      expect(
        () => entryService.createEntry(
          actingUser: owner,
          type: EntryType.idea,
          title: 'Valid idea',
          tags: [1],
          linkUrl: 'not a url',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('FR6: a non-http(s) scheme is rejected', () async {
      expect(
        () => entryService.createEntry(
          actingUser: owner,
          type: EntryType.idea,
          title: 'Valid idea',
          tags: [1],
          linkUrl: 'ftp://example.com/file',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('NFR3 ownership rejection', () {
    test('NFR3: one staff member cannot update another staff member\'s entry',
        () async {
      final entry = await createValidEntry();
      expect(
        () => entryService.updateEntry(
          actingUser: otherStaff,
          entryId: entry.id,
          title: 'Hijacked title',
        ),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('NFR3: one staff member cannot delete another staff member\'s entry',
        () async {
      final entry = await createValidEntry();
      expect(
        () => entryService.deleteEntry(
          actingUser: otherStaff,
          entryId: entry.id,
        ),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('NFR3: only staff may create entries', () async {
      expect(
        () => entryService.createEntry(
          actingUser: student,
          type: EntryType.interest,
          title: 'Valid title',
          tags: [1],
        ),
        throwsA(isA<ForbiddenException>()),
      );
    });
  });

  group('FR7 delete-with-active-enquiry guard', () {
    test(
        'FR7: deleting an entry with an active enquiry requires confirmation',
        () async {
      final entry = await createValidEntry();
      await enquiryRepository.insert(
        Enquiry(
          id: 'enq_1',
          studentId: student.id,
          entryId: entry.id,
          message: 'x' * 20,
          sentAt: DateTime.now(),
        ),
      );

      expect(
        () => entryService.deleteEntry(actingUser: owner, entryId: entry.id),
        throwsA(isA<ConflictException>()),
      );

      await entryService.deleteEntry(
        actingUser: owner,
        entryId: entry.id,
        confirm: true,
      );
      expect(await entryRepository.findById(entry.id), isNull);
    });
  });
}

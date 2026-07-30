import 'dart:io';

import 'package:supervisor_finder_backend/src/data/json_store.dart';
import 'package:supervisor_finder_backend/src/models/entry.dart';
import 'package:supervisor_finder_backend/src/models/user.dart';
import 'package:supervisor_finder_backend/src/repositories/entry_repository.dart';
import 'package:supervisor_finder_backend/src/repositories/enquiry_repository.dart';
import 'package:supervisor_finder_backend/src/services/app_exceptions.dart';
import 'package:supervisor_finder_backend/src/services/enquiry_service.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late EntryRepository entryRepository;
  late EnquiryService enquiryService;
  late User staffA;
  late User staffB;
  late User student;
  late Entry entryA;
  late Entry entryB;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('enquiry_service_test_');
    final store = JsonStore(File('${tempDir.path}/db.json'));
    await store.load();

    entryRepository = EntryRepository(store);
    final enquiryRepository = EnquiryRepository(store);
    enquiryService = EnquiryService(enquiryRepository, entryRepository);

    staffA = User(
      id: 'staff_a',
      name: 'Staff A',
      email: 'a@test.com',
      role: UserRole.staff,
      salt: 's',
      passwordHash: 'h',
    );
    staffB = User(
      id: 'staff_b',
      name: 'Staff B',
      email: 'b@test.com',
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

    final now = DateTime.now();
    entryA = Entry(
      id: 'entry_a',
      userId: staffA.id,
      type: EntryType.idea,
      title: 'Staff A idea',
      tags: const [1],
      createdAt: now,
      updatedAt: now,
    );
    entryB = Entry(
      id: 'entry_b',
      userId: staffB.id,
      type: EntryType.idea,
      title: 'Staff B idea',
      tags: const [1],
      createdAt: now,
      updatedAt: now,
    );
    await entryRepository.insert(entryA);
    await entryRepository.insert(entryB);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('FR9 message length boundary', () {
    test('FR9: a message of 19 characters is rejected', () async {
      expect(
        () => enquiryService.sendEnquiry(
          actingUser: student,
          entryId: entryA.id,
          message: 'x' * 19,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('FR9: a message of 20 characters is accepted', () async {
      final enquiry = await enquiryService.sendEnquiry(
        actingUser: student,
        entryId: entryA.id,
        message: 'x' * 20,
      );
      expect(enquiry.message.length, 20);
    });
  });

  group('NFR4 enquiry inbox scoping', () {
    test(
        "NFR4: a staff member's inbox never contains another staff "
        'member\'s enquiries', () async {
      await enquiryService.sendEnquiry(
        actingUser: student,
        entryId: entryA.id,
        message: 'Message for staff A about their idea.',
      );
      await enquiryService.sendEnquiry(
        actingUser: student,
        entryId: entryB.id,
        message: 'Message for staff B about their idea.',
      );

      final inboxA = await enquiryService.getInboxForStaff(staffA);
      final inboxB = await enquiryService.getInboxForStaff(staffB);

      expect(inboxA, hasLength(1));
      expect(inboxA.single.entryId, entryA.id);
      expect(inboxB, hasLength(1));
      expect(inboxB.single.entryId, entryB.id);
    });

    test('NFR4: a staff member with no enquiries sees an empty inbox',
        () async {
      final inboxB = await enquiryService.getInboxForStaff(staffB);
      expect(inboxB, isEmpty);
    });
  });
}

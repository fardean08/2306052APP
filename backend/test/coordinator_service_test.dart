import 'dart:io';

import 'package:supervisor_finder_backend/src/data/json_store.dart';
import 'package:supervisor_finder_backend/src/models/entry.dart';
import 'package:supervisor_finder_backend/src/models/staff_profile.dart';
import 'package:supervisor_finder_backend/src/models/user.dart';
import 'package:supervisor_finder_backend/src/repositories/entry_repository.dart';
import 'package:supervisor_finder_backend/src/repositories/staff_profile_repository.dart';
import 'package:supervisor_finder_backend/src/repositories/user_repository.dart';
import 'package:supervisor_finder_backend/src/services/app_exceptions.dart';
import 'package:supervisor_finder_backend/src/services/coordinator_service.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late CoordinatorService coordinatorService;
  late User coordinator;
  late User staffOld;
  late User staffMid;
  late User staffNoEntries;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('coordinator_service_test_');
    final store = JsonStore(File('${tempDir.path}/db.json'));
    await store.load();

    final userRepository = UserRepository(store);
    final profileRepository = StaffProfileRepository(store);
    final entryRepository = EntryRepository(store);
    coordinatorService = CoordinatorService(
      profileRepository,
      userRepository,
      entryRepository,
    );

    coordinator = User(
      id: 'coordinator_1',
      name: 'Coordinator One',
      email: 'coordinator@test.com',
      role: UserRole.coordinator,
      salt: 's',
      passwordHash: 'h',
    );

    final now = DateTime.now();

    // Most stale overall: both the profile and its only entry are ~300
    // days old, so most recent activity is ~300 days ago.
    staffOld = User(
      id: 'staff_old',
      name: 'Staff Old',
      email: 'old@test.com',
      role: UserRole.staff,
      salt: 's',
      passwordHash: 'h',
    );
    final oldTimestamp = now.subtract(const Duration(days: 300));
    await userRepository.insert(staffOld);
    await profileRepository.insert(
      StaffProfile(
        userId: staffOld.id,
        office: 'Room A',
        lastUpdated: oldTimestamp,
      ),
    );
    await entryRepository.insert(
      Entry(
        id: 'entry_old',
        userId: staffOld.id,
        type: EntryType.interest,
        title: 'An old interest',
        tags: const [1],
        createdAt: oldTimestamp,
        updatedAt: oldTimestamp,
      ),
    );

    // Zero entries: profile last touched ~50 days ago, no entries at all.
    staffNoEntries = User(
      id: 'staff_no_entries',
      name: 'Staff No Entries',
      email: 'noentries@test.com',
      role: UserRole.staff,
      salt: 's',
      passwordHash: 'h',
    );
    await userRepository.insert(staffNoEntries);
    await profileRepository.insert(
      StaffProfile(
        userId: staffNoEntries.id,
        office: 'Room B',
        lastUpdated: now.subtract(const Duration(days: 50)),
      ),
    );

    // Most recently active: profile itself is ~100 days old, but one of
    // its entries was updated only ~10 days ago, so most recent activity
    // should be ~10 days ago, not ~100.
    staffMid = User(
      id: 'staff_mid',
      name: 'Staff Mid',
      email: 'mid@test.com',
      role: UserRole.staff,
      salt: 's',
      passwordHash: 'h',
    );
    await userRepository.insert(staffMid);
    await profileRepository.insert(
      StaffProfile(
        userId: staffMid.id,
        office: 'Room C',
        lastUpdated: now.subtract(const Duration(days: 100)),
      ),
    );
    await entryRepository.insert(
      Entry(
        id: 'entry_mid',
        userId: staffMid.id,
        type: EntryType.idea,
        title: 'A recently updated idea',
        tags: const [1],
        createdAt: now.subtract(const Duration(days: 100)),
        updatedAt: now.subtract(const Duration(days: 10)),
      ),
    );
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('FR8 staleness report', () {
    test(
        'FR8: rows are sorted oldest-first by most recent activity across '
        'profile and entry timestamps', () async {
      final rows =
          await coordinatorService.getStalenessReport(actingUser: coordinator);

      expect(rows.map((r) => r.user.id).toList(), [
        staffOld.id,
        staffNoEntries.id,
        staffMid.id,
      ]);

      for (var i = 0; i < rows.length - 1; i++) {
        expect(
          rows[i].mostRecentActivity.isBefore(rows[i + 1].mostRecentActivity) ||
              rows[i]
                  .mostRecentActivity
                  .isAtSameMomentAs(rows[i + 1].mostRecentActivity),
          isTrue,
        );
      }
    });

    test(
        'FR8: a staff member with zero entries is flagged as "no entries", '
        'not omitted', () async {
      final rows =
          await coordinatorService.getStalenessReport(actingUser: coordinator);

      expect(rows, hasLength(3));
      final noEntriesRow =
          rows.firstWhere((r) => r.user.id == staffNoEntries.id);
      expect(noEntriesRow.hasNoEntries, isTrue);

      final oldRow = rows.firstWhere((r) => r.user.id == staffOld.id);
      expect(oldRow.hasNoEntries, isFalse);
    });

    test('FR8: only a coordinator may view the staleness report', () async {
      expect(
        () => coordinatorService.getStalenessReport(actingUser: staffOld),
        throwsA(isA<ForbiddenException>()),
      );
    });
  });
}

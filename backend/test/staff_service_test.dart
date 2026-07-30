import 'dart:io';

import 'package:supervisor_finder_backend/src/data/json_store.dart';
import 'package:supervisor_finder_backend/src/models/staff_profile.dart';
import 'package:supervisor_finder_backend/src/models/user.dart';
import 'package:supervisor_finder_backend/src/repositories/staff_profile_repository.dart';
import 'package:supervisor_finder_backend/src/repositories/user_repository.dart';
import 'package:supervisor_finder_backend/src/services/app_exceptions.dart';
import 'package:supervisor_finder_backend/src/services/staff_service.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late StaffProfileRepository profileRepository;
  late StaffService staffService;
  late User owner;
  late User otherStaff;
  late User coordinator;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('staff_service_test_');
    final store = JsonStore(File('${tempDir.path}/db.json'));
    await store.load();

    profileRepository = StaffProfileRepository(store);
    final userRepository = UserRepository(store);
    staffService = StaffService(profileRepository, userRepository);

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
    coordinator = User(
      id: 'coordinator_1',
      name: 'Coordinator One',
      email: 'coordinator@test.com',
      role: UserRole.coordinator,
      salt: 's',
      passwordHash: 'h',
    );

    await userRepository.insert(owner);
    await userRepository.insert(otherStaff);
    await userRepository.insert(coordinator);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('FR2 availability', () {
    test('FR2: a newly created profile defaults to open', () async {
      final profile = await staffService.createProfile(
        userId: owner.id,
        office: 'Room 1',
      );
      expect(profile.status, AvailabilityStatus.open);
    });

    test('FR2: the owner can change their own availability status',
        () async {
      await staffService.createProfile(userId: owner.id, office: 'Room 1');

      final updated = await staffService.setAvailability(
        actingUser: owner,
        targetUserId: owner.id,
        status: AvailabilityStatus.limited,
      );

      expect(updated.status, AvailabilityStatus.limited);
      final reloaded = await profileRepository.findByUserId(owner.id);
      expect(reloaded!.status, AvailabilityStatus.limited);
    });
  });

  group('NFR3 ownership on availability changes', () {
    test('NFR3: a coordinator may change another staff member\'s availability',
        () async {
      await staffService.createProfile(userId: owner.id, office: 'Room 1');

      final updated = await staffService.setAvailability(
        actingUser: coordinator,
        targetUserId: owner.id,
        status: AvailabilityStatus.closed,
      );

      expect(updated.status, AvailabilityStatus.closed);
    });

    test(
        'NFR3: one staff member cannot change another staff member\'s '
        'availability', () async {
      await staffService.createProfile(userId: owner.id, office: 'Room 1');

      expect(
        () => staffService.setAvailability(
          actingUser: otherStaff,
          targetUserId: owner.id,
          status: AvailabilityStatus.closed,
        ),
        throwsA(isA<ForbiddenException>()),
      );

      final reloaded = await profileRepository.findByUserId(owner.id);
      expect(reloaded!.status, AvailabilityStatus.open);
    });
  });
}

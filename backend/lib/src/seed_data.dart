import 'models/entry.dart';
import 'models/staff_profile.dart';
import 'models/tag.dart';
import 'models/user.dart';
import 'repositories/entry_repository.dart';
import 'repositories/staff_profile_repository.dart';
import 'repositories/tag_repository.dart';
import 'repositories/user_repository.dart';
import 'services/auth_service.dart';

/// Seeds demo data: 8 subject tags, 3 staff (with varying entries — one
/// deliberately stale so FR8's report has something to show, one with
/// zero entries for FR8's "no entries" edge case), 1 student, and 1
/// coordinator. Every seeded account uses the password "password123".
///
/// Idempotent: does nothing if the store already has users, so restarting
/// the server against an existing data file never duplicates seed data.
Future<void> seedDatabase({
  required UserRepository userRepository,
  required StaffProfileRepository staffProfileRepository,
  required EntryRepository entryRepository,
  required TagRepository tagRepository,
}) async {
  final existingUsers = await userRepository.getAll();
  if (existingUsers.isNotEmpty) return;

  const seedPassword = 'password123';

  final tags = [
    Tag(id: 1, name: 'Artificial Intelligence'),
    Tag(id: 2, name: 'Web Development'),
    Tag(id: 3, name: 'Mobile Development'),
    Tag(id: 4, name: 'Databases'),
    Tag(id: 5, name: 'Networks & Security'),
    Tag(id: 6, name: 'Cloud Computing'),
    Tag(id: 7, name: 'Human-Computer Interaction'),
    Tag(id: 8, name: 'Data Science'),
  ];
  for (final tag in tags) {
    await tagRepository.insert(tag);
  }

  Future<User> createUser(String id, String name, String email, UserRole role) async {
    final salt = AuthService.generateSalt();
    final user = User(
      id: id,
      name: name,
      email: email,
      role: role,
      salt: salt,
      passwordHash: AuthService.hashPassword(seedPassword, salt),
    );
    await userRepository.insert(user);
    return user;
  }

  final alice = await createUser(
    'staff_alice',
    'Dr. Alice Ng',
    'alice.ng@university.ac.uk',
    UserRole.staff,
  );
  final bob = await createUser(
    'staff_bob',
    'Dr. Bob Smith',
    'bob.smith@university.ac.uk',
    UserRole.staff,
  );
  final carol = await createUser(
    'staff_carol',
    'Dr. Carol Jones',
    'carol.jones@university.ac.uk',
    UserRole.staff,
  );
  await createUser(
    'student_dan',
    'Dan Patel',
    'dan.patel@university.ac.uk',
    UserRole.student,
  );
  await createUser(
    'coordinator_eve',
    'Eve Thompson',
    'eve.thompson@university.ac.uk',
    UserRole.coordinator,
  );

  final now = DateTime.now();
  final longAgo = now.subtract(const Duration(days: 260));

  // Alice: fresh profile and entries — the "healthy" case.
  await staffProfileRepository.insert(
    StaffProfile(
      userId: alice.id,
      office: 'Room 2.14, Ada Lovelace Building',
      status: AvailabilityStatus.open,
      lastUpdated: now,
    ),
  );
  await entryRepository.insert(
    Entry(
      id: 'entry_alice_1',
      userId: alice.id,
      type: EntryType.interest,
      title: 'Machine Learning for Healthcare Diagnostics',
      description:
          'Applying supervised learning to medical imaging and early '
          'diagnosis support.',
      tags: [1, 8],
      createdAt: now,
      updatedAt: now,
    ),
  );
  await entryRepository.insert(
    Entry(
      id: 'entry_alice_2',
      userId: alice.id,
      type: EntryType.idea,
      title: 'Recommender System for Course Selection',
      description:
          'Build a content-based recommender to help students choose '
          'optional modules based on past performance and interests.',
      tags: [1, 2],
      projectType: ProjectType.implementationBased,
      linkUrl: 'https://github.com/example/course-recommender',
      createdAt: now,
      updatedAt: now,
    ),
  );

  // Bob: deliberately stale — both the profile and its entries were last
  // touched ~260 days ago, so FR8's report should surface him near the top
  // once sorted oldest-first.
  await staffProfileRepository.insert(
    StaffProfile(
      userId: bob.id,
      office: 'Room 3.02, Turing Building',
      status: AvailabilityStatus.limited,
      lastUpdated: longAgo,
    ),
  );
  await entryRepository.insert(
    Entry(
      id: 'entry_bob_1',
      userId: bob.id,
      type: EntryType.interest,
      title: 'Distributed Systems and Consistency Models',
      description:
          'Consensus protocols, CRDTs, and trade-offs between consistency '
          'and availability in distributed data stores.',
      tags: [4, 6],
      createdAt: longAgo,
      updatedAt: longAgo,
    ),
  );
  await entryRepository.insert(
    Entry(
      id: 'entry_bob_2',
      userId: bob.id,
      type: EntryType.idea,
      title: 'Building a Fault-Tolerant Key-Value Store',
      description:
          'Design and implement a replicated key-value store that '
          'tolerates node failures without losing writes.',
      tags: [4, 5],
      projectType: ProjectType.researchBased,
      createdAt: longAgo,
      updatedAt: longAgo,
    ),
  );

  // Carol: zero entries — FR8's "no entries" edge case, flagged rather
  // than omitted from the report.
  await staffProfileRepository.insert(
    StaffProfile(
      userId: carol.id,
      office: 'Room 1.08, Hopper Building',
      status: AvailabilityStatus.closed,
      lastUpdated: now,
    ),
  );
}

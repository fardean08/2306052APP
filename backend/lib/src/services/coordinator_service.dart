import '../models/staff_profile.dart';
import '../models/user.dart';
import '../repositories/entry_repository.dart';
import '../repositories/staff_profile_repository.dart';
import '../repositories/user_repository.dart';
import 'app_exceptions.dart';

/// One row of the FR8 staleness report: a staff member, their profile,
/// the most recent timestamp of *any* activity on their profile (the
/// later of the profile's own [StaffProfile.lastUpdated] and the newest
/// `updatedAt` among their entries), and whether they currently have zero
/// entries at all.
class StaffReportRow {
  final User user;
  final StaffProfile profile;
  final DateTime mostRecentActivity;
  final bool hasNoEntries;

  StaffReportRow({
    required this.user,
    required this.profile,
    required this.mostRecentActivity,
    required this.hasNoEntries,
  });
}

/// FR8: a coordinator-only report of every staff profile, sorted
/// oldest-first by most recent activity, so the most stale profiles surface
/// at the top. Staff with zero entries are flagged, not omitted — an empty
/// profile is itself the most stale case a coordinator needs to see.
class CoordinatorService {
  final StaffProfileRepository _profileRepository;
  final UserRepository _userRepository;
  final EntryRepository _entryRepository;

  CoordinatorService(
    this._profileRepository,
    this._userRepository,
    this._entryRepository,
  );

  Future<List<StaffReportRow>> getStalenessReport({
    required User actingUser,
  }) async {
    _requireCoordinator(actingUser);

    final profiles = await _profileRepository.getAll();
    final allUsers = await _userRepository.getAll();
    final allEntries = await _entryRepository.getAll();
    final usersById = {for (final u in allUsers) u.id: u};

    final rows = <StaffReportRow>[];
    for (final profile in profiles) {
      final user = usersById[profile.userId];
      if (user == null) continue; // orphaned profile; skip defensively

      final myEntries =
          allEntries.where((e) => e.userId == profile.userId).toList();

      var mostRecent = profile.lastUpdated;
      for (final entry in myEntries) {
        if (entry.updatedAt.isAfter(mostRecent)) {
          mostRecent = entry.updatedAt;
        }
      }

      rows.add(
        StaffReportRow(
          user: user,
          profile: profile,
          mostRecentActivity: mostRecent,
          hasNoEntries: myEntries.isEmpty,
        ),
      );
    }

    rows.sort(
      (a, b) => a.mostRecentActivity.compareTo(b.mostRecentActivity),
    );
    return rows;
  }

  void _requireCoordinator(User actingUser) {
    if (actingUser.role != UserRole.coordinator) {
      throw ForbiddenException(
        'Only a coordinator may view the staleness report',
      );
    }
  }
}

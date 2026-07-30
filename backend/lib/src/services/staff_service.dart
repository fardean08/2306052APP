import '../models/staff_profile.dart';
import '../models/user.dart';
import '../repositories/staff_profile_repository.dart';
import 'app_exceptions.dart';

/// Business rules for staff profiles: reading the canonical profile record
/// (FR4) and changing supervision availability (FR2).
class StaffService {
  final StaffProfileRepository _profileRepository;

  StaffService(this._profileRepository);

  Future<List<StaffProfile>> getAllProfiles() => _profileRepository.getAll();

  Future<StaffProfile> getProfile(String userId) async {
    final profile = await _profileRepository.findByUserId(userId);
    if (profile == null) {
      throw NotFoundException('No staff profile for user $userId');
    }
    return profile;
  }

  /// Creates the one canonical profile for a newly-seeded staff member.
  /// Defaults to [AvailabilityStatus.open] (FR2) unless overridden.
  Future<StaffProfile> createProfile({
    required String userId,
    required String office,
    AvailabilityStatus status = AvailabilityStatus.open,
    DateTime? lastUpdated,
  }) async {
    final profile = StaffProfile(
      userId: userId,
      office: office,
      status: status,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
    await _profileRepository.insert(profile);
    return profile;
  }

  /// FR2: sets Open/Limited/Closed. NFR3: only the profile owner or a
  /// coordinator may do this — enforced here, not just in the UI.
  Future<StaffProfile> setAvailability({
    required User actingUser,
    required String targetUserId,
    required AvailabilityStatus status,
  }) async {
    _requireOwnerOrCoordinator(actingUser, targetUserId);
    final profile = await getProfile(targetUserId);
    final updated = profile.copyWith(
      status: status,
      lastUpdated: DateTime.now(),
    );
    await _profileRepository.update(updated);
    return updated;
  }

  void _requireOwnerOrCoordinator(User actingUser, String targetUserId) {
    final isOwner = actingUser.id == targetUserId;
    final isCoordinator = actingUser.role == UserRole.coordinator;
    if (!isOwner && !isCoordinator) {
      throw ForbiddenException(
        'Only the profile owner or a coordinator may change availability',
      );
    }
  }
}

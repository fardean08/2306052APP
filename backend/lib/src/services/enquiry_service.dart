import 'dart:math';

import '../models/enquiry.dart';
import '../models/user.dart';
import '../repositories/entry_repository.dart';
import '../repositories/enquiry_repository.dart';
import 'app_exceptions.dart';

/// Business rules for enquiries: FR9's send flow (with its message-length
/// floor) and NFR4's strict per-staff inbox scoping.
class EnquiryService {
  static const minMessageLength = 20;

  final EnquiryRepository _enquiryRepository;
  final EntryRepository _entryRepository;
  final Random _idRandom = Random.secure();

  EnquiryService(this._enquiryRepository, this._entryRepository);

  /// FR9: an authenticated student sends a message about a specific entry.
  /// The message is linked to that entry and to the sending student, and
  /// becomes visible only to the entry's owning staff member (NFR4).
  Future<Enquiry> sendEnquiry({
    required User actingUser,
    required String entryId,
    required String message,
  }) async {
    _requireStudent(actingUser);

    final entry = await _entryRepository.findById(entryId);
    if (entry == null) {
      throw NotFoundException('No entry with id $entryId');
    }

    final trimmed = message.trim();
    if (trimmed.length < minMessageLength) {
      throw ValidationException(
        'Message must be at least $minMessageLength characters',
      );
    }

    final enquiry = Enquiry(
      id: _generateId(),
      studentId: actingUser.id,
      entryId: entryId,
      message: trimmed,
      sentAt: DateTime.now(),
    );
    await _enquiryRepository.insert(enquiry);
    return enquiry;
  }

  /// NFR4: returns only enquiries sent about [actingUser]'s own entries.
  /// A staff member's inbox must never contain another staff member's
  /// enquiries — this is what enforces that, by construction (the result
  /// is filtered down from every enquiry to only those whose entry is
  /// owned by the caller).
  Future<List<Enquiry>> getInboxForStaff(User actingUser) async {
    _requireStaff(actingUser);

    final myEntries = await _entryRepository.findByUserId(actingUser.id);
    final myEntryIds = myEntries.map((e) => e.id).toSet();

    final allEnquiries = await _enquiryRepository.getAll();
    return allEnquiries.where((e) => myEntryIds.contains(e.entryId)).toList();
  }

  void _requireStudent(User actingUser) {
    if (actingUser.role != UserRole.student) {
      throw ForbiddenException('Only students may send enquiries');
    }
  }

  void _requireStaff(User actingUser) {
    if (actingUser.role != UserRole.staff) {
      throw ForbiddenException('Only staff may view an enquiry inbox');
    }
  }

  String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final suffix = _idRandom.nextInt(1 << 32);
    return 'enquiry_${timestamp}_$suffix';
  }
}

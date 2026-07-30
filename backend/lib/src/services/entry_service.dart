import 'dart:math';

import '../models/entry.dart';
import '../models/user.dart';
import '../repositories/entry_repository.dart';
import '../repositories/enquiry_repository.dart';
import '../repositories/tag_repository.dart';
import 'app_exceptions.dart';

/// Business rules for areas of interest / project ideas: FR3's structural
/// validation, FR6's URL validation, and FR7's ownership + safe-delete
/// rules.
class EntryService {
  static const minTitleLength = 3;
  static const maxTitleLength = 80;
  static const maxDescriptionLength = 300;
  static const minTagCount = 1;
  static const maxTagCount = 5;

  final EntryRepository _entryRepository;
  final EnquiryRepository _enquiryRepository;
  final TagRepository _tagRepository;
  final Random _idRandom = Random.secure();

  EntryService(
    this._entryRepository,
    this._enquiryRepository,
    this._tagRepository,
  );

  Future<List<Entry>> getEntriesForStaff(String userId) =>
      _entryRepository.findByUserId(userId);

  Future<Entry> getEntry(String id) async {
    final entry = await _entryRepository.findById(id);
    if (entry == null) {
      throw NotFoundException('No entry with id $id');
    }
    return entry;
  }

  /// FR7: only authenticated staff may create entries, and always as
  /// themselves (no creating on another staff member's behalf).
  Future<Entry> createEntry({
    required User actingUser,
    required EntryType type,
    required String title,
    String? description,
    required List<int> tags,
    ProjectType? projectType,
    String? linkUrl,
  }) async {
    _requireStaff(actingUser);
    final normalizedDescription = _normalizeDescription(description);
    final normalizedLinkUrl =
        type == EntryType.idea ? _normalizeLinkUrl(linkUrl) : null;
    await _validateFields(
      title: title,
      description: normalizedDescription,
      tags: tags,
      linkUrl: normalizedLinkUrl,
    );

    final now = DateTime.now();
    final entry = Entry(
      id: _generateId(),
      userId: actingUser.id,
      type: type,
      title: title.trim(),
      description: normalizedDescription,
      tags: List<int>.from(tags),
      projectType: type == EntryType.idea ? projectType : null,
      linkUrl: normalizedLinkUrl,
      createdAt: now,
      updatedAt: now,
    );
    await _entryRepository.insert(entry);
    return entry;
  }

  /// FR7: ownership is enforced here (server-side), not just hidden in the
  /// UI — any staff member calling this for another staff member's entry
  /// is rejected regardless of what the client sent.
  Future<Entry> updateEntry({
    required User actingUser,
    required String entryId,
    String? title,
    String? description,
    List<int>? tags,
    ProjectType? projectType,
    String? linkUrl,
  }) async {
    final entry = await getEntry(entryId);
    _requireOwner(actingUser, entry.userId);

    final newTitle = title ?? entry.title;
    final newDescription = description == null
        ? entry.description
        : _normalizeDescription(description);
    final newTags = tags ?? entry.tags;
    final newProjectType =
        entry.type == EntryType.idea ? (projectType ?? entry.projectType) : null;
    final newLinkUrl = entry.type == EntryType.idea
        ? (linkUrl == null ? entry.linkUrl : _normalizeLinkUrl(linkUrl))
        : null;

    await _validateFields(
      title: newTitle,
      description: newDescription,
      tags: newTags,
      linkUrl: newLinkUrl,
    );

    final updated = entry.copyWith(
      title: newTitle.trim(),
      description: newDescription,
      clearDescription: newDescription == null,
      tags: List<int>.from(newTags),
      projectType: newProjectType,
      clearProjectType: newProjectType == null,
      linkUrl: newLinkUrl,
      clearLinkUrl: newLinkUrl == null,
      updatedAt: DateTime.now(),
    );
    await _entryRepository.update(updated);
    return updated;
  }

  /// FR7: deleting an entry with an active enquiry against it requires
  /// explicit confirmation rather than silently orphaning the enquiry.
  /// Callers should first call without [confirm], show the count from the
  /// resulting [ConflictException] to the user, then retry with
  /// `confirm: true`.
  Future<void> deleteEntry({
    required User actingUser,
    required String entryId,
    bool confirm = false,
  }) async {
    final entry = await getEntry(entryId);
    _requireOwner(actingUser, entry.userId);

    final enquiries = await _enquiryRepository.findByEntryId(entryId);
    if (enquiries.isNotEmpty && !confirm) {
      throw ConflictException(
        'This entry has ${enquiries.length} enquiry(ies) against it. '
        'Resend the request with confirm=true to delete it anyway.',
      );
    }
    await _entryRepository.delete(entryId);
  }

  Future<void> _validateFields({
    required String title,
    String? description,
    required List<int> tags,
    String? linkUrl,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.length < minTitleLength ||
        trimmedTitle.length > maxTitleLength) {
      throw ValidationException(
        'Title must be between $minTitleLength and $maxTitleLength characters',
      );
    }
    if (description != null && description.length > maxDescriptionLength) {
      throw ValidationException(
        'Description must be at most $maxDescriptionLength characters',
      );
    }
    if (tags.length < minTagCount || tags.length > maxTagCount) {
      throw ValidationException(
        'Must have between $minTagCount and $maxTagCount tags',
      );
    }
    await _validateTagsExist(tags);
    if (linkUrl != null && !_isWellFormedHttpUrl(linkUrl)) {
      throw ValidationException(
        'linkUrl must be a well-formed http or https URL',
      );
    }
  }

  Future<void> _validateTagsExist(List<int> tagIds) async {
    final allTags = await _tagRepository.getAll();
    final validIds = allTags.map((t) => t.id).toSet();
    for (final id in tagIds) {
      if (!validIds.contains(id)) {
        throw ValidationException('Unknown tag id $id');
      }
    }
  }

  bool _isWellFormedHttpUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  String? _normalizeDescription(String? description) {
    if (description == null) return null;
    final trimmed = description.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _normalizeLinkUrl(String? linkUrl) {
    if (linkUrl == null) return null;
    final trimmed = linkUrl.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _requireOwner(User actingUser, String ownerId) {
    if (actingUser.id != ownerId) {
      throw ForbiddenException('You may only modify your own entries');
    }
  }

  void _requireStaff(User actingUser) {
    if (actingUser.role != UserRole.staff) {
      throw ForbiddenException('Only staff may create entries');
    }
  }

  String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final suffix = _idRandom.nextInt(1 << 32);
    return 'entry_${timestamp}_$suffix';
  }
}

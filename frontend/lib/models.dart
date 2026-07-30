/// Dart-side mirrors of the backend's entities (see
/// backend/lib/src/models/), used only to parse JSON responses from the
/// API. There is no local persistence — the JSON file on the backend
/// remains the single source of truth.
library;

enum UserRole {
  student,
  staff,
  coordinator;

  static UserRole fromJson(String value) =>
      UserRole.values.firstWhere((r) => r.name == value);
}

enum AvailabilityStatus {
  open,
  limited,
  closed;

  static AvailabilityStatus fromJson(String value) =>
      AvailabilityStatus.values.firstWhere((s) => s.name == value);

  String toJson() => name;

  /// A short label for display (FR2: status must be visible on the
  /// summary list, not only the full profile).
  String get label {
    switch (this) {
      case AvailabilityStatus.open:
        return 'Open';
      case AvailabilityStatus.limited:
        return 'Limited';
      case AvailabilityStatus.closed:
        return 'Closed';
    }
  }
}

enum EntryType {
  interest,
  idea;

  static EntryType fromJson(String value) =>
      EntryType.values.firstWhere((t) => t.name == value);

  String toJson() => name;
}

enum ProjectType {
  researchBased,
  implementationBased;

  static ProjectType fromJson(String value) =>
      ProjectType.values.firstWhere((t) => t.name == value);

  String toJson() => name;

  String get label {
    switch (this) {
      case ProjectType.researchBased:
        return 'Research-based';
      case ProjectType.implementationBased:
        return 'Implementation-based';
    }
  }
}

/// The public view of a user account — never carries a password hash or
/// salt, since the backend only ever sends [User.toPublicJson].
class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.fromJson(json['role'] as String),
    );
  }
}

class StaffProfile {
  final String userId;
  final String office;
  final AvailabilityStatus status;
  final DateTime lastUpdated;

  StaffProfile({
    required this.userId,
    required this.office,
    required this.status,
    required this.lastUpdated,
  });

  factory StaffProfile.fromJson(Map<String, dynamic> json) {
    return StaffProfile(
      userId: json['userId'] as String,
      office: json['office'] as String,
      status: AvailabilityStatus.fromJson(json['status'] as String),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }
}

class Entry {
  final String id;
  final String userId;
  final EntryType type;
  final String title;
  final String? description;
  final List<int> tags;
  final ProjectType? projectType;
  final String? linkUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Entry({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.description,
    required this.tags,
    this.projectType,
    this.linkUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: EntryType.fromJson(json['type'] as String),
      title: json['title'] as String,
      description: json['description'] as String?,
      tags: (json['tags'] as List<dynamic>).cast<int>(),
      projectType: json['projectType'] == null
          ? null
          : ProjectType.fromJson(json['projectType'] as String),
      linkUrl: json['linkUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class Tag {
  final int id;
  final String name;

  Tag({required this.id, required this.name});

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(id: json['id'] as int, name: json['name'] as String);
  }
}

class Enquiry {
  final String id;
  final String studentId;
  final String entryId;
  final String message;
  final DateTime sentAt;

  Enquiry({
    required this.id,
    required this.studentId,
    required this.entryId,
    required this.message,
    required this.sentAt,
  });

  factory Enquiry.fromJson(Map<String, dynamic> json) {
    return Enquiry(
      id: json['id'] as String,
      studentId: json['studentId'] as String,
      entryId: json['entryId'] as String,
      message: json['message'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
    );
  }
}

/// One row of the FR8 coordinator staleness report.
class StaffReportRow {
  final AppUser user;
  final StaffProfile profile;
  final DateTime mostRecentActivity;
  final bool hasNoEntries;

  StaffReportRow({
    required this.user,
    required this.profile,
    required this.mostRecentActivity,
    required this.hasNoEntries,
  });

  factory StaffReportRow.fromJson(Map<String, dynamic> json) {
    return StaffReportRow(
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      profile: StaffProfile.fromJson(json['profile'] as Map<String, dynamic>),
      mostRecentActivity:
          DateTime.parse(json['mostRecentActivity'] as String),
      hasNoEntries: json['hasNoEntries'] as bool,
    );
  }
}

/// One staff profile's match in a browse/search result (FR1/FR10).
class StaffSearchResult {
  final AppUser user;
  final StaffProfile profile;
  final List<Entry> entries;

  StaffSearchResult({
    required this.user,
    required this.profile,
    required this.entries,
  });

  factory StaffSearchResult.fromJson(Map<String, dynamic> json) {
    return StaffSearchResult(
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      profile: StaffProfile.fromJson(json['profile'] as Map<String, dynamic>),
      entries: (json['entries'] as List<dynamic>)
          .map((e) => Entry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

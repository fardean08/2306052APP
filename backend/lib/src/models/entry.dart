/// Whether an [Entry] is a general area of interest or a concrete project
/// idea. Only ideas make use of [Entry.projectType] and [Entry.linkUrl].
enum EntryType {
  interest,
  idea;

  static EntryType fromJson(String value) =>
      EntryType.values.firstWhere((t) => t.name == value);

  String toJson() => name;
}

/// FR10: an optional classification for project ideas, filterable
/// alongside the subject-area tag filter.
enum ProjectType {
  researchBased,
  implementationBased;

  static ProjectType fromJson(String value) =>
      ProjectType.values.firstWhere((t) => t.name == value);

  String toJson() => name;
}

/// A structured area-of-interest or project-idea record owned by a staff
/// member (FR3). Ownership is enforced by [userId] in the Service layer,
/// not here.
class Entry {
  final String id;
  final String userId;
  final EntryType type;
  final String title;
  final String? description;

  /// References to [Tag.id]. Must hold 1-5 entries (FR3), enforced by the
  /// Service layer.
  final List<int> tags;

  /// Only meaningful when [type] is [EntryType.idea] (FR10).
  final ProjectType? projectType;

  /// Only meaningful when [type] is [EntryType.idea] (FR6). Validated as a
  /// well-formed http/https URL by the Service layer.
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

  Entry copyWith({
    String? title,
    String? description,
    List<int>? tags,
    ProjectType? projectType,
    String? linkUrl,
    DateTime? updatedAt,
    bool clearDescription = false,
    bool clearProjectType = false,
    bool clearLinkUrl = false,
  }) {
    return Entry(
      id: id,
      userId: userId,
      type: type,
      title: title ?? this.title,
      description:
          clearDescription ? null : (description ?? this.description),
      tags: tags ?? this.tags,
      projectType:
          clearProjectType ? null : (projectType ?? this.projectType),
      linkUrl: clearLinkUrl ? null : (linkUrl ?? this.linkUrl),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.toJson(),
      'title': title,
      'description': description,
      'tags': tags,
      'projectType': projectType?.toJson(),
      'linkUrl': linkUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

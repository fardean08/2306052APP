/// Supervision availability (FR2). Defaults to [open] on profile creation.
enum AvailabilityStatus {
  open,
  limited,
  closed;

  static AvailabilityStatus fromJson(String value) =>
      AvailabilityStatus.values.firstWhere((s) => s.name == value);

  String toJson() => name;
}

/// One canonical profile record per staff member (FR4), keyed by [userId].
/// Entries (interests/ideas) reference the same [userId] rather than being
/// embedded here, so the browse view always reads live data with no
/// cached/duplicate listing.
class StaffProfile {
  final String userId;
  final String office;
  final AvailabilityStatus status;

  /// Timestamp of the profile's own last edit (e.g. office/status change).
  /// The coordinator staleness report (FR8) combines this with the most
  /// recent entry timestamp to find the true "last activity" time.
  final DateTime lastUpdated;

  StaffProfile({
    required this.userId,
    required this.office,
    this.status = AvailabilityStatus.open,
    required this.lastUpdated,
  });

  StaffProfile copyWith({
    String? office,
    AvailabilityStatus? status,
    DateTime? lastUpdated,
  }) {
    return StaffProfile(
      userId: userId,
      office: office ?? this.office,
      status: status ?? this.status,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  factory StaffProfile.fromJson(Map<String, dynamic> json) {
    return StaffProfile(
      userId: json['userId'] as String,
      office: json['office'] as String,
      status: AvailabilityStatus.fromJson(json['status'] as String),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'office': office,
      'status': status.toJson(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

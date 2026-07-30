/// A message a student sends to a staff member about a specific [Entry]
/// (FR9). Visibility is restricted to the entry's owning staff member —
/// enforced by the Service layer (NFR4), not this model.
class Enquiry {
  final String id;
  final String studentId;
  final String entryId;

  /// Must be >= 20 characters (FR9), enforced by the Service layer.
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'entryId': entryId,
      'message': message,
      'sentAt': sentAt.toIso8601String(),
    };
  }
}

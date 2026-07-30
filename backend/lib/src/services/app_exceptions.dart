/// Base type for Service-layer failures. Every exception carries the HTTP
/// status code the Controller layer should respond with, so controllers
/// never need to know *why* a service rejected a request, only what it
/// says. See also [AuthException] in auth_service.dart for login/session
/// failures specifically.
abstract class AppException implements Exception {
  final String message;
  final int statusCode;
  AppException(this.message, this.statusCode);
  @override
  String toString() => message;
}

/// The requested resource does not exist. Maps to HTTP 404.
class NotFoundException extends AppException {
  NotFoundException(String message) : super(message, 404);
}

/// The request violates a business rule (FR3 field limits, FR9 message
/// length, FR6 URL format, etc). Maps to HTTP 422.
class ValidationException extends AppException {
  ValidationException(String message) : super(message, 422);
}

/// The caller is authenticated but not permitted to perform this action
/// (NFR3 ownership, FR2/FR8 coordinator-only actions). Maps to HTTP 403.
class ForbiddenException extends AppException {
  ForbiddenException(String message) : super(message, 403);
}

/// The action is disallowed because of the current state of the resource,
/// not the caller (e.g. FR7's delete-with-active-enquiry guard). Maps to
/// HTTP 409.
class ConflictException extends AppException {
  ConflictException(String message) : super(message, 409);
}

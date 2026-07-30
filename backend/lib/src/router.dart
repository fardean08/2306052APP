import 'dart:io';

import 'controllers/auth_controller.dart';
import 'controllers/coordinator_controller.dart';
import 'controllers/entry_controller.dart';
import 'controllers/enquiry_controller.dart';
import 'controllers/search_controller.dart';
import 'controllers/staff_controller.dart';
import 'controllers/tag_controller.dart';

/// A route handler receives the raw request plus any path parameters
/// extracted from `:name` segments in the route's path template.
typedef RouteHandler = Future<void> Function(
  HttpRequest request,
  Map<String, String> params,
);

class _Route {
  final String method;
  final List<String> segments;
  final RouteHandler handler;

  _Route(this.method, String pathTemplate, this.handler)
      : segments = pathTemplate
            .split('/')
            .where((segment) => segment.isNotEmpty)
            .toList();

  Map<String, String>? match(String method, List<String> pathSegments) {
    if (method != this.method) return null;
    if (pathSegments.length != segments.length) return null;
    final params = <String, String>{};
    for (var i = 0; i < segments.length; i++) {
      final template = segments[i];
      if (template.startsWith(':')) {
        params[template.substring(1)] = Uri.decodeComponent(pathSegments[i]);
      } else if (template != pathSegments[i]) {
        return null;
      }
    }
    return params;
  }
}

/// A minimal hand-rolled router over dart:io's [HttpServer]: matches
/// method + path templates (with `:name` placeholders) to a handler. No
/// external routing package is used, per the architecture spec.
class Router {
  final List<_Route> _routes = [];

  void get(String path, RouteHandler handler) => _add('GET', path, handler);
  void post(String path, RouteHandler handler) => _add('POST', path, handler);
  void patch(String path, RouteHandler handler) =>
      _add('PATCH', path, handler);
  void delete(String path, RouteHandler handler) =>
      _add('DELETE', path, handler);

  void _add(String method, String path, RouteHandler handler) {
    _routes.add(_Route(method, path, handler));
  }

  /// Finds the first matching route and runs its handler, or writes a
  /// generic 404 JSON body if nothing matches.
  Future<void> dispatch(HttpRequest request) async {
    final pathSegments = request.uri.pathSegments;
    for (final route in _routes) {
      final params = route.match(request.method, pathSegments);
      if (params != null) {
        await route.handler(request, params);
        return;
      }
    }
    request.response
      ..statusCode = HttpStatus.notFound
      ..headers.contentType = ContentType.json
      ..write('{"error":"Not found"}');
    await request.response.close();
  }
}

/// Wires every controller to its HTTP method + path. This is the single
/// place that defines the app's API surface.
Router buildRouter({
  required AuthController authController,
  required StaffController staffController,
  required EntryController entryController,
  required SearchController searchController,
  required EnquiryController enquiryController,
  required CoordinatorController coordinatorController,
  required TagController tagController,
}) {
  final router = Router();

  router.post('/api/login', (req, params) => authController.login(req));
  router.post('/api/register', (req, params) => authController.register(req));
  router.post('/api/logout', (req, params) => authController.logout(req));

  router.get('/api/search', (req, params) => searchController.search(req));

  router.get('/api/tags', (req, params) => tagController.getAllTags(req));

  router.get(
    '/api/staff/:userId',
    (req, params) => staffController.getProfile(req, params['userId']!),
  );
  router.patch(
    '/api/staff/:userId/availability',
    (req, params) => staffController.setAvailability(req, params['userId']!),
  );

  router.get(
    '/api/entries/:id',
    (req, params) => entryController.getEntry(req, params['id']!),
  );
  router.post(
    '/api/entries',
    (req, params) => entryController.createEntry(req),
  );
  router.patch(
    '/api/entries/:id',
    (req, params) => entryController.updateEntry(req, params['id']!),
  );
  router.delete(
    '/api/entries/:id',
    (req, params) => entryController.deleteEntry(req, params['id']!),
  );

  router.post(
    '/api/entries/:entryId/enquiries',
    (req, params) => enquiryController.sendEnquiry(req, params['entryId']!),
  );
  router.get(
    '/api/enquiries',
    (req, params) => enquiryController.getInbox(req),
  );

  router.get(
    '/api/coordinator/report',
    (req, params) => coordinatorController.getStalenessReport(req),
  );

  return router;
}

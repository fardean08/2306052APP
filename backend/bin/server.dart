import 'dart:io';

import 'package:supervisor_finder_backend/src/controllers/auth_controller.dart';
import 'package:supervisor_finder_backend/src/controllers/coordinator_controller.dart';
import 'package:supervisor_finder_backend/src/controllers/entry_controller.dart';
import 'package:supervisor_finder_backend/src/controllers/enquiry_controller.dart';
import 'package:supervisor_finder_backend/src/controllers/search_controller.dart';
import 'package:supervisor_finder_backend/src/controllers/staff_controller.dart';
import 'package:supervisor_finder_backend/src/controllers/tag_controller.dart';
import 'package:supervisor_finder_backend/src/data/json_store.dart';
import 'package:supervisor_finder_backend/src/repositories/entry_repository.dart';
import 'package:supervisor_finder_backend/src/repositories/enquiry_repository.dart';
import 'package:supervisor_finder_backend/src/repositories/staff_profile_repository.dart';
import 'package:supervisor_finder_backend/src/repositories/tag_repository.dart';
import 'package:supervisor_finder_backend/src/repositories/user_repository.dart';
import 'package:supervisor_finder_backend/src/router.dart';
import 'package:supervisor_finder_backend/src/seed_data.dart';
import 'package:supervisor_finder_backend/src/services/auth_service.dart';
import 'package:supervisor_finder_backend/src/services/coordinator_service.dart';
import 'package:supervisor_finder_backend/src/services/entry_service.dart';
import 'package:supervisor_finder_backend/src/services/enquiry_service.dart';
import 'package:supervisor_finder_backend/src/services/search_service.dart';
import 'package:supervisor_finder_backend/src/services/staff_service.dart';
import 'package:supervisor_finder_backend/src/services/tag_service.dart';

/// Entry point: wires Repository -> Service -> Controller -> Router,
/// seeds demo data on first run, and starts a plain dart:io [HttpServer].
Future<void> main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final dataFile = File('data/db.json');

  final store = JsonStore(dataFile);
  await store.load();

  final userRepository = UserRepository(store);
  final staffProfileRepository = StaffProfileRepository(store);
  final entryRepository = EntryRepository(store);
  final tagRepository = TagRepository(store);
  final enquiryRepository = EnquiryRepository(store);

  await seedDatabase(
    userRepository: userRepository,
    staffProfileRepository: staffProfileRepository,
    entryRepository: entryRepository,
    tagRepository: tagRepository,
  );

  final authService = AuthService(userRepository);
  final staffService = StaffService(staffProfileRepository, userRepository);
  final entryService =
      EntryService(entryRepository, enquiryRepository, tagRepository);
  final searchService = SearchService(
    staffProfileRepository,
    userRepository,
    entryRepository,
    tagRepository,
  );
  final enquiryService = EnquiryService(enquiryRepository, entryRepository);
  final coordinatorService = CoordinatorService(
    staffProfileRepository,
    userRepository,
    entryRepository,
  );
  final tagService = TagService(tagRepository);

  final router = buildRouter(
    authController: AuthController(authService),
    staffController: StaffController(staffService, entryService, authService),
    entryController: EntryController(entryService, authService),
    searchController: SearchController(searchService),
    enquiryController: EnquiryController(enquiryService, authService),
    coordinatorController:
        CoordinatorController(coordinatorService, authService),
    tagController: TagController(tagService),
  );

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Supervisor Finder backend listening on port $port');
  stdout.writeln('Data file: ${dataFile.absolute.path}');
  stdout.writeln('Seed login password for all demo accounts: password123');

  await for (final request in server) {
    try {
      await router.dispatch(request);
    } catch (e, st) {
      stderr.writeln('Unhandled error dispatching request: $e\n$st');
      try {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..headers.contentType = ContentType.json
          ..write('{"error":"Internal server error"}');
        await request.response.close();
      } catch (_) {
        // Response may already be closed; nothing more we can do.
      }
    }
  }
}

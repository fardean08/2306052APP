import 'package:flutter/material.dart';

import 'models.dart';
import 'screens/browse_screen.dart';
import 'screens/coordinator_report_screen.dart';
import 'screens/login_screen.dart';
import 'screens/staff_dashboard_screen.dart';
import 'services/api_client.dart';
import 'services/session.dart';

void main() {
  runApp(const SupervisorFinderApp());
}

/// App root: owns the single [ApiClient]/[Session] for the app's
/// lifetime, and switches between the login screen and a role-appropriate
/// home screen based on [Session.isLoggedIn].
class SupervisorFinderApp extends StatefulWidget {
  const SupervisorFinderApp({super.key});

  @override
  State<SupervisorFinderApp> createState() => _SupervisorFinderAppState();
}

class _SupervisorFinderAppState extends State<SupervisorFinderApp> {
  late final ApiClient _apiClient = ApiClient(
    baseUrl: ApiClient.defaultBaseUrl(),
  );
  late final Session _session = Session(_apiClient);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supervisor Finder',
      // Material 3's default seeded color scheme gives reasonable
      // contrast out of the box (NFR7).
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: ListenableBuilder(
        listenable: _session,
        builder: (context, _) {
          if (!_session.isLoggedIn) {
            return LoginScreen(session: _session);
          }
          return _HomeScaffold(apiClient: _apiClient, session: _session);
        },
      ),
    );
  }
}

/// The role-appropriate home screen (one per actor, matching the five
/// use cases): students browse, staff manage their dashboard, and
/// coordinators see the staleness report.
class _HomeScaffold extends StatelessWidget {
  final ApiClient apiClient;
  final Session session;

  const _HomeScaffold({required this.apiClient, required this.session});

  @override
  Widget build(BuildContext context) {
    final user = session.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(user.role)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => session.logout(),
          ),
        ],
      ),
      body: _bodyFor(user.role),
    );
  }

  String _titleFor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'Find a Supervisor';
      case UserRole.staff:
        return 'My Dashboard';
      case UserRole.coordinator:
        return 'Staleness Report';
    }
  }

  Widget _bodyFor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return BrowseScreen(apiClient: apiClient, session: session);
      case UserRole.staff:
        return StaffDashboardScreen(apiClient: apiClient, session: session);
      case UserRole.coordinator:
        return CoordinatorReportScreen(apiClient: apiClient);
    }
  }
}

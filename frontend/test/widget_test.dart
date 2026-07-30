import 'package:flutter_test/flutter_test.dart';

import 'package:supervisor_finder_frontend/main.dart';

void main() {
  testWidgets('the app starts on the login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SupervisorFinderApp());

    expect(find.text('Supervisor Finder'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}

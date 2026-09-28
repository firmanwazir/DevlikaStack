import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_app/main.dart';
import 'package:server_app/services/version_checker_service.dart';

void main() {
  testWidgets('DevlikaStackApp desktop smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1366, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Provide mock info so post-frame callbacks don't fire background process during smoke test
    VersionCheckerService.instance.checkMariaDb();

    await tester.pumpWidget(const DevlikaStackApp());
    expect(find.byType(DevlikaStackApp), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_app/main.dart';
import 'package:server_app/theme/app_theme.dart';
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

  testWidgets('DevlikaStackApp theme mode defaults to light and toggles correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1366, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Reset theme to default light
    AppTheme.setThemeMode(ThemeMode.light);
    expect(AppTheme.isDarkMode, isFalse);

    await tester.pumpWidget(const DevlikaStackApp());
    await tester.pumpAndSettle();

    // Verify sun/moon toggle button exists
    final toggleFinder = find.byTooltip('Beralih ke Tema Gelap (Dark Mode)');
    expect(toggleFinder, findsOneWidget);

    // Tap theme toggle button
    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    // Verify switched to dark mode
    expect(AppTheme.isDarkMode, isTrue);

    // Reset back to light mode
    AppTheme.setThemeMode(ThemeMode.light);
    expect(AppTheme.isDarkMode, isFalse);
  });
}

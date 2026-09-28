import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'server_controller.dart';

class TrayService with TrayListener, WindowListener {
  static final TrayService instance = TrayService._();
  TrayService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  String _resolveIconPath() {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final candidates = [
      p.join(exeDir, 'data', 'flutter_assets', 'assets', 'app_icon.ico'),
      p.join(exeDir, 'app_icon.ico'),
      p.join(exeDir, 'data', 'flutter_assets', 'windows', 'runner', 'resources', 'app_icon.ico'),
      p.join(Directory.current.path, 'assets', 'app_icon.ico'),
      p.join(Directory.current.path, 'windows', 'runner', 'resources', 'app_icon.ico'),
    ];

    for (final c in candidates) {
      if (File(c).existsSync()) {
        return c;
      }
    }
    return 'assets/app_icon.ico';
  }

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) return;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    try {
      await windowManager.ensureInitialized();
      windowManager.addListener(this);
      await windowManager.setPreventClose(true);

      trayManager.addListener(this);
      final iconPath = _resolveIconPath();
      await trayManager.setIcon(iconPath);
      await updateTrayMenu();
      _initialized = true;
    } catch (_) {}
  }

  Future<void> updateTrayMenu() async {
    if (!_initialized) return;

    try {
      final serverController = ServerController.instance;
      final isWebRunning = serverController.isWebRunning;
      final isDbRunning = serverController.isMariaDbRunning;

      final toolTip = 'DevlikaStack - '
          'Web: ${isWebRunning ? "Running" : "Stopped"} | '
          'MariaDB: ${isDbRunning ? "Running" : "Stopped"}';

      await trayManager.setToolTip(toolTip);

      final menu = Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: 'Buka DevlikaStack',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'status_web',
            label: 'Web Server: ${isWebRunning ? "Running (Port 80/443)" : "Stopped"}',
            disabled: true,
          ),
          MenuItem(
            key: 'status_db',
            label: 'MariaDB: ${isDbRunning ? "Running (Port 3306)" : "Stopped"}',
            disabled: true,
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'open_browser',
            label: 'Buka Localhost (Browser)',
          ),
          MenuItem(
            key: 'open_pma',
            label: 'Buka phpMyAdmin',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Keluar',
          ),
        ],
      );

      await trayManager.setContextMenu(menu);
    } catch (_) {}
  }

  @override
  void onWindowClose() async {
    final serverController = ServerController.instance;
    final isRunning = serverController.isWebRunning || serverController.isMariaDbRunning;

    // Jika server aktif: jangan tutup aplikasi, sembunyikan ke background (System Tray)
    if (isRunning) {
      try {
        await windowManager.hide();
        await updateTrayMenu();
      } catch (_) {}
    } else {
      await exitApp();
    }
  }

  @override
  void onWindowMinimize() async {
    final serverController = ServerController.instance;
    final isRunning = serverController.isWebRunning || serverController.isMariaDbRunning;

    // Jika server aktif dan jendela diminimalkan, sembunyikan ke Tray
    if (isRunning) {
      try {
        await windowManager.hide();
        await updateTrayMenu();
      } catch (_) {}
    }
  }

  @override
  void onTrayIconMouseDown() async {
    await showWindow();
  }

  @override
  void onTrayIconRightMouseDown() async {
    await updateTrayMenu();
    try {
      await trayManager.popUpContextMenu();
    } catch (_) {}
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_window':
        await showWindow();
        break;
      case 'open_browser':
        try {
          await launchUrl(Uri.parse('http://127.0.0.1/'));
        } catch (_) {}
        break;
      case 'open_pma':
        try {
          await ServerController.instance.openPhpMyAdmin();
        } catch (_) {}
        break;
      case 'exit_app':
        await exitApp();
        break;
    }
  }

  Future<void> showWindow() async {
    try {
      final isMinimized = await windowManager.isMinimized();
      if (isMinimized) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  Future<void> exitApp() async {
    try {
      await ServerController.instance.toggleWebServer(false);
      await ServerController.instance.toggleMariaDb(false);
    } catch (_) {}

    try {
      await trayManager.destroy();
      await windowManager.destroy();
    } catch (_) {}

    exit(0);
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'theme/app_theme.dart';
import 'widgets/sidebar.dart';
import 'widgets/header_bar.dart';
import 'views/dashboard_view.dart';
import 'views/hosts_view.dart';
import 'views/web_server_view.dart';
import 'views/php_view.dart';
import 'views/mariadb_view.dart';
import 'views/turbo_importer_view.dart';
import 'views/phpmyadmin_view.dart';
import 'views/environment_view.dart';
import 'views/logs_view.dart';
import 'services/tray_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      !Platform.environment.containsKey('FLUTTER_TEST') &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        size: Size(1280, 720),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (_) {}
  }

  runApp(const DevlikaStackApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    TrayService.instance.init();
  });
}

class DevlikaStackApp extends StatelessWidget {
  const DevlikaStackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Devlika Stack - Portable Web Development Environment',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _titles = [
    'Dashboard',
    'Virtual Hosts',
    'Web Server',
    'PHP Environment',
    'MariaDB Server',
    'SQL Importer',
    'phpMyAdmin',
    'Pusat Komponen',
    'Log Aktivitas',
  ];

  final _subtitles = [
    'Status layanan dan kontrol web server lokal.',
    'Kelola domain lokal kustom dan DocumentRoot proyek.',
    'Pilihan engine HTTP (Native Dart, Nginx 1.26, Apache 2.4).',
    'Manajemen multi-versi PHP, ekstensi, dan konfigurasi php.ini.',
    'Database server MariaDB port 3306 dan parameter koneksi.',
    'Import berkas SQL dump besar langsung ke database.',
    'Antarmuka web untuk manajemen database MariaDB.',
    'Status dan instalasi runtime komponen server.',
    'Output log aktivitas HTTP dan query database secara real-time.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left Categorized Sidebar Navigation (FlyEnv Style)
          Sidebar(
            selectedIndex: _currentIndex,
            onItemSelected: (index) => setState(() => _currentIndex = index),
          ),

          // Main Content Workspace
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                HeaderBar(
                  title: _titles[_currentIndex],
                  subtitle: _subtitles[_currentIndex],
                ),

                // View Body
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      DashboardView(onNavigate: (index) => setState(() => _currentIndex = index)),
                      const HostsView(),
                      WebServerView(onNavigate: (index) => setState(() => _currentIndex = index)),
                      const PhpView(),
                      MariaDbView(onNavigate: (index) => setState(() => _currentIndex = index)),
                      const TurboImporterView(),
                      const PhpMyAdminView(),
                      const EnvironmentView(),
                      const LogsView(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

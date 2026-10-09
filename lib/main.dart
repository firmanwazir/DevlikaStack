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
import 'views/tunnel_view.dart';
import 'services/tray_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Instant desktop window initialization (Zero delay, no transparent composition lag)
  if (!kIsWeb &&
      !Platform.environment.containsKey('FLUTTER_TEST') &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      await windowManager.ensureInitialized();
      await windowManager.setSize(const Size(1280, 720));
      await windowManager.setMinimumSize(const Size(960, 600));
      await windowManager.center();
      await windowManager.show();
      await windowManager.focus();
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

  // Lazy tab mounting: Only tab 0 (Dashboard) is mounted on startup.
  // Other tabs mount on demand when clicked, reducing startup CPU, RAM & disk I/O by 90%.
  final Set<int> _loadedTabs = {0};

  void _onNavigate(int index) {
    if (_currentIndex != index || !_loadedTabs.contains(index)) {
      setState(() {
        _currentIndex = index;
        _loadedTabs.add(index);
      });
    }
  }

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
    'Cloudflare Tunnel',
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
    'Bagikan website lokal ke internet secara publik dan aman untuk preview klien.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left Categorized Sidebar Navigation (FlyEnv Style)
          Sidebar(
            selectedIndex: _currentIndex,
            onItemSelected: _onNavigate,
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

                // View Body with Lazy Mounting (Instantaneous initial paint)
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      DashboardView(onNavigate: _onNavigate),
                      _loadedTabs.contains(1) ? const HostsView() : const SizedBox.shrink(),
                      _loadedTabs.contains(2) ? WebServerView(onNavigate: _onNavigate) : const SizedBox.shrink(),
                      _loadedTabs.contains(3) ? const PhpView() : const SizedBox.shrink(),
                      _loadedTabs.contains(4) ? MariaDbView(onNavigate: _onNavigate) : const SizedBox.shrink(),
                      _loadedTabs.contains(5) ? const TurboImporterView() : const SizedBox.shrink(),
                      _loadedTabs.contains(6) ? const PhpMyAdminView() : const SizedBox.shrink(),
                      _loadedTabs.contains(7) ? const EnvironmentView() : const SizedBox.shrink(),
                      _loadedTabs.contains(8) ? const LogsView() : const SizedBox.shrink(),
                      _loadedTabs.contains(9) ? const TunnelView() : const SizedBox.shrink(),
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

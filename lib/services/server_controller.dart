import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/component_status.dart';
import '../models/site_model.dart';
import 'config_service.dart';
import 'hosts_manager.dart';
import 'http_server_service.dart';
import 'mariadb_manager.dart';
import 'component_downloader.dart';
import 'db_importer_service.dart';
import 'web_server_engine_manager.dart';
import 'tray_service.dart';
import 'port_checker_service.dart';

class ServerController extends ChangeNotifier {
  static final ServerController instance = ServerController._();
  ServerController._() {
    _init();
  }

  bool isWebRunning = false;
  bool isMariaDbRunning = false;
  bool isStartingAll = false;
  bool isStoppingAll = false;
  bool isWebToggling = false;
  bool isMariaDbToggling = false;
  bool isBatchInstalling = false;
  double batchInstallProgress = 0.0;
  String batchInstallMessage = '';

  bool get isOperatingAll => isStartingAll || isStoppingAll;

  int get httpPort => ConfigService.instance.httpPort;
  int get httpsPort => ConfigService.instance.httpsPort;
  int get mariaDbPort => ConfigService.instance.mariaDbPort;

  Future<void> setHttpPort(int port) async {
    final wasRunning = isWebRunning;
    if (wasRunning) {
      await toggleWebServer(false);
    }
    ConfigService.instance.setHttpPort(port);
    refreshStatus();
    if (wasRunning) {
      await toggleWebServer(true);
    }
    notifyListeners();
  }

  Future<void> setHttpsPort(int port) async {
    final wasRunning = isWebRunning;
    if (wasRunning) {
      await toggleWebServer(false);
    }
    ConfigService.instance.setHttpsPort(port);
    refreshStatus();
    if (wasRunning) {
      await toggleWebServer(true);
    }
    notifyListeners();
  }

  Future<void> setMariaDbPort(int port) async {
    final wasRunning = isMariaDbRunning;
    if (wasRunning) {
      await toggleMariaDb(false);
    }
    ConfigService.instance.setMariaDbPort(port);
    refreshStatus();
    if (wasRunning) {
      await toggleMariaDb(true);
    }
    notifyListeners();
  }

  List<SiteModel> sites = [];
  final LogsNotifier logsNotifier = LogsNotifier();
  List<String> get logs => logsNotifier.logs;

  late SystemComponents components;

  void _init() {
    components = SystemComponents(
      php: ComponentItem(
        id: 'php',
        name: 'PHP 8.x / 7.x Engine',
        description: 'Menjalankan file script PHP & integrasi database.',
      ),
      mariaDb: ComponentItem(
        id: 'mariadb',
        name: 'MariaDB (MySQL) Database',
        description: 'Server basis data SQL lokal.',
      ),
      phpMyAdmin: ComponentItem(
        id: 'phpmyadmin',
        name: 'phpMyAdmin',
        description: 'Antarmuka web visual lengkap untuk manajemen database.',
      ),
      nginx: ComponentItem(
        id: 'nginx',
        name: 'Nginx 1.26 Engine',
        description: 'Web server event-driven berkecepatan tinggi dengan FastCGI PHP.',
      ),
      apache: ComponentItem(
        id: 'apache',
        name: 'Apache HTTPD 2.4',
        description: 'Server HTTP standar industri dengan modul native .htaccess.',
      ),
    );

    refreshStatus();

    HttpServerService.instance.logStream.listen((msg) {
      _addLog(msg);
    });

    MariaDbManager.instance.logStream.listen((msg) {
      _addLog(msg);
    });
  }

  void _addLog(String msg) {
    logsNotifier.addLog(msg);
  }

  void clearLogs() {
    logsNotifier.clear();
  }

  void refreshStatus() {
    HttpServerService.instance.clearDocRootCache();
    final config = ConfigService.instance;
    sites = config.loadSites(forceReload: true);

    // Check PHP
    final hasPhp = File(config.phpExe).existsSync();
    components.php.isInstalled = hasPhp;
    components.php.path = hasPhp ? config.phpExe : '';
    components.php.version = hasPhp ? 'PHP Portable (Aktif)' : 'Belum Terpasang';

    // Check MariaDB
    final hasMariaDb = File(config.mariaDbExe).existsSync();
    components.mariaDb.isInstalled = hasMariaDb;
    components.mariaDb.path = hasMariaDb ? config.mariaDbExe : '';
    components.mariaDb.version = hasMariaDb ? 'MariaDB 11.x (Port $mariaDbPort)' : 'Belum Terpasang';

    // Check phpMyAdmin
    final hasPma = Directory(config.phpMyAdminDir).existsSync();
    components.phpMyAdmin.isInstalled = hasPma;
    components.phpMyAdmin.path = hasPma ? config.phpMyAdminDir : '';
    components.phpMyAdmin.version = hasPma ? 'phpMyAdmin 5.x (Siap)' : 'Belum Terpasang';

    // Check Nginx
    final hasNginx = File(config.nginxExe).existsSync();
    components.nginx.isInstalled = hasNginx;
    components.nginx.path = hasNginx ? config.nginxExe : '';
    components.nginx.version = hasNginx ? 'Nginx 1.26 (Port $httpPort)' : 'Belum Terpasang';

    // Check Apache
    final hasApache = File(config.apacheExe).existsSync();
    components.apache.isInstalled = hasApache;
    components.apache.path = hasApache ? config.apacheExe : '';
    components.apache.version = hasApache ? 'Apache 2.4 (Port $httpPort)' : 'Belum Terpasang';

    isWebRunning = WebServerEngineManager.instance.isRunning;
    isMariaDbRunning = MariaDbManager.instance.isRunning;

    TrayService.instance.updateTrayMenu();
    notifyListeners();
  }

  Future<void> toggleWebServer(bool enable) async {
    if (isWebToggling) return;
    isWebToggling = true;
    notifyListeners();

    try {
      final engineMgr = WebServerEngineManager.instance;
      final currentHttpPort = httpPort;
      if (enable) {
        if (engineMgr.activeEngine == 'nginx' && !components.nginx.isInstalled) {
          _addLog('[Peringatan] Nginx belum terpasang. Unduh Nginx terlebih dahulu di Pusat Komponen.');
          return;
        }
        if (engineMgr.activeEngine == 'apache' && !components.apache.isInstalled) {
          _addLog('[Peringatan] Apache belum terpasang. Unduh Apache terlebih dahulu di Pusat Komponen.');
          return;
        }
        if (engineMgr.activeEngine == 'builtin' && !components.php.isInstalled) {
          _addLog('[Peringatan] PHP belum terpasang. Silakan install PHP terlebih dahulu.');
          return;
        }

        // Pre-flight port conflict check
        final portStatus = await PortCheckerService.instance.checkPort(currentHttpPort);
        if (!portStatus.isFree && !engineMgr.isRunning) {
          _addLog('[Web Server Konflik] Port $currentHttpPort sedang digunakan oleh ${portStatus.friendlyName ?? portStatus.processName ?? "aplikasi lain"} (PID: ${portStatus.pid ?? "Unknown"}).');
          _addLog('[Web Server Solusi] Ubah port HTTP ke 8080 di Pengaturan Port atau matikan aplikasi tersebut.');
        }

        final success = await engineMgr.start();
        isWebRunning = success;
        if (success) {
          await syncHosts();
          _addLog('[Web Server] ${engineMgr.activeEngineDisplayName} aktif pada port $currentHttpPort.');
          cleanOldSessions();
        }
      } else {
        await engineMgr.stop();
        isWebRunning = false;
        _addLog('[Web Server] Web server dihentikan.');
      }
      TrayService.instance.updateTrayMenu();
    } finally {
      isWebToggling = false;
      notifyListeners();
    }
  }

  Future<bool> switchWebEngine(String engine) async {
    final success = await WebServerEngineManager.instance.switchEngine(engine);
    isWebRunning = WebServerEngineManager.instance.isRunning;
    _addLog('[Web Server] Engine dialihkan ke: ${WebServerEngineManager.instance.activeEngineDisplayName}');
    notifyListeners();
    return success;
  }

  Future<void> toggleMariaDb(bool enable) async {
    if (isMariaDbToggling) return;
    isMariaDbToggling = true;
    notifyListeners();

    try {
      final currentDbPort = mariaDbPort;
      if (enable) {
        if (!components.mariaDb.isInstalled) {
          _addLog('[Peringatan] MariaDB belum terpasang. Silakan install MariaDB terlebih dahulu.');
          return;
        }

        // Pre-flight port conflict check
        final portStatus = await PortCheckerService.instance.checkPort(currentDbPort);
        if (!portStatus.isFree && !MariaDbManager.instance.isRunning) {
          _addLog('[MariaDB Konflik] Port $currentDbPort sedang digunakan oleh ${portStatus.friendlyName ?? portStatus.processName ?? "aplikasi lain"} (PID: ${portStatus.pid ?? "Unknown"}).');
          _addLog('[MariaDB Solusi] Ubah port MariaDB ke 3307 di Pengaturan Port atau matikan MySQL/XAMPP.');
        }

        final success = await MariaDbManager.instance.start();
        isMariaDbRunning = success;
      } else {
        if (DbImporterService.instance.isImporting) {
          DbImporterService.instance.cancelImport();
        }
        await MariaDbManager.instance.stop();
        isMariaDbRunning = false;
      }
      TrayService.instance.updateTrayMenu();
    } finally {
      isMariaDbToggling = false;
      notifyListeners();
    }
  }

  Future<void> startAll() async {
    if (isStartingAll || isStoppingAll) return;
    isStartingAll = true;
    notifyListeners();

    try {
      if (!components.php.isInstalled && !components.mariaDb.isInstalled) {
        _addLog('[Peringatan] Komponen belum terpasang. Install komponen terlebih dahulu.');
        return;
      }

      if (components.php.isInstalled) {
        await toggleWebServer(true);
      }
      if (components.mariaDb.isInstalled) {
        await toggleMariaDb(true);
      }
    } finally {
      isStartingAll = false;
      notifyListeners();
    }
  }

  Future<void> stopAll() async {
    if (isStartingAll || isStoppingAll) return;
    isStoppingAll = true;
    notifyListeners();

    try {
      await toggleWebServer(false);
      await toggleMariaDb(false);
    } finally {
      isStoppingAll = false;
      notifyListeners();
    }
  }

  Future<void> addSite(SiteModel site) async {
    sites.removeWhere((s) => s.id == site.id || s.domain.toLowerCase() == site.domain.toLowerCase());
    sites.add(site);
    ConfigService.instance.saveSites(sites);
    await syncHosts();
    _addLog('[Hosts] Website ${site.domain} berhasil disimpan.');
    notifyListeners();
  }

  Future<void> updateSite(SiteModel site, {String? oldDomain}) async {
    final index = sites.indexWhere((s) => s.id == site.id);
    if (index != -1) {
      sites[index] = site;
    } else {
      sites.add(site);
    }
    ConfigService.instance.saveSites(sites);
    await syncHosts();
    _addLog('[Hosts] Website ${site.domain} berhasil diperbarui.');
    notifyListeners();
  }

  Future<void> toggleSite(String siteId, bool enable) async {
    final index = sites.indexWhere((s) => s.id == siteId);
    if (index != -1) {
      sites[index].isEnabled = enable;
      ConfigService.instance.saveSites(sites);
      await syncHosts();
      _addLog('[Hosts] Website ${sites[index].domain} diubah menjadi ${enable ? "Aktif" : "Nonaktif"}.');
      notifyListeners();
    }
  }

  Future<void> deleteSite(String id) async {
    sites.removeWhere((s) => s.id == id);
    ConfigService.instance.saveSites(sites);
    await syncHosts();
    _addLog('[Hosts] Website berhasil dihapus.');
    notifyListeners();
  }

  Future<void> syncHosts() async {
    final domains = sites.where((s) => s.isEnabled).map((s) => s.domain).toList();
    await HostsManager.instance.syncDomains(domains);
    await WebServerEngineManager.instance.syncVhosts();
  }

  Future<void> installSingleComponent(String componentId) async {
    final downloader = ComponentDownloader.instance;

    if (componentId == 'php') {
      components.php.isInstalling = true;
      components.php.installProgress = 0.05;
      notifyListeners();

      try {
        await downloader.installPhp(onProgress: (msg, prog) {
          components.php.statusMessage = msg;
          components.php.installProgress = prog;
          notifyListeners();
        });
      } finally {
        components.php.isInstalling = false;
        refreshStatus();
      }
    } else if (componentId == 'mariadb') {
      components.mariaDb.isInstalling = true;
      components.mariaDb.installProgress = 0.05;
      notifyListeners();

      try {
        await downloader.installMariaDb(onProgress: (msg, prog) {
          components.mariaDb.statusMessage = msg;
          components.mariaDb.installProgress = prog;
          notifyListeners();
        });
      } finally {
        components.mariaDb.isInstalling = false;
        refreshStatus();
      }
    } else if (componentId == 'phpmyadmin') {
      components.phpMyAdmin.isInstalling = true;
      components.phpMyAdmin.installProgress = 0.05;
      notifyListeners();

      try {
        await downloader.installPhpMyAdmin(onProgress: (msg, prog) {
          components.phpMyAdmin.statusMessage = msg;
          components.phpMyAdmin.installProgress = prog;
          notifyListeners();
        });
      } finally {
        components.phpMyAdmin.isInstalling = false;
        refreshStatus();
      }
    } else if (componentId == 'nginx') {
      components.nginx.isInstalling = true;
      components.nginx.installProgress = 0.05;
      notifyListeners();

      try {
        await downloader.installNginx(onProgress: (msg, prog) {
          components.nginx.statusMessage = msg;
          components.nginx.installProgress = prog;
          notifyListeners();
        });
      } finally {
        components.nginx.isInstalling = false;
        refreshStatus();
      }
    } else if (componentId == 'apache') {
      components.apache.isInstalling = true;
      components.apache.installProgress = 0.05;
      notifyListeners();

      try {
        await downloader.installApache(onProgress: (msg, prog) {
          components.apache.statusMessage = msg;
          components.apache.installProgress = prog;
          notifyListeners();
        });
      } finally {
        components.apache.isInstalling = false;
        refreshStatus();
      }
    }
  }

  Future<void> installAllComponents() async {
    isBatchInstalling = true;
    batchInstallProgress = 0.05;
    batchInstallMessage = 'Mempersiapkan instalasi semua komponen...';
    notifyListeners();

    try {
      // 1. PHP
      batchInstallMessage = 'Langkah 1/3: Memasang PHP Portable...';
      batchInstallProgress = 0.15;
      notifyListeners();
      await ComponentDownloader.instance.installPhp(onProgress: (msg, p) {
        batchInstallMessage = 'PHP: $msg';
        batchInstallProgress = 0.1 + (p * 0.25);
        notifyListeners();
      });

      // 2. MariaDB
      batchInstallMessage = 'Langkah 2/3: Memasang MariaDB Portable...';
      batchInstallProgress = 0.40;
      notifyListeners();
      await ComponentDownloader.instance.installMariaDb(onProgress: (msg, p) {
        batchInstallMessage = 'MariaDB: $msg';
        batchInstallProgress = 0.4 + (p * 0.35);
        notifyListeners();
      });

      // 3. phpMyAdmin
      batchInstallMessage = 'Langkah 3/3: Memasang phpMyAdmin...';
      batchInstallProgress = 0.80;
      notifyListeners();
      await ComponentDownloader.instance.installPhpMyAdmin(onProgress: (msg, p) {
        batchInstallMessage = 'phpMyAdmin: $msg';
        batchInstallProgress = 0.75 + (p * 0.25);
        notifyListeners();
      });

      batchInstallMessage = 'Semua komponen berhasil dipasang!';
      batchInstallProgress = 1.0;
      notifyListeners();
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      isBatchInstalling = false;
      refreshStatus();
    }
  }

  String formatSiteUrl(String domain, {bool isHttps = false}) {
    if (isHttps) {
      final portSuffix = httpsPort == 443 ? '' : ':$httpsPort';
      return 'https://$domain$portSuffix';
    } else {
      final portSuffix = httpPort == 80 ? '' : ':$httpPort';
      return 'http://$domain$portSuffix';
    }
  }

  String resolveSiteUrl(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      if (uri.hasPort) return rawUrl;
      if (uri.scheme == 'http' && httpPort != 80) {
        return uri.replace(port: httpPort).toString();
      }
      if (uri.scheme == 'https' && httpsPort != 443) {
        return uri.replace(port: httpsPort).toString();
      }
    } catch (_) {}
    return rawUrl;
  }

  Future<void> openUrl(String url) async {
    try {
      final resolved = resolveSiteUrl(url);
      final uri = Uri.parse(resolved);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _addLog('[Browser Error] Gagal membuka $url: $e');
    }
  }

  Future<void> openFolder(String folderPath) async {
    try {
      if (Directory(folderPath).existsSync()) {
        await Process.run('explorer.exe', [folderPath]);
      }
    } catch (e) {
      _addLog('[Folder Error] Gagal membuka $folderPath: $e');
    }
  }

  Future<void> openPhpMyAdmin() async {
    if (!isWebRunning) {
      await toggleWebServer(true);
    }
    if (!isMariaDbRunning && components.mariaDb.isInstalled) {
      await toggleMariaDb(true);
    }
    final portSuffix = httpPort == 80 ? '' : ':$httpPort';
    await openUrl('http://127.0.0.1$portSuffix/__phpmyadmin/');
  }

  /// Automatically clean stale PHP session files older than 7 days
  Future<void> cleanOldSessions() async {
    try {
      final config = ConfigService.instance;
      final sessionDir = Directory(p.join(config.storageDir, 'sessions'));
      if (!sessionDir.existsSync()) return;

      final now = DateTime.now();
      const maxAge = Duration(days: 7);

      await for (final entity in sessionDir.list(followLinks: false)) {
        if (entity is File) {
          final stat = await entity.stat();
          if (now.difference(stat.modified) > maxAge) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}

class LogsNotifier extends ChangeNotifier {
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  void addLog(String msg) {
    _logs.add(msg);
    // Batch trim to avoid O(N) array shifting on every single log entry
    if (_logs.length > 600) {
      _logs.removeRange(0, 100);
    }
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/site_model.dart';
import '../models/php_version_model.dart';
import 'php_manager.dart';

class ConfigService {
  static final ConfigService instance = ConfigService._();
  ConfigService._();

  String? _binDirOverride;
  late final String _defaultBinDir = _detectBinDir();
  String get binDir => _binDirOverride ?? _defaultBinDir;

  void setBinDirForTesting(String? path) {
    _binDirOverride = path;
    _settingsCache = null;
    _cachedSites = null;
    _directoriesEnsured = false;
  }

  static String normalizePhpVersionKey(String? key) {
    if (key == null || key.isEmpty || key.toLowerCase() == 'default') return 'default';
    final clean = key.toLowerCase().replaceAll('php', '').replaceAll('-', '').replaceAll('_', '').trim();
    if (clean.startsWith('7.4') || clean == '7' || clean.startsWith('7.')) return '7.4';
    if (clean.startsWith('8.1')) return '8.1';
    if (clean.startsWith('8.2')) return '8.2';
    if (clean.startsWith('8.3')) return '8.3';
    if (clean.startsWith('8')) return '8.2';
    return key.trim();
  }

  String get phpBaseDir => p.join(binDir, 'php');

  PhpVersionModel getPhpForSite(String? versionKey) {
    final normalized = normalizePhpVersionKey(versionKey);
    final list = PhpManager.instance.getVersions();

    // 1. If exact or normalized version requested
    if (normalized != 'default') {
      // Check cached versions
      for (var v in list) {
        if ((v.versionKey == normalized || v.versionKey == versionKey) && v.isInstalled) {
          return v;
        }
      }
      // If cache was stale, verify file existence on disk directly
      for (var v in list) {
        if (v.versionKey == normalized || v.versionKey == versionKey) {
          final exe = p.join(v.dirPath, 'php.exe');
          if (File(exe).existsSync()) {
            return PhpVersionModel(
              versionKey: v.versionKey,
              name: v.name,
              dirPath: v.dirPath,
              isInstalled: true,
              exactVersion: v.exactVersion,
              downloadUrl: v.downloadUrl,
            );
          }
        }
      }
      // Check if folder exists directly in phpBaseDir (e.g. bin/php/php-7.4)
      final directDir = p.join(phpBaseDir, 'php-$normalized');
      final directExe = p.join(directDir, 'php.exe');
      if (File(directExe).existsSync()) {
        return PhpVersionModel(
          versionKey: normalized,
          name: 'PHP $normalized',
          dirPath: directDir,
          isInstalled: true,
          exactVersion: normalized,
          downloadUrl: '',
        );
      }
    }

    // 2. Default: look for any installed subfolder version (prefer 8.2 or 7.4)
    final installed = list.where((v) => v.isInstalled || File(p.join(v.dirPath, 'php.exe')).existsSync()).toList();
    if (installed.isNotEmpty) {
      for (var v in installed) {
        if (v.versionKey == '8.2') return v;
      }
      return installed.first;
    }

    // 3. Fallback to unversioned bin/php if present directly
    if (File(p.join(phpBaseDir, 'php.exe')).existsSync()) {
      return PhpVersionModel(
        versionKey: 'default',
        name: 'PHP Default (Portable)',
        dirPath: phpBaseDir,
        isInstalled: true,
        exactVersion: 'Portable',
        downloadUrl: '',
      );
    }

    return list.first;
  }

  String get phpDir => getPhpForSite('default').dirPath;
  String get phpExe => getPhpForSite('default').phpExe;
  String get phpCgiExe => getPhpForSite('default').phpCgiExe;
  String get phpIni => getPhpForSite('default').phpIni;

  String get mariaDbDir => p.join(binDir, 'mariadb');
  String get mariaDbExe => p.join(mariaDbDir, 'bin', 'mysqld.exe');
  String get mariaDbInstallDbExe => p.join(mariaDbDir, 'bin', 'mariadb-install-db.exe');
  String get mariaDbFallbackInstallExe => p.join(mariaDbDir, 'bin', 'mysql_install_db.exe');
  String get mariaDbClientExe {
    final client = p.join(mariaDbDir, 'bin', 'mysql.exe');
    if (File(client).existsSync()) return client;
    final mariadb = p.join(mariaDbDir, 'bin', 'mariadb.exe');
    if (File(mariadb).existsSync()) return mariadb;
    return client;
  }
  String get mariaDbDumpExe {
    final dump = p.join(mariaDbDir, 'bin', 'mysqldump.exe');
    if (File(dump).existsSync()) return dump;
    final mariadbdump = p.join(mariaDbDir, 'bin', 'mariadb-dump.exe');
    if (File(mariadbdump).existsSync()) return mariadbdump;
    return dump;
  }

  String get toolsDir => p.join(binDir, 'tools');
  String get phpMyAdminDir => p.join(toolsDir, 'phpmyadmin');

  // ALL data, databases, config, and demo site are strictly inside binDir!
  String get storageDir => p.join(binDir, 'storage');
  String get dataDir => storageDir;
  String get mariaDbDataDir => p.join(storageDir, 'mariadb');
  String get sitesJsonFile => p.join(storageDir, 'sites.json');
  String get settingsJsonFile => p.join(storageDir, 'settings.json');
  String get demoSiteDir => p.join(binDir, 'demo-site');

  // Nginx Portable Directories
  String get nginxDir => p.join(binDir, 'nginx');
  String get nginxExe => p.join(nginxDir, 'nginx.exe');
  String get nginxConfDir => p.join(nginxDir, 'conf');
  String get nginxConfFile => p.join(nginxConfDir, 'nginx.conf');
  String get nginxVhostsDir => p.join(nginxConfDir, 'vhosts');

  // Apache HTTPD Portable Directories
  String get apacheDir => p.join(binDir, 'apache');
  String get apacheExe => p.join(apacheDir, 'bin', 'httpd.exe');
  String get apacheConfDir => p.join(apacheDir, 'conf');
  String get apacheConfFile => p.join(apacheConfDir, 'httpd.conf');
  String get apacheVhostsFile => p.join(apacheConfDir, 'extra', 'httpd-vhosts.conf');

  // SSL Certificate & Key Paths
  String get sslDir => p.join(storageDir, 'ssl');
  String get sslCaCertFile => p.join(sslDir, 'ca.crt');
  String get sslCaKeyFile => p.join(sslDir, 'ca.key');
  String get sslCertFile => p.join(sslDir, 'server.crt');
  String get sslKeyFile => p.join(sslDir, 'server.key');
  String get sslCnfFile => p.join(sslDir, 'openssl.cnf');

  String get opensslExe {
    final phpOpenssl = p.join(binDir, 'php', 'extras', 'openssl', 'openssl.exe');
    if (File(phpOpenssl).existsSync()) return phpOpenssl;
    final php74Openssl = p.join(binDir, 'php', 'php-7.4', 'extras', 'openssl', 'openssl.exe');
    if (File(php74Openssl).existsSync()) return php74Openssl;
    return 'openssl';
  }

  Map<String, dynamic>? _settingsCache;

  Map<String, dynamic> _loadSettings() {
    if (_settingsCache != null) return _settingsCache!;
    final file = File(settingsJsonFile);
    if (!file.existsSync()) {
      _settingsCache = {'active_web_engine': 'builtin'};
      return _settingsCache!;
    }
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      _settingsCache = json;
      return json;
    } catch (_) {
      _settingsCache = {'active_web_engine': 'builtin'};
      return _settingsCache!;
    }
  }

  void _saveSettings(Map<String, dynamic> settings) {
    _settingsCache = settings;
    ensureDirectories();
    final file = File(settingsJsonFile);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(settings));
  }

  String get activeWebEngine {
    final settings = _loadSettings();
    return settings['active_web_engine'] as String? ?? 'builtin';
  }

  void setActiveWebEngine(String engine) {
    if (engine == 'builtin' || engine == 'nginx' || engine == 'apache') {
      final settings = Map<String, dynamic>.from(_loadSettings());
      settings['active_web_engine'] = engine;
      _saveSettings(settings);
    }
  }

  String _detectBinDir() {
    final exeDir = p.dirname(Platform.resolvedExecutable);

    // 1. If running from bin/ itself (e.g. DevlikaStack-Portable/bin/DevlikaStack.exe)
    if (Directory(p.join(exeDir, 'php')).existsSync() ||
        Directory(p.join(exeDir, 'mariadb')).existsSync() ||
        Directory(p.join(exeDir, 'tools')).existsSync()) {
      return exeDir;
    }

    // 2. If running from bin/app/
    if (p.basename(exeDir).toLowerCase() == 'app') {
      final parent = p.dirname(exeDir);
      if (Directory(p.join(parent, 'php')).existsSync() ||
          Directory(p.join(parent, 'mariadb')).existsSync()) {
        return parent;
      }
    }

    // 3. If running from root next to bin/ (e.g. DevlikaStack-Portable/DevlikaStack.exe)
    final adjacentBin = p.join(exeDir, 'bin');
    if (Directory(adjacentBin).existsSync()) {
      return adjacentBin;
    }

    // 4. Development mode: current working directory or search upwards for bin/
    var current = Directory.current.path;
    if (Directory(p.join(current, 'bin', 'php')).existsSync() ||
        File(p.join(current, 'pubspec.yaml')).existsSync()) {
      final wsBin = p.join(current, 'bin');
      if (Directory(wsBin).existsSync()) return wsBin;
      // Fallback: create bin dir for development mode
      Directory(wsBin).createSync(recursive: true);
      return wsBin;
    }

    var check = exeDir;
    for (int i = 0; i < 5; i++) {
      if (Directory(p.join(check, 'bin', 'php')).existsSync() ||
          File(p.join(check, 'pubspec.yaml')).existsSync()) {
        return p.join(check, 'bin');
      }
      var parent = p.dirname(check);
      if (parent == check) break;
      check = parent;
    }

    return adjacentBin;
  }

  bool _directoriesEnsured = false;

  void ensureDirectories({bool force = false}) {
    if (_directoriesEnsured && !force && Directory(storageDir).existsSync()) return;
    try {
      Directory(binDir).createSync(recursive: true);
      Directory(phpDir).createSync(recursive: true);
      Directory(mariaDbDir).createSync(recursive: true);
      Directory(toolsDir).createSync(recursive: true);
      Directory(storageDir).createSync(recursive: true);
      Directory(mariaDbDataDir).createSync(recursive: true);
      Directory(demoSiteDir).createSync(recursive: true);
      _ensureDefaultDemoSite();
      _directoriesEnsured = true;
    } catch (_) {}
  }

  void _ensureDefaultDemoSite() {
    final indexFile = File(p.join(demoSiteDir, 'index.php'));
    if (!indexFile.existsSync()) {
      indexFile.writeAsStringSync('''<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>Devlika Stack - Portable Web Development Environment</title>
    <style>
        body { font-family: 'Segoe UI', system-ui, sans-serif; background: #0A0D14; color: #fff; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        .card { background: #161B26; border: 1px solid #283244; padding: 40px; border-radius: 16px; text-align: center; box-shadow: 0 10px 30px rgba(0,0,0,0.5); max-width: 500px; }
        h1 { color: #00D2FF; margin-top: 0; font-size: 26px; }
        p { color: #94A3B8; font-size: 15px; line-height: 1.6; }
        .badge { display: inline-block; background: rgba(0,210,255,0.15); color: #00D2FF; border: 1px solid rgba(0,210,255,0.4); border-radius: 20px; padding: 6px 16px; font-weight: 600; font-size: 13px; margin: 15px 0; }
        .info { background: #0F131C; border-radius: 10px; padding: 15px; margin-top: 20px; text-align: left; font-size: 13px; color: #CBD5E1; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Devlika Stack Aktif!</h1>
        <div class="badge">PHP <?php echo phpversion(); ?> &bull; MariaDB Portable</div>
        <p>Domain lokal <strong><?php echo \$_SERVER['HTTP_HOST'] ?? 'demo.local'; ?></strong> berhasil diarahkan ke folder <code>bin/demo-site</code>.</p>
        <div class="info">
            <div><strong>PHP CGI:</strong> Berjalan di Port 80</div>
            <div><strong>Database:</strong> MariaDB Port 3306</div>
            <div><strong>phpMyAdmin:</strong> Akses via Tab phpMyAdmin</div>
        </div>
    </div>
</body>
</html>
''');
    }

    final htaccessFile = File(p.join(demoSiteDir, '.htaccess'));
    if (!htaccessFile.existsSync()) {
      htaccessFile.writeAsStringSync('''# ==========================================
# Devlika Stack Default .htaccess Configuration
# ==========================================

Options -Indexes
Options +FollowSymlinks

RewriteEngine On

# Redirect Trailing Slashes if not a directory
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)/\$ /\$1 [L,R=301]

# Route all virtual URLs to index.php with PATH_INFO
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule .* index.php/\$0 [PT,L]

# Security: Block sensitive files
<FilesMatch ".*\\.(log|env|sql|sqlite|db)\$">
    Deny from all
</FilesMatch>
''');
    }
  }

  List<SiteModel>? _cachedSites;

  List<SiteModel> loadSites({bool forceReload = false}) {
    if (!forceReload && _cachedSites != null) {
      return _cachedSites!;
    }

    ensureDirectories();
    var file = File(sitesJsonFile);
    if (!file.existsSync()) {
      final defaultList = [
        SiteModel(
          id: 'demo-site-1',
          domain: 'demo.local',
          rootPath: demoSiteDir,
          type: 'php',
          proxyPort: 3000,
          isEnabled: true,
        ),
      ];
      saveSites(defaultList);
      _cachedSites = defaultList;
      return defaultList;
    }

    try {
      var content = file.readAsStringSync();
      var list = jsonDecode(content) as List;
      var sites = list.map((e) => SiteModel.fromJson(e)).toList();
      // Auto-fix demo-site path if folder moved to different machine/drive
      bool modified = false;
      for (var site in sites) {
        if (site.id == 'demo-site-1' && !Directory(site.rootPath).existsSync()) {
          site.rootPath = demoSiteDir;
          modified = true;
        }
      }
      if (modified) {
        saveSites(sites);
      }
      _cachedSites = sites;
      return sites;
    } catch (_) {
      _cachedSites = [];
      return [];
    }
  }

  void saveSites(List<SiteModel> sites) {
    _cachedSites = List.from(sites);
    ensureDirectories();
    var file = File(sitesJsonFile);
    var jsonStr = const JsonEncoder.withIndent('  ')
        .convert(sites.map((e) => e.toJson()).toList());
    file.writeAsStringSync(jsonStr);
  }

  void invalidateSitesCache() {
    _cachedSites = null;
  }
}

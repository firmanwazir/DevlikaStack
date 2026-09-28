import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'config_service.dart';
import 'mariadb_manager.dart';
import 'php_manager.dart';
import 'vhost_config_generator.dart';

class ComponentDownloader {
  static final ComponentDownloader instance = ComponentDownloader._();
  ComponentDownloader._();

  Future<void> installPhp({
    required Function(String msg, double progress) onProgress,
  }) async {
    final config = ConfigService.instance;
    config.ensureDirectories();

    // Check local source first (XAMPP / Laragon)
    final localSources = [
      r'D:\WebServer\xampp\php',
      r'D:\WebServer\laragon\bin\php',
      r'C:\PhpWebStudy-Data\env\php',
    ];

    String? foundLocal;
    for (var s in localSources) {
      if (File(p.join(s, 'php.exe')).existsSync()) {
        foundLocal = s;
        break;
      }
    }

    if (foundLocal != null) {
      onProgress('Menyalin PHP dari sistem lokal ($foundLocal)...', 0.3);
      await _copyDirectory(Directory(foundLocal), Directory(config.phpDir));
      _ensurePhpIni(config.phpDir);
      PhpManager.instance.clearCache();
      onProgress('PHP Portable siap digunakan!', 1.0);
      return;
    }

    // Official Windows PHP 8.2 zip
    onProgress('Mengunduh PHP Portable dari server resmi...', 0.1);
    const url = 'https://windows.php.net/downloads/releases/archives/php-8.2.18-nts-Win32-vs16-x64.zip';
    final tempZip = p.join(config.binDir, 'temp_php.zip');

    try {
      await _downloadFile(url, tempZip, (pct) => onProgress('Mengunduh PHP (${(pct * 100).toInt()}%)...', pct * 0.7));
      onProgress('Mengekstrak PHP ke bin/php...', 0.75);

      final bytes = File(tempZip).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      final normPhpDir = p.normalize(config.phpDir);
      for (final file in archive) {
        final filename = p.normalize(p.join(normPhpDir, file.name));
        if (!p.isWithin(normPhpDir, filename)) {
          throw Exception('Zip Slip terdeteksi pada file: ${file.name}');
        }
        if (file.isFile) {
          final outFile = File(filename);
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(filename).createSync(recursive: true);
        }
      }

      _ensurePhpIni(config.phpDir);
      PhpManager.instance.clearCache();
      onProgress('PHP Portable berhasil dipasang!', 1.0);
    } finally {
      final f = File(tempZip);
      if (f.existsSync()) f.deleteSync();
    }
  }

  Future<void> installMariaDb({
    required Function(String msg, double progress) onProgress,
  }) async {
    final config = ConfigService.instance;
    config.ensureDirectories();

    final localSources = [
      r'C:\PhpWebStudy-Data\env\mariadb',
      r'D:\WebServer\xampp\mysql',
      r'D:\WebServer\laragon\bin\mysql',
    ];

    String? foundLocal;
    for (var s in localSources) {
      if (File(p.join(s, 'bin', 'mysqld.exe')).existsSync()) {
        foundLocal = s;
        break;
      }
    }

    if (foundLocal != null) {
      onProgress('Menyalin MariaDB dari lokal ($foundLocal)...', 0.3);
      await _copyDirectory(Directory(foundLocal), Directory(config.mariaDbDir));
      onProgress('Menginisialisasi database...', 0.8);
      await MariaDbManager.instance.initializeDatabase();
      onProgress('MariaDB siap digunakan!', 1.0);
      return;
    }

    onProgress('Mengunduh MariaDB Portable resmi...', 0.1);
    const url = 'https://archive.mariadb.org/mariadb-11.4.3/winx64-packages/mariadb-11.4.3-winx64.zip';
    final tempZip = p.join(config.binDir, 'temp_mariadb.zip');

    try {
      await _downloadFile(url, tempZip, (pct) => onProgress('Mengunduh MariaDB (${(pct * 100).toInt()}%)...', pct * 0.7));
      onProgress('Mengekstrak MariaDB...', 0.75);

      final bytes = File(tempZip).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      final normMariaDbDir = p.normalize(config.mariaDbDir);
      for (final file in archive) {
        // Strip top-level folder from ZIP (e.g. "mariadb-11.4.3-winx64/bin/..." → "bin/...")
        var name = file.name;
        final slashIdx = name.indexOf('/');
        if (slashIdx >= 0) name = name.substring(slashIdx + 1);
        if (name.isEmpty) continue;

        final filename = p.normalize(p.join(normMariaDbDir, name));
        if (!p.isWithin(normMariaDbDir, filename)) {
          throw Exception('Zip Slip terdeteksi pada file: ${file.name}');
        }
        if (file.isFile) {
          final outFile = File(filename);
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(filename).createSync(recursive: true);
        }
      }

      await MariaDbManager.instance.initializeDatabase();
      onProgress('MariaDB Portable berhasil dipasang!', 1.0);
    } finally {
      final f = File(tempZip);
      if (f.existsSync()) f.deleteSync();
    }
  }

  Future<void> installPhpMyAdmin({
    required Function(String msg, double progress) onProgress,
  }) async {
    final config = ConfigService.instance;
    config.ensureDirectories();

    final localSources = [
      r'D:\WebServer\xampp\phpMyAdmin',
      r'D:\WebServer\laragon\etc\apps\phpMyAdmin',
    ];

    String? foundLocal;
    for (var s in localSources) {
      if (File(p.join(s, 'index.php')).existsSync()) {
        foundLocal = s;
        break;
      }
    }

    if (foundLocal != null) {
      onProgress('Menyalin phpMyAdmin dari lokal...', 0.4);
      await _copyDirectory(Directory(foundLocal), Directory(config.phpMyAdminDir));
      _ensurePhpMyAdminConfig(config.phpMyAdminDir);
      onProgress('phpMyAdmin siap digunakan!', 1.0);
      return;
    }

    onProgress('Mengunduh phpMyAdmin resmi...', 0.1);
    const url = 'https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip';
    final tempZip = p.join(config.binDir, 'temp_pma.zip');

    try {
      await _downloadFile(url, tempZip, (pct) => onProgress('Mengunduh phpMyAdmin (${(pct * 100).toInt()}%)...', pct * 0.7));
      onProgress('Mengekstrak phpMyAdmin...', 0.75);

      final bytes = File(tempZip).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      final normPmaDir = p.normalize(config.phpMyAdminDir);
      for (final file in archive) {
        // Strip top-level folder from ZIP (e.g. "phpMyAdmin-5.2.1-all-languages/index.php" → "index.php")
        var name = file.name;
        final slashIdx = name.indexOf('/');
        if (slashIdx >= 0) name = name.substring(slashIdx + 1);
        if (name.isEmpty) continue;

        final filename = p.normalize(p.join(normPmaDir, name));
        if (!p.isWithin(normPmaDir, filename)) {
          throw Exception('Zip Slip terdeteksi pada file: ${file.name}');
        }
        if (file.isFile) {
          final outFile = File(filename);
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(filename).createSync(recursive: true);
        }
      }

      _ensurePhpMyAdminConfig(config.phpMyAdminDir);
      onProgress('phpMyAdmin berhasil dipasang!', 1.0);
    } finally {
      final f = File(tempZip);
      if (f.existsSync()) f.deleteSync();
    }
  }

  Future<void> installNginx({
    required Function(String msg, double progress) onProgress,
  }) async {
    final config = ConfigService.instance;
    config.ensureDirectories();

    final localSources = [
      r'C:\PhpWebStudy-Data\env\nginx',
      r'D:\WebServer\laragon\bin\nginx',
      r'C:\laragon\bin\nginx',
    ];

    String? foundLocal;
    for (var s in localSources) {
      if (File(p.join(s, 'nginx.exe')).existsSync()) {
        foundLocal = s;
        break;
      }
    }

    if (foundLocal != null) {
      onProgress('Menyalin Nginx dari sistem lokal ($foundLocal)...', 0.3);
      await _copyDirectory(Directory(foundLocal), Directory(config.nginxDir));
      await VhostConfigGenerator.instance.generateNginxConfigs(config.loadSites());
      onProgress('Nginx 1.26 Portable siap digunakan!', 1.0);
      return;
    }

    onProgress('Mengunduh Nginx 1.26 Portable resmi...', 0.1);
    const url = 'https://nginx.org/download/nginx-1.26.2.zip';
    final tempZip = p.join(config.binDir, 'temp_nginx.zip');

    try {
      await _downloadFile(url, tempZip, (pct) => onProgress('Mengunduh Nginx (${(pct * 100).toInt()}%)...', pct * 0.7));
      onProgress('Mengekstrak Nginx ke bin/nginx...', 0.75);

      final bytes = File(tempZip).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      final normNginxDir = p.normalize(config.nginxDir);
      for (final file in archive) {
        var relPath = file.name;
        final slashIdx = relPath.indexOf('/');
        if (slashIdx != -1) {
          relPath = relPath.substring(slashIdx + 1);
        }
        if (relPath.isEmpty) continue;

        final filename = p.normalize(p.join(normNginxDir, relPath));
        if (!p.isWithin(normNginxDir, filename)) {
          throw Exception('Zip Slip terdeteksi pada file: ${file.name}');
        }
        if (file.isFile) {
          final outFile = File(filename);
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(filename).createSync(recursive: true);
        }
      }

      await VhostConfigGenerator.instance.generateNginxConfigs(config.loadSites());
      onProgress('Nginx 1.26 Portable berhasil dipasang!', 1.0);
    } finally {
      final f = File(tempZip);
      if (f.existsSync()) f.deleteSync();
    }
  }

  Future<void> installApache({
    required Function(String msg, double progress) onProgress,
  }) async {
    final config = ConfigService.instance;
    config.ensureDirectories();

    final localSources = [
      r'C:\PhpWebStudy-Data\env\apache',
      r'D:\WebServer\xampp\apache',
      r'D:\WebServer\laragon\bin\apache',
      r'C:\xampp\apache',
    ];

    String? foundLocal;
    for (var s in localSources) {
      if (File(p.join(s, 'bin', 'httpd.exe')).existsSync()) {
        foundLocal = s;
        break;
      }
    }

    if (foundLocal != null) {
      onProgress('Menyalin Apache dari sistem lokal ($foundLocal)...', 0.3);
      await _copyDirectory(Directory(foundLocal), Directory(config.apacheDir));
      await VhostConfigGenerator.instance.generateApacheConfigs(config.loadSites());
      onProgress('Apache HTTPD 2.4 siap digunakan!', 1.0);
      return;
    }

    onProgress('Mengunduh Apache 2.4 Portable...', 0.1);
    const url = 'https://www.apachelounge.com/download/VS17/binaries/httpd-2.4.62-240904-win64-VS17.zip';
    final tempZip = p.join(config.binDir, 'temp_apache.zip');

    try {
      await _downloadFile(url, tempZip, (pct) => onProgress('Mengunduh Apache (${(pct * 100).toInt()}%)...', pct * 0.7));
      onProgress('Mengekstrak Apache ke bin/apache...', 0.75);

      final bytes = File(tempZip).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      final normApacheDir = p.normalize(config.apacheDir);
      for (final file in archive) {
        var relPath = file.name;
        if (relPath.startsWith('Apache24/')) {
          relPath = relPath.substring('Apache24/'.length);
        }
        if (relPath.isEmpty) continue;

        final filename = p.normalize(p.join(normApacheDir, relPath));
        if (!p.isWithin(normApacheDir, filename)) {
          throw Exception('Zip Slip terdeteksi pada file: ${file.name}');
        }
        if (file.isFile) {
          final outFile = File(filename);
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(filename).createSync(recursive: true);
        }
      }

      await VhostConfigGenerator.instance.generateApacheConfigs(config.loadSites());
      onProgress('Apache HTTPD 2.4 berhasil dipasang!', 1.0);
    } finally {
      final f = File(tempZip);
      if (f.existsSync()) f.deleteSync();
    }
  }

  Future<void> _downloadFile(
    String url,
    String savePath,
    Function(double progress) onProgress,
  ) async {
    final client = http.Client();
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw HttpException(
          'Gagal mengunduh berkas (HTTP ${response.statusCode}: ${response.reasonPhrase ?? "Error"}).',
          uri: Uri.parse(url),
        );
      }

      final total = response.contentLength ?? 1;
      int received = 0;
      final file = File(savePath);
      sink = file.openWrite();

      await response.stream.listen((chunk) {
        received += chunk.length;
        sink?.add(chunk);
        onProgress(received / total);
      }).asFuture();
    } finally {
      if (sink != null) {
        await sink.close();
      }
      client.close();
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      if (entity is Directory) {
        final newDirectory = Directory(p.join(destination.path, p.basename(entity.path)));
        await _copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        await entity.copy(p.join(destination.path, p.basename(entity.path)));
      }
    }
  }

  void _ensurePhpIni(String phpDir) {
    final iniPath = p.join(phpDir, 'php.ini');
    final defaultIni = p.join(phpDir, 'php.ini-development');
    if (!File(iniPath).existsSync() && File(defaultIni).existsSync()) {
      File(defaultIni).copySync(iniPath);
    }

    if (File(iniPath).existsSync()) {
      var content = File(iniPath).readAsStringSync();
      // Ensure relative extension_dir
      content = content.replaceAll(RegExp(r'^;?\s*extension_dir\s*=.*$', multiLine: true), 'extension_dir = "ext"');

      // Comprehensive extensions for Laravel, CodeIgniter, WordPress, etc.
      final extensions = [
        'bz2',
        'curl',
        'fileinfo',
        'gd',
        'gd2',
        'gettext',
        'intl',
        'mbstring',
        'exif',
        'mysqli',
        'openssl',
        'pdo_mysql',
        'pdo_sqlite',
        'sqlite3',
        'pgsql',
        'pdo_pgsql',
        'sodium',
        'soap',
        'sockets',
        'zip',
      ];

      for (var ext in extensions) {
        content = content.replaceAll(RegExp('^;\\s*extension\\s*=\\s*$ext\\b', multiLine: true), 'extension=$ext');
        content = content.replaceAll(RegExp('^;\\s*extension\\s*=\\s*php_$ext\\.dll\\b', multiLine: true), 'extension=php_$ext.dll');
      }

      // Avoid duplicates causing warnings
      content = content.replaceAll('extension=php_openssl.dll', ';extension=php_openssl.dll');
      content = content.replaceAll('extension=php_ftp.dll', ';extension=php_ftp.dll');
      content = content.replaceAll('extension=php_mysqli.dll', ';extension=php_mysqli.dll');

      // Limits & settings for modern frameworks
      content = content.replaceAll(RegExp(r'^;?\s*memory_limit\s*=.*$', multiLine: true), 'memory_limit = 512M');
      content = content.replaceAll(RegExp(r'^;?\s*upload_max_filesize\s*=.*$', multiLine: true), 'upload_max_filesize = 128M');
      content = content.replaceAll(RegExp(r'^;?\s*post_max_size\s*=.*$', multiLine: true), 'post_max_size = 128M');
      content = content.replaceAll(RegExp(r'^;?\s*max_execution_time\s*=.*$', multiLine: true), 'max_execution_time = 300');
      content = content.replaceAll(RegExp(r'^;?\s*max_input_vars\s*=.*$', multiLine: true), 'max_input_vars = 5000');
      content = content.replaceAll(RegExp(r'^;?\s*cgi\.fix_pathinfo\s*=.*$', multiLine: true), 'cgi.fix_pathinfo = 1');
      content = content.replaceAll(RegExp(r'^;?\s*date\.timezone\s*=.*$', multiLine: true), 'date.timezone = Asia/Jakarta');
      content = content.replaceAll(RegExp(r'^;?\s*realpath_cache_size\s*=.*$', multiLine: true), 'realpath_cache_size = 16M');
      content = content.replaceAll(RegExp(r'^;?\s*realpath_cache_ttl\s*=.*$', multiLine: true), 'realpath_cache_ttl = 600');
      content = content.replaceAll(RegExp(r'^;?\s*mysqlnd\.collect_statistics\s*=.*$', multiLine: true), 'mysqlnd.collect_statistics = Off');
      content = content.replaceAll(RegExp(r'^;?\s*mysqlnd\.collect_memory_statistics\s*=.*$', multiLine: true), 'mysqlnd.collect_memory_statistics = Off');

      // Zend OPcache Turbo Bytecode Accelerator
      if (RegExp(r'^;\s*zend_extension\s*=\s*"?opcache"?', multiLine: true).hasMatch(content)) {
        content = content.replaceAll(RegExp(r'^;\s*zend_extension\s*=\s*"?opcache"?', multiLine: true), 'zend_extension=opcache');
      } else if (!RegExp(r'^\s*zend_extension\s*=\s*"?opcache"?', multiLine: true).hasMatch(content)) {
        content += '\nzend_extension=opcache\n';
      }

      content = content.replaceAll(RegExp(r'^;?\s*opcache\.enable\s*=.*$', multiLine: true), 'opcache.enable=1');
      content = content.replaceAll(RegExp(r'^;?\s*opcache\.enable_cli\s*=.*$', multiLine: true), 'opcache.enable_cli=1');
      content = content.replaceAll(RegExp(r'^;?\s*opcache\.memory_consumption\s*=.*$', multiLine: true), 'opcache.memory_consumption=256');
      content = content.replaceAll(RegExp(r'^;?\s*opcache\.interned_strings_buffer\s*=.*$', multiLine: true), 'opcache.interned_strings_buffer=16');
      content = content.replaceAll(RegExp(r'^;?\s*opcache\.max_accelerated_files\s*=.*$', multiLine: true), 'opcache.max_accelerated_files=20000');
      content = content.replaceAll(RegExp(r'^;?\s*opcache\.revalidate_freq\s*=.*$', multiLine: true), 'opcache.revalidate_freq=0');
      content = content.replaceAll(RegExp(r'^;?\s*opcache\.validate_timestamps\s*=.*$', multiLine: true), 'opcache.validate_timestamps=1');
      content = content.replaceAll(RegExp(r'^;?\s*opcache\.save_comments\s*=.*$', multiLine: true), 'opcache.save_comments=1');

      File(iniPath).writeAsStringSync(content);
    }
  }

  void _ensurePhpMyAdminConfig(String pmaDir) {
    final configPath = p.join(pmaDir, 'config.inc.php');
    if (!File(configPath).existsSync()) {
      final sample = p.join(pmaDir, 'config.sample.inc.php');
      if (File(sample).existsSync()) {
        var content = File(sample).readAsStringSync();
        content = content.replaceAll("AllowNoPassword'] = false;", "AllowNoPassword'] = true;");
        File(configPath).writeAsStringSync(content);
      }
    }
  }
}

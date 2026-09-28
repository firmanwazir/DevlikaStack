import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../models/php_version_model.dart';
import 'config_service.dart';
import 'vhost_config_generator.dart';

class PhpManager {
  static final PhpManager instance = PhpManager._();
  PhpManager._();

  final List<PhpVersionModel> _definitions = [
    const PhpVersionModel(
      versionKey: '7.4',
      name: 'PHP 7.4 (Legacy / CI3)',
      dirPath: '',
      isInstalled: false,
      exactVersion: '7.4.33',
      downloadUrl: 'https://windows.php.net/downloads/releases/archives/php-7.4.33-nts-Win32-vc15-x64.zip',
    ),
    const PhpVersionModel(
      versionKey: '8.1',
      name: 'PHP 8.1 (Laravel 9/10)',
      dirPath: '',
      isInstalled: false,
      exactVersion: '8.1.30',
      downloadUrl: 'https://windows.php.net/downloads/releases/archives/php-8.1.30-nts-Win32-vs16-x64.zip',
    ),
    const PhpVersionModel(
      versionKey: '8.2',
      name: 'PHP 8.2 (Laravel 10/11 / CI4)',
      dirPath: '',
      isInstalled: false,
      exactVersion: '8.2.18',
      downloadUrl: 'https://windows.php.net/downloads/releases/archives/php-8.2.18-nts-Win32-vs16-x64.zip',
    ),
    const PhpVersionModel(
      versionKey: '8.3',
      name: 'PHP 8.3 (Terbaru)',
      dirPath: '',
      isInstalled: false,
      exactVersion: '8.3.6',
      downloadUrl: 'https://windows.php.net/downloads/releases/archives/php-8.3.6-nts-Win32-vs16-x64.zip',
    ),
  ];

  List<PhpVersionModel>? _cachedVersions;
  final Map<String, String> _versionCache = {};

  void clearCache() {
    _cachedVersions = null;
    _versionCache.clear();
  }

  List<PhpVersionModel> getVersions({bool forceReload = false}) {
    if (!forceReload && _cachedVersions != null) {
      return _cachedVersions!;
    }

    final phpBase = ConfigService.instance.phpBaseDir;
    final results = <PhpVersionModel>[];

    for (var def in _definitions) {
      var dir = p.join(phpBase, 'php-${def.versionKey}');
      var exe = p.join(dir, 'php.exe');
      var isInstalled = File(exe).existsSync();
      if (!isInstalled) {
        final altDir = p.join(phpBase, 'php${def.versionKey}');
        final altExe = p.join(altDir, 'php.exe');
        if (File(altExe).existsSync()) {
          dir = altDir;
          exe = altExe;
          isInstalled = true;
        }
      }

      results.add(PhpVersionModel(
        versionKey: def.versionKey,
        name: def.name,
        dirPath: dir,
        isInstalled: isInstalled,
        exactVersion: isInstalled ? _detectExactVersion(exe) : def.exactVersion,
        downloadUrl: def.downloadUrl,
      ));
    }

    _cachedVersions = results;
    return results;
  }

  String _detectExactVersion(String exePath) {
    if (_versionCache.containsKey(exePath)) {
      return _versionCache[exePath]!;
    }

    try {
      final res = Process.runSync(exePath, ['-v'], runInShell: false);
      if (res.exitCode == 0) {
        final line = res.stdout.toString().split('\n').first;
        final match = RegExp(r'PHP\s+([0-9\.]+)').firstMatch(line);
        if (match != null) {
          _versionCache[exePath] = match.group(1)!;
          return match.group(1)!;
        }
      }
    } catch (_) {}
    _versionCache[exePath] = 'Portable';
    return 'Portable';
  }

  Future<void> installVersion(
    String versionKey, {
    required Function(String msg, double progress) onProgress,
  }) async {
    final phpBase = ConfigService.instance.phpBaseDir;
    final targetDir = p.join(phpBase, 'php-$versionKey');
    Directory(targetDir).createSync(recursive: true);

    // 1. Look for local sources first
    final localCandidates = _getLocalCandidates(versionKey);
    for (var src in localCandidates) {
      if (File(p.join(src, 'php.exe')).existsSync() && File(p.join(src, 'php-cgi.exe')).existsSync()) {
        onProgress('Menyalin PHP $versionKey dari sistem lokal...', 0.4);
        await _copyDirectory(Directory(src), Directory(targetDir));
        optimizePhpIni(targetDir);
        clearCache();
        onProgress('PHP $versionKey siap digunakan!', 1.0);
        return;
      }
    }

    // 2. Download from official windows.php.net
    final def = _definitions.firstWhere((d) => d.versionKey == versionKey);
    final tempZip = p.join(ConfigService.instance.binDir, 'temp_php_$versionKey.zip');
    onProgress('Mengunduh PHP $versionKey resmi...', 0.1);

    final client = http.Client();
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(def.downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw HttpException('Gagal mengunduh PHP $versionKey (HTTP ${response.statusCode}).');
      }

      final totalBytes = response.contentLength ?? 30000000;
      var receivedBytes = 0;
      final file = File(tempZip);
      sink = file.openWrite();

      await response.stream.listen((chunk) {
        receivedBytes += chunk.length;
        sink?.add(chunk);
        onProgress('Mengunduh PHP $versionKey (${(receivedBytes / totalBytes * 100).toInt()}%)...', (receivedBytes / totalBytes) * 0.7);
      }).asFuture();

      await sink.close();
      sink = null;

      onProgress('Mengekstrak PHP $versionKey...', 0.8);
      final bytes = file.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      final normTargetDir = p.normalize(targetDir);
      for (final f in archive) {
        final outPath = p.normalize(p.join(normTargetDir, f.name));
        if (!p.isWithin(normTargetDir, outPath)) {
          throw Exception('Zip Slip terdeteksi pada file: ${f.name}');
        }
        if (f.isFile) {
          final outFile = File(outPath);
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(f.content as List<int>);
        } else {
          Directory(outPath).createSync(recursive: true);
        }
      }

      optimizePhpIni(targetDir);
      clearCache();
      onProgress('PHP $versionKey berhasil dipasang!', 1.0);
    } catch (e) {
      onProgress('Gagal mengunduh PHP $versionKey: $e', 0.0);
      rethrow;
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      client.close();
      final f = File(tempZip);
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }

  Future<void> uninstallVersion(String versionKey) async {
    // Terminate any active FastCGI process using this version on Windows
    final port = VhostConfigGenerator.getFastCgiPort(versionKey);
    try {
      if (Platform.isWindows) {
        await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          'Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id \$_.OwningProcess -Force -ErrorAction SilentlyContinue }'
        ]);
      }
    } catch (_) {}

    final phpBase = ConfigService.instance.phpBaseDir;
    final targetDir = Directory(p.join(phpBase, 'php-$versionKey'));
    if (targetDir.existsSync()) {
      try {
        targetDir.deleteSync(recursive: true);
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 300));
        try {
          targetDir.deleteSync(recursive: true);
        } catch (_) {}
      }
      clearCache();
    }
  }

  List<String> _getLocalCandidates(String versionKey) {
    if (versionKey == '7.4') {
      return [
        r'D:\WebServer\xampp\php',
        r'C:\PhpWebStudy-Data\app\php-7.4.33',
        r'D:\WebServer\laragon\bin\php\php-7.4.33-nts-Win32-vs16-x64',
      ];
    } else if (versionKey == '8.1') {
      return [
        r'D:\WebServer\laragon\bin\php\php-8.1.30-nts-Win32-vs16-x64',
      ];
    } else if (versionKey == '8.2') {
      return [
        r'C:\Program Files\Ampps\php82',
        r'D:\WebServer\laragon\bin\php\php-8.2.20-Win32-vs16-x64',
      ];
    } else if (versionKey == '8.3') {
      return [
        r'D:\WebServer\laragon\bin\php\php-8.3.16-Win32-vs16-x64',
      ];
    }
    return [];
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        try {
          await entity.copy(newPath);
        } catch (_) {}
      }
    }
  }

  void optimizePhpIni(String phpDir) {
    final iniPath = p.join(phpDir, 'php.ini');
    final defaultIni = p.join(phpDir, 'php.ini-development');
    final prodIni = p.join(phpDir, 'php.ini-production');

    if (!File(iniPath).existsSync()) {
      if (File(defaultIni).existsSync()) {
        File(defaultIni).copySync(iniPath);
      } else if (File(prodIni).existsSync()) {
        File(prodIni).copySync(iniPath);
      }
    }

    if (!File(iniPath).existsSync()) return;

    var content = File(iniPath).readAsStringSync();

    // 1. Portable extension_dir
    content = content.replaceAll(RegExp(r'^;?\s*extension_dir\s*=.*$', multiLine: true), 'extension_dir = "ext"');

    // 2. Enable critical extensions for Laravel & CodeIgniter
    final exts = [
      'bz2', 'curl', 'fileinfo', 'gd', 'gd2', 'gettext', 'intl', 'mbstring',
      'exif', 'mysqli', 'openssl', 'pdo_mysql', 'pdo_sqlite', 'sqlite3',
      'pgsql', 'pdo_pgsql', 'sodium', 'soap', 'sockets', 'zip'
    ];

    for (var ext in exts) {
      content = content.replaceAll(RegExp('^;\\s*extension\\s*=\\s*$ext\\b', multiLine: true), 'extension=$ext');
      content = content.replaceAll(RegExp('^;\\s*extension\\s*=\\s*php_$ext\\.dll\\b', multiLine: true), 'extension=php_$ext.dll');
    }

    // Clean duplicates that cause startup warnings
    content = content.replaceAll('extension=php_openssl.dll', ';extension=php_openssl.dll');
    content = content.replaceAll('extension=php_ftp.dll', ';extension=php_ftp.dll');
    content = content.replaceAll(RegExp(r'^error_log\s*=.*$', multiLine: true), ';error_log = "logs/php_error.log"');

    // Ensure portable session and upload dirs (use Windows default temp)
    content = content.replaceAll(RegExp(r'^session\.save_path\s*=.*$', multiLine: true), ';session.save_path = ""');
    content = content.replaceAll(RegExp(r'^upload_tmp_dir\s*=.*$', multiLine: true), ';upload_tmp_dir = ""');

    // 3. Recommended values
    content = _replaceDirective(content, 'memory_limit', '512M');
    content = _replaceDirective(content, 'upload_max_filesize', '128M');
    content = _replaceDirective(content, 'post_max_size', '128M');
    content = _replaceDirective(content, 'max_execution_time', '300');
    content = _replaceDirective(content, 'max_input_vars', '5000');
    content = _replaceDirective(content, 'cgi.fix_pathinfo', '1');
    content = _replaceDirective(content, 'date.timezone', 'Asia/Jakarta');
    content = _replaceDirective(content, 'realpath_cache_size', '4096k');
    content = _replaceDirective(content, 'realpath_cache_ttl', '600');

    // 4. Zend OPcache Turbo Bytecode Accelerator
    if (!content.contains('zend_extension=opcache') && !content.contains('zend_extension="opcache"')) {
      content += '''

; --- Devlika Stack Turbo OPcache Configuration ---
zend_extension=opcache
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=128
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.revalidate_freq=0
opcache.validate_timestamps=1
''';
    } else {
      content = content.replaceAll(RegExp(r'^;?\s*zend_extension\s*=\s*"?opcache"?', multiLine: true), 'zend_extension=opcache');
      content = content.replaceAll(RegExp(r'^;?\s*opcache\.enable\s*=.*$', multiLine: true), 'opcache.enable=1');
      content = content.replaceAll(RegExp(r'^;?\s*opcache\.validate_timestamps\s*=.*$', multiLine: true), 'opcache.validate_timestamps=1');
      content = content.replaceAll(RegExp(r'^;?\s*opcache\.revalidate_freq\s*=.*$', multiLine: true), 'opcache.revalidate_freq=0');
    }

    File(iniPath).writeAsStringSync(content);
  }

  Map<String, String> readDirectives(String iniPath) {
    final values = <String, String>{
      'memory_limit': '512M',
      'upload_max_filesize': '128M',
      'post_max_size': '128M',
      'max_execution_time': '300',
      'max_input_vars': '5000',
      'cgi.fix_pathinfo': '1',
      'date.timezone': 'Asia/Jakarta',
      'display_errors': 'On',
    };

    final file = File(iniPath);
    if (!file.existsSync()) return values;

    final content = file.readAsStringSync();
    for (var key in values.keys) {
      final reg = RegExp('^;?\\s*${RegExp.escape(key)}\\s*=\\s*["\']?([^"\'\\r\\n;]+)["\']?', multiLine: true);
      final match = reg.firstMatch(content);
      if (match != null) {
        values[key] = match.group(1)?.trim() ?? values[key]!;
      }
    }
    return values;
  }

  void saveDirectives(String iniPath, Map<String, String> newValues) {
    final file = File(iniPath);
    if (!file.existsSync()) return;

    var content = file.readAsStringSync();
    newValues.forEach((key, val) {
      content = _replaceDirective(content, key, val);
    });
    file.writeAsStringSync(content);
  }

  String _replaceDirective(String content, String key, String value) {
    final reg = RegExp('^;?\\s*${RegExp.escape(key)}\\s*=.*\$', multiLine: true);
    if (reg.hasMatch(content)) {
      return content.replaceAll(reg, '$key = $value');
    } else {
      return '$content\n$key = $value';
    }
  }
}

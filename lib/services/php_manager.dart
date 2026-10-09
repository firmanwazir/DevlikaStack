import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../models/php_version_model.dart';
import '../models/php_extension_model.dart';
import 'config_service.dart';
import 'http_server_service.dart';
import 'vhost_config_generator.dart';

class PhpManager {
  static final PhpManager instance = PhpManager._();
  PhpManager._();

  final Map<String, Future<void>> _locks = {};

  Future<T> _synchronized<T>(String key, Future<T> Function() action) async {
    final prev = _locks[key] ?? Future.value();
    final completer = Completer<void>();
    _locks[key] = completer.future;
    try {
      await prev;
      return await action();
    } finally {
      completer.complete();
    }
  }

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

  final Set<String> _optimizedDirs = {};

  void clearCache() {
    _cachedVersions = null;
    _versionCache.clear();
    _optimizedDirs.clear();
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

      if (isInstalled && !_optimizedDirs.contains(dir)) {
        _optimizedDirs.add(dir);
        final ini = p.join(dir, 'php.ini');
        if (!File(ini).existsSync() || !File(ini).readAsStringSync().contains('opcache.memory_consumption=256')) {
          try {
            optimizePhpIni(dir);
          } catch (_) {}
        }
      }

      results.add(PhpVersionModel(
        versionKey: def.versionKey,
        name: def.name,
        dirPath: dir,
        isInstalled: isInstalled,
        exactVersion: isInstalled ? _detectExactVersion(exe, def.exactVersion) : def.exactVersion,
        downloadUrl: def.downloadUrl,
      ));
    }

    _cachedVersions = results;
    return results;
  }

  String _detectExactVersion(String exePath, String fallbackVersion) {
    if (_versionCache.containsKey(exePath)) {
      return _versionCache[exePath]!;
    }

    _versionCache[exePath] = fallbackVersion;
    // Asynchronously detect in background without stalling the main UI thread
    Process.run(exePath, ['-v'], runInShell: false).then((res) {
      if (res.exitCode == 0) {
        final line = res.stdout.toString().split('\n').first;
        final match = RegExp(r'PHP\s+([0-9\.]+)').firstMatch(line);
        if (match != null) {
          _versionCache[exePath] = match.group(1)!;
        }
      }
    }).catchError((_) {});

    return fallbackVersion;
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

    // 2. Enable critical extensions matching available DLLs
    final extDir = p.join(phpDir, 'ext');
    final availableDlls = <String>{};
    if (Directory(extDir).existsSync()) {
      for (final f in Directory(extDir).listSync()) {
        if (f is File && f.path.toLowerCase().endsWith('.dll')) {
          availableDlls.add(p.basename(f.path).toLowerCase());
        }
      }
    }

    final exts = [
      'bz2', 'curl', 'fileinfo', 'gettext', 'intl', 'mbstring',
      'exif', 'mysqli', 'openssl', 'pdo_mysql', 'pdo_sqlite', 'sqlite3',
      'pgsql', 'pdo_pgsql', 'sodium', 'soap', 'sockets'
    ];

    final isPhp74 = phpDir.contains('php-7.4') || phpDir.contains('php7');

    for (var ext in exts) {
      if (availableDlls.isEmpty || availableDlls.contains('php_$ext.dll')) {
        content = content.replaceAll(RegExp('^;\\s*extension\\s*=\\s*$ext\\b', multiLine: true), 'extension=$ext');
        content = content.replaceAll(RegExp('^;\\s*extension\\s*=\\s*php_$ext\\.dll\\b', multiLine: true), 'extension=$ext');
      }
    }

    if (isPhp74) {
      content = content.replaceAll(RegExp(r'^\s*extension\s*=\s*gd\b', multiLine: true), ';extension=gd');
      content = content.replaceAll(RegExp(r'^\s*extension\s*=\s*zip\b', multiLine: true), ';extension=zip');
      content = content.replaceAll(RegExp(r'^;\s*extension\s*=\s*gd2\b', multiLine: true), 'extension=gd2');
      content = content.replaceAll(RegExp(r'^;\s*extension\s*=\s*php_gd2\.dll\b', multiLine: true), 'extension=gd2');
    } else {
      if (availableDlls.isEmpty || availableDlls.contains('php_gd.dll')) {
        if (!phpDir.contains('php-8.1')) {
          content = content.replaceAll(RegExp(r'^;\s*extension\s*=\s*gd\b', multiLine: true), 'extension=gd');
        }
      }
      if (availableDlls.isEmpty || availableDlls.contains('php_zip.dll')) {
        content = content.replaceAll(RegExp(r'^;\s*extension\s*=\s*zip\b', multiLine: true), 'extension=zip');
      }
    }

    // Clean duplicates that cause startup warnings
    content = content.replaceAll('extension=php_openssl.dll', ';extension=php_openssl.dll');
    content = content.replaceAll('extension=php_ftp.dll', ';extension=php_ftp.dll');
    content = content.replaceAll('extension=php_mysqli.dll', ';extension=php_mysqli.dll');
    content = content.replaceAll('extension=php_pdo_pgsql.dll', ';extension=php_pdo_pgsql.dll');
    content = content.replaceAll('extension=php_pgsql.dll', ';extension=php_pgsql.dll');
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
    content = _replaceDirective(content, 'realpath_cache_size', '16M');
    content = _replaceDirective(content, 'realpath_cache_ttl', '600');
    content = _replaceDirective(content, 'mysqlnd.collect_statistics', 'Off');
    content = _replaceDirective(content, 'mysqlnd.collect_memory_statistics', 'Off');
    content = _replaceDirective(content, 'session.lazy_write', '1');

    // 4. Zend OPcache Turbo Bytecode Accelerator
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
    content = content.replaceAll(RegExp(r'^;?\s*opcache\.revalidate_freq\s*=.*$', multiLine: true), 'opcache.revalidate_freq=2');
    content = content.replaceAll(RegExp(r'^;?\s*opcache\.validate_timestamps\s*=.*$', multiLine: true), 'opcache.validate_timestamps=1');
    content = content.replaceAll(RegExp(r'^;?\s*opcache\.save_comments\s*=.*$', multiLine: true), 'opcache.save_comments=1');

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

  bool writeDirectives(String iniPath, Map<String, String> newValues) {
    try {
      saveDirectives(iniPath, newValues);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _replaceDirective(String content, String key, String value) {
    final reg = RegExp('^;?\\s*${RegExp.escape(key)}\\s*=.*\$', multiLine: true);
    if (reg.hasMatch(content)) {
      return content.replaceAll(reg, '$key = $value');
    } else {
      return '$content\n$key = $value';
    }
  }

  // =========================================================================
  // PHP EXTENSION SWITCH MANAGER & PRESETS
  // =========================================================================

  static const List<Map<String, dynamic>> knownExtensionsMetadata = [
    // Database
    {
      'key': 'pdo_mysql',
      'name': 'PDO MySQL',
      'category': 'Database',
      'description': 'Driver database relasional standar modern untuk MySQL & MariaDB (Laravel, CodeIgniter, Yii).',
      'isZend': false,
    },
    {
      'key': 'mysqli',
      'name': 'MySQLi',
      'category': 'Database',
      'description': 'Konektor native MySQL klasik & modern yang wajib untuk CMS WordPress, Joomla, dan script legacy.',
      'isZend': false,
    },
    {
      'key': 'pdo_sqlite',
      'name': 'PDO SQLite',
      'category': 'Database',
      'description': 'Driver database SQLite via PDO, ideal untuk development cepat & unit testing lokal tanpa MySQL.',
      'isZend': false,
    },
    {
      'key': 'sqlite3',
      'name': 'SQLite 3',
      'category': 'Database',
      'description': 'Library direct interface SQLite 3 untuk manipulasi database file tanpa server terpisah.',
      'isZend': false,
    },
    {
      'key': 'pdo_pgsql',
      'name': 'PDO PostgreSQL',
      'category': 'Database',
      'description': 'Driver koneksi database PostgreSQL berbasis PDO untuk aplikasi enterprise.',
      'isZend': false,
    },
    {
      'key': 'pgsql',
      'name': 'PostgreSQL',
      'category': 'Database',
      'description': 'Driver native PostgreSQL procedural untuk eksekusi query langsung ke database Postgres.',
      'isZend': false,
    },

    // Web & Network
    {
      'key': 'curl',
      'name': 'cURL (Client URL)',
      'category': 'Web & API',
      'description': 'Mengizinkan request HTTP/HTTPS ke luar (REST API, Guzzle, webhook, payment gateway).',
      'isZend': false,
    },
    {
      'key': 'soap',
      'name': 'SOAP Web Services',
      'category': 'Web & API',
      'description': 'Protokol XML SOAP untuk integrasi webservice legacy, perbankan, dan logistik.',
      'isZend': false,
    },
    {
      'key': 'sockets',
      'name': 'Sockets (Low-level TCP/UDP)',
      'category': 'Web & API',
      'description': 'Komunikasi low-level socket, dibutuhkan oleh server WebSocket, Ratchet, dan worker background.',
      'isZend': false,
    },
    {
      'key': 'ldap',
      'name': 'LDAP (Directory Access)',
      'category': 'Web & API',
      'description': 'Koneksi ke Active Directory / OpenLDAP untuk autentikasi single sign-on (SSO).',
      'isZend': false,
    },

    // Media & Files
    {
      'key': 'gd',
      'name': 'GD (Image Processing)',
      'category': 'Media & File',
      'description': 'Manipulasi gambar (crop, resize, watermark, thumbnail) untuk upload foto dan captcha. (Otomatis gd2 di PHP 7.4).',
      'isZend': false,
    },
    {
      'key': 'zip',
      'name': 'Zip Archive',
      'category': 'Media & File',
      'description': 'Membuka, membaca, dan membuat file .zip. Wajib untuk Composer package download & CMS backup.',
      'isZend': false,
    },
    {
      'key': 'fileinfo',
      'name': 'FileInfo (MIME Detector)',
      'category': 'Media & File',
      'description': 'Mendeteksi tipe MIME file upload secara akurat berdasarkan magic bytes (validasi upload Laravel/WP).',
      'isZend': false,
    },
    {
      'key': 'exif',
      'name': 'EXIF (Photo Metadata)',
      'category': 'Media & File',
      'description': 'Membaca metadata kamera, orientasi foto, dan timestamp dari file gambar JPEG/TIFF.',
      'isZend': false,
    },
    {
      'key': 'bz2',
      'name': 'Bzip2 Compression',
      'category': 'Media & File',
      'description': 'Kompresi dan dekompresi file arsip .bz2 berdensitas tinggi.',
      'isZend': false,
    },

    // Security & Crypto
    {
      'key': 'openssl',
      'name': 'OpenSSL Cryptography',
      'category': 'Security & Crypto',
      'description': 'Enkripsi SSL/TLS, token signing, JWT, enkripsi password, dan HTTPS stream request.',
      'isZend': false,
    },
    {
      'key': 'sodium',
      'name': 'Sodium (Modern Crypto)',
      'category': 'Security & Crypto',
      'description': 'Library kriptografi modern standar industri (ChaCha20, Argon2id, ed25519) bawaan PHP.',
      'isZend': false,
    },

    // Framework & Text
    {
      'key': 'intl',
      'name': 'Intl (Internationalization)',
      'category': 'Framework & Text',
      'description': 'Format mata uang, tanggal multibahasa, dan ICU transliteration. Wajib untuk Laravel Filament & Symfony.',
      'isZend': false,
    },
    {
      'key': 'mbstring',
      'name': 'Mbstring (Multibyte String)',
      'category': 'Framework & Text',
      'description': 'Penanganan karakter non-ASCII (UTF-8, emoji, aksara asing). Wajib untuk hampir semua framework modern.',
      'isZend': false,
    },
    {
      'key': 'bcmath',
      'name': 'BCMath (Arbitrary Precision)',
      'category': 'Framework & Text',
      'description': 'Kalkulasi presisi floating point tinggi tanpa rounding error (sistem finansial, kalkulasi akuntansi).',
      'isZend': false,
    },
    {
      'key': 'gmp',
      'name': 'GMP (GNU Multiple Precision)',
      'category': 'Framework & Text',
      'description': 'Kalkulasi angka integer berukuran raksasa untuk matematika tingkat tinggi dan kriptografi public-key.',
      'isZend': false,
    },
    {
      'key': 'tidy',
      'name': 'Tidy (HTML Repair)',
      'category': 'Framework & Text',
      'description': 'Pembersih dan pemformat sintaks markup HTML/XHTML otomatis.',
      'isZend': false,
    },

    // Performance & Debug
    {
      'key': 'opcache',
      'name': 'Zend OPcache (Accelerator)',
      'category': 'Performance & Debug',
      'description': 'Menyimpan bytecode terkompilasi dalam RAM. Mempercepat eksekusi PHP hingga 3x-5x lipat.',
      'isZend': true,
    },
    {
      'key': 'xdebug',
      'name': 'Xdebug (Profiler & Debugger)',
      'category': 'Performance & Debug',
      'description': 'Step debugging untuk VS Code / PHPStorm, profiling performa (cachegrind), dan code coverage.',
      'isZend': true,
    },
  ];

  static const Map<String, List<String>> extensionPresets = {
    'laravel': [
      'curl', 'intl', 'gd', 'fileinfo', 'mbstring', 'openssl',
      'pdo_mysql', 'zip', 'sodium', 'pdo_sqlite', 'sqlite3', 'bcmath', 'opcache'
    ],
    'wordpress': [
      'curl', 'gd', 'intl', 'mbstring', 'mysqli', 'openssl',
      'zip', 'exif', 'fileinfo', 'opcache'
    ],
    'minimal': [
      'pdo_mysql', 'mbstring', 'openssl', 'curl'
    ],
  };

  /// Returns extension list for a specific PHP version with enabled state and disk availability
  List<PhpExtensionModel> getExtensions(String versionKey) {
    final versions = getVersions();
    final version = versions.where((v) => v.versionKey == versionKey).firstOrNull;
    if (version == null || !version.isInstalled) {
      return knownExtensionsMetadata.map((meta) => PhpExtensionModel(
        key: meta['key'] as String,
        name: meta['name'] as String,
        category: meta['category'] as String,
        description: meta['description'] as String,
        isZend: meta['isZend'] as bool,
        isEnabled: false,
        isAvailableOnDisk: false,
      )).toList();
    }

    final iniFile = File(version.phpIni);
    final content = iniFile.existsSync() ? iniFile.readAsStringSync() : '';
    final isPhp74 = versionKey == '7.4' || version.dirPath.contains('7.4');

    // Scan available DLLs in ext/ folder
    final extDir = Directory(p.join(version.dirPath, 'ext'));
    final availableDlls = <String>{};
    if (extDir.existsSync()) {
      for (final entity in extDir.listSync()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.dll')) {
          availableDlls.add(p.basename(entity.path).toLowerCase());
        }
      }
    }

    final results = <PhpExtensionModel>[];
    final processedKeys = <String>{};

    for (final meta in knownExtensionsMetadata) {
      final key = meta['key'] as String;
      final isZend = meta['isZend'] as bool;
      processedKeys.add(key);

      bool available = true;
      if (extDir.existsSync()) {
        if (isZend && key == 'opcache') {
          // OPcache is either a DLL or built directly into php.exe
          available = availableDlls.contains('php_opcache.dll') || !isPhp74;
        } else if (key == 'gd') {
          available = isPhp74
              ? (availableDlls.contains('php_gd2.dll') || availableDlls.contains('php_gd.dll'))
              : availableDlls.contains('php_gd.dll');
        } else {
          available = availableDlls.contains('php_$key.dll');
        }
      }

      final enabled = isExtensionEnabled(content, key, isZend: isZend, isPhp74: isPhp74);

      results.add(PhpExtensionModel(
        key: key,
        name: meta['name'] as String,
        category: meta['category'] as String,
        description: meta['description'] as String,
        isZend: isZend,
        isEnabled: enabled,
        isAvailableOnDisk: available,
      ));
    }

    // Auto-detect extra DLLs in ext/ folder not in known list
    if (extDir.existsSync()) {
      for (final dll in availableDlls) {
        if (dll.startsWith('php_') && dll.endsWith('.dll')) {
          final rawKey = dll.substring(4, dll.length - 4);
          if (rawKey == 'gd2') continue;
          if (!processedKeys.contains(rawKey)) {
            final isEnabled = isExtensionEnabled(content, rawKey, isZend: false, isPhp74: isPhp74);
            results.add(PhpExtensionModel(
              key: rawKey,
              name: rawKey.toUpperCase(),
              category: 'Ekstensi Ekstra',
              description: 'Modul binary tambahan di folder ext/$dll',
              isZend: false,
              isEnabled: isEnabled,
              isAvailableOnDisk: true,
            ));
            processedKeys.add(rawKey);
          }
        }
      }
    }

    return results;
  }

  /// Checks if an extension is currently enabled in php.ini content
  bool isExtensionEnabled(String content, String key, {required bool isZend, required bool isPhp74}) {
    if (content.isEmpty) return false;
    const lookahead = r'''(?:\.dll)?["']?(?=\s*(?:[;#\r\n]|$))''';
    if (isZend) {
      final reg = RegExp(
        r'''^\s*zend_extension\s*=\s*["']?(?:php_)?''' + RegExp.escape(key) + lookahead,
        multiLine: true,
        caseSensitive: false,
      );
      return reg.hasMatch(content);
    }

    if (key == 'gd') {
      final gdTarget = isPhp74 ? 'gd2' : 'gd';
      final reg = RegExp(
        r'''^\s*extension\s*=\s*["']?(?:php_)?''' + gdTarget + lookahead,
        multiLine: true,
        caseSensitive: false,
      );
      return reg.hasMatch(content);
    }

    final reg = RegExp(
      r'''^\s*extension\s*=\s*["']?(?:php_)?''' + RegExp.escape(key) + lookahead,
      multiLine: true,
      caseSensitive: false,
    );
    return reg.hasMatch(content);
  }

  /// Toggles an extension inside php.ini string content without corrupting other directives
  String toggleExtensionInContent(String content, String key, bool enable, {required bool isZend, required bool isPhp74}) {
    const lookahead = r'''(?:\.dll)?["']?(?=\s*(?:[;#\r\n]|$))''';
    final newline = content.contains('\r\n') ? '\r\n' : '\n';

    if (isZend) {
      if (enable) {
        if (isExtensionEnabled(content, key, isZend: true, isPhp74: isPhp74)) {
          return content;
        }
        final commentedReg = RegExp(
          r'''^;\s*(zend_extension\s*=\s*["']?(?:php_)?''' + RegExp.escape(key) + lookahead + r''')''',
          multiLine: true,
          caseSensitive: false,
        );
        bool replaced = false;
        if (commentedReg.hasMatch(content)) {
          content = content.replaceAllMapped(commentedReg, (m) {
            if (!replaced) {
              replaced = true;
              return 'zend_extension=$key';
            }
            return m.group(0)!;
          });
          if (key == 'opcache') {
            content = _replaceDirective(content, 'opcache.enable', '1');
            content = _replaceDirective(content, 'opcache.enable_cli', '1');
          }
          return content;
        }
        final trailing = content.endsWith('\n') ? '' : newline;
        content = '$content$trailing' 'zend_extension=$key$newline';
        if (key == 'opcache') {
          content = _replaceDirective(content, 'opcache.enable', '1');
          content = _replaceDirective(content, 'opcache.enable_cli', '1');
        }
        return content;
      } else {
        final activeReg = RegExp(
          r'''^\s*(zend_extension\s*=\s*["']?(?:php_)?''' + RegExp.escape(key) + lookahead + r''')''',
          multiLine: true,
          caseSensitive: false,
        );
        content = content.replaceAllMapped(activeReg, (m) => ';${m.group(1)}');
        if (key == 'opcache') {
          content = _replaceDirective(content, 'opcache.enable', '0');
          content = _replaceDirective(content, 'opcache.enable_cli', '0');
        }
        return content;
      }
    }

    // Regular extension
    final targetExtName = (key == 'gd' && isPhp74) ? 'gd2' : key;

    if (enable) {
      if (isExtensionEnabled(content, key, isZend: false, isPhp74: isPhp74)) {
        return content;
      }

      if (key == 'gd') {
        final wrongVariant = isPhp74 ? 'gd' : 'gd2';
        final wrongReg = RegExp(
          r'''^\s*(extension\s*=\s*["']?(?:php_)?''' + wrongVariant + lookahead + r''')''',
          multiLine: true,
          caseSensitive: false,
        );
        content = content.replaceAllMapped(wrongReg, (m) => ';${m.group(1)}');

        final commentedGd = RegExp(
          r'''^;\s*(extension\s*=\s*["']?(?:php_)?(gd|gd2)''' + lookahead + r''')''',
          multiLine: true,
          caseSensitive: false,
        );
        bool replaced = false;
        if (commentedGd.hasMatch(content)) {
          return content.replaceAllMapped(commentedGd, (m) {
            if (!replaced) {
              replaced = true;
              return 'extension=$targetExtName';
            }
            return m.group(0)!;
          });
        }
        final trailing = content.endsWith('\n') ? '' : newline;
        return '$content$trailing' 'extension=$targetExtName$newline';
      }

      final commentedReg = RegExp(
        r'''^;\s*(extension\s*=\s*["']?(?:php_)?''' + RegExp.escape(key) + lookahead + r''')''',
        multiLine: true,
        caseSensitive: false,
      );
      bool replaced = false;
      if (commentedReg.hasMatch(content)) {
        return content.replaceAllMapped(commentedReg, (m) {
          if (!replaced) {
            replaced = true;
            return 'extension=$key';
          }
          return m.group(0)!;
        });
      }
      final trailing = content.endsWith('\n') ? '' : newline;
      return '$content$trailing' 'extension=$key$newline';
    } else {
      // Disable
      if (key == 'gd') {
        final activeGd = RegExp(
          r'''^\s*(extension\s*=\s*["']?(?:php_)?(gd|gd2)''' + lookahead + r''')''',
          multiLine: true,
          caseSensitive: false,
        );
        return content.replaceAllMapped(activeGd, (m) => ';${m.group(1)}');
      }

      final activeReg = RegExp(
        r'''^\s*(extension\s*=\s*["']?(?:php_)?''' + RegExp.escape(key) + lookahead + r''')''',
        multiLine: true,
        caseSensitive: false,
      );
      return content.replaceAllMapped(activeReg, (m) => ';${m.group(1)}');
    }
  }

  /// Sets an extension enabled or disabled on disk and triggers FastCGI worker hot-reload
  Future<bool> setExtension({
    required String versionKey,
    required String extensionKey,
    required bool enable,
    bool reloadFastCgi = true,
  }) async {
    return _synchronized(versionKey, () async {
      final versions = getVersions();
      final version = versions.where((v) => v.versionKey == versionKey).firstOrNull;
      if (version == null || !version.isInstalled) return false;

      final iniFile = File(version.phpIni);
      if (!iniFile.existsSync()) {
        optimizePhpIni(version.dirPath);
      }
      if (!iniFile.existsSync()) return false;

      final isPhp74 = versionKey == '7.4' || version.dirPath.contains('7.4');
      final meta = knownExtensionsMetadata.where((m) => m['key'] == extensionKey).firstOrNull;
      final isZend = meta != null ? (meta['isZend'] as bool) : (extensionKey == 'opcache' || extensionKey == 'xdebug');

      var content = iniFile.readAsStringSync();
      content = toggleExtensionInContent(content, extensionKey, enable, isZend: isZend, isPhp74: isPhp74);
      iniFile.writeAsStringSync(content);

      if (reloadFastCgi) {
        await HttpServerService.instance.restartFastCgiPool(versionKey);
      }
      return true;
    });
  }

  /// Applies a preset bundle (laravel, wordpress, minimal) to the selected PHP version
  Future<bool> applyPreset({
    required String versionKey,
    required String presetName,
    bool reloadFastCgi = true,
  }) async {
    return _synchronized(versionKey, () async {
      final presetKey = presetName.toLowerCase().trim();
      final targetExts = extensionPresets[presetKey];
      if (targetExts == null) return false;

      final versions = getVersions();
      final version = versions.where((v) => v.versionKey == versionKey).firstOrNull;
      if (version == null || !version.isInstalled) return false;

      final iniFile = File(version.phpIni);
      if (!iniFile.existsSync()) {
        optimizePhpIni(version.dirPath);
      }
      if (!iniFile.existsSync()) return false;

      final isPhp74 = versionKey == '7.4' || version.dirPath.contains('7.4');
      var content = iniFile.readAsStringSync();

      for (final extKey in targetExts) {
        final meta = knownExtensionsMetadata.where((m) => m['key'] == extKey).firstOrNull;
        final isZend = meta != null ? (meta['isZend'] as bool) : (extKey == 'opcache' || extKey == 'xdebug');
        content = toggleExtensionInContent(content, extKey, true, isZend: isZend, isPhp74: isPhp74);
      }

      iniFile.writeAsStringSync(content);

      if (reloadFastCgi) {
        await HttpServerService.instance.restartFastCgiPool(versionKey);
      }
      return true;
    });
  }
}

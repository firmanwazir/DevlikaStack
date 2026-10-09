import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import '../models/site_model.dart';
import '../models/php_version_model.dart';
import 'config_service.dart';
import 'fastcgi_client.dart';
import 'htaccess_service.dart';
import 'ssl_service.dart';
import 'vhost_config_generator.dart';

class HttpServerService {
  static final HttpServerService instance = HttpServerService._();
  HttpServerService._();

  HttpServer? _server;
  HttpServer? _serverIpv6;
  HttpServer? _secureServer;
  HttpServer? _secureServerIpv6;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  final Set<String> _ensuredDirs = {};
  Map<String, SiteModel>? _siteDomainMap;
  final http.Client _proxyClient = http.Client();

  // --- Multi-Worker FastCGI Daemon Pools (Zero-queue parallel concurrency per PHP version) ---
  final Map<String, List<Process>> _fastCgiDaemons = {};
  final Map<String, List<FastCgiClient>> _fastCgiPools = {};
  final Map<String, int> _poolIndex = {};
  final Map<String, bool> _fastCgiReady = {};

  // --- Performance Caches (avoid disk I/O per request) ---
  final Map<String, bool> _fileExistsCache = {};
  final Map<String, bool> _dirExistsCache = {};
  final Map<String, PhpVersionModel> _phpModelCache = {};
  final Map<String, String> _phpExeCache = {};
  final Map<String, bool> _phpIniExistsCache = {};
  final Map<String, bool> _extDirExistsCache = {};
  final Map<String, bool> _opcacheDirExistsCache = {};
  // Pre-computed PHP args per version to avoid rebuilding on every request
  final Map<String, List<String>> _phpBaseArgsCache = {};
  // In-memory RAM cache for static assets <= 2MB
  final Map<String, _StaticFileCacheEntry> _staticFileCache = {};

  bool _cachedFileExists(String path) {
    return _fileExistsCache[path] ??= File(path).existsSync();
  }

  bool _cachedDirExists(String path) {
    return _dirExistsCache[path] ??= Directory(path).existsSync();
  }

  Future<List<int>> _collectBytes(Stream<List<int>> stream) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<bool> start() async {
    if (_isRunning) return true;

    final httpPort = ConfigService.instance.httpPort;
    final httpsPort = ConfigService.instance.httpsPort;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, httpPort);
      _server!.autoCompress = true;
      // Enable persistent connections (Keep-Alive) to reduce TCP handshake overhead
      _server!.idleTimeout = const Duration(seconds: 15);
      _isRunning = true;
      _logController.add('[Web Server] Berjalan pada http://127.0.0.1:$httpPort');

      _server!.listen(
        _handleRequest,
        onError: (e) => _logController.add('[Web Server Error] $e'),
      );

      // Also bind IPv6 loopback [::1] on configured port to eliminate Windows IPv6 TCP timeout
      try {
        _serverIpv6 = await HttpServer.bind(InternetAddress.loopbackIPv6, httpPort);
        _serverIpv6!.autoCompress = true;
        _serverIpv6!.idleTimeout = const Duration(seconds: 15);
        _serverIpv6!.listen(
          _handleRequest,
          onError: (e) => _logController.add('[Web Server IPv6 Error] $e'),
        );
      } catch (_) {}

      // Start FastCGI daemons for all configured PHP versions
      await _startAllConfiguredFastCgiDaemons();

      // Start HTTPS Server with SSL
      try {
        final ssl = SslService.instance;
        await ssl.ensureCertificate();
        if (ssl.hasCertificate) {
          final sec = SecurityContext()
            ..useCertificateChain(ssl.certPath)
            ..usePrivateKey(ssl.keyPath);
          _secureServer = await HttpServer.bindSecure(
            InternetAddress.loopbackIPv4,
            httpsPort,
            sec,
          );
          _secureServer!.autoCompress = true;
          _secureServer!.idleTimeout = const Duration(seconds: 15);
          _secureServer!.listen(
            _handleRequest,
            onError: (e) => _logController.add('[Web Server HTTPS Error] $e'),
          );
          _logController.add('[Web Server] Berjalan pada https://127.0.0.1:$httpsPort (SSL Aktif)');

          try {
            _secureServerIpv6 = await HttpServer.bindSecure(
              InternetAddress.loopbackIPv6,
              httpsPort,
              sec,
            );
            _secureServerIpv6!.autoCompress = true;
            _secureServerIpv6!.idleTimeout = const Duration(seconds: 15);
            _secureServerIpv6!.listen(
              _handleRequest,
              onError: (e) => _logController.add('[Web Server HTTPS IPv6 Error] $e'),
            );
          } catch (_) {}
        }
      } catch (sslErr) {
        _logController.add('[Web Server SSL Warning] HTTPS Port $httpsPort tidak aktif: $sslErr');
      }

      return true;
    } catch (e) {
      _logController.add('[Web Server Error] Gagal bind port $httpPort: $e');
      _isRunning = false;
      return false;
    }
  }

  Future<void> stop() async {
    // Stop FastCGI daemon first
    await _stopFastCgiDaemon();

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    if (_serverIpv6 != null) {
      await _serverIpv6!.close(force: true);
      _serverIpv6 = null;
    }
    if (_secureServer != null) {
      await _secureServer!.close(force: true);
      _secureServer = null;
    }
    if (_secureServerIpv6 != null) {
      await _secureServerIpv6!.close(force: true);
      _secureServerIpv6 = null;
    }
    _staticFileCache.clear();
    _isRunning = false;
    // Clear all caches on stop
    _fileExistsCache.clear();
    _dirExistsCache.clear();
    _phpModelCache.clear();
    _phpExeCache.clear();
    _phpIniExistsCache.clear();
    _extDirExistsCache.clear();
    _opcacheDirExistsCache.clear();
    _phpBaseArgsCache.clear();
    _logController.add('[Web Server] Berhenti.');
  }

  /// Start FastCGI worker pools for all PHP versions needed by enabled sites + default PHP
  Future<void> _startAllConfiguredFastCgiDaemons() async {
    final sites = ConfigService.instance.loadSites();
    final neededKeys = <String>{'default'};
    for (var s in sites) {
      if (s.isEnabled && s.type == 'php' && s.phpVersion.isNotEmpty) {
        neededKeys.add(ConfigService.normalizePhpVersionKey(s.phpVersion));
      }
    }

    final futures = <Future<bool>>[];
    for (var key in neededKeys) {
      final model = ConfigService.instance.getPhpForSite(key);
      futures.add(_startFastCgiDaemonFor(model));
    }
    await Future.wait(futures);
  }

  /// Start a persistent multi-worker php-cgi pool for a specific PHP version.
  Future<bool> _startFastCgiDaemonFor(PhpVersionModel phpModel) async {
    final versionKey = phpModel.versionKey;
    final ports = VhostConfigGenerator.getFastCgiPorts(versionKey);
    final cgiExe = phpModel.phpCgiExe;

    if (!File(cgiExe).existsSync()) {
      _logController.add('[FastCGI] Binary php-cgi.exe untuk ${phpModel.name} tidak ditemukan di ${phpModel.dirPath}');
      return false;
    }

    _fastCgiPools.putIfAbsent(versionKey, () => []);
    _fastCgiDaemons.putIfAbsent(versionKey, () => []);
    _poolIndex.putIfAbsent(versionKey, () => 0);

    final config = ConfigService.instance;
    final sessionDir = p.join(config.storageDir, 'sessions');
    final uploadDir = p.join(config.storageDir, 'temp');
    final opcacheDir = p.join(config.storageDir, 'opcache', 'php-$versionKey');

    // Ensure storage directories
    for (final dir in [sessionDir, uploadDir, opcacheDir]) {
      try {
        Directory(dir).createSync(recursive: true);
      } catch (_) {}
    }

    final extDir = p.join(phpModel.dirPath, 'ext');
    bool anyReady = false;

    for (final port in ports) {
      // Check if port is already active (reuse existing daemon)
      try {
        final testSocket = await Socket.connect('127.0.0.1', port,
            timeout: const Duration(milliseconds: 150));
        testSocket.destroy();
        if (!_fastCgiPools[versionKey]!.any((c) => c.port == port)) {
          _fastCgiPools[versionKey]!.add(FastCgiClient(port: port));
        }
        anyReady = true;
        continue;
      } catch (_) {
        // Port free, spawn worker
      }

      final args = <String>[
        '-b', '127.0.0.1:$port',
        if (File(phpModel.phpIni).existsSync()) ...['-c', phpModel.phpIni],
        if (Directory(extDir).existsSync()) ...['-d', 'extension_dir=$extDir'],
        '-d', 'realpath_cache_size=16M',
        '-d', 'realpath_cache_ttl=600',
        '-d', 'opcache.enable=1',
        '-d', 'opcache.enable_cli=1',
        '-d', 'opcache.memory_consumption=256',
        '-d', 'opcache.interned_strings_buffer=16',
        '-d', 'opcache.max_accelerated_files=20000',
        '-d', 'opcache.validate_timestamps=1',
        '-d', 'opcache.revalidate_freq=2',
        '-d', 'opcache.save_comments=1',
        if (Directory(opcacheDir).existsSync()) ...['-d', 'opcache.file_cache=$opcacheDir'],
        '-d', 'session.save_path=$sessionDir',
        '-d', 'session.lazy_write=1',
        '-d', 'upload_tmp_dir=$uploadDir',
        '-d', 'mysqli.default_host=127.0.0.1',
        '-d', 'pdo_mysql.default_host=127.0.0.1',
        '-d', 'mysqlnd.collect_statistics=0',
        '-d', 'mysqlnd.collect_memory_statistics=0',
      ];

      try {
        final proc = await Process.start(
          cgiExe,
          args,
          environment: {
            'PHP_FCGI_CHILDREN': '0',
            'PHP_FCGI_MAX_REQUESTS': '10000',
            if (File(phpModel.phpIni).existsSync()) 'PHPRC': phpModel.dirPath,
            'PATH': '${phpModel.dirPath};$extDir;${Platform.environment['PATH'] ?? ''}',
          },
          workingDirectory: phpModel.dirPath,
        );

        _fastCgiDaemons[versionKey]!.add(proc);

        // Monitor stderr
        proc.stderr.listen((data) {
          final msg = utf8.decode(data, allowMalformed: true).trim();
          if (msg.isNotEmpty && !msg.contains('already loaded')) {
            _logController.add('[FastCGI $versionKey Error] $msg');
          }
        });

        // Monitor exit
        proc.exitCode.then((code) {
          _fastCgiPools[versionKey]?.removeWhere((c) => c.port == port);
          _fastCgiDaemons[versionKey]?.remove(proc);
        });

        // Wait for daemon port to be ready (up to 2 seconds)
        for (int i = 0; i < 20; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          try {
            final testSocket = await Socket.connect('127.0.0.1', port,
                timeout: const Duration(milliseconds: 150));
            testSocket.destroy();
            if (!_fastCgiPools[versionKey]!.any((c) => c.port == port)) {
              _fastCgiPools[versionKey]!.add(FastCgiClient(port: port));
            }
            anyReady = true;
            break;
          } catch (_) {}
        }
      } catch (e) {
        _logController.add('[FastCGI Error] Gagal memulai worker $port untuk ${phpModel.name}: $e');
      }
    }

    if (anyReady) {
      _fastCgiReady[versionKey] = true;
      _logController.add('[FastCGI] Worker pool ${phpModel.name} (${_fastCgiPools[versionKey]!.length} workers) aktif.');
      return true;
    }
    return false;
  }

  /// Get or on-demand start FastCGI client with round-robin worker distribution
  Future<FastCgiClient?> _getOrStartFastCgiClient(PhpVersionModel phpModel) async {
    final versionKey = phpModel.versionKey;
    final pool = _fastCgiPools[versionKey];
    if (_fastCgiReady[versionKey] == true && pool != null && pool.isNotEmpty) {
      final idx = (_poolIndex[versionKey] ?? 0) % pool.length;
      _poolIndex[versionKey] = idx + 1;
      return pool[idx];
    }

    final started = await _startFastCgiDaemonFor(phpModel);
    final newPool = _fastCgiPools[versionKey];
    if (started && newPool != null && newPool.isNotEmpty) {
      final idx = (_poolIndex[versionKey] ?? 0) % newPool.length;
      _poolIndex[versionKey] = idx + 1;
      return newPool[idx];
    }
    return null;
  }

  Future<void> _stopFastCgiDaemon() async {
    _fastCgiPools.clear();
    _poolIndex.clear();
    _fastCgiReady.clear();

    for (var procs in _fastCgiDaemons.values) {
      for (var proc in procs) {
        try {
          proc.kill();
        } catch (_) {}
      }
    }
    _fastCgiDaemons.clear();

    // Clean up any orphaned php-cgi processes on all known ports
    if (Platform.isWindows) {
      const ports = '9000,9074,9081,9082,9083,9123';
      try {
        await Process.run('powershell', [
          '-NoProfile', '-Command',
          'Get-NetTCPConnection -LocalPort @($ports) -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id \$_.OwningProcess -Force -ErrorAction SilentlyContinue }'
        ]);
      } catch (_) {}
    }
  }

  final Map<String, Timer?> _fastCgiDebounceTimers = {};
  final Map<String, Completer<void>?> _fastCgiRestartLocks = {};

  /// Hot-reloads the FastCGI worker pool for a specific PHP version (e.g. after editing php.ini or toggling extensions)
  Future<void> restartFastCgiPool(String versionKey, {bool debounce = true}) async {
    if (debounce) {
      final completer = Completer<void>();
      _fastCgiDebounceTimers[versionKey]?.cancel();
      _fastCgiDebounceTimers[versionKey] = Timer(const Duration(milliseconds: 250), () async {
        try {
          await _executeRestartFastCgiPool(versionKey);
          if (!completer.isCompleted) completer.complete();
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      });
      return completer.future;
    } else {
      return _executeRestartFastCgiPool(versionKey);
    }
  }

  Future<void> _executeRestartFastCgiPool(String versionKey) async {
    while (_fastCgiRestartLocks[versionKey] != null) {
      await _fastCgiRestartLocks[versionKey]!.future;
    }
    final lock = Completer<void>();
    _fastCgiRestartLocks[versionKey] = lock;

    try {
      final procs = _fastCgiDaemons[versionKey];
      if (procs != null) {
        for (var proc in procs) {
          try {
            proc.kill();
          } catch (_) {}
        }
        procs.clear();
      }

      final ports = VhostConfigGenerator.getFastCgiPorts(versionKey);
      if (Platform.isWindows && ports.isNotEmpty) {
        final portList = ports.join(',');
        try {
          await Process.run('powershell', [
            '-NoProfile',
            '-Command',
            'Get-NetTCPConnection -LocalPort @($portList) -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id \$_.OwningProcess -Force -ErrorAction SilentlyContinue }'
          ]);
        } catch (_) {}
      }

      _fastCgiPools[versionKey]?.clear();
      _fastCgiReady.remove(versionKey);
      _poolIndex[versionKey] = 0;
      _phpBaseArgsCache.remove(versionKey);
      _phpModelCache.clear();

      _logController.add('[FastCGI] Worker pool PHP $versionKey dimuat ulang.');

      if (_isRunning) {
        final phpModel = ConfigService.instance.getPhpForSite(versionKey);
        if (phpModel.isInstalled) {
          await _startFastCgiDaemonFor(phpModel);
        }
      }
    } finally {
      lock.complete();
      _fastCgiRestartLocks.remove(versionKey);
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final sw = Stopwatch()..start();
    final uri = request.uri;
    var host = request.headers.value('host') ?? 'localhost';
    if (host.contains(':')) host = host.split(':')[0];

    try {
      // 1. phpMyAdmin route
      if (uri.path.startsWith('/__phpmyadmin')) {
        await _servePhpMyAdmin(request);
        sw.stop();
        _logController.add('[${DateTime.now().toIso8601String().substring(11, 19)}] ${request.method} $host${uri.path} -> 200 (${sw.elapsedMilliseconds}ms)');
        return;
      }

      // 2. High-speed O(1) Virtual Host matching
      if (_siteDomainMap == null) {
        final sites = ConfigService.instance.loadSites();
        _siteDomainMap = {
          for (var s in sites)
            if (s.isEnabled && s.domain.isNotEmpty) s.domain.toLowerCase(): s,
        };
      }
      final site = _siteDomainMap![host.toLowerCase()];

      if (site != null) {
        if (site.type == 'proxy') {
          await _handleProxy(request, site.proxyPort);
        } else {
          await _handleFileOrPhp(request, site.rootPath, phpVersion: site.phpVersion, host: host);
        }
      } else {
        await _serveWelcomePage(request, host);
      }

      sw.stop();
      _logController.add('[${DateTime.now().toIso8601String().substring(11, 19)}] ${request.method} $host${uri.path} -> ${request.response.statusCode} (${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      try {
        request.response.statusCode = 500;
        request.response.write('Server Error: $e');
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _servePhpMyAdmin(HttpRequest request) async {
    final config = ConfigService.instance;
    final phpMyAdminDir = config.phpMyAdminDir;

    if (!Directory(phpMyAdminDir).existsSync()) {
      request.response.statusCode = 404;
      request.response.headers.contentType = ContentType.html;
      request.response.write('<h2>phpMyAdmin Belum Terpasang</h2><p>Buka menu Komponen Server di DevlikaStack untuk memasang phpMyAdmin.</p>');
      await request.response.close();
      return;
    }

    var subPath = request.uri.path.replaceFirst('/__phpmyadmin', '');
    if (subPath.isEmpty || subPath == '/') subPath = '/index.php';

    final relativeSafe = subPath.startsWith('/') ? subPath.substring(1) : subPath;
    final normalizedPmaDir = p.normalize(phpMyAdminDir);
    final targetPath = p.normalize(p.join(normalizedPmaDir, relativeSafe));
    if (!p.equals(targetPath, normalizedPmaDir) && !p.isWithin(normalizedPmaDir, targetPath)) {
      request.response.statusCode = 403;
      request.response.headers.contentType = ContentType.html;
      request.response.write(_errorPage(403, 'Forbidden', 'Akses ditolak: path di luar direktori phpMyAdmin.'));
      await request.response.close();
      return;
    }
    final targetFile = File(targetPath);

    if (targetFile.existsSync() && !targetPath.endsWith('.php')) {
      await _serveStaticFile(request, targetFile);
      return;
    }

    final indexPath = p.join(phpMyAdminDir, 'index.php');
    final scriptToRun = targetFile.existsSync() && targetPath.endsWith('.php') ? targetPath : indexPath;

    await _executePhp(
      request,
      scriptPath: scriptToRun,
      docRoot: phpMyAdminDir,
      scriptName: '/__phpmyadmin$subPath',
      pathInfo: '',
      phpVersion: 'default',
    );
  }

  final Map<String, String> _effectiveDocRootCache = {};

  void clearDocRootCache() {
    _effectiveDocRootCache.clear();
    _siteDomainMap = null;
    _fileExistsCache.clear();
    _dirExistsCache.clear();
    _phpModelCache.clear();
    _phpExeCache.clear();
    _phpIniExistsCache.clear();
    _extDirExistsCache.clear();
    _opcacheDirExistsCache.clear();
    _phpBaseArgsCache.clear();
    _staticFileCache.clear();
  }

  String _getEffectiveDocRoot(String rootDir) {
    final cached = _effectiveDocRootCache[rootDir];
    if (cached != null) return cached;

    var effective = rootDir;
    if (!_cachedFileExists(p.join(rootDir, 'index.php'))) {
      if (_cachedFileExists(p.join(rootDir, 'public_html', 'index.php'))) {
        effective = p.join(rootDir, 'public_html');
      } else if (_cachedFileExists(p.join(rootDir, 'public', 'index.php'))) {
        effective = p.join(rootDir, 'public');
      }
    }
    _effectiveDocRootCache[rootDir] = effective;
    return effective;
  }

  Future<void> _handleFileOrPhp(
    HttpRequest request,
    String rootDir, {
    String? customPath,
    String? phpVersion,
    String? host,
  }) async {
    // 1. Framework auto-detection: If rootDir doesn't have index.php but has public/index.php (Laravel / CodeIgniter 4)
    final effectiveDocRoot = _getEffectiveDocRoot(rootDir);

    final rawPath = customPath ?? request.uri.path;

    // 2. Evaluate .htaccess rules (RewriteRule, RewriteCond, FilesMatch, Headers, php_value)
    final htaccess = HtaccessService.instance.evaluate(
      request: request,
      docRoot: effectiveDocRoot,
      rawPath: rawPath,
      host: host,
    );

    // If .htaccess says 403 Forbidden (e.g. .env, uploads/*.php, referrer spam)
    if (htaccess.isForbidden) {
      request.response.statusCode = 403;
      request.response.headers.contentType = ContentType.html;
      htaccess.responseHeaders.forEach((k, v) {
        try {
          request.response.headers.set(k, v);
        } catch (_) {}
      });
      request.response.write(_errorPage(403, 'Akses Ditolak (403 Forbidden)',
          htaccess.forbiddenReason ?? 'Akses ke file atau URL ini diblokir oleh kebijakan keamanan .htaccess.'));
      await request.response.close();
      return;
    }

    // If .htaccess says Redirect (e.g. trailing slash redirect [R=301])
    if (htaccess.isRedirect && htaccess.redirectUrl != null) {
      request.response.statusCode = htaccess.redirectStatusCode;
      htaccess.responseHeaders.forEach((k, v) {
        try {
          request.response.headers.set(k, v);
        } catch (_) {}
      });
      request.response.headers.set(HttpHeaders.locationHeader, htaccess.redirectUrl!);
      await request.response.close();
      return;
    }

    final effectivePath = htaccess.rewrittenPath;
    final pathInfo = htaccess.pathInfo;

    // Remove leading slash for local joining
    var relativePath = effectivePath.startsWith('/') ? effectivePath.substring(1) : effectivePath;
    // Normalize and verify path stays within document root (prevent path traversal)
    final normalizedDocRoot = p.normalize(effectiveDocRoot);
    var targetPath = p.normalize(p.join(normalizedDocRoot, relativePath));
    if (!p.equals(targetPath, normalizedDocRoot) && !p.isWithin(normalizedDocRoot, targetPath)) {
      request.response.statusCode = 403;
      request.response.headers.contentType = ContentType.html;
      request.response.write(_errorPage(403, 'Forbidden', 'Akses ditolak: path di luar folder proyek.'));
      await request.response.close();
      return;
    }

    // Handle directory request: ensure trailing slash then try index.php or index.html
    if (_cachedDirExists(targetPath)) {
      if (!rawPath.endsWith('/') && !rawPath.contains('.')) {
        request.response.statusCode = 301;
        final queryPart = request.uri.hasQuery ? '?${request.uri.query}' : '';
        request.response.headers.set(HttpHeaders.locationHeader, '$rawPath/$queryPart');
        await request.response.close();
        return;
      }
      final dirIndexPhp = p.join(targetPath, 'index.php');
      final dirIndexHtml = p.join(targetPath, 'index.html');
      if (_cachedFileExists(dirIndexPhp)) {
        targetPath = dirIndexPhp;
      } else if (_cachedFileExists(dirIndexHtml)) {
        await _serveStaticFile(request, File(dirIndexHtml), customHeaders: htaccess.responseHeaders);
        return;
      }
    }

    // Check if exact file exists
    final targetFile = File(targetPath);
    if (_cachedFileExists(targetPath)) {
      if (targetPath.endsWith('.php')) {
        await _executePhp(
          request,
          scriptPath: targetPath,
          docRoot: effectiveDocRoot,
          scriptName: effectivePath,
          pathInfo: pathInfo ?? '',
          phpVersion: phpVersion,
          customHeaders: htaccess.responseHeaders,
          phpIniOverrides: htaccess.phpIniOverrides,
          customEnv: htaccess.customEnv,
        );
      } else {
        await _serveStaticFile(request, targetFile, customHeaders: htaccess.responseHeaders);
      }
      return;
    }

    // 3. URL Rewrite fallback to front controller index.php if available (CRITICAL FOR LARAVEL & CODEIGNITER)
    final rootIndexPhp = p.join(effectiveDocRoot, 'index.php');
    if (_cachedFileExists(rootIndexPhp)) {
      await _executePhp(
        request,
        scriptPath: rootIndexPhp,
        docRoot: effectiveDocRoot,
        scriptName: '/index.php',
        pathInfo: pathInfo ?? (effectivePath.isNotEmpty ? effectivePath : rawPath),
        phpVersion: phpVersion,
        customHeaders: htaccess.responseHeaders,
        phpIniOverrides: htaccess.phpIniOverrides,
        customEnv: htaccess.customEnv,
      );
      return;
    }

    // Fallback to root index.html if available (for SPA: Vue/React/Angular/Vite)
    final rootIndexHtml = p.join(effectiveDocRoot, 'index.html');
    if (_cachedFileExists(rootIndexHtml)) {
      await _serveStaticFile(request, File(rootIndexHtml), customHeaders: htaccess.responseHeaders);
      return;
    }

    // Truly 404
    request.response.statusCode = 404;
    request.response.headers.contentType = ContentType.html;
    request.response.write(_errorPage(404, 'File Tidak Ditemukan', 'File <code>$rawPath</code> tidak ada di dalam folder proyek.'));
    await request.response.close();
  }

  /// Resolve PHP model with in-memory caching (avoids disk check per request)
  PhpVersionModel _getCachedPhpModel(String? phpVersion) {
    final key = phpVersion ?? 'default';
    return _phpModelCache[key] ??= ConfigService.instance.getPhpForSite(phpVersion);
  }

  /// Get pre-computed base PHP args (extension_dir, opcache, session, upload dirs)
  /// Cached per PHP version to avoid disk I/O on every request.
  List<String> _getBasePhpArgs(PhpVersionModel phpModel) {
    final key = phpModel.versionKey;
    if (_phpBaseArgsCache.containsKey(key)) return _phpBaseArgsCache[key]!;

    final config = ConfigService.instance;
    final extDir = p.join(phpModel.dirPath, 'ext');
    final sessionDir = p.join(config.storageDir, 'sessions');
    final uploadDir = p.join(config.storageDir, 'temp');
    final opcacheDir = p.join(config.storageDir, 'opcache');

    // Ensure directories exist (once per version)
    if (!_ensuredDirs.contains(sessionDir)) {
      Directory(sessionDir).createSync(recursive: true);
      _ensuredDirs.add(sessionDir);
    }
    if (!_ensuredDirs.contains(uploadDir)) {
      Directory(uploadDir).createSync(recursive: true);
      _ensuredDirs.add(uploadDir);
    }
    if (!_ensuredDirs.contains(opcacheDir)) {
      try {
        Directory(opcacheDir).createSync(recursive: true);
        _ensuredDirs.add(opcacheDir);
      } catch (_) {}
    }

    final args = <String>[
      if (_cachedDirExists(extDir)) ...['-d', 'extension_dir=$extDir'],
      '-d', 'realpath_cache_size=16M',
      '-d', 'realpath_cache_ttl=600',
      '-d', 'opcache.enable=1',
      '-d', 'opcache.enable_cli=1',
      '-d', 'opcache.memory_consumption=256',
      '-d', 'opcache.interned_strings_buffer=16',
      '-d', 'opcache.max_accelerated_files=20000',
      '-d', 'opcache.validate_timestamps=1',
      '-d', 'opcache.revalidate_freq=2',
      '-d', 'opcache.save_comments=1',
      if (_cachedDirExists(opcacheDir)) ...['-d', 'opcache.file_cache=$opcacheDir'],
      '-d', 'session.save_path=$sessionDir',
      '-d', 'session.lazy_write=1',
      '-d', 'upload_tmp_dir=$uploadDir',
      '-d', 'mysqli.default_host=127.0.0.1',
      '-d', 'pdo_mysql.default_host=127.0.0.1',
      '-d', 'mysqlnd.collect_statistics=0',
      '-d', 'mysqlnd.collect_memory_statistics=0',
    ];

    _phpBaseArgsCache[key] = args;
    return args;
  }

  Future<void> _executePhp(
    HttpRequest request, {
    required String scriptPath,
    required String docRoot,
    required String scriptName,
    required String pathInfo,
    String? phpVersion,
    Map<String, String>? customHeaders,
    Map<String, String>? phpIniOverrides,
    Map<String, String>? customEnv,
  }) async {
    final phpModel = _getCachedPhpModel(phpVersion);
    final phpExe = phpModel.phpCgiExe;
    final cgiPath = p.join(phpModel.dirPath, 'php-cgi.exe');

    // Use cached existence checks (only checks disk once per server lifecycle)
    if (!_cachedFileExists(phpExe)) {
      request.response.statusCode = 500;
      request.response.headers.contentType = ContentType.html;
      request.response.write(_errorPage(500, 'PHP Belum Terpasang', 'PHP versi <code>${phpModel.name}</code> belum terpasang.'));
      await request.response.close();
      return;
    }

    if (!_cachedFileExists(cgiPath)) {
      request.response.statusCode = 500;
      request.response.headers.contentType = ContentType.html;
      request.response.write(_errorPage(
        500,
        'Binary php-cgi.exe Tidak Ditemukan',
        'PHP versi <strong>${phpModel.name}</strong> di folder <code>${phpModel.dirPath}</code> tidak memiliki berkas <code>php-cgi.exe</code>.<br><br>'
        'Devlika Stack memerlukan <code>php-cgi.exe</code> untuk menjalankan website tanpa menghasilkan halaman kosong (blank).<br>'
        'Silakan unduh atau pasang ulang versi ini di menu <strong>Runtime & Bahasa &rarr; PHP Engine</strong>.',
      ));
      await request.response.close();
      return;
    }

    // Start building environment while also reading body (parallelize for POST)
    var host = request.headers.value('host') ?? 'localhost';
    if (host.contains(':')) host = host.split(':')[0];

    final requestUri = request.uri.hasQuery
        ? '${request.uri.path}?${request.uri.query}'
        : request.uri.path;

    final isHttps = request.connectionInfo?.localPort == 443 ||
        request.certificate != null ||
        request.headers.value('x-forwarded-proto') == 'https';

    // Read request body (non-blocking for GET/HEAD which have empty bodies)
    final bodyBytes = await _readRequestBody(request);
    if (bodyBytes == null) {
      request.response.statusCode = HttpStatus.requestEntityTooLarge;
      request.response.headers.contentType = ContentType.html;
      request.response.write(_errorPage(413, 'Payload Terlalu Besar (413)', 'Ukuran payload request melebihi batas maksimum 128 MB.'));
      await request.response.close();
      return;
    }

    final env = <String, String>{
      'GATEWAY_INTERFACE': 'CGI/1.1',
      'SERVER_SOFTWARE': 'DevlikaStack/2.0 (Portable)',
      'SERVER_PROTOCOL': 'HTTP/1.1',
      'REQUEST_METHOD': request.method,
      'REQUEST_URI': requestUri,
      'SCRIPT_FILENAME': scriptPath,
      'SCRIPT_NAME': scriptName,
      'PATH_INFO': pathInfo,
      'PHP_SELF': pathInfo.isNotEmpty ? '$scriptName$pathInfo' : scriptName,
      'QUERY_STRING': request.uri.query,
      'DOCUMENT_ROOT': docRoot,
      'SERVER_NAME': host,
      'HTTP_HOST': host,
      'SERVER_PORT': isHttps ? '${ConfigService.instance.httpsPort}' : '${request.connectionInfo?.localPort ?? ConfigService.instance.httpPort}',
      'SERVER_ADDR': '127.0.0.1',
      'REMOTE_ADDR': request.connectionInfo?.remoteAddress.address ?? '127.0.0.1',
      'REMOTE_PORT': '${request.connectionInfo?.remotePort ?? 0}',
      'REDIRECT_STATUS': '200',
      'CONTENT_LENGTH': bodyBytes.length.toString(),
      'REQUEST_SCHEME': isHttps ? 'https' : 'http',
    };

    if (isHttps) {
      env['HTTPS'] = 'on';
    }

    if (customEnv != null && customEnv.isNotEmpty) {
      env.addAll(customEnv);
    }

    // Cached php.ini existence check
    final phpIniPath = phpModel.phpIni;
    final phpIniExists = _phpIniExistsCache[phpIniPath] ??= File(phpIniPath).existsSync();
    if (phpIniExists) {
      env['PHPRC'] = phpModel.dirPath;
    }

    // Forward HTTP Headers (Filter out Proxy header to prevent HTTPOXY CVE-2016-5385)
    request.headers.forEach((name, values) {
      if (name.toLowerCase() == 'proxy') return;
      final headerKey = 'HTTP_${name.toUpperCase().replaceAll('-', '_')}';
      env[headerKey] = values.join(', ');
      if (name.toLowerCase() == 'content-type') env['CONTENT_TYPE'] = values.join(', ');
    });
    env.remove('HTTP_PROXY');

    // Explicit Authorization header for Laravel Sanctum, Passport & JWT
    final authHeader = request.headers.value('authorization');
    if (authHeader != null && authHeader.isNotEmpty) {
      env['HTTP_AUTHORIZATION'] = authHeader;
      env['REDIRECT_HTTP_AUTHORIZATION'] = authHeader;
    }

    try {
      // ===== FAST PATH: Use FastCGI daemon matching EXACT PHP version =====
      final fcgiClient = await _getOrStartFastCgiClient(phpModel);
      if (fcgiClient != null) {
        // Add php.ini overrides as PHP_VALUE / PHP_ADMIN_VALUE params
        if (phpIniOverrides != null && phpIniOverrides.isNotEmpty) {
          final phpValueParts = <String>[];
          phpIniOverrides.forEach((key, val) {
            phpValueParts.add('$key=$val');
          });
          env['PHP_VALUE'] = phpValueParts.join('\n');
        }

        final fcgiResult = await fcgiClient.execute(
          params: env,
          stdinData: bodyBytes,
        );

        if (fcgiResult.success && fcgiResult.stdout.isNotEmpty) {
          // Log PHP errors from FastCGI stderr
          if (fcgiResult.stderr.isNotEmpty) {
            final errMsg = utf8.decode(fcgiResult.stderr, allowMalformed: true).trim();
            if (errMsg.isNotEmpty) {
              _logController.add('[PHP Error ${phpModel.versionKey}] $errMsg');
            }
          }
          _sendCgiResponse(request.response, fcgiResult.stdout, customHeaders: customHeaders);
          return;
        }

        // FastCGI failed — fall through to Process.start() fallback
        if (!fcgiResult.success) {
          _logController.add('[FastCGI ${phpModel.versionKey}] Koneksi gagal, fallback ke Process.start()...');
        }
      }

      // ===== FALLBACK: Classic Process.start() (slower but always works) =====
      // Use pre-computed base args (cached per PHP version, zero disk I/O)
      final baseArgs = _getBasePhpArgs(phpModel);
      final phpArgs = List<String>.from(baseArgs);

      // Inject php_value / php_flag from .htaccess
      if (phpIniOverrides != null && phpIniOverrides.isNotEmpty) {
        phpIniOverrides.forEach((key, val) {
          phpArgs.addAll(['-d', '$key=$val']);
        });
      }

      // Strictly isolate PATH with this PHP version and extension directory
      final isolatedEnv = Map<String, String>.from(env);
      final extDir = p.join(phpModel.dirPath, 'ext');
      isolatedEnv['PATH'] = '${phpModel.dirPath};$extDir;${Platform.environment['PATH'] ?? ''}';

      final process = await Process.start(
        phpExe,
        phpArgs,
        environment: isolatedEnv,
        workingDirectory: docRoot,
      );

      if (bodyBytes.isNotEmpty) {
        process.stdin.add(bodyBytes);
      }
      await process.stdin.close();

      // Consume both stdout and stderr in parallel with zero-copy BytesBuilder to prevent OS buffer deadlock
      final stdoutFuture = _collectBytes(process.stdout);
      final stderrFuture = _collectBytes(process.stderr);

      final results = await Future.wait([stdoutFuture, stderrFuture])
          .timeout(const Duration(seconds: 30), onTimeout: () {
        try {
          process.kill();
          if (Platform.isWindows) {
            Process.run('taskkill', ['/F', '/PID', '${process.pid}']);
          }
        } catch (_) {}
        _logController.add('[PHP Timeout] Script $scriptPath melebihi batas 30 detik.');
        return [utf8.encode('PHP execution timeout (30s)'), <int>[]];
      });

      final output = results[0];
      final stderrOutput = results[1];

      // Log PHP errors/warnings for debugging
      if (stderrOutput.isNotEmpty) {
        final errMsg = utf8.decode(stderrOutput, allowMalformed: true).trim();
        if (errMsg.isNotEmpty) {
          _logController.add('[PHP Error] $errMsg');
        }
      }

      _sendCgiResponse(request.response, output, customHeaders: customHeaders);
    } catch (e) {
      try {
        request.response.statusCode = 500;
        request.response.write('PHP Process Error: $e');
        await request.response.close();
      } catch (_) {}
    }
  }

  void _sendCgiResponse(HttpResponse response, List<int> output, {Map<String, String>? customHeaders}) {
    if (output.isEmpty) {
      response.statusCode = 500;
      response.headers.contentType = ContentType.html;
      response.write(_errorPage(
        500,
        'PHP Tidak Menghasilkan Output (Empty Response)',
        'Skrip PHP berhenti atau keluar tanpa menghasilkan output maupun header HTTP.<br><br>'
        'Kemungkinan penyebab:<br>'
        '&bull; Skrip PHP memicu fatal error sebelum buffer dicetak (periksa tab <strong>Log Server</strong>).<br>'
        '&bull; Binary PHP memerlukan dependensi Visual C++ Redistributable.<br>'
        '&bull; Berkas ekstensi di <code>php.ini</code> tidak cocok atau modul crash.',
      ));
      response.close();
      return;
    }

    int headerEnd = -1;
    int delimLen = 0;

    for (int i = 0; i < output.length - 1; i++) {
      if (output[i] == 10 && output[i + 1] == 10) { // \n\n
        headerEnd = i;
        delimLen = 2;
        break;
      }
      if (i < output.length - 3 && output[i] == 13 && output[i + 1] == 10 && output[i + 2] == 13 && output[i + 3] == 10) { // \r\n\r\n
        headerEnd = i;
        delimLen = 4;
        break;
      }
    }

    if (headerEnd == -1) {
      response.statusCode = 200;
      customHeaders?.forEach((k, v) {
        try {
          response.headers.set(k, v);
        } catch (_) {}
      });
      response.add(output);
      response.close();
      return;
    }

    final headerString = utf8.decode(output.sublist(0, headerEnd), allowMalformed: true);
    final bodyBytes = output.sublist(headerEnd + delimLen);

    for (var line in headerString.split(RegExp(r'\r?\n'))) {
      if (line.trim().isEmpty) continue;
      final colon = line.indexOf(':');
      if (colon > 0) {
        final key = line.substring(0, colon).trim();
        final value = line.substring(colon + 1).trim();
        if (key.toLowerCase() == 'status') {
          final parts = value.split(' ');
          response.statusCode = int.tryParse(parts[0]) ?? 200;
        } else if (key.toLowerCase() == 'set-cookie') {
          try {
            response.headers.add(key, value);
          } catch (_) {}
        } else {
          try {
            response.headers.set(key, value);
          } catch (_) {}
        }
      }
    }

    // Apply custom response headers (e.g. Header set from .htaccess)
    customHeaders?.forEach((k, v) {
      try {
        response.headers.set(k, v);
      } catch (_) {}
    });

    response.add(bodyBytes);
    response.close();
  }

  // Static cache extension set for fast lookup
  static const _staticCacheExts = <String>{
    '.css', '.js', '.mjs', '.png', '.jpg', '.jpeg', '.gif',
    '.webp', '.svg', '.ico', '.woff', '.woff2', '.ttf', '.otf',
    '.pdf', '.mp4', '.webm',
  };

  Future<void> _serveStaticFile(HttpRequest request, File file, {Map<String, String>? customHeaders}) async {
    final ext = p.extension(file.path).toLowerCase();
    request.response.headers.contentType = _getContentType(ext);

    // Support HTTP Caching (304 Not Modified) and Content-Length
    FileStat? stat;
    DateTime? lastModified;
    try {
      stat = file.statSync();
      lastModified = stat.modified;
      request.response.headers.set(HttpHeaders.lastModifiedHeader, HttpDate.format(lastModified));
      request.response.contentLength = stat.size;

      // Cache-Control for static assets (images, fonts, css, js) to eliminate roundtrip latency
      if (_staticCacheExts.contains(ext)) {
        request.response.headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=86400, immutable');
        // ETag for even faster cache validation
        request.response.headers.set('ETag', '"${stat.size}-${lastModified.millisecondsSinceEpoch}"');
      }

      // Check If-None-Match (ETag) first for fastest 304
      final ifNoneMatch = request.headers.value('if-none-match');
      if (ifNoneMatch != null) {
        final expectedEtag = '"${stat.size}-${lastModified.millisecondsSinceEpoch}"';
        if (ifNoneMatch == expectedEtag) {
          request.response.statusCode = HttpStatus.notModified;
          await request.response.close();
          return;
        }
      }

      final ifModifiedSinceStr = request.headers.value(HttpHeaders.ifModifiedSinceHeader);
      if (ifModifiedSinceStr != null) {
        try {
          final ifModifiedSince = HttpDate.parse(ifModifiedSinceStr);
          if (!lastModified.isAfter(ifModifiedSince)) {
            request.response.statusCode = HttpStatus.notModified;
            await request.response.close();
            return;
          }
        } catch (_) {}
      }
    } catch (_) {}

    // Keep-Alive header for persistent connections
    request.response.headers.set('Connection', 'keep-alive');

    customHeaders?.forEach((k, v) {
      try {
        request.response.headers.set(k, v);
      } catch (_) {}
    });

    if (request.method == 'HEAD') {
      await request.response.close();
      return;
    }

    // Fast RAM Cache for files <= 2MB to eliminate disk I/O on repeated asset loads
    if (stat != null && lastModified != null && stat.size <= 2 * 1024 * 1024) {
      List<int>? bytes;
      final cached = _staticFileCache[file.path];
      if (cached != null && cached.modified == lastModified) {
        bytes = cached.bytes;
      } else {
        try {
          bytes = await file.readAsBytes();
          if (_staticFileCache.length > 500) {
            _staticFileCache.clear();
          }
          _staticFileCache[file.path] = _StaticFileCacheEntry(bytes, lastModified, stat.size);
        } catch (_) {}
      }

      if (bytes != null) {
        try {
          request.response.add(bytes);
          await request.response.close();
          return;
        } catch (_) {
          try {
            await request.response.close();
          } catch (_) {}
          return;
        }
      }
    }

    try {
      await file.openRead().pipe(request.response);
    } catch (_) {
      // Client disconnected early (e.g. cancelled stream or closed tab)
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  ContentType _getContentType(String ext) {
    switch (ext) {
      case '.html':
      case '.htm':
        return ContentType.html;
      case '.css':
        return ContentType('text', 'css', charset: 'utf-8');
      case '.js':
      case '.mjs':
        return ContentType('application', 'javascript', charset: 'utf-8');
      case '.json':
        return ContentType.json;
      case '.png':
        return ContentType('image', 'png');
      case '.jpg':
      case '.jpeg':
        return ContentType('image', 'jpeg');
      case '.gif':
        return ContentType('image', 'gif');
      case '.webp':
        return ContentType('image', 'webp');
      case '.svg':
        return ContentType('image', 'svg+xml');
      case '.ico':
        return ContentType('image', 'x-icon');
      case '.woff':
        return ContentType('font', 'woff');
      case '.woff2':
        return ContentType('font', 'woff2');
      case '.ttf':
        return ContentType('font', 'ttf');
      case '.otf':
        return ContentType('font', 'otf');
      case '.pdf':
        return ContentType('application', 'pdf');
      case '.xml':
        return ContentType('application', 'xml', charset: 'utf-8');
      case '.mp4':
        return ContentType('video', 'mp4');
      case '.webm':
        return ContentType('video', 'webm');
      case '.map':
        return ContentType('application', 'json', charset: 'utf-8');
      case '.txt':
        return ContentType.text;
      default:
        return ContentType.binary;
    }
  }

  Future<List<int>?> _readRequestBody(HttpRequest request, {int maxBytes = 128 * 1024 * 1024}) async {
    if (request.method == 'GET' || request.method == 'HEAD') {
      return const <int>[];
    }
    final builder = BytesBuilder(copy: false);
    int received = 0;
    try {
      await for (final chunk in request.timeout(const Duration(seconds: 60))) {
        received += chunk.length;
        if (received > maxBytes) {
          return null;
        }
        builder.add(chunk);
      }
    } catch (_) {
      // Timeout or client abort
      return null;
    }
    return builder.takeBytes();
  }

  Future<void> _handleProxy(HttpRequest request, int targetPort) async {
    final targetUrl = 'http://127.0.0.1:$targetPort${request.uri.path}${request.uri.hasQuery ? '?${request.uri.query}' : ''}';
    final bodyBytes = await _readRequestBody(request);
    if (bodyBytes == null) {
      request.response.statusCode = HttpStatus.requestEntityTooLarge;
      request.response.headers.contentType = ContentType.html;
      request.response.write(_errorPage(413, 'Payload Terlalu Besar (413)', 'Ukuran payload request melebihi batas maksimum 128 MB.'));
      await request.response.close();
      return;
    }

    try {
      final req = http.Request(request.method, Uri.parse(targetUrl));
      request.headers.forEach((name, values) {
        if (name.toLowerCase() != 'host') {
          req.headers[name] = values.join(', ');
        }
      });
      req.bodyBytes = bodyBytes;

      final streamedResponse = await _proxyClient.send(req);
      request.response.statusCode = streamedResponse.statusCode;
      streamedResponse.headers.forEach((name, value) {
        try {
          request.response.headers.set(name, value);
        } catch (_) {}
      });

      await streamedResponse.stream.pipe(request.response);
    } catch (e) {
      request.response.statusCode = 502;
      request.response.headers.contentType = ContentType.html;
      request.response.write(_errorPage(502, 'Bad Gateway', 'Aplikasi pada port <code>$targetPort</code> tidak merespons.<br><small>$e</small>'));
      await request.response.close();
    }
  }

  Future<void> _serveWelcomePage(HttpRequest request, String host) async {
    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType.html;
    request.response.write('''<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Devlika Stack - Local Web Environment</title>
    <style>
        body { background: #0A0D14; color: #F3F4F6; font-family: 'Segoe UI', system-ui, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        .card { background: #161B26; border: 1px solid #232B3B; border-radius: 16px; padding: 40px; text-align: center; max-width: 500px; box-shadow: 0 20px 40px rgba(0,0,0,0.6); }
        h1 { color: #00D2FF; margin-top: 0; font-size: 26px; }
        p { color: #9CA3AF; line-height: 1.6; }
        .badge { display: inline-block; background: rgba(0,210,255,0.15); color: #00D2FF; border: 1px solid rgba(0,210,255,0.3); padding: 4px 14px; border-radius: 20px; font-weight: 600; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="card">
        <h1>DevlikaStack</h1>
        <div class="badge">Host: $host</div>
        <p>Domain ini belum dikonfigurasi ke direktori root. Buka <b>DevlikaStack</b> lalu tambahkan konfigurasi virtual host untuk domain ini.</p>
    </div>
</body>
</html>''');
    await request.response.close();
  }

  String _errorPage(int code, String title, String desc) {
    return '''<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>$code - $title</title>
<style>body{background:#0A0D14;color:#F3F4F6;font-family:'Segoe UI',sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;}
.card{background:#161B26;border:1px solid #232B3B;border-radius:16px;padding:36px;text-align:center;max-width:480px;}
h1{color:#FF5252;font-size:36px;margin:0 0 10px;}h2{color:#F3F4F6;margin:0 0 12px;}p{color:#9CA3AF;line-height:1.5;}code{background:#10141D;padding:3px 8px;border-radius:6px;color:#00D2FF;}</style>
</head><body><div class="card"><h1>$code</h1><h2>$title</h2><p>$desc</p></div></body></html>''';
  }
}

class _StaticFileCacheEntry {
  final List<int> bytes;
  final DateTime modified;
  final int size;
  _StaticFileCacheEntry(this.bytes, this.modified, this.size);
}

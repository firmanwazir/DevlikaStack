import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'config_service.dart';
import 'http_server_service.dart';
import 'vhost_config_generator.dart';
import '../models/php_version_model.dart';

class WebServerEngineManager extends ChangeNotifier {
  static final WebServerEngineManager instance = WebServerEngineManager._();
  WebServerEngineManager._();

  Process? _fastCgiProcess;
  Process? _nginxProcess;
  Process? _apacheProcess;

  bool _isNginxRunning = false;
  bool _isApacheRunning = false;
  bool _isFastCgiRunning = false;

  bool get isFastCgiRunning => _isFastCgiRunning;

  String get activeEngine => ConfigService.instance.activeWebEngine;

  bool get isRunning {
    switch (activeEngine) {
      case 'nginx':
        return _isNginxRunning;
      case 'apache':
        return _isApacheRunning;
      case 'builtin':
      default:
        return HttpServerService.instance.isRunning;
    }
  }

  String get activeEngineDisplayName {
    switch (activeEngine) {
      case 'nginx':
        return 'Nginx 1.26 Portable';
      case 'apache':
        return 'Apache HTTPD 2.4';
      case 'builtin':
      default:
        return 'Devlika Native HTTP Engine';
    }
  }

  Future<bool> checkPortOpen(int port, {int timeoutMs = 300}) async {
    try {
      final socket = await Socket.connect('127.0.0.1', port, timeout: Duration(milliseconds: timeoutMs));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Start active web server engine
  Future<bool> start() async {
    if (activeEngine == 'nginx') {
      return await _startNginx();
    } else if (activeEngine == 'apache') {
      return await _startApache();
    } else {
      return await _startBuiltin();
    }
  }

  /// Stop active web server engine
  Future<void> stop() async {
    await _stopBuiltin();
    await _stopNginx();
    await _stopApache();
    await _stopFastCgi();
    notifyListeners();
  }

  /// Switch active engine safely with mutual exclusion on Port 80
  Future<bool> switchEngine(String newEngine) async {
    if (newEngine != 'builtin' && newEngine != 'nginx' && newEngine != 'apache') {
      return false;
    }

    final wasRunning = isRunning;
    if (wasRunning) {
      await stop();
    }

    ConfigService.instance.setActiveWebEngine(newEngine);

    // Sync vhosts for new engine
    await syncVhosts();

    if (wasRunning) {
      final started = await start();
      notifyListeners();
      return started;
    }

    notifyListeners();
    return true;
  }

  /// Synchronize all virtual host configuration files from sites.json
  Future<void> syncVhosts() async {
    final sites = ConfigService.instance.loadSites();
    HttpServerService.instance.clearDocRootCache();

    // Always generate vhosts so Nginx and Apache are immediately ready with SSL & DocRoots
    try {
      await VhostConfigGenerator.instance.generateNginxConfigs(sites);
      await VhostConfigGenerator.instance.generateApacheConfigs(sites);
    } catch (_) {}

    if (activeEngine == 'nginx' && _isNginxRunning) {
      await _startFastCgi();
      final config = ConfigService.instance;
      try {
        await Process.run(config.nginxExe, ['-p', config.nginxDir, '-s', 'reload']);
      } catch (_) {}
    } else if (activeEngine == 'apache' && _isApacheRunning) {
      await _startFastCgi();
      final config = ConfigService.instance;
      try {
        await Process.run(config.apacheExe, ['-d', config.apacheDir, '-k', 'restart']);
      } catch (_) {}
    }
  }

  // --- Engine Implementations ---

  Future<bool> _startBuiltin() async {
    await _stopNginx();
    await _stopApache();
    await _stopFastCgi();

    final started = await HttpServerService.instance.start();
    notifyListeners();
    return started;
  }

  Future<void> _stopBuiltin() async {
    await HttpServerService.instance.stop();
  }

  Future<bool> _startNginx() async {
    final config = ConfigService.instance;
    if (!File(config.nginxExe).existsSync()) {
      return false;
    }

    await _stopBuiltin();
    await _stopApache();

    // 1. Ensure FastCGI worker is active on port 9000
    final fastCgiOk = await _startFastCgi();
    if (!fastCgiOk) return false;

    // 2. Generate configuration
    await VhostConfigGenerator.instance.generateNginxConfigs(config.loadSites());

    // 3. Start Nginx
    try {
      _nginxProcess = await Process.start(
        config.nginxExe,
        ['-p', config.nginxDir, '-c', 'conf/nginx.conf'],
        runInShell: false,
      );

      // Verify port 80 is listening
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (await checkPortOpen(80)) {
          _isNginxRunning = true;
          notifyListeners();
          return true;
        }
      }

      _isNginxRunning = await checkPortOpen(80);
      notifyListeners();
      return _isNginxRunning;
    } catch (_) {
      _isNginxRunning = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _stopNginx() async {
    final config = ConfigService.instance;
    if (File(config.nginxExe).existsSync()) {
      try {
        await Process.run(config.nginxExe, ['-p', config.nginxDir, '-s', 'stop']);
      } catch (_) {}
    }
    if (_nginxProcess != null) {
      try {
        _nginxProcess!.kill();
      } catch (_) {}
      _nginxProcess = null;
    }
    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/F', '/T', '/IM', 'nginx.exe']);
      } catch (_) {}
    }
    _isNginxRunning = false;
  }

  Future<bool> _startApache() async {
    final config = ConfigService.instance;
    if (!File(config.apacheExe).existsSync()) {
      return false;
    }

    await _stopBuiltin();
    await _stopNginx();

    // 1. Ensure FastCGI worker is active on port 9000
    final fastCgiOk = await _startFastCgi();
    if (!fastCgiOk) return false;

    // 2. Generate configuration
    await VhostConfigGenerator.instance.generateApacheConfigs(config.loadSites());

    // 3. Start Apache HTTPD
    try {
      _apacheProcess = await Process.start(
        config.apacheExe,
        ['-d', config.apacheDir, '-f', 'conf/httpd.conf'],
        runInShell: false,
      );

      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (await checkPortOpen(80)) {
          _isApacheRunning = true;
          notifyListeners();
          return true;
        }
      }

      _isApacheRunning = await checkPortOpen(80);
      notifyListeners();
      return _isApacheRunning;
    } catch (_) {
      _isApacheRunning = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _stopApache() async {
    final config = ConfigService.instance;
    if (File(config.apacheExe).existsSync()) {
      try {
        await Process.run(config.apacheExe, ['-d', config.apacheDir, '-k', 'stop']);
      } catch (_) {}
    }
    if (_apacheProcess != null) {
      try {
        _apacheProcess!.kill();
      } catch (_) {}
      _apacheProcess = null;
    }
    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/F', '/T', '/IM', 'httpd.exe']);
      } catch (_) {}
    }
    _isApacheRunning = false;
  }

  // --- FastCGI Daemon Manager ---

  final List<Process> _fastCgiProcesses = [];

  Future<bool> _startFastCgi() async {
    final config = ConfigService.instance;
    bool anyStarted = false;

    // 1. Start Default PHP Multi-Worker Pool on ports 9000..9003
    final defaultPorts = VhostConfigGenerator.getFastCgiPorts('default');
    final defaultModel = config.getPhpForSite('default');
    final defaultCgi = defaultModel.phpCgiExe;

    if (File(defaultCgi).existsSync()) {
      final defaultExtDir = p.join(defaultModel.dirPath, 'ext');
      for (final port in defaultPorts) {
        if (await checkPortOpen(port)) {
          anyStarted = true;
          continue;
        }
        try {
          final defaultArgs = _buildFastCgiArgs(defaultModel, port);
          final proc = await Process.start(
            defaultCgi,
            defaultArgs,
            runInShell: false,
            mode: ProcessStartMode.normal,
            workingDirectory: defaultModel.dirPath,
            environment: {
              'PHP_FCGI_CHILDREN': '0',
              'PHP_FCGI_MAX_REQUESTS': '10000',
              if (File(defaultModel.phpIni).existsSync()) 'PHPRC': defaultModel.dirPath,
              'PATH': '${defaultModel.dirPath};$defaultExtDir;${Platform.environment['PATH'] ?? ''}',
            },
          );
          _fastCgiProcesses.add(proc);
          for (int i = 0; i < 15; i++) {
            await Future.delayed(const Duration(milliseconds: 100));
            if (await checkPortOpen(port)) {
              anyStarted = true;
              break;
            }
          }
        } catch (_) {}
      }
    }

    // 2. Start other required PHP version worker pools (e.g. 7.4 on 9074..9077, 8.1 on 9084..9087)
    final sites = config.loadSites();
    final neededVersions = sites
        .where((s) => s.isEnabled && s.type == 'php' && s.phpVersion.isNotEmpty && s.phpVersion != 'default')
        .map((s) => ConfigService.normalizePhpVersionKey(s.phpVersion))
        .toSet();

    for (var ver in neededVersions) {
      final ports = VhostConfigGenerator.getFastCgiPorts(ver);
      final phpModel = config.getPhpForSite(ver);
      final cgiExe = phpModel.phpCgiExe;
      if (File(cgiExe).existsSync() && cgiExe.toLowerCase().contains('cgi')) {
        final extDir = p.join(phpModel.dirPath, 'ext');
        for (final port in ports) {
          if (await checkPortOpen(port)) continue;
          try {
            final args = _buildFastCgiArgs(phpModel, port);
            final proc = await Process.start(
              cgiExe,
              args,
              runInShell: false,
              mode: ProcessStartMode.normal,
              workingDirectory: phpModel.dirPath,
              environment: {
                'PHP_FCGI_CHILDREN': '0',
                'PHP_FCGI_MAX_REQUESTS': '10000',
                if (File(phpModel.phpIni).existsSync()) 'PHPRC': phpModel.dirPath,
                'PATH': '${phpModel.dirPath};$extDir;${Platform.environment['PATH'] ?? ''}',
              },
            );
            _fastCgiProcesses.add(proc);
            for (int i = 0; i < 15; i++) {
              await Future.delayed(const Duration(milliseconds: 100));
              if (await checkPortOpen(port)) break;
            }
          } catch (_) {}
        }
      }
    }

    _isFastCgiRunning = anyStarted || await checkPortOpen(9000);
    return _isFastCgiRunning;
  }

  Future<void> _stopFastCgi() async {
    for (var p in _fastCgiProcesses) {
      try {
        p.kill();
      } catch (_) {}
    }
    _fastCgiProcesses.clear();

    if (_fastCgiProcess != null) {
      try {
        _fastCgiProcess!.kill();
      } catch (_) {}
      _fastCgiProcess = null;
    }
    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/F', '/T', '/IM', 'php-cgi.exe']);
      } catch (_) {}
    }
    _isFastCgiRunning = false;
  }

  List<String> _buildFastCgiArgs(PhpVersionModel phpModel, int port) {
    final config = ConfigService.instance;
    final extDir = p.join(phpModel.dirPath, 'ext');
    final sessionDir = p.join(config.storageDir, 'sessions');
    final uploadDir = p.join(config.storageDir, 'temp');
    final opcacheDir = p.join(config.storageDir, 'opcache', 'php-${phpModel.versionKey}');

    for (final dir in [sessionDir, uploadDir, opcacheDir]) {
      try {
        Directory(dir).createSync(recursive: true);
      } catch (_) {}
    }

    return [
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
  }
}

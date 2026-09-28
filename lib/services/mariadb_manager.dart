import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'config_service.dart';

class MariaDbManager {
  static final MariaDbManager instance = MariaDbManager._();
  MariaDbManager._();

  Process? _process;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  Future<bool> checkPortOpen(int port) async {
    try {
      final socket = await Socket.connect('127.0.0.1', port,
          timeout: const Duration(milliseconds: 300));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> start() async {
    if (_isRunning) return true;

    // Check if MariaDB is already open on port 3306
    if (await checkPortOpen(3306)) {
      _isRunning = true;
      _logController.add('[MariaDB] Port 3306 aktif dan siap digunakan.');
      return true;
    }

    final config = ConfigService.instance;
    final exe = config.mariaDbExe;

    if (!File(exe).existsSync()) {
      _logController.add('[MariaDB Error] mysqld.exe tidak ditemukan di $exe');
      return false;
    }

    config.ensureDirectories();
    final myIniPath = ensureMyIni();

    try {
      final args = [
        if (myIniPath != null) '--defaults-file=$myIniPath',
        '--datadir=${config.mariaDbDataDir}',
        '--port=3306',
        '--bind-address=127.0.0.1,::1',
        '--skip-name-resolve',
        '--skip-host-cache',
        '--max_allowed_packet=1024M',
        '--innodb-buffer-pool-size=512M',
        '--innodb-flush-log-at-trx-commit=2',
        '--innodb-io-capacity=1000',
        '--innodb-io-capacity-max=2000',
      ];

      _process = await Process.start(
        exe,
        args,
        runInShell: false,
        mode: ProcessStartMode.normal,
      );

      _process!.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
        for (var line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            _logController.add('[MariaDB] ${line.trim()}');
          }
        }
      });

      _process!.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
        for (var line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            _logController.add('[MariaDB] ${line.trim()}');
          }
        }
      });

      // Poll until port 3306 is open (up to 4 seconds)
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (await checkPortOpen(3306)) {
          _isRunning = true;
          _logController.add('[MariaDB] Berhasil berjalan di port 3306.');
          return true;
        }
      }

      _isRunning = true;
      return true;
    } catch (e) {
      _logController.add('[MariaDB Error] Gagal menjalankan MariaDB: $e');
      return false;
    }
  }

  Future<void> stop() async {
    final config = ConfigService.instance;
    final mysqlAdmin = File(p.join(config.mariaDbDir, 'bin', 'mysqladmin.exe')).existsSync()
        ? p.join(config.mariaDbDir, 'bin', 'mysqladmin.exe')
        : (File(p.join(config.mariaDbDir, 'bin', 'mariadb-admin.exe')).existsSync()
            ? p.join(config.mariaDbDir, 'bin', 'mariadb-admin.exe')
            : null);

    // 1. Attempt graceful shutdown via mysqladmin (flushes tables and avoids InnoDB corruption)
    if (mysqlAdmin != null && (_isRunning || _process != null)) {
      try {
        _logController.add('[MariaDB] Mengirim sinyal graceful shutdown...');
        await Process.run(
          mysqlAdmin,
          ['-u', 'root', '--port=3306', 'shutdown'],
        ).timeout(const Duration(seconds: 2));

        // Wait briefly for port to close
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 150));
          if (!await checkPortOpen(3306)) break;
        }
      } catch (_) {}
    }

    // 2. Terminate tracked process if still alive
    if (_process != null) {
      final pid = _process!.pid;
      try {
        _process!.kill(ProcessSignal.sigterm);
        await Future.delayed(const Duration(milliseconds: 300));
        // Force kill only OUR tracked PID if still active
        await Process.run('taskkill', ['/F', '/PID', '$pid']);
      } catch (_) {}
      _process = null;
    }

    // 3. Fallback kill if port is still occupied
    if (await checkPortOpen(3306) && Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/F', '/IM', 'mysqld.exe']);
      } catch (_) {}
    }

    _isRunning = false;
    _logController.add('[MariaDB] Servis MariaDB dihentikan.');
  }

  Future<void> initializeDatabase() async {
    final config = ConfigService.instance;
    config.ensureDirectories();

    final mysqlDbDir = Directory('${config.mariaDbDataDir}\\mysql');
    if (mysqlDbDir.existsSync()) return; // Already initialized

    final installer = File(config.mariaDbInstallDbExe).existsSync()
        ? config.mariaDbInstallDbExe
        : (File(config.mariaDbFallbackInstallExe).existsSync()
            ? config.mariaDbFallbackInstallExe
            : null);

    if (installer != null) {
      try {
        await Process.run(
          installer,
          ['--datadir=${config.mariaDbDataDir}'],
        );
        _logController.add('[MariaDB Init] Database default diinisialisasi.');
      } catch (e) {
        _logController.add('[MariaDB Init Error] $e');
      }
    }
  }

  String? ensureMyIni() {
    final config = ConfigService.instance;
    final iniPath = p.join(config.mariaDbDir, 'my.ini');
    try {
      final file = File(iniPath);
      if (!file.existsSync()) {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('''# DevlikaStack MariaDB Turbo Configuration
[mysqld]
port = 3306
bind-address = 127.0.0.1,::1

# Network & DNS Optimization (Eliminates localhost / reverse DNS delay)
skip-name-resolve
skip-host-cache

# Connections & Concurrency
max_connections = 150
thread_cache_size = 64
table_open_cache = 2000
table_definition_cache = 2000
max_allowed_packet = 128M

# InnoDB Windows NTFS Optimization (5-10x faster queries)
innodb_buffer_pool_size = 512M
innodb_log_file_size = 64M
innodb_log_buffer_size = 16M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = normal
innodb_file_per_table = 1
innodb_io_capacity = 1000
innodb_io_capacity_max = 2000
innodb_read_io_threads = 4
innodb_write_io_threads = 4

# Timeouts
connect_timeout = 10
wait_timeout = 600
interactive_timeout = 600

# Character Set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[client]
port = 3306
default-character-set = utf8mb4

[mysql]
default-character-set = utf8mb4
''');
      }

      // Clean up legacy my.ini in data dir if it contains stale hardcoded absolute paths
      final legacyDataIni = File(p.join(config.mariaDbDataDir, 'my.ini'));
      if (legacyDataIni.existsSync()) {
        try {
          final content = legacyDataIni.readAsStringSync();
          if (content.contains('/Server/data/mariadb') || content.contains('plugin-dir')) {
            legacyDataIni.deleteSync();
          }
        } catch (_) {}
      }

      return iniPath;
    } catch (_) {
      return null;
    }
  }
}
